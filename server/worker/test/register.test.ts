import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any)

const register = (body: unknown) =>
  call('/v1/register', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('register + bearer guard', () => {
  it('issues a stable 64-char token for the right provisioning key', async () => {
    const a = await register({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' })
    expect(a.status).toBe(200)
    const t1 = (await a.json() as any).token
    expect(t1).toHaveLength(64)
    const b = await register({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' })
    expect((await b.json() as any).token).toBe(t1) // same device -> same token
  })

  it('gives concurrent registers for one device the same token, no 500', async () => {
    const body = { provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd-race' }
    const [a, b] = await Promise.all([register(body), register(body)])
    expect([a.status, b.status]).toEqual([200, 200])
    expect((await a.json() as any).token).toBe((await b.json() as any).token)
  })

  it('rejects a bad provisioning key with 401', async () => {
    const res = await register({ provisioningKey: 'wrong', deviceId: 'd1' })
    expect(res.status).toBe(401)
    expect((await res.json() as any).error.code).toBe('unauthorized')
  })

  it('rejects a malformed body with 400', async () => {
    const res = await register({ deviceId: 'd1' })
    expect(res.status).toBe(400)
  })

  it('rejects a /v1 route with no bearer token', async () => {
    const res = await call('/v1/memory')
    expect(res.status).toBe(401)
  })

  it('accepts a valid bearer token (routeAuthed reached -> 404 for the stub path)', async () => {
    const reg = await register({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd2' })
    const token = (await reg.json() as any).token
    const res = await call('/v1/does-not-exist', { headers: { authorization: `Bearer ${token}` } })
    expect(res.status).toBe(404) // authenticated, but no such route
  })
})
