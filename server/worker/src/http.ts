import type { z } from 'zod'

export const json = (data: unknown, status = 200): Response =>
  new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json' } })

export const error = (code: string, message: string, status: number, details?: string[]): Response =>
  json({ error: details ? { code, message, details } : { code, message } }, status)

// mirrors server/src/app.ts badRequest: name the failing path + the received value.
export function badRequest(err: z.ZodError, body: unknown): Response {
  const valueAtPath = (obj: unknown, path: (string | number)[]): unknown =>
    path.reduce<unknown>((o, k) => (o == null ? o : (o as Record<string, unknown>)[k]), obj)
  const details = err.issues.map((i) => {
    const v = valueAtPath(body, i.path)
    const received = v === undefined ? 'undefined' : JSON.stringify(v).slice(0, 80)
    return `${i.path.join('.') || '(root)'}: ${i.message} (received: ${received})`
  })
  return error('bad_request', 'invalid body', 400, details)
}
