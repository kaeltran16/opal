import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import { handle } from '../src/worker'
import { stubPal } from './support/stub-client'
import { D1MemoryStore } from '../src/stores/memory'

const CHAT_CTX = {
  userName: 'A', todayEntries: [], dailyBudget: 100, moveGoalKcal: 400, ritualGoal: 3,
  spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 700,
  weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 21, moveStreakDays: 4, hourOfDay: 9, weekday: 1,
}
const REVIEW_CTX = {
  range: 'week', spent: 100, spentDeltaPct: 5, kcalMoved: 2000, movedDeltaPct: null,
  activeDays: 4, ritualsKept: 10, ritualsTarget: 21, ritualsPct: 48, streakDays: 4,
  topCategory: 'Coffee', topCategoryPct: 30,
}
const INSIGHTS_CTX = {
  range: 'week', spent: 100, budget: 700, moveKcal: 2000, moveTargetKcal: 2800,
  ritualsKept: 10, ritualsTarget: 21, activeDays: 4, streakDays: 4,
  topCategory: 'Coffee', topCategoryPct: 30, spendByWeekday: [10, 20, 0, 5, 0, 30, 35], entries: [],
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

describe('memory-read pal routes', () => {
  it('POST /v1/review wraps the recap string, digest loaded', async () => {
    const tok = await token()
    await new D1MemoryStore(env.DB).addFact(tok, 'likes coffee') // rides in the prompt, not the response
    const res = await post(tok, '/v1/review', { context: REVIEW_CTX }, stubPal({ text: 'weekly recap' }))
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ text: 'weekly recap' })
  })

  it('POST /v1/insights returns an Insights object', async () => {
    const tok = await token()
    const canned = JSON.stringify({
      headline: 'You saved money', lede: null, suggestion: null,
      wins: [{ colorToken: 'money', title: 'Under budget', sub: '-30%' }],
      patterns: [{ colorToken: 'move', title: 'Morning runs', detail: 'you move most before noon' }],
    })
    const res = await post(tok, '/v1/insights', { context: INSIGHTS_CTX }, stubPal({ text: canned }))
    expect(res.status).toBe(200)
    const body = await res.json() as any
    expect(body.headline).toBe('You saved money')
    expect(body.wins[0].colorToken).toBe('money')
  })

  it('POST /v1/agenda derives icon/action and echoes streakDays', async () => {
    const tok = await token()
    const canned = JSON.stringify({
      proposals: [{ kind: 'close_out', colorToken: 'money', tag: 'Tonight', title: 'Wrap up', body: '...', reason: 'Evening open tonight', approveLabel: 'Do it', doneLabel: 'Done' }],
      autopilot: [],
    })
    const res = await post(tok, '/v1/agenda', { context: { ...CHAT_CTX, hourOfDay: 21 } }, stubPal({ text: canned }))
    expect(res.status).toBe(200)
    const body = await res.json() as any
    expect(body.proposals[0].icon).toBe('moon.stars.fill') // derived from kind=close_out
    expect(body.proposals[0].action).toBe('close_out')
    expect(body.streakDays).toBe(4) // echoed from ctx.moveStreakDays
  })

  it('POST /v1/routine drops non-catalog exercise ids', async () => {
    const tok = await token()
    const canned = JSON.stringify({
      name: 'Push', tag: 'upper',
      exercises: [
        { exerciseId: 'e1', sets: [{ reps: 5 }] },
        { exerciseId: 'invented', sets: [{ reps: 5 }] },
      ],
    })
    const res = await post(tok, '/v1/routine', {
      goal: 'push day',
      exercises: [{ id: 'e1', name: 'Bench', group: 'chest', equipment: null }],
    }, stubPal({ text: canned }))
    expect(res.status).toBe(200)
    const body = await res.json() as any
    expect(body.exercises).toHaveLength(1)
    expect(body.exercises[0].exerciseId).toBe('e1')
  })
})
