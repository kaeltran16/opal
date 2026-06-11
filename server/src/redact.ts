// High-confidence, deterministic PII scrubbing applied to email content before
// it leaves for the LLM. Amounts, merchant names and dates are intentionally
// left intact — the receipt extractor needs them. We only mask patterns that
// are both clearly personal and clearly not a monetary total: email addresses,
// phone numbers, card numbers and long account/order numbers.

const EMAIL = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g
// 13-19 digits, contiguous or grouped by single spaces/hyphens (Visa/MC/Amex)
const CARD = /\b\d(?:[ -]?\d){12,18}\b/g
// 3-3-4 with required separators; contiguous runs fall to LONG_NUMBER instead
const PHONE = /(?:\+\d{1,3}[ .-]?)?\(?\d{3}\)?[ .-]\d{3}[ .-]\d{4}\b/g
// 9+ contiguous digits: order/account numbers. Amounts use separators/decimals,
// so they never form a run this long.
const LONG_NUMBER = /\b\d{9,}\b/g

/** Mask personal identifiers in free-form email text. Order matters: cards win the [card] label before the generic long-number rule. */
export function redactPii(input: string): string {
  return input
    .replace(EMAIL, '[email]')
    .replace(CARD, '[card]')
    .replace(PHONE, '[phone]')
    .replace(LONG_NUMBER, '[number]')
}
