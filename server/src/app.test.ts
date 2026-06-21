import { describe, it, expect, beforeEach } from 'vitest'
import { buildApp } from './app.js'
import { ImapAuthError } from './imap.js'
import { TokenStore } from './store.js'
import { HealthStore } from './health.js'
import { WidgetSnapshotStore } from './widget.js'
import { MemoryStore } from './memory.js'

function fakePal() {
  return {
    chat: async () => ({ reply: 'reply text', actions: [{ kind: 'log_expense', amount: 5, category: 'Coffee', title: 'coffee', note: null }], memoryOps: [] }),
    parse: async () => ({ type: 'money', amount: 5, duration: null, category: 'Coffee', title: 'Coffee', note: null }),
    review: async () => 'review text',
    insights: async () => ({ headline: 'Spending eased mid-week.', lede: null, suggestion: null, wins: [], patterns: [] }),
    suggestWorkout: async () => ({ routineId: 'r2', reason: 'Legs rested.' }),
    postWorkoutNote: async () => 'note text',
    generateRoutine: async () => ({
      name: 'Push Day', tag: 'upper', estMin: 45, rationale: 'compound first',
      exercises: [{ exerciseId: 'e1', sets: [{ reps: 8, weight: 40, duration: null }] }],
    }),
    agenda: async () => ({ proposals: [], autopilot: [], streakDays: 0 }),
    refreshPatterns: async () => [{ colorToken: 'money', title: 't', detail: 'd' }],
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

// builds an app wired with a fresh MemoryStore and an already-issued token, for
// the memory routes. palOverrides swaps in a fake Pal method per test.
function buildTestApp(palOverrides: Record<string, unknown> = {}) {
  const store = new TokenStore(':memory:')
  const memory = new MemoryStore(':memory:')
  const app = buildApp({
    pal: { ...fakePal(), ...palOverrides } as never,
    worker: fakeWorker() as never,
    store, memory,
    healthStore: new HealthStore(':memory:'),
    widgetStore: new WidgetSnapshotStore(':memory:'),
    provisioningKey: 'secret', corsOrigins: [],
  })
  const token = store.issue('d1')
  return { app, memory, token }
}

const insightsCtxFixture = {
  range: 'week', spent: 200, budget: 420, moveKcal: 1400, moveTargetKcal: 2100,
  ritualsKept: 18, ritualsTarget: 35, activeDays: 5, streakDays: 11,
  topCategory: 'Food', topCategoryPct: 34, spendByWeekday: [10, 20, 30, 40, 50, 25, 25], entries: [],
}

describe('memory endpoints', () => {
  it('GET /v1/memory returns the stored digest for the token', async () => {
    const { app, memory, token } = buildTestApp()
    memory.addFact(token, 'rent due on the 1st')
    const res = await app.inject({ method: 'GET', url: '/v1/memory', headers: { authorization: `Bearer ${token}` } })
    expect(res.statusCode).toBe(200)
    expect(res.json().facts[0].text).toBe('rent due on the 1st')
  })

  it('DELETE /v1/memory/facts/:id forgets one fact', async () => {
    const { app, memory, token } = buildTestApp()
    const f = memory.addFact(token, 'vegetarian')
    const res = await app.inject({ method: 'DELETE', url: `/v1/memory/facts/${f.id}`, headers: { authorization: `Bearer ${token}` } })
    expect(res.statusCode).toBe(200)
    expect(memory.listFacts(token)).toEqual([])
  })

  it('DELETE /v1/memory wipes all memory', async () => {
    const { app, memory, token } = buildTestApp()
    memory.addFact(token, 'a'); memory.setPatterns(token, [{ colorToken: 'money', title: 't', detail: 'd' }])
    await app.inject({ method: 'DELETE', url: '/v1/memory', headers: { authorization: `Bearer ${token}` } })
    expect(memory.digest(token)).toEqual({ facts: [], patterns: [] })
  })

  it('POST /v1/memory/refresh rewrites patterns and returns the digest', async () => {
    const { app, memory, token } = buildTestApp() // fake Pal.refreshPatterns returns one pattern
    const res = await app.inject({
      method: 'POST', url: '/v1/memory/refresh',
      headers: { authorization: `Bearer ${token}` },
      payload: { context: insightsCtxFixture },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().patterns).toHaveLength(1)
    expect(memory.getPatterns(token)).toHaveLength(1)
  })

  it('rejects memory routes without a valid token', async () => {
    const { app } = buildTestApp()
    expect((await app.inject({ method: 'GET', url: '/v1/memory' })).statusCode).toBe(401)
  })

  it('chat applies memoryOps to the store and never returns them as actions', async () => {
    const { app, memory, token } = buildTestApp({
      chat: async () => ({ reply: 'ok', actions: [], memoryOps: [{ op: 'remember', text: 'likes oat milk' }] }),
    })
    const res = await app.inject({
      method: 'POST', url: '/v1/chat',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        history: [], message: 'i like oat milk',
        context: {
          userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalKcal: 400, ritualGoal: 5,
          spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0,
          weekSpent: 0, weekBudget: 420, weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
          hourOfDay: 8, weekday: 6,
        },
      },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json()).not.toHaveProperty('memoryOps')
    expect(memory.listFacts(token).map((f) => f.text)).toContain('likes oat milk')
  })
})

describe('app', () => {
  let app: ReturnType<typeof buildApp>
  let store: TokenStore

  function build(worker = fakeWorker()) {
    store = new TokenStore(':memory:')
    return buildApp({ pal: fakePal() as never, worker: worker as never, store, memory: new MemoryStore(':memory:'), healthStore: new HealthStore(':memory:'), widgetStore: new WidgetSnapshotStore(':memory:'), provisioningKey: 'secret', corsOrigins: [] })
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
          userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalKcal: 400, ritualGoal: 5,
          spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0,
          weekSpent: 0, weekBudget: 420, weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
          hourOfDay: 8, weekday: 6,
        },
      },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().reply).toBe('reply text')
    expect(res.json().actions).toEqual([{ kind: 'log_expense', amount: 5, category: 'Coffee', title: 'coffee', note: null }])
  })

  const insightsCtx = {
    range: 'week', spent: 200, budget: 420, moveKcal: 1400, moveTargetKcal: 2100,
    ritualsKept: 18, ritualsTarget: 35, activeDays: 5, streakDays: 11,
    topCategory: 'Food', topCategoryPct: 34, spendByWeekday: [10, 20, 30, 40, 50, 25, 25], entries: [],
    correlation: { summary: 'On your 12 workout days you averaged $34; on your 16 rest days, $52.' },
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

  const health = {
    date: '2026-06-12',
    capturedAt: '2026-06-12T18:42:00Z',
    metrics: { steps: { value: 8423, unit: 'count' }, avgHeartRate: { value: 72, unit: 'bpm' } },
  }

  it('rejects /v1/health/ingest without a valid token', async () => {
    const res = await app.inject({ method: 'POST', url: '/v1/health/ingest', payload: health })
    expect(res.statusCode).toBe(401)
  })

  it('ingests health metrics and reports the count upserted', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/health/ingest',
      headers: { authorization: `Bearer ${token}` }, payload: health,
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().upserted).toBe(2)
  })

  it('returns 400 on an unknown metric name', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/health/ingest',
      headers: { authorization: `Bearer ${token}` },
      payload: { ...health, metrics: { bogus: { value: 1, unit: 'x' } } },
    })
    expect(res.statusCode).toBe(400)
  })

  it('ingests without capturedAt (server stamps its own receive time)', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/health/ingest',
      headers: { authorization: `Bearer ${token}` },
      payload: { date: '2026-06-18', metrics: { activeEnergy: { value: 450, unit: 'kcal' } } },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().upserted).toBe(1)
  })

  it('returns 400 on a malformed date', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/health/ingest',
      headers: { authorization: `Bearer ${token}` },
      payload: { ...health, date: '06/12/2026' },
    })
    expect(res.statusCode).toBe(400)
  })

  it('names the failing field in the 400 (e.g. a string value)', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/health/ingest',
      headers: { authorization: `Bearer ${token}` },
      // a Shortcut typing the dictionary value as Text sends "450" not 450
      payload: { ...health, metrics: { activeEnergy: { value: '450', unit: 'kcal' } } },
    })
    expect(res.statusCode).toBe(400)
    const details = res.json().error.details as string[]
    const hit = details.find((d) => d.includes('metrics.activeEnergy.value'))
    expect(hit).toBeDefined()
    expect(hit).toContain('received: "450"') // echoes the offending value
  })

  it('reads back an ingested day', async () => {
    const token = store.issue('d1')
    await app.inject({ method: 'POST', url: '/v1/health/ingest', headers: { authorization: `Bearer ${token}` }, payload: health })
    const res = await app.inject({ method: 'GET', url: '/v1/health/day?date=2026-06-12', headers: { authorization: `Bearer ${token}` } })
    expect(res.statusCode).toBe(200)
    expect(res.json().metrics.steps.value).toBe(8423)
  })

  it('rejects /v1/health/day with a bad date', async () => {
    const token = store.issue('d1')
    const res = await app.inject({ method: 'GET', url: '/v1/health/day?date=bad', headers: { authorization: `Bearer ${token}` } })
    expect(res.statusCode).toBe(400)
  })

  const snapshot = {
    moneyRing: 0.7, moveRing: 0.45, ritualsRing: 0.6,
    moneySpent: 42, dailyBudget: 60,
    moveKcal: 180, dailyMoveKcal: 400,
    ritualsDone: 3, dailyRitualTarget: 5,
  }

  it('rejects /v1/widget/snapshot without a valid token', async () => {
    const post = await app.inject({ method: 'POST', url: '/v1/widget/snapshot', payload: snapshot })
    expect(post.statusCode).toBe(401)
    const get = await app.inject({ method: 'GET', url: '/v1/widget/snapshot' })
    expect(get.statusCode).toBe(401)
  })

  it('returns 404 before any snapshot is posted', async () => {
    const token = store.issue('d1')
    const res = await app.inject({ method: 'GET', url: '/v1/widget/snapshot', headers: { authorization: `Bearer ${token}` } })
    expect(res.statusCode).toBe(404)
  })

  it('stores and reads back the rings snapshot', async () => {
    const token = store.issue('d1')
    const post = await app.inject({
      method: 'POST', url: '/v1/widget/snapshot',
      headers: { authorization: `Bearer ${token}` }, payload: snapshot,
    })
    expect(post.statusCode).toBe(200)
    expect(post.json().ok).toBe(true)

    const get = await app.inject({ method: 'GET', url: '/v1/widget/snapshot', headers: { authorization: `Bearer ${token}` } })
    expect(get.statusCode).toBe(200)
    expect(get.json()).toEqual(snapshot)
  })

  it('overwrites the snapshot on a second post (latest wins)', async () => {
    const token = store.issue('d1')
    await app.inject({ method: 'POST', url: '/v1/widget/snapshot', headers: { authorization: `Bearer ${token}` }, payload: snapshot })
    await app.inject({
      method: 'POST', url: '/v1/widget/snapshot',
      headers: { authorization: `Bearer ${token}` }, payload: { ...snapshot, moneySpent: 99 },
    })
    const get = await app.inject({ method: 'GET', url: '/v1/widget/snapshot', headers: { authorization: `Bearer ${token}` } })
    expect(get.json().moneySpent).toBe(99)
  })

  it('returns 400 when ring fractions are non-finite', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/widget/snapshot',
      headers: { authorization: `Bearer ${token}` },
      payload: { ...snapshot, moveKcal: 1.5 }, // must be an int
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

describe('rate limit keying', () => {
  let app: ReturnType<typeof buildApp>
  let store: TokenStore

  beforeEach(async () => {
    store = new TokenStore(':memory:')
    app = buildApp({ pal: fakePal() as never, worker: fakeWorker() as never, store, memory: new MemoryStore(':memory:'), healthStore: new HealthStore(':memory:'), widgetStore: new WidgetSnapshotStore(':memory:'), provisioningKey: 'secret', corsOrigins: [] })
    await app.ready()
  })

  const hit = (token: string) =>
    app.inject({ method: 'POST', url: '/v1/parse', headers: { authorization: `Bearer ${token}` }, payload: { text: 'coffee 5' } })

  it('gives different bearer tokens independent buckets', async () => {
    const a = store.issue('da')
    const b = store.issue('db')
    // exhaust token a's 60/min bucket; token b must be untouched.
    for (let i = 0; i < 60; i++) expect((await hit(a)).statusCode).toBe(200)
    expect((await hit(a)).statusCode).toBe(429)
    expect((await hit(b)).statusCode).toBe(200)
  })

  it('shares one bucket across requests with the same bearer token', async () => {
    const a = store.issue('da')
    for (let i = 0; i < 60; i++) expect((await hit(a)).statusCode).toBe(200)
    expect((await hit(a)).statusCode).toBe(429)
  })
})

describe('cors', () => {
  const allowed = 'https://web.example'

  function buildCors() {
    const store = new TokenStore(':memory:')
    return buildApp({ pal: fakePal() as never, worker: fakeWorker() as never, store, memory: new MemoryStore(':memory:'), healthStore: new HealthStore(':memory:'), widgetStore: new WidgetSnapshotStore(':memory:'), provisioningKey: 'secret', corsOrigins: [allowed] })
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
