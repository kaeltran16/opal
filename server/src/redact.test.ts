import { describe, it, expect } from 'vitest'
import { redactPii } from './redact.js'

describe('redactPii', () => {
  it('masks email addresses', () => {
    expect(redactPii('Hi cktran16x2@gmail.com, your order shipped')).toBe('Hi [email], your order shipped')
  })

  it('masks card numbers, grouped or contiguous', () => {
    expect(redactPii('paid with 4111 1111 1111 1111')).toBe('paid with [card]')
    expect(redactPii('card 4111111111111111 charged')).toBe('card [card] charged')
  })

  it('masks phone numbers with separators', () => {
    expect(redactPii('call 555-123-4567')).toBe('call [phone]')
    expect(redactPii('call +1 (555) 123-4567')).toBe('call [phone]')
  })

  it('masks long account/order numbers', () => {
    expect(redactPii('order 123456789')).toBe('order [number]')
  })

  it('leaves dollar amounts intact', () => {
    expect(redactPii('Order total $42.99')).toBe('Order total $42.99')
    expect(redactPii('Subtotal $1,234.56 incl tax')).toBe('Subtotal $1,234.56 incl tax')
  })

  it('leaves dates and short numbers intact', () => {
    expect(redactPii('placed 2026-06-09, qty 3')).toBe('placed 2026-06-09, qty 3')
  })
})
