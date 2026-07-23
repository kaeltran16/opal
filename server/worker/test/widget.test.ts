import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, {} as any)

async function token(): Promise<string> {
  const res = await call('/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  })
  return (await res.json() as any).token
}

const SNAP = {
  moneyRing: 0.5, moveRing: 0.8, ritualsRing: 0.33, moneySpent: 42000, dailyBudget: 100000,
  moveKcal: 320, dailyMoveKcal: 600, ritualsDone: 1, dailyRitualTarget: 3,
}

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('widget routes', () => {
  const auth = (tok: string, init: RequestInit = {}) =>
    ({ ...init, headers: { ...(init.headers ?? {}), authorization: `Bearer ${tok}`, 'content-type': 'application/json' } })

  it('GET returns 404 before any snapshot', async () => {
    const tok = await token()
    const res = await call('/v1/widget/snapshot', auth(tok))
    expect(res.status).toBe(404)
    expect((await res.json() as any).error.code).toBe('not_found')
  })

  it('POST stores and GET reads back the exact snapshot', async () => {
    const tok = await token()
    const post = await call('/v1/widget/snapshot', auth(tok, { method: 'POST', body: JSON.stringify(SNAP) }))
    expect(post.status).toBe(200)
    expect(await post.json()).toEqual({ ok: true })
    const get = await call('/v1/widget/snapshot', auth(tok))
    expect(get.status).toBe(200)
    expect(await get.json()).toEqual(SNAP)
  })

  it('rejects a snapshot with a non-finite ring with 400', async () => {
    const tok = await token()
    const res = await call('/v1/widget/snapshot', auth(tok, { method: 'POST', body: JSON.stringify({ ...SNAP, moneyRing: 'x' }) }))
    expect(res.status).toBe(400)
  })
})
