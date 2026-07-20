import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import { D1TokenStore, D1MemoryStore } from '../src/stores'

beforeEach(async () => {
  await applyD1Migrations(env.DB, env.TEST_MIGRATIONS)
  // pool 0.18.x isolates storage per test file, not per test; reset for a clean slate.
  await env.DB.batch([
    env.DB.prepare('DELETE FROM pal_facts'),
    env.DB.prepare('DELETE FROM pal_patterns'),
    env.DB.prepare('DELETE FROM device_tokens'),
  ])
})

describe('D1TokenStore', () => {
  it('issues one stable token per device and validates it', async () => {
    const s = new D1TokenStore(env.DB)
    const a = await s.issue('device-1')
    const b = await s.issue('device-1')
    expect(a).toBe(b)
    expect(a).toHaveLength(64)
    expect(await s.isValid(a)).toBe(true)
    expect(await s.isValid('nope')).toBe(false)
  })
})

describe('D1MemoryStore', () => {
  it('caps facts at 20, keeping the newest', async () => {
    const m = new D1MemoryStore(env.DB)
    for (let i = 0; i < 25; i++) await m.addFact('t', `fact ${i}`)
    const d = await m.digest('t')
    expect(d.facts).toHaveLength(20)
    expect(d.facts.at(-1)!.text).toBe('fact 24')
  })

  it('applies remember/forget ops and wipes', async () => {
    const m = new D1MemoryStore(env.DB)
    const f = await m.addFact('t', 'keep me')
    await m.applyOps('t', [{ op: 'remember', text: 'new fact' }, { op: 'forget', id: f.id }])
    let d = await m.digest('t')
    expect(d.facts.map((x) => x.text)).toEqual(['new fact'])
    await m.setPatterns('t', Array.from({ length: 8 }, (_, i) => ({ colorToken: 'money', title: `p${i}`, detail: 'd' })))
    d = await m.digest('t')
    expect(d.patterns).toHaveLength(5)
    await m.wipe('t')
    d = await m.digest('t')
    expect(d).toEqual({ facts: [], patterns: [] })
  })
})
