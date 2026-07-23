import { json, error, badRequest } from './http.js'
import { parseOrigins, preflight, withCors } from './cors.js'
import { extractBearer } from '../../src/auth.js'
import { registerBody, healthIngestBody, healthDayQuery, widgetSnapshotBody } from '../../src/schemas.js'
import {
  chatBody, parseBody, nutritionEstimateBody, reviewBody, insightsBody, suggestBody,
  postWorkoutBody, routineBody, agendaBody, suggestionsBody, memoryRefreshBody,
} from '../../src/schemas.js'
import { D1TokenStore } from './stores/tokens.js'
import { D1MemoryStore } from './stores/memory.js'
import { D1HealthStore } from './stores/health.js'
import { D1WidgetStore } from './stores/widget.js'
import { makePal } from './pal-factory.js'
import { OpenRouterError, type Pal } from '../../src/pal.js'

export interface Env {
  DB: D1Database
  RL: RateLimit
  PAL_PROVISIONING_KEY: string
  CORS_ORIGINS?: string
  OPENROUTER_API_KEY: string
  OPENROUTER_BASE_URL?: string
  PAL_MODEL?: string
  PAL_REQUEST_TIMEOUT_MS?: string
}

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return handle(request, env)
  },
}

// exported so tests can inject a stub Pal without a network. production passes no overrides.
export async function handle(request: Request, env: Env, overrides?: { pal?: Pal }): Promise<Response> {
  const origins = parseOrigins(env.CORS_ORIGINS)
  if (request.method === 'OPTIONS') return preflight(request, origins)
  let res: Response
  try {
    res = await route(request, env, overrides)
  } catch {
    // never leak internals; log left to Worker observability (no prompts/PII here anyway).
    res = error('upstream', 'request failed', 500)
  }
  return withCors(res, request, origins)
}

async function route(request: Request, env: Env, overrides?: { pal?: Pal }): Promise<Response> {
  const url = new URL(request.url)
  const { pathname } = url
  const method = request.method

  if (pathname === '/healthz') return new Response('ok') // unlimited: monitoring

  // rate limit everything else by token, else by client IP (matches app.ts keyGenerator).
  const rlKey = extractBearer(request.headers.get('authorization') ?? undefined)
    ?? request.headers.get('cf-connecting-ip') ?? 'anon'
  const { success } = await env.RL.limit({ key: rlKey })
  if (!success) return error('rate_limited', 'too many requests', 429)

  const tokens = new D1TokenStore(env.DB)

  if (pathname === '/v1/register' && method === 'POST') {
    const body = await request.json().catch(() => null)
    const parsed = registerBody.safeParse(body)
    if (!parsed.success) return error('bad_request', 'invalid body', 400)
    if (parsed.data.provisioningKey !== env.PAL_PROVISIONING_KEY) {
      return error('unauthorized', 'bad provisioning key', 401)
    }
    return json({ token: await tokens.issue(parsed.data.deviceId) })
  }

  if (pathname.startsWith('/v1/')) {
    const token = extractBearer(request.headers.get('authorization') ?? undefined)
    if (!token || !(await tokens.isValid(token))) {
      return error('unauthorized', 'invalid token', 401)
    }
    return routeAuthed(request, env, url, method, token, overrides)
  }

  return error('not_found', 'no such route', 404)
}

