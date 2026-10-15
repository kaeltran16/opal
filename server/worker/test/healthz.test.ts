import { env } from 'cloudflare:test'
import { describe, it, expect } from 'vitest'
import worker from '../src/worker'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any)

describe('healthz + baseline', () => {
  it('returns ok', async () => {
    const res = await call('/healthz')
    expect(res.status).toBe(200)
    expect(await res.text()).toBe('ok')
  })

  it('unknown route is 404 with the error envelope', async () => {
    const res = await call('/nope')
    expect(res.status).toBe(404)
    expect((await res.json() as any).error.code).toBe('not_found')
  })

  it('OPTIONS preflight is 204', async () => {
    const res = await call('/v1/register', { method: 'OPTIONS' })
    expect(res.status).toBe(204)
  })
})
