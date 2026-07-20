import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, {} as any)

beforeEach(async () => {
  await applyD1Migrations(env.DB, env.TEST_MIGRATIONS)
  await env.DB.batch([
    env.DB.prepare('DELETE FROM pal_facts'),
    env.DB.prepare('DELETE FROM pal_patterns'),
    env.DB.prepare('DELETE FROM device_tokens'),
  ])
})

describe('register + auth', () => {
  it('issues a token with the right provisioning key', async () => {
    const res = await call('/v1/register', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
    })
    expect(res.status).toBe(200)
    expect((await res.json() as any).token).toHaveLength(64)
  })

  it('rejects a bad provisioning key with 401', async () => {
    const res = await call('/v1/register', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ provisioningKey: 'wrong', deviceId: 'd1' }),
    })
    expect(res.status).toBe(401)
  })

  it('rejects a /v1 route with no bearer token', async () => {
    const res = await call('/v1/memory')
    expect(res.status).toBe(401)
  })
})
