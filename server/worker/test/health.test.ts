import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'
import { D1HealthStore } from '../src/stores/health'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, {} as any)

async function token(): Promise<string> {
  const res = await call('/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  })
  return (await res.json() as any).token
}

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('D1HealthStore', () => {
  it('upserts a day and overwrites on re-ingest', async () => {
    const s = new D1HealthStore(env.DB)
    expect(await s.upsert('2026-07-01', { steps: { value: 100, unit: 'count' } }, 'cap1')).toBe(1)
    await s.upsert('2026-07-01', { steps: { value: 200, unit: 'count' } }, 'cap2')
    expect((await s.getDay('2026-07-01')).steps).toEqual({ value: 200, unit: 'count' })
  })
})

describe('health routes', () => {
  const auth = (tok: string, init: RequestInit = {}) =>
    ({ ...init, headers: { ...(init.headers ?? {}), authorization: `Bearer ${tok}`, 'content-type': 'application/json' } })

  it('POST /v1/health/ingest returns { upserted } and GET /v1/health/day reads it back', async () => {
    const tok = await token()
    const ing = await call('/v1/health/ingest', auth(tok, {
      method: 'POST',
      body: JSON.stringify({ date: '2026-07-02', metrics: { steps: { value: 5000, unit: 'count' }, activeEnergy: { value: 300, unit: 'kcal' } } }),
    }))
    expect(ing.status).toBe(200)
    expect((await ing.json() as any).upserted).toBe(2)

    const day = await call('/v1/health/day?date=2026-07-02', auth(tok))
    expect(day.status).toBe(200)
    const b = await day.json() as any
    expect(b.date).toBe('2026-07-02')
    expect(b.metrics.steps).toEqual({ value: 5000, unit: 'count' })
  })

  it('rejects an unknown metric key with 400', async () => {
    const tok = await token()
    const res = await call('/v1/health/ingest', auth(tok, {
      method: 'POST', body: JSON.stringify({ date: '2026-07-02', metrics: { bogus: { value: 1, unit: 'x' } } }),
    }))
    expect(res.status).toBe(400)
  })

  it('rejects a malformed date query with 400', async () => {
    const tok = await token()
    const res = await call('/v1/health/day?date=not-a-date', auth(tok))
    expect(res.status).toBe(400)
  })
})
