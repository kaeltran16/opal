import { describe, it, expect } from 'vitest'
import { filterBySender, extractReceipts, isLikelyNonReceipt, extractTxnDate, resolveReceivedAt } from './receipts.js'
import type { RawEmail } from './imap.js'
import type { TextCompleter } from './pal.js'

function email(overrides: Partial<RawEmail> = {}): RawEmail {
  return {
    messageId: 'm1',
    from: 'receipts@amazon.com',
    fromName: 'Amazon',
    subject: 'Your order',
    date: new Date('2026-06-09T10:00:00Z'),
    text: 'Order total $42.99',
    ...overrides,
  }
}

const client = (reply: string): TextCompleter => ({ complete: async () => reply })

describe('filterBySender', () => {
  it('keeps everything when no filters are configured', () => {
    const all = [email(), email({ from: 'random@x.com' })]
    expect(filterBySender(all, [])).toHaveLength(2)
  })

  it('keeps only senders matching a filter (case-insensitive substring)', () => {
    const all = [email({ from: 'receipts@amazon.com' }), email({ from: 'news@spam.com' })]
    const kept = filterBySender(all, ['AMAZON.com'])
    expect(kept).toHaveLength(1)
    expect(kept[0].from).toBe('receipts@amazon.com')
  })
})

// wraps a single-result envelope into the batch shape for terse tests
const oneResult = (r: object): string => `{"results": [${JSON.stringify({ index: 0, ...r })}]}`

describe('extractReceipts', () => {
  it('returns an empty array for no emails without calling the model', async () => {
    let called = false
    const c: TextCompleter = { complete: async () => { called = true; return '' } }
    expect(await extractReceipts([], c)).toEqual([])
    expect(called).toBe(false)
  })

  it('returns fields for a receipt', async () => {
    const c = client(oneResult({ isReceipt: true, merchant: 'Amazon', amount: 42.99, category: 'Shopping' }))
    expect(await extractReceipts([email()], c)).toEqual([
      { merchant: 'Amazon', amount: 42.99, category: 'Shopping' },
    ])
  })

  it('returns null when the model says it is not a receipt', async () => {
    const c = client(oneResult({ isReceipt: false, merchant: null, amount: null, category: null }))
    expect(await extractReceipts([email()], c)).toEqual([null])
  })

  it('returns null when no amount was found even if flagged a receipt', async () => {
    const c = client(oneResult({ isReceipt: true, merchant: 'Amazon', amount: null, category: 'Shopping' }))
    expect(await extractReceipts([email()], c)).toEqual([null])
  })

  it('tolerates code fences and surrounding prose in the model reply', async () => {
    const c = client('Here you go:\n```json\n{"results": [{"index": 0, "isReceipt": true, "merchant": "Uber", "amount": 18.4, "category": "Transport"}]}\n```')
    const [r] = await extractReceipts([email()], c)
    expect(r?.merchant).toBe('Uber')
  })

  it('maps results back by index, ignoring the model ordering', async () => {
    // results returned out of order; index, not position, decides the slot
    const c = client(`{"results": [
      {"index": 1, "isReceipt": true, "merchant": "Uber", "amount": 18.4, "category": "Transport"},
      {"index": 0, "isReceipt": true, "merchant": "Amazon", "amount": 42.99, "category": "Shopping"}
    ]}`)
    const out = await extractReceipts([email({ messageId: 'm1' }), email({ messageId: 'm2' })], c)
    expect(out[0]?.merchant).toBe('Amazon')
    expect(out[1]?.merchant).toBe('Uber')
  })

  it('yields null for a missing index', async () => {
    const c = client(oneResult({ isReceipt: true, merchant: 'Amazon', amount: 42.99, category: 'Shopping' }))
    const out = await extractReceipts([email(), email()], c)
    expect(out).toHaveLength(2)
    expect(out[0]?.merchant).toBe('Amazon')
    expect(out[1]).toBeNull()
  })

  it('ignores out-of-range and duplicate indices', async () => {
    const c = client(`{"results": [
      {"index": 0, "isReceipt": true, "merchant": "Amazon", "amount": 42.99, "category": "Shopping"},
      {"index": 0, "isReceipt": true, "merchant": "Spoof", "amount": 99, "category": "Shopping"},
      {"index": 5, "isReceipt": true, "merchant": "OutOfRange", "amount": 1, "category": "Shopping"}
    ]}`)
    const out = await extractReceipts([email()], c)
    expect(out).toEqual([{ merchant: 'Amazon', amount: 42.99, category: 'Shopping' }])
  })

  it('coerces an off-list category to null', async () => {
    // 'Travel' is not in the client's kSpendCategories, so it must coerce to null.
    const c = client(oneResult({ isReceipt: true, merchant: 'Amazon', amount: 42.99, category: 'Travel' }))
    expect(await extractReceipts([email()], c)).toEqual([
      { merchant: 'Amazon', amount: 42.99, category: null },
    ])
  })

  it('keeps a Food & Drink category (feeds the nutrition meal prompt)', async () => {
    const c = client(oneResult({ isReceipt: true, merchant: 'Grab', amount: 8, category: 'Food & Drink' }))
    expect(await extractReceipts([email()], c)).toEqual([
      { merchant: 'Grab', amount: 8, category: 'Food & Drink' },
    ])
  })

  it('requests deterministic output and scales the token cap with the batch size', async () => {
    let opts: { maxTokens?: number; temperature?: number } | undefined
    const capturing: TextCompleter = {
      complete: async (_msgs, o) => {
        opts = o
        return oneResult({ isReceipt: true, merchant: 'Amazon', amount: 42.99, category: 'Shopping' })
      },
    }
    await extractReceipts([email(), email(), email()], capturing)
    expect(opts?.temperature).toBe(0)
    // 3 emails worth of result objects must not be capped at the default 1024.
    expect(opts?.maxTokens).toBe(3 * 256)
  })

  it('scrubs PII from every body before it reaches the model, keeping the amount', async () => {
    let seen = ''
    const capturing: TextCompleter = {
      complete: async (msgs) => {
        seen = msgs[0].content
        return oneResult({ isReceipt: true, merchant: 'Amazon', amount: 42.99, category: 'Shopping' })
      },
    }
    await extractReceipts(
      [email({ text: 'Hi cktran16x2@gmail.com, total $42.99 on card 4111 1111 1111 1111' })],
      capturing,
    )
    expect(seen).not.toContain('cktran16x2@gmail.com')
    expect(seen).not.toContain('4111 1111 1111 1111')
    expect(seen).toContain('$42.99')
  })
})

