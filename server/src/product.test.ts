import { describe, it, expect } from 'vitest'
import { ENTRY_TYPES, DIMENSIONS, PRODUCT_FRAMING, USD, money, type CurrencyDescriptor } from './product.js'

const VND: CurrencyDescriptor = { symbol: '₫', symbolBefore: false, decimals: 0, group: '.', decimal: ',' }

describe('product vocabulary', () => {
  it('entry types are the three timeline trackers (no nutrition)', () => {
    expect(ENTRY_TYPES).toEqual(['money', 'move', 'rituals'])
  })
  it('dimensions add nutrition for colour/correlation', () => {
    expect(DIMENSIONS).toEqual(['money', 'move', 'rituals', 'nutrition'])
  })
  it('framing names nutrition', () => {
    expect(PRODUCT_FRAMING).toContain('nutrition')
  })
})

describe('money', () => {
  it('USD trims .00 on whole amounts and groups thousands', () => {
    expect(money(60, USD)).toBe('$60')
    expect(money(1840, USD)).toBe('$1,840')
  })
  it('USD keeps cents when present', () => {
    expect(money(12.5, USD)).toBe('$12.50')
  })
  it('VND trails the symbol, no decimals, dot grouping', () => {
    expect(money(2500000, VND)).toBe('2.500.000 ₫')
  })
  it('defaults to USD when no descriptor is given', () => {
    expect(money(5)).toBe('$5')
  })
  it('renders a minus for negative amounts', () => {
    expect(money(-5, USD)).toBe('-$5')
  })
})
