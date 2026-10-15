import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import { handle } from '../src/worker'
import { StubCompleter } from './support/stub-client'
import { OpenRouterError } from '../../src/pal'

const modelResults = (results: unknown[]) => JSON.stringify({ results })

const CAND = {
  id: 'msg-1', from: 'billing@cafe.com', subject: 'Your receipt',
  text: 'Total $5 on 06 Jan 2026 11:27', envelopeDate: '2026-01-08T09:00:00.000Z',
}

async function token(): Promise<string> {
  const res = await handle(new Request('https://x/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  }), env as any)
  return (await res.json() as any).token
}

const post = (tok: string, body: unknown, completer?: any) =>
  handle(new Request('https://x/v1/email/extract', {
    method: 'POST', headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  }), env as any, completer ? { completer } : undefined)

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('POST /v1/email/extract', () => {
  it('returns the mapped import items', async () => {
    const tok = await token()
    const canned = modelResults([{ index: 0, isReceipt: true, merchant: 'Cafe', amount: 5, category: 'Food & Drink' }])
    const res = await post(tok, { candidates: [CAND] }, new StubCompleter({ text: canned }))
    expect(res.status).toBe(200)
    const body = await res.json() as any
    expect(body.items).toEqual([{
      id: 'msg-1', merchant: 'Cafe', amount: -5,
      receivedAt: '2026-01-06T11:27:00.000Z', category: 'Food & Drink', orderRef: null,
    }])
  })

  it('stamps a local receipt time with the candidate offset (VIB alert at UTC+7)', async () => {
    const tok = await token()
    const vib = {
      id: 'vib-1', from: 'info@card.vib.com.vn', subject: 'VIB - Thong bao giao dich the',
      text: 'So tien: 185.000 VND. Tai: HIGHLANDS COFFEE. Thoi gian: 13/10/2026 08:42.',
      envelopeDate: '2026-10-13T01:43:00Z', utcOffsetMinutes: 420,
    }
    const canned = modelResults([{ index: 0, isReceipt: true, merchant: 'Highlands Coffee', amount: 185000, category: 'Food & Drink' }])
    const res = await post(tok, { candidates: [vib] }, new StubCompleter({ text: canned }))
    expect((await res.json() as any).items[0].receivedAt).toBe('2026-10-13T01:42:00.000Z')
  })

  it('400 on an offset outside the real UTC range', async () => {
    const tok = await token()
    const res = await post(tok, { candidates: [{ ...CAND, utcOffsetMinutes: 900 }] }, new StubCompleter({ text: '{}' }))
    expect(res.status).toBe(400)
  })

  it('returns an empty batch when nothing is a receipt', async () => {
    const tok = await token()
    const canned = modelResults([{ index: 0, isReceipt: false, merchant: null, amount: null, category: null }])
    const res = await post(tok, { candidates: [CAND] }, new StubCompleter({ text: canned }))
    expect(res.status).toBe(200)
    expect((await res.json() as any).items).toEqual([])
  })

  it('400 on malformed body', async () => {
    const tok = await token()
    const res = await post(tok, { candidates: [] }, new StubCompleter({ text: '{}' }))
    expect(res.status).toBe(400)
    expect((await res.json() as any).error.code).toBe('bad_request')
  })

  it('401 without a valid token', async () => {
    const res = await handle(new Request('https://x/v1/email/extract', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ candidates: [CAND] }),
    }), env as any)
    expect(res.status).toBe(401)
  })

  it('502 on OpenRouterError, 500 on a generic error', async () => {
    const tok = await token()
    const r502 = await post(tok, { candidates: [CAND] }, new StubCompleter({ error: new OpenRouterError(500, 'boom') }))
    expect(r502.status).toBe(502)
    expect((await r502.json() as any).error.code).toBe('upstream')
    const r500 = await post(tok, { candidates: [CAND] }, new StubCompleter({ error: new Error('nope') }))
    expect(r500.status).toBe(500)
  })
})
