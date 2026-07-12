import { z } from 'zod'
import { extractJson, type TextCompleter } from './pal.js'
import { receiptsBatchPrompt } from './prompts.js'
import { redactPii } from './redact.js'
import type { RawEmail } from './imap.js'

// emails per LLM call; bounds prompt size at BATCH_SIZE x ~4k body chars.
export const BATCH_SIZE = 8

// output budget per email's result object; scaled by batch size so a full batch's
// JSON never trips the default 1024 cap (which would drop the whole batch on a
// finish_reason=length error).
const MAX_TOKENS_PER_RECEIPT = 256

/** Deterministic allowlist: keep emails whose sender matches a filter. */
export function filterBySender(emails: RawEmail[], filters: string[]): RawEmail[] {
  const needles = filters.map((f) => f.trim().toLowerCase()).filter(Boolean)
  // no filters configured → don't drop anything (the model still gates on isReceipt)
  if (!needles.length) return emails
  return emails.filter((e) => {
    const hay = `${e.from} ${e.fromName}`.toLowerCase()
    return needles.some((n) => hay.includes(n))
  })
}

// Subjects/bodies that are NEVER a completed purchase regardless of body
// content. Kept deliberately narrow so a real receipt is never dropped — in
// particular, payment-state wording ("order confirmation", "awaiting payment")
// is left OUT because a paid order-confirmation IS a receipt; the model judges
// those with full context via the prompt's isReceipt rules (#2). Matched
// case-insensitively as substrings.
const NON_RECEIPT_MARKERS = [
  // promotional
  'unsubscribe',
  'refer a friend',
  'invite friends',
  '% off',
  'sale ends',
  // review / feedback requests
  'rate your',
  'how was your',
  'share your feedback',
  'leave a review',
  // fulfilment / logistics status, not a charge
  'out for delivery',
  'has been delivered',
  'delivery completed',
  'has shipped',
  'shipping confirmation',
  'tracking number',
  'track your order',
  'đã giao hàng thành công', // (vi) delivered successfully — logistics, not a charge
  // money moving the other way
  'refund',
]

// Vietnamese promotional wording, matched against the SUBJECT ONLY. Unlike the
// markers above, these (discount/offer phrases) legitimately appear inside a
// real receipt's body — a food-delivery receipt lists a "giảm giá" discount
// line — so body-matching them would drop genuine receipts. In the subject they
// are a safe promo signal. Pending/order-state wording ("đơn hàng đã được
// nhận", "chờ xác nhận") is deliberately excluded, mirroring the English
// payment-state exclusion above.
const PROMO_SUBJECT_MARKERS = [
  'khuyến mãi', // promotion
  'giảm giá', // discount
  'ưu đãi', // offer
  'miễn phí', // free
  'chăm lo', // promotional
  'đặc biệt', // special (offer)
]

/**
 * Deterministic pre-LLM gate (#1): true when an email is almost certainly not a
 * completed purchase (promotional, pending order, delivery/tracking status,
 * refund). Lets the worker skip it before the batch LLM call, cutting cost and
 * false-positive receipts. Deliberately narrow — the model still judges the rest.
 */
export function isLikelyNonReceipt(email: { subject: string; text: string }): boolean {
  const hay = `${email.subject}\n${email.text}`.toLowerCase()
  if (NON_RECEIPT_MARKERS.some((m) => hay.includes(m))) return true
  const subject = email.subject.toLowerCase()
  return PROMO_SUBJECT_MARKERS.some((m) => subject.includes(m))
}

const MONTHS: Record<string, number> = {
  jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5,
  jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11,
}

// Day-first ("06 Jan 26 11:27", "8 November 2025 18:38") and month-first
// ("Jan 06, 2026 11:27") alpha-month dates, plus numeric day-first dates that
// carry a time ("05/06/2025 14:30", the common Shopee/VN receipt format). A
// bare numeric date with no time stays unparsed — locale-ambiguous (May 6 vs
// June 5) — and falls back to the envelope date. A 24h time is optional for
// alpha-month dates.
const MONTH = 'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec'
const TIME = '(?:[\\s,]+(\\d{1,2}):(\\d{2}))?'
const DAY_FIRST = new RegExp(`\\b(\\d{1,2})\\s+(${MONTH})[a-z]*\\.?\\s+(\\d{4}|\\d{2})${TIME}`, 'i')
const MONTH_FIRST = new RegExp(`\\b(${MONTH})[a-z]*\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(\\d{4}|\\d{2})${TIME}`, 'i')
// Numeric DD/MM/YYYY (or DD-MM-YYYY) day-first, time required. Day-first is
// assumed for the VN market; a month field > 12 is rejected rather than guessed
// (so an accidental US MM/DD value falls through to the envelope date).
const NUMERIC_DAY_FIRST = /\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})[\s,]+(\d{1,2}):(\d{2})/

