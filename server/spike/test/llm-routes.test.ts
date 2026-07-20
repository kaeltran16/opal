import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'

beforeEach(async () => {
  await applyD1Migrations(env.DB, env.TEST_MIGRATIONS)
  await env.DB.batch([
    env.DB.prepare('DELETE FROM pal_facts'),
    env.DB.prepare('DELETE FROM pal_patterns'),
    env.DB.prepare('DELETE FROM device_tokens'),
  ])
})

async function token(): Promise<string> {
  const res = await worker.fetch(new Request('https://x/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  }), env as any, {} as any)
  return (await res.json() as any).token
}

const post = (path: string, tok: string, body: unknown) =>
  worker.fetch(new Request(`https://x${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${tok}` },
    body: JSON.stringify(body),
  }), env as any, {} as any)

describe('LLM routes (stub mode)', () => {
  it('chat returns { reply, actions }', async () => {
    const tok = await token()
    const res = await post('/v1/chat', tok, {
      history: [], message: 'log 12k coffee',
      context: { userName: 'K', todayEntries: [], dailyBudget: 100, moveGoalKcal: 500, ritualGoal: 3,
        spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 700,
        weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 21, moveStreakDays: 0, hourOfDay: 9, weekday: 1 },
    })
    expect(res.status).toBe(200)
    const b = await res.json() as any
    expect(b).toHaveProperty('reply')
    expect(Array.isArray(b.actions)).toBe(true)
  })

  it('routine returns a validated routine', async () => {
    const tok = await token()
    const res = await post('/v1/routine', tok, {
      goal: 'push day',
      // id must intersect STUB.routine's emitted exerciseIds (ex-0..ex-35);
      // generateRoutine drops model exercises not in the provided catalog.
      exercises: [{ id: 'ex-0', name: 'Barbell Bench Press', group: 'Push', equipment: 'Barbell' }],
    })
    expect(res.status).toBe(200)
    expect(await res.json()).toHaveProperty('name')
  })
})
