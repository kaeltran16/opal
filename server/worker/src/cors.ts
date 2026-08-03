export const parseOrigins = (csv?: string): string[] =>
  (csv ?? '').split(',').map((s) => s.trim()).filter(Boolean)

function apply(headers: Headers, request: Request, origins: string[]): void {
  const origin = request.headers.get('origin')
  if (origin && origins.includes(origin)) {
    headers.set('Access-Control-Allow-Origin', origin)
    headers.set('Vary', 'Origin')
    headers.set('Access-Control-Allow-Headers', 'authorization,content-type')
    headers.set('Access-Control-Allow-Methods', 'POST,GET,DELETE,OPTIONS')
  }
}

// 204 preflight for unmatched OPTIONS; preflight never reaches a route handler.
export function preflight(request: Request, origins: string[]): Response {
  const headers = new Headers()
  apply(headers, request, origins)
  return new Response(null, { status: 204, headers })
}

// re-emit a response with CORS headers merged in (Response headers are immutable once set,
// so clone into a fresh Response).
export function withCors(response: Response, request: Request, origins: string[]): Response {
  const headers = new Headers(response.headers)
  apply(headers, request, origins)
  return new Response(response.body, { status: response.status, headers })
}
