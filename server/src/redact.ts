// High-confidence, deterministic PII scrubbing applied to email content before
// it leaves for the LLM. Amounts, merchant names and dates are intentionally
// left intact — the receipt extractor needs them. We only mask patterns that
// are both clearly personal and clearly not a monetary total: email addresses,
// phone numbers, card numbers and endings, long account/order numbers, and the
// name or address after a label that marks it as the account holder's.

const EMAIL = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g
// 13-19 digits, contiguous or grouped by single spaces/hyphens (Visa/MC/Amex)
const CARD = /\b\d(?:[ -]?\d){12,18}\b/g
// 3-3-4 with required separators; contiguous runs fall to LONG_NUMBER instead
const PHONE = /(?:\+\d{1,3}[ .-]?)?\(?\d{3}\)?[ .-]\d{3}[ .-]\d{4}\b/g
// 9+ contiguous digits: order/account numbers. Amounts use separators/decimals,
// so they never form a run this long.
const LONG_NUMBER = /\b\d{9,}\b/g
// a card's last four after a card word or mask (`ATM 9816`, `**** 4242`); not
// when a currency follows, so `thẻ 2000đ` stays an amount.
// `(?:[^\S\n]*\n)?[^\S\n]*` below: spaces with at most one line break, since
// receipt tables put a label and its value in separate cells (separate lines).
const CARD_TAIL =
  /((?<!\p{L})(?:atm|visa|mastercard|jcb|amex|thẻ|card|ending in)[^\S\n]*[:#]?(?:[^\S\n]*\n)?[^\S\n]*|[*x•]{2,}[ -]?)\d{4}(?!\d|[.,]\d|[^\S\n]*(?:đ|₫|vnd|usd))/giu
// labels that address the account holder. Beneficiary labels (`Người nhận`,
// `Chủ tài khoản`) are left out: in a transfer they name the merchant.
const NAME_LABEL =
  /(?<!\p{L})(?:kính gửi|người dùng|xin chào|chào|khách hàng|họ và tên|họ tên|dear|hello|hi)(?!\p{L})[^\S\n]*[:,]?(?:[^\S\n]*\n)?[^\S\n]*/giu
// up to five Capitalised words, all on one line. Case-sensitive, apart from
// the label: with the i flag, \p{Lu} would match lowercase too.
const NAME = /\p{Lu}[\p{L}\p{M}'’.-]*(?:[^\S\n]+\p{Lu}[\p{L}\p{M}'’.-]*){0,4}/uy
const ADDRESS =
  /((?<!\p{L})(?:địa chỉ[^:\n]{0,30}:|(?:shipping|delivery|billing) address:?|ship to:|giao đến)(?:[^\S\n]*\n)?[^\S\n]*)[^\n]*\S/giu

/**
 * Mask personal identifiers in free-form email text. Names and addresses are
 * masked only after a label that marks them as the account holder's. Order
 * matters: cards win the [card] label before the generic long-number rule.
 * Mirrors lib/services/email/receipt_filters.dart redactPii.
 */
export function redactPii(input: string): string {
  return redactNames(
    input
      .replace(EMAIL, '[email]')
      .replace(CARD, '[card]')
      .replace(CARD_TAIL, '$1[card]')
      .replace(PHONE, '[phone]')
      .replace(LONG_NUMBER, '[number]')
      .replace(ADDRESS, '$1[address]'),
  )
}

function redactNames(input: string): string {
  let out = ''
  let last = 0
  for (const label of input.matchAll(NAME_LABEL)) {
    const end = label.index + label[0].length
    if (label.index < last) continue
    NAME.lastIndex = end
    const name = NAME.exec(input)
    if (!name) continue
    out += input.slice(last, end) + '[name]'
    last = NAME.lastIndex
  }
  return out + input.slice(last)
}
