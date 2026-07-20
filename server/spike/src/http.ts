export const json = (data: unknown, status = 200): Response =>
  new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json' } })

export const error = (code: string, message: string, status: number, details?: string[]): Response =>
  json({ error: details ? { code, message, details } : { code, message } }, status)
