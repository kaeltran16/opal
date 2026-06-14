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

// off-list categories coerce to null, mirroring routineSchema.tag's catch();
// the client treats a null category fine, so an unknown one never crashes.
const receiptResultSchema = z.object({
  index: z.number(),
  isReceipt: z.boolean(),
  merchant: z.string().nullable(),
  amount: z.number().nullable(),
  category: z
    .enum(['Shopping', 'Food', 'Transport', 'Bills', 'Entertainment', 'Health', 'Travel', 'Other'])
    .nullable()
    .catch(null),
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
