import { json, error, badRequest } from './http.js'
import { parseOrigins, preflight, withCors } from './cors.js'
import { extractBearer } from '../../src/auth.js'
import { registerBody, healthIngestBody, healthDayQuery, widgetSnapshotBody } from '../../src/schemas.js'
import { D1TokenStore } from './stores/tokens.js'
import { D1MemoryStore } from './stores/memory.js'
import { D1HealthStore } from './stores/health.js'
import { D1WidgetStore } from './stores/widget.js'

export interface Env {
  DB: D1Database
  RL: RateLimit
  PAL_PROVISIONING_KEY: string
  CORS_ORIGINS?: string
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origins = parseOrigins(env.CORS_ORIGINS)
    if (request.method === 'OPTIONS') return preflight(request, origins)
    let res: Response
    try {
      res = await route(request, env)
    } catch {
      // never leak internals; log left to Worker observability (no prompts/PII here anyway).
      res = error('upstream', 'request failed', 500)
    }
    return withCors(res, request, origins)
  },
}

async function route(request: Request, env: Env): Promise<Response> {
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
    return routeAuthed(request, env, url, method, token)
  }

  return error('not_found', 'no such route', 404)
}

async function routeAuthed(
  request: Request, env: Env, url: URL, method: string, token: string,
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

  return error('not_found', 'no such route', 404)
}
