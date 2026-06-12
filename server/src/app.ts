import Fastify, { type FastifyInstance, type FastifyRequest, type FastifyReply } from 'fastify'
import rateLimit from '@fastify/rate-limit'
import { z } from 'zod'
import { extractBearer } from './auth.js'
import { OpenRouterError, type Pal } from './pal.js'
import { ImapAuthError, type ImapCreds } from './imap.js'
import type { EmailWorker } from './email.js'
import type { TokenStore } from './store.js'
import type { HealthStore } from './health.js'
import { registerBody, chatBody, parseBody, reviewBody, insightsBody, suggestBody, postWorkoutBody, routineBody, emailTestBody, emailSyncBody, healthIngestBody, healthDayQuery } from './schemas.js'

export interface AppDeps {
  pal: Pal
  worker: EmailWorker
  store: TokenStore
  healthStore: HealthStore
  provisioningKey: string
  corsOrigins: string[]
  // enable request logging in production so LLM/IMAP failures aren't silent (Bug D).
  logger?: boolean
}

// first-sync window when the client has no prior sync time
const DEFAULT_SYNC_WINDOW_MS = 7 * 24 * 60 * 60 * 1000

export function buildApp(deps: AppDeps): FastifyInstance {
  const app = Fastify({ logger: deps.logger ?? false })

  // key by device token so one client can't burn the budget by rotating IPs, and
  // devices behind a shared carrier NAT don't collide. falls back to ip for register/healthz.
  app.register(rateLimit, {
    max: 60,
    timeWindow: '1 minute',
    keyGenerator: (req) => extractBearer(req.headers.authorization) ?? req.ip,
  })

  // minimal CORS for the chrome preview; no extra dep needed. stays at the root so it
  // intercepts unmatched OPTIONS preflights (which never reach the child plugin's routes).
  app.addHook('onRequest', async (req, reply) => {
    const origin = req.headers.origin
    if (origin && deps.corsOrigins.includes(origin)) {
      reply.header('Access-Control-Allow-Origin', origin)
      reply.header('Vary', 'Origin')
      reply.header('Access-Control-Allow-Headers', 'authorization,content-type')
      reply.header('Access-Control-Allow-Methods', 'POST,GET,OPTIONS')
    }
    if (req.method === 'OPTIONS') reply.code(204).send()
  })

  // routes live in a child plugin registered after rate-limit so its onRoute hook
  // catches them; routes added at the root before the (un-awaited) plugin loads stay
  // unlimited.
  app.register(async (app) => {
  app.get('/healthz', async () => 'ok')

  app.post('/v1/register', async (req, reply) => {
    const parsed = registerBody.safeParse(req.body)
    if (!parsed.success) return reply.code(400).send({ error: { code: 'bad_request', message: 'invalid body' } })
    if (parsed.data.provisioningKey !== deps.provisioningKey) {
      return reply.code(401).send({ error: { code: 'unauthorized', message: 'bad provisioning key' } })
    }
    return { token: deps.store.issue(parsed.data.deviceId) }
  })

  // bearer guard for every /v1/* route except /v1/register
  app.addHook('preHandler', async (req: FastifyRequest, reply: FastifyReply) => {
    if (!req.url.startsWith('/v1/') || req.url.startsWith('/v1/register')) return
    const token = extractBearer(req.headers.authorization)
    if (!token || !deps.store.isValid(token)) {
      return reply.code(401).send({ error: { code: 'unauthorized', message: 'invalid token' } })
    }
  })

  const guard = <T>(schema: z.ZodType<T>, handler: (body: T) => Promise<unknown>) =>
    async (req: FastifyRequest, reply: FastifyReply) => {
      const parsed = schema.safeParse(req.body)
      if (!parsed.success) return reply.code(400).send({ error: { code: 'bad_request', message: 'invalid body' } })
      try {
        return await handler(parsed.data)
      } catch (err) {
        const status = err instanceof OpenRouterError ? 502 : 500
        req.log?.error?.(err)
        return reply.code(status).send({ error: { code: 'upstream', message: 'pal request failed' } })
      }
    }

  app.post('/v1/chat', guard(chatBody, async (b) => deps.pal.chat(b.history, b.message, b.context)))
  app.post('/v1/parse', guard(parseBody, async (b) => deps.pal.parse(b.text)))
  app.post('/v1/review', guard(reviewBody, async (b) => ({ text: await deps.pal.review(b.context) })))
  app.post('/v1/insights', guard(insightsBody, async (b) => deps.pal.insights(b.context)))
  app.post('/v1/suggest-workout', guard(suggestBody, async (b) => deps.pal.suggestWorkout(b.another, b.context)))
  app.post('/v1/post-workout-note', guard(postWorkoutBody, async (b) => ({ note: await deps.pal.postWorkoutNote(b.context) })))
  app.post('/v1/routine', guard(routineBody, async (b) => deps.pal.generateRoutine(b.goal, b.exercises)))

  app.post('/v1/health/ingest', guard(healthIngestBody, async (b) =>
    ({ upserted: deps.healthStore.upsert(b.date, b.metrics, b.capturedAt) })))

  app.get('/v1/health/day', async (req, reply) => {
    const parsed = healthDayQuery.safeParse(req.query)
    if (!parsed.success) return reply.code(400).send({ error: { code: 'bad_request', message: 'invalid query' } })
    return { date: parsed.data.date, metrics: deps.healthStore.getDay(parsed.data.date) }
  })

  // Email routes map IMAP auth failures to 401 (bad app-password) vs. 502 (LLM/IMAP transport).
  const emailGuard = <T>(schema: z.ZodType<T>, handler: (body: T) => Promise<unknown>) =>
    async (req: FastifyRequest, reply: FastifyReply) => {
      const parsed = schema.safeParse(req.body)
      if (!parsed.success) return reply.code(400).send({ error: { code: 'bad_request', message: 'invalid body' } })
      try {
        return await handler(parsed.data)
      } catch (err) {
        // 422 (not 401) so it never collides with the bearer-token 401 the client retries.
        if (err instanceof ImapAuthError) {
          return reply.code(422).send({ error: { code: 'imap_auth', message: 'imap authentication failed' } })
        }
        const status = err instanceof OpenRouterError ? 502 : 500
        req.log?.error?.(err)
        return reply.code(status).send({ error: { code: 'upstream', message: 'email sync failed' } })
      }
    }

  const credsOf = (b: { host: string; port: number; address: string; appPassword: string }): ImapCreds =>
    ({ host: b.host, port: b.port, address: b.address, appPassword: b.appPassword })

  app.post('/v1/email/test', emailGuard(emailTestBody, async (b) => {
    try {
      await deps.worker.test(credsOf(b))
      return { ok: true }
    } catch (err) {
      if (err instanceof ImapAuthError) return { ok: false } // expected outcome, not an error
      throw err
    }
  }))

  app.post('/v1/email/sync', emailGuard(emailSyncBody, async (b) => {
    const since = new Date(b.since ?? Date.now() - DEFAULT_SYNC_WINDOW_MS)
    return deps.worker.sync(credsOf(b), b.senderFilters ?? [], since) // { items, truncated }
  }))
  })

  return app
}
