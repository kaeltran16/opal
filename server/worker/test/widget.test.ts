import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any)

async function token(): Promise<string> {
  const res = await call('/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  })
  return (await res.json() as any).token
}

const SNAP = {
  until: 1760425200,
  move: { fraction: 0.62, value: '310 of 500 kcal', states: [{ at: 1760371260, state: 'good', word: 'On track' }] },
  routines: {
    fraction: 0.5, value: '2 of 4 done',
    states: [
      { at: 1760371260, state: 'good', word: 'On track' },
      { at: 1760410800, state: 'watch', word: 'Worth watching' },
    ],
  },
  money: { value: '$22 left of $60', states: [{ at: 1760371260, state: 'watch', word: 'Worth watching' }] },
}

const V1_SNAP = {
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

  const post = async (body: unknown) =>
    call('/v1/widget/snapshot', auth(await token(), { method: 'POST', body: JSON.stringify(body) }))

  it('rejects the v1 snapshot with 400', async () => {
    expect((await post(V1_SNAP)).status).toBe(400)
  })

  it('rejects an unknown state or an out-of-range fraction with 400', async () => {
    const great = { ...SNAP, move: { ...SNAP.move, states: [{ at: 1760371260, state: 'great', word: 'Great' }] } }
    expect((await post(great)).status).toBe(400)
    expect((await post({ ...SNAP, routines: { ...SNAP.routines, fraction: 1.5 } })).status).toBe(400)
  })

  it('rejects an empty states list with 400', async () => {
    expect((await post({ ...SNAP, money: { ...SNAP.money, states: [] } })).status).toBe(400)
  })
})
