import { describe, it, expect } from 'vitest'
import { filterBySender, extractReceipt } from './receipts.js'
import type { RawEmail } from './imap.js'
import type { CompletionClient } from './pal.js'

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

const client = (reply: string): CompletionClient => ({ complete: async () => reply })

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

describe('extractReceipt', () => {
  it('returns fields for a receipt', async () => {
    const c = client('{"isReceipt": true, "merchant": "Amazon", "amount": 42.99, "category": "Shopping"}')
    const r = await extractReceipt(email(), c)
    expect(r).toEqual({ merchant: 'Amazon', amount: 42.99, category: 'Shopping' })
  })

  it('returns null when the model says it is not a receipt', async () => {
    const c = client('{"isReceipt": false, "merchant": null, "amount": null, "category": null}')
    expect(await extractReceipt(email(), c)).toBeNull()
  })

  it('returns null when no amount was found even if flagged a receipt', async () => {
    const c = client('{"isReceipt": true, "merchant": "Amazon", "amount": null, "category": "Shopping"}')
    expect(await extractReceipt(email(), c)).toBeNull()
  })

  it('tolerates code fences and surrounding prose in the model reply', async () => {
    const c = client('Here you go:\n```json\n{"isReceipt": true, "merchant": "Uber", "amount": 18.4, "category": "Transport"}\n```')
    const r = await extractReceipt(email(), c)
    expect(r?.merchant).toBe('Uber')
  })
})
