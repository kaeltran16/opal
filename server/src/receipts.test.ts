import { describe, it, expect } from 'vitest'
import { filterBySender, extractReceipts } from './receipts.js'
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
    const c = client(oneResult({ isReceipt: true, merchant: 'Amazon', amount: 42.99, category: 'Groceries' }))
    expect(await extractReceipts([email()], c)).toEqual([
      { merchant: 'Amazon', amount: 42.99, category: null },
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
