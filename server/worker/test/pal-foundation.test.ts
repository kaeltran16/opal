import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker, { handle } from '../src/worker'
import { makePal } from '../src/pal-factory'
import { stubPal } from './support/stub-client'
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

describe('pal foundation', () => {
  it('makePal builds a Pal without touching the network', () => {
    const pal = makePal({ ...(env as any), OPENROUTER_API_KEY: 'x' })
    expect(typeof pal.chat).toBe('function')
  })

  it('D1MemoryStore.applyOps applies remember/forget', async () => {
    const m = new D1MemoryStore(env.DB)
    await m.applyOps('t', [{ op: 'remember', text: 'likes coffee' }])
    const d = await m.digest('t')
    expect(d.facts.map((f) => f.text)).toContain('likes coffee')
    await m.applyOps('t', [{ op: 'forget', id: d.facts[0].id }])
    expect((await m.digest('t')).facts).toHaveLength(0)
  })

  it('an unknown authed route still 404s through routePal', async () => {
    const tok = await token()
    const res = await handle(
      new Request('https://x/v1/nope', { headers: { authorization: `Bearer ${tok}` } }),
      env as any,
      { pal: stubPal({ text: '{}' }) },
    )
    expect(res.status).toBe(404)
  })
})
