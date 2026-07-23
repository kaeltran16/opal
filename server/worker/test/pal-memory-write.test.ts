import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import { handle } from '../src/worker'
import { stubPal } from './support/stub-client'
import { OpenRouterError } from '../../src/pal'

const CHAT_CTX = {
  userName: 'A', todayEntries: [], dailyBudget: 100, moveGoalKcal: 400, ritualGoal: 3,
  spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 700,
  weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 21, moveStreakDays: 0, hourOfDay: 9, weekday: 1,
}
const INSIGHTS_CTX = {
  range: 'week', spent: 100, budget: 700, moveKcal: 2000, moveTargetKcal: 2800,
  ritualsKept: 10, ritualsTarget: 21, activeDays: 4, streakDays: 4,
  topCategory: 'Coffee', topCategoryPct: 30, spendByWeekday: [10, 20, 0, 5, 0, 30, 35], entries: [],
}

// a distinct deviceId per test yields a distinct token; memory is keyed by token,
// so tests stay independent even though storage is not reset between them.
async function token(deviceId: string): Promise<string> {
  const res = await handle(new Request('https://x/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId }),
  }), env as any)
  return (await res.json() as any).token
}

const post = (tok: string, path: string, body: unknown, pal?: any) =>
  handle(new Request(`https://x${path}`, {
    method: 'POST', headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  }), env as any, pal ? { pal } : undefined)

const getMemory = (tok: string) =>
  handle(new Request('https://x/v1/memory', { headers: { authorization: `Bearer ${tok}` } }), env as any)

const chatBodyFor = (message: string) => ({ history: [], message, context: CHAT_CTX })

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('memory-write pal routes', () => {
  it('POST /v1/chat returns { reply, actions } and never exposes memoryOps', async () => {
    const tok = await token('chat-plain')
    const pal = stubPal({ tool: { content: 'hi there', toolCalls: [] } })
    const res = await post(tok, '/v1/chat', chatBodyFor('hello'), pal)
    expect(res.status).toBe(200)
    const body = await res.json() as any
    expect(body).toEqual({ reply: 'hi there', actions: [] })
    expect('memoryOps' in body).toBe(false)
  })

  it('POST /v1/chat with a remember tool call persists the fact server-side', async () => {
    const tok = await token('chat-remember')
    const pal = stubPal({ tool: { content: '', toolCalls: [{ name: 'remember', arguments: JSON.stringify({ fact: 'likes espresso' }) }] } })
    const res = await post(tok, '/v1/chat', chatBodyFor('remember I like espresso'), pal)
    expect((await res.json() as any).actions).toEqual([])
    const mem = await (await getMemory(tok)).json() as any
    expect(mem.facts.map((f: any) => f.text)).toContain('likes espresso')
  })

  it('POST /v1/chat with a log_expense tool call yields an action, no memory write', async () => {
    const tok = await token('chat-expense')
    const pal = stubPal({ tool: { content: '', toolCalls: [{ name: 'log_expense', arguments: JSON.stringify({ amount: 5000, category: 'Coffee', title: 'coffee' }) }] } })
    const res = await post(tok, '/v1/chat', chatBodyFor('spent 5k on coffee'), pal)
    const body = await res.json() as any
    expect(body.actions[0].kind).toBe('log_expense')
    const mem = await (await getMemory(tok)).json() as any
    expect(mem.facts).toHaveLength(0)
  })

  it('POST /v1/memory/refresh persists patterns and returns the digest', async () => {
    const tok = await token('refresh')
    const canned = JSON.stringify({ patterns: [{ colorToken: 'money', title: 'Coffee habit', detail: 'daily latte' }] })
    const res = await post(tok, '/v1/memory/refresh', { context: INSIGHTS_CTX }, stubPal({ text: canned }))
    expect(res.status).toBe(200)
    expect((await res.json() as any).patterns[0].title).toBe('Coffee habit')
    const mem = await (await getMemory(tok)).json() as any
    expect(mem.patterns[0].title).toBe('Coffee habit')
  })

  it('502 on OpenRouterError, 500 on generic error for /v1/chat', async () => {
    const tok = await token('chat-errors')
    const r502 = await post(tok, '/v1/chat', chatBodyFor('x'), stubPal({ error: new OpenRouterError(503, 'down') }))
    expect(r502.status).toBe(502)
    const r500 = await post(tok, '/v1/chat', chatBodyFor('x'), stubPal({ error: new Error('boom') }))
    expect(r500.status).toBe(500)
  })
})
