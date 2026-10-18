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

  // mirrors lib/services/email/receipt_filters.dart; the two must agree.
  it('masks the name after a recipient label, in any case', () => {
    expect(redactPii('Người dùng Trần Khang\nMã đơn hàng A-9VW')).toBe('Người dùng [name]\nMã đơn hàng A-9VW')
    expect(redactPii('Kính gửi: TRẦN CAO KHANG')).toBe('Kính gửi: [name]')
    expect(redactPii('Dear John Smith, thanks')).toBe('Dear [name], thanks')
    expect(redactPii('Hi Khang, your order')).toBe('Hi [name], your order')
  })

  it('leaves the merchant and uncapitalised words after labels', () => {
    const body = 'Đặt từ MACHIYA BENTO\nHi there\nĐến tài khoản CTCP TM BÁCH HÓA XANH'
    expect(redactPii(body)).toBe(body)
  })

  it('masks the rest of an address line', () => {
    expect(redactPii('Địa chỉ nhận hàng: 12 Nguyễn Huệ, Q1\nTổng 45.000đ')).toBe('Địa chỉ nhận hàng: [address]\nTổng 45.000đ')
    expect(redactPii('Giao đến 12 Lê Lợi')).toBe('Giao đến [address]')
    expect(redactPii('Shipping address: 1 Main St')).toBe('Shipping address: [address]')
  })

  it('masks the last four digits of a card', () => {
    expect(redactPii('Bạn trả bằng: ATM 9816')).toBe('Bạn trả bằng: ATM [card]')
    expect(redactPii('Visa ending in 4242.')).toBe('Visa ending in [card].')
    expect(redactPii('card **** 1234')).toBe('card **** [card]')
  })

  it('reaches a value one line below its label (table cells)', () => {
    expect(redactPii('Người dùng\nTrần Khang\nMã đơn hàng\nA-9VW\nBạn trả bằng:\nATM\n9816\nGiao đến\nWork')).toBe(
      'Người dùng\n[name]\nMã đơn hàng\nA-9VW\nBạn trả bằng:\nATM\n[card]\nGiao đến\n[address]',
    )
  })

  it('leaves an amount after a card word', () => {
    const body = 'Phí thẻ 2000đ, card 1500 VND, thẻ 1.500.000'
    expect(redactPii(body)).toBe(body)
  })

  it('is idempotent, so re-applying it after the client is safe', () => {
    const once = redactPii('user@example.com paid 4111111111111111\nKính gửi: TRẦN CAO KHANG\nGiao đến 12 Lê Lợi\nATM 9816')
    expect(redactPii(once)).toBe(once)
  })
})