async function routeAuthed(
  request: Request, env: Env, url: URL, method: string, token: string, overrides?: { pal?: Pal },
): Promise<Response> {
  const { pathname } = url
  const memory = new D1MemoryStore(env.DB)

  if (pathname === '/v1/memory' && method === 'GET') return json(await memory.digest(token))
  if (pathname === '/v1/memory' && method === 'DELETE') { await memory.wipe(token); return json({ ok: true }) }
  const factMatch = pathname.match(/^\/v1\/memory\/facts\/(.+)$/)
  if (factMatch && method === 'DELETE') {
    await memory.forgetFact(token, decodeURIComponent(factMatch[1]))
    return json(await memory.digest(token))
  }

  if (pathname === '/v1/health/ingest' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = healthIngestBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    const store = new D1HealthStore(env.DB)
    const upserted = await store.upsert(parsed.data.date, parsed.data.metrics, new Date().toISOString())
    return json({ upserted })
  }

  if (pathname === '/v1/health/day' && method === 'GET') {
    const parsed = healthDayQuery.safeParse({ date: url.searchParams.get('date') })
    if (!parsed.success) return error('bad_request', 'invalid query', 400)
    const store = new D1HealthStore(env.DB)
    return json({ date: parsed.data.date, metrics: await store.getDay(parsed.data.date) })
  }

  if (pathname === '/v1/widget/snapshot' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = widgetSnapshotBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    const store = new D1WidgetStore(env.DB)
    await store.set(parsed.data, Date.now())
    return json({ ok: true })
  }

  if (pathname === '/v1/widget/snapshot' && method === 'GET') {
    const store = new D1WidgetStore(env.DB)
    const snapshot = await store.get()
    if (!snapshot) return error('not_found', 'no snapshot yet', 404)
    return json(snapshot)
  }

  const pal = overrides?.pal ?? makePal(env)
  return routePal(request, env, url, method, token, pal, memory)
}

// map a Pal handler's result to JSON, preserving the app.ts status contract:
// OpenRouterError -> 502, anything else -> 500, both as the `upstream` envelope.
async function runPal(fn: () => Promise<unknown>): Promise<Response> {
  try {
    return json(await fn())
  } catch (err) {
    return error('upstream', 'pal request failed', err instanceof OpenRouterError ? 502 : 500)
  }
}

async function routePal(
  request: Request, env: Env, url: URL, method: string, token: string, pal: Pal, memory: D1MemoryStore,
): Promise<Response> {
  const { pathname } = url

  if (pathname === '/v1/parse' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = parseBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(() => pal.parse(parsed.data.text))
  }

  if (pathname === '/v1/nutrition/estimate' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = nutritionEstimateBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(() => pal.estimateMeal(parsed.data.text))
  }

  if (pathname === '/v1/suggest-workout' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = suggestBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(() => pal.suggestWorkout(parsed.data.another, parsed.data.context))
  }

  if (pathname === '/v1/post-workout-note' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = postWorkoutBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(async () => ({ note: await pal.postWorkoutNote(parsed.data.context) }))
  }

  if (pathname === '/v1/suggestions' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = suggestionsBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(() => pal.suggestions(parsed.data.surface, parsed.data.context))
  }

  if (pathname === '/v1/review' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = reviewBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(async () => ({ text: await pal.review(parsed.data.context, await memory.digest(token)) }))
  }

  if (pathname === '/v1/insights' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = insightsBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(async () => pal.insights(parsed.data.context, await memory.digest(token)))
  }

  if (pathname === '/v1/agenda' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = agendaBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(async () => pal.agenda(parsed.data.context, await memory.digest(token)))
  }

  if (pathname === '/v1/routine' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = routineBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(async () => pal.generateRoutine(parsed.data.goal, parsed.data.exercises, await memory.digest(token)))
  }

  if (pathname === '/v1/chat' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = chatBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(async () => {
      const res = await pal.chat(parsed.data.history, parsed.data.message, parsed.data.context, await memory.digest(token))
      await memory.applyOps(token, res.memoryOps) // server-side; not on the wire
      return { reply: res.reply, actions: res.actions }
    })
  }

  if (pathname === '/v1/memory/refresh' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = memoryRefreshBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    return runPal(async () => {
      const patterns = await pal.refreshPatterns(parsed.data.context, await memory.digest(token))
      await memory.setPatterns(token, patterns)
      return memory.digest(token)
    })
  }

  return error('not_found', 'no such route', 404)
}
