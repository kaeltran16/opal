import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test'
import { describe, it, expect } from 'vitest'
import worker from '../src/worker'

describe('healthz', () => {
  it('returns ok', async () => {
    const ctx = createExecutionContext()
    const res = await worker.fetch(new Request('https://x/healthz'), env as any, ctx)
    await waitOnExecutionContext(ctx)
    expect(res.status).toBe(200)
    expect(await res.text()).toBe('ok')
  })
})