describe('isLikelyNonReceipt', () => {
  it('drops promotional, delivery, tracking, refund and review emails', () => {
    const cases = [
      { subject: 'Rate your trip', text: '' },
      { subject: '20% off this weekend', text: 'sale ends soon' },
      { subject: 'Your order is out for delivery', text: '' },
      { subject: 'Shipping confirmation', text: 'tracking number 12345' },
      { subject: 'Refund processed', text: '' },
      { subject: 'How was your experience?', text: 'leave a review' },
    ]
    for (const c of cases) expect(isLikelyNonReceipt(c)).toBe(true)
  })

  it('keeps a genuine paid receipt', () => {
    expect(isLikelyNonReceipt({ subject: 'Your receipt from Amazon', text: 'Total charged $42.99' })).toBe(false)
  })

  it('does NOT drop a paid order confirmation (the model judges payment state)', () => {
    // payment-state wording is intentionally left to the model, not the filter.
    expect(isLikelyNonReceipt({ subject: 'Order confirmation', text: 'We charged your card $59.00' })).toBe(false)
  })

  it('drops Vietnamese promotional subjects and a delivered-successfully marker', () => {
    const cases = [
      { subject: 'Khuyến mãi cuối tuần', text: '' },
      { subject: 'Giảm giá 50% hôm nay', text: '' },
      { subject: 'Ưu đãi đặc biệt cho bạn', text: '' },
      { subject: 'Đơn hàng của bạn đã giao hàng thành công', text: '' },
    ]
    for (const c of cases) expect(isLikelyNonReceipt(c)).toBe(true)
  })

  it('does NOT drop a real receipt whose body mentions a discount line', () => {
    // promo wording is matched in the subject only; a "giảm giá" discount line
    // in a paid receipt body must not drop it.
    expect(
      isLikelyNonReceipt({ subject: 'Hóa đơn GrabFood', text: 'Tạm tính 120.000đ\nGiảm giá -20.000đ\nTổng cộng 100.000đ' }),
    ).toBe(false)
  })
})

describe('extractTxnDate', () => {
  it('parses a day-first alpha-month date with time (Grab-style)', () => {
    const r = extractTxnDate('Paid on 06 Jan 26 11:27 at the cafe')
    expect(r?.date.toISOString()).toBe('2026-01-06T11:27:00.000Z')
    expect(r?.hasTime).toBe(true)
  })

  it('parses a month-first date and a full month name, 4-digit year', () => {
    expect(extractTxnDate('Jan 6, 2026 09:05')?.date.toISOString()).toBe('2026-01-06T09:05:00.000Z')
    expect(extractTxnDate('8 November 2025 18:38')?.date.toISOString()).toBe('2025-11-08T18:38:00.000Z')
  })

  it('reports hasTime false for a date with no time', () => {
    const r = extractTxnDate('Invoice date: 8 Nov 2025')
    expect(r?.date.toISOString()).toBe('2025-11-08T00:00:00.000Z')
    expect(r?.hasTime).toBe(false)
  })

  it('parses a numeric day-first date that carries a time (Shopee/VN style)', () => {
    // 05/06/2025 14:30 → 5 June 2025 (day-first), UTC.
    expect(extractTxnDate('Thời gian đặt: 05/06/2025 14:30')?.date.toISOString()).toBe('2025-06-05T14:30:00.000Z')
    expect(extractTxnDate('Ngày 5-6-2025 09:00')?.date.toISOString()).toBe('2025-06-05T09:00:00.000Z')
  })

  it('rejects a numeric date whose month field exceeds 12 rather than guessing', () => {
    // a US-style 06/13/2025 has month=13 under day-first → left to the envelope date.
    expect(extractTxnDate('paid 06/13/2025 08:00')).toBeNull()
  })

  it('returns null for a bare numeric date (no time) and when absent', () => {
    expect(extractTxnDate('charged on 05/06/2025')).toBeNull()
    expect(extractTxnDate('Total $10, thanks')).toBeNull()
  })
})

describe('resolveReceivedAt', () => {
  const envelope = new Date('2026-06-09T10:15:30Z')

  it('uses the body date+time when present', () => {
    expect(resolveReceivedAt('06 Jan 26 11:27', envelope).toISOString()).toBe('2026-01-06T11:27:00.000Z')
  })

  it('keeps the envelope time-of-day for a date-only body date', () => {
    // date from body, hours/minutes/seconds from the envelope (meal-slot stays sane)
    expect(resolveReceivedAt('Invoice date: 8 Nov 2025', envelope).toISOString()).toBe('2025-11-08T10:15:30.000Z')
  })

  it('falls back to the envelope date when the body has no parseable date', () => {
    expect(resolveReceivedAt('Total $10', envelope).toISOString()).toBe(envelope.toISOString())
  })
})
