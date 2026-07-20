import { z } from 'zod'
import type { z as zt } from 'zod'
import { extractBearer } from '../../src/auth.js'
import { OpenRouterClient } from '../../src/pal.js'
import { chatBody, routineBody, insightsBody } from '../../src/schemas.js'
import { extractReceipts } from '../../src/receipts.js'
import type { RawEmail } from '../../src/imap.js'
import { D1TokenStore, D1MemoryStore } from './stores.js'
import { json, error } from './http.js'
import { makePal } from './pal-factory.js'
import { StubClient } from './stub.js'
import { STUB } from '../bench/fixtures.js'

export interface Env {
  DB: D1Database
  OPENROUTER_API_KEY: string
  PAL_PROVISIONING_KEY: string
  OPENROUTER_BASE_URL?: string
  PAL_MODEL?: string
  PAL_REQUEST_TIMEOUT_MS?: string
  CORS_ORIGINS?: string
  STUB_LLM?: string
}

const registerBody = z.object({ provisioningKey: z.string().min(1), deviceId: z.string().min(1) })

// The Worker receives ALREADY-sanitized candidates (redaction is client-side in
// the target). Only the fields receipt extraction reads are accepted.
const emailExtractBody = z.object({
  candidates: z.array(z.object({
    from: z.string(),
    subject: z.string(),
    text: z.string().max(8000),
  })).max(8),
})

// Mirrors server/src/app.ts: a 400 whose details name the failing path + received value.
function badRequest(err: zt.ZodError, body: unknown): Response {
  const valueAtPath = (obj: unknown, path: (string | number)[]): unknown =>
    path.reduce<unknown>((o, k) => (o == null ? o : (o as Record<string, unknown>)[k]), obj)
  const details = err.issues.map((i) => {
    const v = valueAtPath(body, i.path)
    const received = v === undefined ? 'undefined' : JSON.stringify(v).slice(0, 80)
    return `${i.path.join('.') || '(root)'}: ${i.message} (received: ${received})`
  })
  return error('bad_request', 'invalid body', 400, details)
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)
    const { pathname } = url
    const method = request.method

    if (pathname === '/healthz') return new Response('ok')

    const tokens = new D1TokenStore(env.DB)
    const memory = new D1MemoryStore(env.DB)

    if (pathname === '/v1/register' && method === 'POST') {
      const body = await request.json().catch(() => null)
      const parsed = registerBody.safeParse(body)
      if (!parsed.success) return error('bad_request', 'invalid body', 400)
      if (parsed.data.provisioningKey !== env.PAL_PROVISIONING_KEY) {
        return error('unauthorized', 'bad provisioning key', 401)
      }
      return json({ token: await tokens.issue(parsed.data.deviceId) })
    }

    // bearer guard for the rest of /v1/*
    if (pathname.startsWith('/v1/')) {
      const token = extractBearer(request.headers.get('authorization') ?? undefined)
      if (!token || !(await tokens.isValid(token))) {
        return error('unauthorized', 'invalid token', 401)
      }
      return routeAuthed(request, env, url, method, token, memory)
    }

    return error('not_found', 'no such route', 404)
  },
}

async function routeAuthed(
  request: Request, env: Env, url: URL, method: string, token: string, memory: D1MemoryStore,
): Promise<Response> {
  const { pathname } = url

  if (pathname === '/v1/memory' && method === 'GET') return json(await memory.digest(token))
  if (pathname === '/v1/memory' && method === 'DELETE') { await memory.wipe(token); return json({ ok: true }) }
  const factMatch = pathname.match(/^\/v1\/memory\/facts\/(.+)$/)
  if (factMatch && method === 'DELETE') { await memory.forgetFact(token, factMatch[1]); return json(await memory.digest(token)) }

  if (method === 'POST') {
    const raw = await request.json().catch(() => null)

    if (pathname === '/v1/chat') {
      const parsed = chatBody.safeParse(raw)
      if (!parsed.success) return badRequest(parsed.error, raw)
      const pal = makePal(env, STUB.chat)
      const res = await pal.chat(parsed.data.history, parsed.data.message, parsed.data.context, await memory.digest(token))
      await memory.applyOps(token, res.memoryOps)
      return json({ reply: res.reply, actions: res.actions })
    }

    if (pathname === '/v1/insights') {
      const parsed = insightsBody.safeParse(raw)
      if (!parsed.success) return badRequest(parsed.error, raw)
      const pal = makePal(env, STUB.insights)
      return json(await pal.insights(parsed.data.context, await memory.digest(token)))
    }

    if (pathname === '/v1/routine') {
      const parsed = routineBody.safeParse(raw)
      if (!parsed.success) return badRequest(parsed.error, raw)
      const pal = makePal(env, STUB.routine)
      return json(await pal.generateRoutine(parsed.data.goal, parsed.data.exercises, await memory.digest(token)))
    }

    if (pathname === '/v1/email/extract') {
      const parsed = emailExtractBody.safeParse(raw)
      if (!parsed.success) return badRequest(parsed.error, raw)
      // Reuse extractReceipts (DRY). It re-runs redactPii on already-sanitized
      // text — a cheap, conservative CPU over-count vs the target. Map candidates
      // to RawEmail (messageId/date are unused by extraction).
      const emails: RawEmail[] = parsed.data.candidates.map((c, i) => ({
        messageId: `m-${i}`, from: c.from, fromName: c.from, subject: c.subject, date: new Date(0), text: c.text,
      }))
      // extractReceipts needs a TextCompleter ({ complete }), not a Pal — build it directly.
      const completer = env.STUB_LLM === '1'
        ? new StubClient(STUB.receipts)
        : new OpenRouterClient(env.OPENROUTER_API_KEY, env.PAL_MODEL ?? 'deepseek/deepseek-v4-flash',
            env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1', fetch, Number(env.PAL_REQUEST_TIMEOUT_MS ?? 30_000))
      const results = await extractReceipts(emails, completer)
      return json({ results })
    }
  }

  return error('not_found', 'no such route', 404)
}
