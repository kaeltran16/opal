// The single source of truth for product vocabulary the prompts/schemas import.

// Timeline entry types — the set a /chat log-tool or /parse may emit. NOT
// nutrition: meals live in the Nutrition tab / the log_meal tool, never on the
// entry timeline (the client coerces unknown entry types to money).
export const ENTRY_TYPES = ['money', 'move', 'rituals'] as const
export type EntryTypeToken = (typeof ENTRY_TYPES)[number]

// Trackable dimensions for colour + correlation. Adds nutrition.
export const DIMENSIONS = ['money', 'move', 'rituals', 'nutrition'] as const
export type DimensionToken = (typeof DIMENSIONS)[number]

// One framing sentence every prompt reuses.
export const PRODUCT_FRAMING =
  'an iOS app that tracks money, movement, daily rituals, and nutrition'

// Per-user currency rendering, shipped in the context payload (the server has
// no currency table; the client is the source of truth). Mirrors the fields the
// client's Currency enum carries.
export interface CurrencyDescriptor {
  symbol: string
  symbolBefore: boolean
  decimals: number
  group: string // thousands separator
  decimal: string // decimal mark
}

export const USD: CurrencyDescriptor = {
  symbol: '$', symbolBefore: true, decimals: 2, group: ',', decimal: '.',
}

// Renders an amount in the user's currency. Mirrors the client's formatCurrency:
// groups thousands, places the symbol per symbolBefore, trims a .00 tail on whole
// amounts. Defaults to USD so an older client (no currency field) stays correct.
export function money(amount: number, c: CurrencyDescriptor = USD): string {
  const negative = amount < 0
  const abs = Math.abs(amount)
  const isWhole = Number.isInteger(abs)
  const decimals = c.decimals > 0 && !isWhole ? c.decimals : 0
  const [whole, frac] = abs.toFixed(decimals).split('.')
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, c.group)
  const body = frac ? `${grouped}${c.decimal}${frac}` : grouped
  const withSymbol = c.symbolBefore ? `${c.symbol}${body}` : `${body} ${c.symbol}`
  return negative ? `-${withSymbol}` : withSymbol
}
