import Fastify, { type FastifyInstance, type FastifyRequest, type FastifyReply } from 'fastify'
import rateLimit from '@fastify/rate-limit'
import { z } from 'zod'
import { extractBearer } from './auth.js'
import { OpenRouterError, type Pal } from './pal.js'
import type { TokenStore } from './store.js'
import { registerBody, chatBody, parseBody, reviewBody, suggestBody, postWorkoutBody } from './schemas.js'

export interface AppDeps {
  pal: Pal
  store: TokenStore
  provisioningKey: string
  corsOrigins: string[]
}

export function buildApp(deps: AppDeps): FastifyInstance {
  const app = Fastify({ logger: false })

  app.register(rateLimit, { max: 60, timeWindow: '1 minute' })

  // minimal CORS for the chrome preview; no extra dep needed
  app.addHook('onRequest', async (req, reply) => {
    const origin = req.headers.origin
    if (origin && deps.corsOrigins.includes(origin)) {
      reply.header('Access-Control-Allow-Origin', origin)
      reply.header('Access-Control-Allow-Headers', 'authorization,content-type')
      reply.header('Access-Control-Allow-Methods', 'POST,GET,OPTIONS')
    }
    if (req.method === 'OPTIONS') reply.code(204).send()
  })

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

  app.post('/v1/chat', guard(chatBody, async (b) => ({ reply: await deps.pal.chat(b.history, b.message, b.context) })))
  app.post('/v1/parse', guard(parseBody, async (b) => deps.pal.parse(b.text)))
  app.post('/v1/review', guard(reviewBody, async (b) => ({ text: await deps.pal.review(b.context) })))
  app.post('/v1/suggest-workout', guard(suggestBody, async (b) => deps.pal.suggestWorkout(b.another, b.context)))
  app.post('/v1/post-workout-note', guard(postWorkoutBody, async (b) => ({ note: await deps.pal.postWorkoutNote(b.context) })))

  return app
}
