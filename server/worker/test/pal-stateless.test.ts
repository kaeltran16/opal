import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect, vi } from 'vitest'
import { handle } from '../src/worker'
import { stubPal } from './support/stub-client'
import { OpenRouterError } from '../../src/pal'

// minimal schema-valid fixtures (schemas.ts: chatContext / suggestContext / postWorkoutContext).
const CHAT_CTX = {
  userName: 'A', todayEntries: [], dailyBudget: 100, moveGoalKcal: 400, ritualGoal: 3,
  spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 700,
  weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 21, moveStreakDays: 0, hourOfDay: 9, weekday: 1,
}
const SUGGEST_CTX = {
  recentWorkouts: [{ routineName: 'Push', date: '2026-07-20', muscles: 'chest' }],
  dayOfWeek: 'Monday',
  availableRoutines: [{ id: 'r1', name: 'Push' }],
}
const POST_WORKOUT_CTX = {
  routineName: 'Push', setCount: 12, volumeKg: 4000, prCount: 1, prExercises: ['bench'],
  lastSessionVolumeKg: 3800, daysAgoLastSession: 3,
}

async function token(): Promise<string> {
  const res = await handle(new Request('https://x/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  }), env as any)
  return (await res.json() as any).token
}

const post = (tok: string, path: string, body: unknown, pal?: any) =>
  handle(new Request(`https://x${path}`, {
    method: 'POST', headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  }), env as any, pal ? { pal } : undefined)

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('stateless pal routes', () => {
  it('POST /v1/parse returns the parsed entry shape', async () => {
    const tok = await token()
    const canned = JSON.stringify({ type: 'money', amount: 5000, duration: null, category: 'Coffee', title: 'coffee', note: null, direction: 'expense' })
    const res = await post(tok, '/v1/parse', { text: 'coffee 5k' }, stubPal({ text: canned }))
    expect(res.status).toBe(200)
    expect((await res.json() as any).type).toBe('money')
  })

  it('POST /v1/nutrition/estimate returns the estimate shape', async () => {
    const tok = await token()
    const canned = JSON.stringify({ name: 'burrito', calLo: 400, calHi: 700, confidence: 'med' })
    const res = await post(tok, '/v1/nutrition/estimate', { text: 'a burrito' }, stubPal({ text: canned }))
    expect(await res.json()).toMatchObject({ name: 'burrito', calLo: 400, calHi: 700 })
  })

  it('POST /v1/suggest-workout returns { routineId, reason }', async () => {
    const tok = await token()
    const canned = JSON.stringify({ routineId: 'r1', reason: 'legs are fresh' })
    const res = await post(tok, '/v1/suggest-workout', { another: false, context: SUGGEST_CTX }, stubPal({ text: canned }))
    expect(await res.json()).toEqual({ routineId: 'r1', reason: 'legs are fresh' })
  })

  it('POST /v1/post-workout-note wraps the note string', async () => {
    const tok = await token()
    const res = await post(tok, '/v1/post-workout-note', { context: POST_WORKOUT_CTX }, stubPal({ text: 'strong session' }))
    expect(await res.json()).toEqual({ note: 'strong session' })
  })

  it('POST /v1/agenda returns 200 with and without targets', async () => {
    const tok = await token()
    const canned = JSON.stringify({ proposals: [{ kind: 'close_out', title: 't', body: 'b', approveLabel: 'Go', doneLabel: 'Went' }], autopilot: [] })
    const targets = { rituals: [], workouts: [{ id: 'w1', name: 'Push' }], week: [{ weekday: 1, routineId: null }] }
    for (const body of [{ context: CHAT_CTX }, { context: CHAT_CTX, targets }]) {
      const res = await post(tok, '/v1/agenda', body, stubPal({ text: canned }))
      expect(res.status).toBe(200)
      expect((await res.json() as any).proposals[0].action).toBe('close_out')
    }
  })

  it('POST /v1/suggestions returns derived chips', async () => {
    const tok = await token()
    const canned = JSON.stringify({ suggestions: [{ kind: 'log_money', colorToken: 'money', label: 'Log spend', entry: null }] })
    const res = await post(tok, '/v1/suggestions', { surface: 'composer', context: CHAT_CTX }, stubPal({ text: canned }))
    expect((await res.json() as any).suggestions[0].icon).toBe('dollarsign.circle.fill')
  })

  it('400 on malformed body', async () => {
    const tok = await token()
    const res = await post(tok, '/v1/parse', { notText: 1 }, stubPal({ text: '{}' }))
    expect(res.status).toBe(400)
  })

  it('502 on OpenRouterError, 500 on generic error', async () => {
    const tok = await token()
    const r502 = await post(tok, '/v1/parse', { text: 'x' }, stubPal({ error: new OpenRouterError(500, 'boom') }))
    expect(r502.status).toBe(502)
    expect((await r502.json() as any).error.code).toBe('upstream')
    const r500 = await post(tok, '/v1/parse', { text: 'x' }, stubPal({ error: new Error('nope') }))
    expect(r500.status).toBe(500)
  })

  it('logs every Pal failure with its route and reason', async () => {
    const tok = await token()
    const logs: string[] = []
    const spy = vi.spyOn(console, 'error').mockImplementation((line: string) => { logs.push(line) })
    try {
      const truncated = new OpenRouterError(502, 'model output truncated (finish_reason=length) at max_tokens=1024')
      await post(tok, '/v1/suggest-workout', { another: false, context: SUGGEST_CTX }, stubPal({ error: truncated }))
      // a schema failure names the field, never the model output it quotes.
      await post(tok, '/v1/suggest-workout', { another: false, context: SUGGEST_CTX }, stubPal({ text: '{"routineId":"secret-out"}' }))
    } finally {
      spy.mockRestore()
    }
    expect(logs.map((l) => JSON.parse(l))).toEqual([
      { msg: 'pal request failed', route: '/v1/suggest-workout', status: 502, reason: 'model output truncated (finish_reason=length) at max_tokens=1024' },
      { msg: 'pal request failed', route: '/v1/suggest-workout', status: 500, reason: 'ZodError: reason invalid_type' },
    ])
  })
})
