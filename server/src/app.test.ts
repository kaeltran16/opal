import { describe, it, expect, beforeEach } from 'vitest'
import { buildApp } from './app.js'
import { TokenStore } from './store.js'

function fakePal() {
  return {
    chat: async () => 'reply text',
    parse: async () => ({ type: 'money', amount: 5, duration: null, category: 'Coffee', title: 'Coffee', note: null }),
    review: async () => 'review text',
    suggestWorkout: async () => ({ routineId: 'r2', reason: 'Legs rested.' }),
    postWorkoutNote: async () => 'note text',
  }
}

describe('app', () => {
  let app: ReturnType<typeof buildApp>
  let store: TokenStore

  beforeEach(async () => {
    store = new TokenStore(':memory:')
    app = buildApp({ pal: fakePal() as never, store, provisioningKey: 'secret', corsOrigins: [] })
    await app.ready()
  })

  it('GET /healthz returns 200', async () => {
    const res = await app.inject({ method: 'GET', url: '/healthz' })
    expect(res.statusCode).toBe(200)
  })

  it('register issues a token only with the right provisioning key', async () => {
    const bad = await app.inject({ method: 'POST', url: '/v1/register', payload: { provisioningKey: 'wrong', deviceId: 'd1' } })
    expect(bad.statusCode).toBe(401)

    const ok = await app.inject({ method: 'POST', url: '/v1/register', payload: { provisioningKey: 'secret', deviceId: 'd1' } })
    expect(ok.statusCode).toBe(200)
    expect(ok.json().token).toHaveLength(64)
  })

  it('rejects a protected route without a valid token', async () => {
    const res = await app.inject({ method: 'POST', url: '/v1/parse', payload: { text: 'coffee 5' } })
    expect(res.statusCode).toBe(401)
  })

  it('serves /v1/parse with a valid token', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/parse',
      headers: { authorization: `Bearer ${token}` },
      payload: { text: 'coffee 5' },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().title).toBe('Coffee')
  })

  it('returns 400 on a malformed body', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/chat',
      headers: { authorization: `Bearer ${token}` },
      payload: { message: 'hi' }, // missing history + context
    })
    expect(res.statusCode).toBe(400)
  })

  it('serves /v1/chat and returns the reply', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/chat',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        history: [], message: 'hi',
        context: {
          userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalMin: 30, ritualGoal: 5,
          spentToday: 0, movedTodayMin: 0, ritualsDoneToday: 0,
          weekSpent: 0, weekBudget: 420, weekMovedMin: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
        },
      },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().reply).toBe('reply text')
  })
})
