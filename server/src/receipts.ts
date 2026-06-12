import { z } from 'zod'
import { extractJson, type TextCompleter } from './pal.js'
import { receiptPrompt } from './prompts.js'
import { redactPii } from './redact.js'
import type { RawEmail } from './imap.js'

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

const receiptSchema = z.object({
  isReceipt: z.boolean(),
  merchant: z.string().nullable(),
  amount: z.number().nullable(),
  category: z.string().nullable(),
})

/** The fields a receipt yields, or null when the email isn't a purchase. */
export interface ReceiptFields {
  merchant: string
  amount: number
  category: string | null
}

/** Model-extract receipt fields from one email; null if not a receipt. */
export async function extractReceipt(
  email: RawEmail,
  client: TextCompleter,
): Promise<ReceiptFields | null> {
  // scrub PII before the body leaves for the LLM; `from` is the merchant's
  // sender address (needed for merchant inference, not the user's data).
  const raw = await client.complete([
    {
      role: 'user',
      content: receiptPrompt({
        from: email.from,
        subject: redactPii(email.subject),
        text: redactPii(email.text),
      }),
    },
  ], { json: true })
  const parsed = receiptSchema.parse(extractJson(raw))
  if (!parsed.isReceipt || parsed.amount === null || !parsed.merchant) return null
  return { merchant: parsed.merchant, amount: parsed.amount, category: parsed.category }
}
