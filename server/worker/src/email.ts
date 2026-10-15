import { z } from 'zod'
import { extractReceipts, resolveReceivedAt, BATCH_SIZE } from '../../src/receipts.js'
import type { TextCompleter } from '../../src/pal.js'

// Wire shape returned to the client; kept 1:1 with server/src/email.ts
// EmailImportDto so the client's import path (EmailImportItem) needs no change.
export interface EmailImportDto {
  id: string
  merchant: string
  amount: number // negative = expense (client convention)
  receivedAt: string // ISO 8601
  category: string | null
  orderRef: string | null // the order number the email states; null when none
}

// One sanitized receipt candidate. The native client owns IMAP, MIME parsing,
// sender filtering, dedup, body bounds, and PII redaction — the Worker never
// sees credentials or unredacted bodies. `envelopeDate` is the IMAP envelope
// date; the transaction date is re-derived server-side from `text`. `from` is
// the merchant sender address (not user PII) and is left intact for merchant
// inference. Bounds are defensive: the client already caps body size.
export const emailCandidate = z.object({
  id: z.string().min(1).max(998),
  from: z.string().max(320),
  subject: z.string().max(1000),
  text: z.string().max(8000),
  envelopeDate: z.string().refine((s) => !Number.isNaN(Date.parse(s)), 'invalid date'),
})
export type EmailCandidate = z.infer<typeof emailCandidate>

// One request == one batch == one LLM call. Bounded to BATCH_SIZE so a request
// maps to a single extractReceipts call; the client owns the loop across batches.
export const emailExtractBody = z.object({
  candidates: z.array(emailCandidate).min(1).max(BATCH_SIZE),
})
export type EmailExtractBody = z.infer<typeof emailExtractBody>

// Model-extract receipts for one sanitized batch and map each hit onto the
// client import wire shape. extractReceipts re-applies redactPii (idempotent)
// as defense-in-depth, gates isReceipt, and returns one slot per input in order.
export async function extractFromCandidates(
  candidates: EmailCandidate[],
  completer: TextCompleter,
): Promise<EmailImportDto[]> {
  const emails = candidates.map((c) => ({
    messageId: c.id,
    from: c.from,
    fromName: '',
    subject: c.subject,
    date: new Date(c.envelopeDate),
    text: c.text,
  }))
  const fields = await extractReceipts(emails, completer)
  const items: EmailImportDto[] = []
  fields.forEach((f, i) => {
    if (!f) return
    const c = candidates[i]
    items.push({
      id: c.id,
      merchant: f.merchant,
      amount: -Math.abs(f.amount), // receipts are expenses
      receivedAt: resolveReceivedAt(c.text, new Date(c.envelopeDate)).toISOString(),
      category: f.category,
      orderRef: f.orderRef,
    })
  })
  return items
}
