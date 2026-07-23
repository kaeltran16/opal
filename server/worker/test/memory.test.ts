import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'
import { D1MemoryStore } from '../src/stores/memory'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, {} as any)

async function token(deviceId = 'd1'): Promise<string> {
  const res = await call('/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId }),
  })
  return (await res.json() as any).token
}

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('D1MemoryStore', () => {
  it('caps facts at 20, keeping the newest', async () => {
    const m = new D1MemoryStore(env.DB)
    for (let i = 0; i < 25; i++) await m.addFact('t', `fact ${i}`)
    const d = await m.digest('t')
    expect(d.facts).toHaveLength(20)
    expect(d.facts.at(-1)!.text).toBe('fact 24')
  })
})

describe('memory routes', () => {
  const auth = (tok: string, init: RequestInit = {}) =>
    ({ ...init, headers: { ...(init.headers ?? {}), authorization: `Bearer ${tok}` } })

  it('GET /v1/memory returns the digest shape', async () => {
    const tok = await token()
    const res = await call('/v1/memory', auth(tok))
    expect(res.status).toBe(200)
    const b = await res.json() as any
    expect(Array.isArray(b.facts)).toBe(true)
    expect(Array.isArray(b.patterns)).toBe(true)
  })

  it('DELETE /v1/memory/facts/:id removes the fact and returns the digest', async () => {
    const tok = await token()
    const m = new D1MemoryStore(env.DB)
    const f = await m.addFact(tok, 'keep-or-not')
    const res = await call(`/v1/memory/facts/${f.id}`, auth(tok, { method: 'DELETE' }))
    expect(res.status).toBe(200)
    expect((await res.json() as any).facts.map((x: any) => x.text)).not.toContain('keep-or-not')
  })

  it('DELETE /v1/memory wipes and returns { ok: true }', async () => {
    const tok = await token()
    const m = new D1MemoryStore(env.DB)
    await m.addFact(tok, 'x')
    const res = await call('/v1/memory', auth(tok, { method: 'DELETE' }))
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ ok: true })
    expect((await m.digest(tok)).facts).toHaveLength(0)
  })
})
