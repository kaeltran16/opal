import { describe, it, expect } from 'vitest'
import { extractFromCandidates, emailExtractBody } from '../src/email'
import { StubCompleter } from './support/stub-client'
import { OpenRouterError } from '../../src/pal'

// one model result object per candidate index; extractReceipts maps back by index.
const modelResults = (results: unknown[]) => JSON.stringify({ results })

const CAND = {
  id: 'msg-1',
  from: 'billing@cafe.com',
  subject: 'Your receipt',
  text: 'Total $5 on 06 Jan 2026 11:27',
  envelopeDate: '2026-01-08T09:00:00.000Z',
}

describe('extractFromCandidates', () => {
  it('maps a receipt to the import wire shape (negative amount, body txn date)', async () => {
    const completer = new StubCompleter({
      text: modelResults([{ index: 0, isReceipt: true, merchant: 'Cafe', amount: 5, category: 'Food & Drink' }]),
    })
    const items = await extractFromCandidates([CAND], completer)
    expect(items).toEqual([{
      id: 'msg-1', merchant: 'Cafe', amount: -5,
      receivedAt: '2026-01-06T11:27:00.000Z', category: 'Food & Drink',
    }])
  })

  it('drops candidates the model marks non-receipt, preserving order', async () => {
    const completer = new StubCompleter({
      text: modelResults([
        { index: 0, isReceipt: false, merchant: null, amount: null, category: null },
        { index: 1, isReceipt: true, merchant: 'Shop', amount: 12, category: 'Shopping' },
      ]),
    })
    const items = await extractFromCandidates([CAND, { ...CAND, id: 'msg-2' }], completer)
    expect(items).toHaveLength(1)
    expect(items[0].id).toBe('msg-2')
    expect(items[0].amount).toBe(-12)
  })

  it('re-redacts PII in the body before it reaches the model (defense in depth)', async () => {
    const completer = new StubCompleter({
      text: modelResults([{ index: 0, isReceipt: false, merchant: null, amount: null, category: null }]),
    })
    const dirty = { ...CAND, text: 'Paid by user@example.com card 4111 1111 1111 1111 total $5' }
    await extractFromCandidates([dirty], completer)
    const prompt = completer.lastMessages[0].content
    expect(prompt).toContain('[email]')
    expect(prompt).toContain('[card]')
    expect(prompt).not.toContain('user@example.com')
    expect(prompt).not.toContain('4111 1111 1111 1111')
  })

  it('propagates an OpenRouterError from the completer', async () => {
    const completer = new StubCompleter({ error: new OpenRouterError(502, 'boom') })
    await expect(extractFromCandidates([CAND], completer)).rejects.toBeInstanceOf(OpenRouterError)
  })
})

describe('emailExtractBody', () => {
  it('accepts 1..BATCH_SIZE candidates', () => {
    expect(emailExtractBody.safeParse({ candidates: [CAND] }).success).toBe(true)
  })
  it('rejects an empty batch', () => {
    expect(emailExtractBody.safeParse({ candidates: [] }).success).toBe(false)
  })
  it('rejects more than BATCH_SIZE candidates', () => {
    expect(emailExtractBody.safeParse({ candidates: Array(9).fill(CAND) }).success).toBe(false)
  })
  it('rejects an unparseable envelopeDate', () => {
    expect(emailExtractBody.safeParse({ candidates: [{ ...CAND, envelopeDate: 'not-a-date' }] }).success).toBe(false)
  })
})
