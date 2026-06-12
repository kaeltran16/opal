import { describe, it, expect, beforeEach } from 'vitest'
import { buildApp } from './app.js'
import { ImapAuthError } from './imap.js'
import { TokenStore } from './store.js'

function fakePal() {
  return {
    chat: async () => ({ reply: 'reply text', actions: [{ kind: 'log_expense', amount: 5, category: 'Coffee', title: 'coffee', note: null }] }),
    parse: async () => ({ type: 'money', amount: 5, duration: null, category: 'Coffee', title: 'Coffee', note: null }),
    review: async () => 'review text',
    insights: async () => ({ headline: 'Spending eased mid-week.', lede: null, suggestion: null, wins: [], patterns: [] }),
    suggestWorkout: async () => ({ routineId: 'r2', reason: 'Legs rested.' }),
    postWorkoutNote: async () => 'note text',
    generateRoutine: async () => ({
      name: 'Push Day', tag: 'upper', estMin: 45, rationale: 'compound first',
      exercises: [{ exerciseId: 'e1', sets: [{ reps: 8, weight: 40, duration: null }] }],
    }),
  }
}

function fakeWorker(overrides: Partial<{ test: () => Promise<void>; sync: () => Promise<unknown> }> = {}) {
  return {
    test: overrides.test ?? (async () => {}),
    sync:
      overrides.sync ??
      (async () => ({
        items: [
          { id: 'msg-1', merchant: 'Amazon', amount: -42.99, receivedAt: '2026-06-09T10:00:00.000Z', category: 'Shopping' },
        ],
        truncated: false,
      })),
  }
}

describe('app', () => {
  let app: ReturnType<typeof buildApp>
  let store: TokenStore

  function build(worker = fakeWorker()) {
    store = new TokenStore(':memory:')
    return buildApp({ pal: fakePal() as never, worker: worker as never, store, provisioningKey: 'secret', corsOrigins: [] })
  }

  beforeEach(async () => {
    app = build()
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
    expect(res.json().actions).toEqual([{ kind: 'log_expense', amount: 5, category: 'Coffee', title: 'coffee', note: null }])
  })

  const insightsCtx = {
    range: 'week', spent: 200, budget: 420, moveMinutes: 140, moveTarget: 210,
    ritualsKept: 18, ritualsTarget: 35, activeDays: 5, streakDays: 11,
    topCategory: 'Food', topCategoryPct: 34, spendByWeekday: [10, 20, 30, 40, 50, 25, 25], entries: [],
  }

  it('serves /v1/insights with a valid token', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/insights',
      headers: { authorization: `Bearer ${token}` },
      payload: { context: insightsCtx },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().headline).toBe('Spending eased mid-week.')
  })

  it('returns 400 on a malformed /v1/insights body', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/insights',
      headers: { authorization: `Bearer ${token}` },
      payload: { context: { range: 'week' } }, // missing the numeric fields
    })
    expect(res.statusCode).toBe(400)
  })

  it('serves /v1/routine with a valid token', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/routine',
      headers: { authorization: `Bearer ${token}` },
      payload: { goal: 'push day', exercises: [{ id: 'e1', name: 'Bench', group: 'Push', equipment: 'Barbell' }] },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().name).toBe('Push Day')
  })

  it('returns 400 on a malformed /v1/routine body (missing goal)', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/routine',
      headers: { authorization: `Bearer ${token}` },
      payload: { exercises: [] },
    })
    expect(res.statusCode).toBe(400)
  })

  const creds = { host: 'imap.gmail.com', port: 993, address: 'a@b.com', appPassword: 'pw' }

  it('rejects email routes without a valid token', async () => {
    const res = await app.inject({ method: 'POST', url: '/v1/email/sync', payload: creds })
    expect(res.statusCode).toBe(401)
  })

  it('email/test returns ok:true on a good connection', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/email/test',
      headers: { authorization: `Bearer ${token}` }, payload: creds,
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().ok).toBe(true)
  })

  it('email/test returns ok:false on a bad app-password (no 5xx)', async () => {
    app = build(fakeWorker({ test: async () => { throw new ImapAuthError('nope') } }))
    await app.ready()
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/email/test',
      headers: { authorization: `Bearer ${token}` }, payload: creds,
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().ok).toBe(false)
  })

  it('email/sync returns parsed receipt items', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/email/sync',
      headers: { authorization: `Bearer ${token}` },
      payload: { ...creds, senderFilters: [], since: null },
    })
    expect(res.statusCode).toBe(200)
    const body = res.json() as { items: Array<{ merchant: string; amount: number }>; truncated: boolean }
    expect(body.items).toHaveLength(1)
    expect(body.items[0].merchant).toBe('Amazon')
    expect(body.items[0].amount).toBeLessThan(0)
    expect(body.truncated).toBe(false)
  })

  it('email/sync surfaces the truncated flag', async () => {
    app = build(fakeWorker({ sync: async () => ({ items: [], truncated: true }) }))
    await app.ready()
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/email/sync',
      headers: { authorization: `Bearer ${token}` },
      payload: { ...creds, senderFilters: [], since: null },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().truncated).toBe(true)
  })

  it('email/sync maps an IMAP auth failure to 422 (distinct from the bearer 401)', async () => {
    app = build(fakeWorker({ sync: async () => { throw new ImapAuthError('nope') } }))
    await app.ready()
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/email/sync',
      headers: { authorization: `Bearer ${token}` }, payload: creds,
    })
    expect(res.statusCode).toBe(422)
  })
})

describe('cors', () => {
  const allowed = 'https://web.example'

  function buildCors() {
    const store = new TokenStore(':memory:')
    return buildApp({ pal: fakePal() as never, worker: fakeWorker() as never, store, provisioningKey: 'secret', corsOrigins: [allowed] })
  }

  let app: ReturnType<typeof buildApp>
  beforeEach(async () => {
    app = buildCors()
    await app.ready()
  })

  it('echoes Access-Control-Allow-Origin for an allowed origin', async () => {
    const res = await app.inject({ method: 'GET', url: '/healthz', headers: { origin: allowed } })
    expect(res.statusCode).toBe(200)
    expect(res.headers['access-control-allow-origin']).toBe(allowed)
    expect(res.headers['vary']).toBe('Origin')
  })

  it('answers an OPTIONS preflight from an allowed origin with 204 and CORS headers', async () => {
    const res = await app.inject({ method: 'OPTIONS', url: '/v1/register', headers: { origin: allowed } })
    expect(res.statusCode).toBe(204)
    expect(res.headers['access-control-allow-origin']).toBe(allowed)
    expect(res.headers['access-control-allow-headers']).toBe('authorization,content-type')
    expect(res.headers['access-control-allow-methods']).toBe('POST,GET,OPTIONS')
  })

  it('does not echo Access-Control-Allow-Origin for a disallowed origin', async () => {
    const res = await app.inject({ method: 'GET', url: '/healthz', headers: { origin: 'https://evil.example' } })
    expect(res.statusCode).toBe(200)
    expect(res.headers['access-control-allow-origin']).toBeUndefined()
  })
})