function toDate(year: number, monthIndex: number, day: number, h?: string, mi?: string): { date: Date; hasTime: boolean } {
  const yyyy = year < 100 ? 2000 + year : year
  const hasTime = h !== undefined && mi !== undefined
  return {
    date: new Date(Date.UTC(yyyy, monthIndex, day, hasTime ? Number(h) : 0, hasTime ? Number(mi) : 0)),
    hasTime,
  }
}

/**
 * Best-effort extraction of the transaction date from an email body (#3).
 * Returns the parsed date and whether it carried a time, or null when no
 * unambiguous date is present. Interpreted as UTC — no locale timezone is
 * assumed (unlike the reference impl's hardcoded +07:00), including for the
 * numeric day-first form.
 */
export function extractTxnDate(text: string): { date: Date; hasTime: boolean } | null {
  const df = text.match(DAY_FIRST)
  if (df) return toDate(Number(df[3]), MONTHS[df[2].toLowerCase()], Number(df[1]), df[4], df[5])
  const mf = text.match(MONTH_FIRST)
  if (mf) return toDate(Number(mf[3]), MONTHS[mf[1].toLowerCase()], Number(mf[2]), mf[4], mf[5])
  const nm = text.match(NUMERIC_DAY_FIRST)
  if (nm) {
    const day = Number(nm[1])
    const month = Number(nm[2])
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return toDate(Number(nm[3]), month - 1, day, nm[4], nm[5])
    }
  }
  return null
}

/**
 * The timestamp to stamp on an imported receipt (#3): the transaction date from
 * the body when confidently parsed, else the email's envelope date. A body date
 * without a time keeps the envelope's time-of-day so meal-slot inference (which
 * buckets by hour) stays sensible.
 */
export function resolveReceivedAt(text: string, envelope: Date): Date {
  const t = extractTxnDate(text)
  if (!t) return envelope
  if (t.hasTime) return t.date
  return new Date(Date.UTC(
    t.date.getUTCFullYear(), t.date.getUTCMonth(), t.date.getUTCDate(),
    envelope.getUTCHours(), envelope.getUTCMinutes(), envelope.getUTCSeconds(),
  ))
}

// the receipt categories the model may assign. Kept identical to the client's
// canonical `kSpendCategories` (lib/models/spend_category.dart) so an imported
// receipt's category lines up with a budget envelope and, for 'Food & Drink',
// feeds the nutrition "expense looks like a meal" prompt. off-list values coerce
// to null, mirroring routineSchema.tag's catch(); the client treats null fine.
export const RECEIPT_CATEGORIES = [
  'Food & Drink',
  'Groceries',
  'Bills & Utilities',
  'Shopping',
  'Transport',
  'Entertainment',
  'Health',
] as const

const receiptResultSchema = z.object({
  index: z.number(),
  isReceipt: z.boolean(),
  merchant: z.string().nullable(),
  amount: z.number().nullable(),
  category: z.enum(RECEIPT_CATEGORIES).nullable().catch(null),
})

const receiptsBatchSchema = z.object({ results: z.array(receiptResultSchema) })

/** The fields a receipt yields, or null when the email isn't a purchase. */
export interface ReceiptFields {
  merchant: string
  amount: number
  category: string | null
}

/**
 * Model-extract receipt fields for a batch of emails in one LLM call. Returns
 * one slot per input email in input order; a slot is null when the email isn't
 * a receipt (or its result was missing/duplicate/out-of-range — the model's
 * ordering is never trusted, results are mapped back by index).
 */
export async function extractReceipts(
  emails: RawEmail[],
  client: TextCompleter,
): Promise<(ReceiptFields | null)[]> {
  if (!emails.length) return []
  // scrub PII before the body leaves for the LLM; `from` is the merchant's
  // sender address (needed for merchant inference, not the user's data).
  const raw = await client.complete([
    {
      role: 'user',
      content: receiptsBatchPrompt(
        emails.map((e) => ({
          from: e.from,
          subject: redactPii(e.subject),
          text: redactPii(e.text),
        })),
      ),
    },
  ], { json: true, temperature: 0, maxTokens: emails.length * MAX_TOKENS_PER_RECEIPT })
  const { results } = receiptsBatchSchema.parse(extractJson(raw))

  const out: (ReceiptFields | null)[] = new Array(emails.length).fill(null)
  const filled = new Set<number>()
  for (const r of results) {
    if (r.index < 0 || r.index >= emails.length || filled.has(r.index)) continue
    filled.add(r.index)
    if (!r.isReceipt || r.amount === null || !r.merchant) continue
    out[r.index] = { merchant: r.merchant, amount: r.amount, category: r.category }
  }
  return out
}
