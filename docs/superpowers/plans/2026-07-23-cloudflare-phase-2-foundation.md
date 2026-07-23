# Cloudflare Phase 2 — Worker + D1 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the production Cloudflare Worker + D1 for Opal's **non-LLM state endpoints** (healthz, register, memory read/delete, health, widget), preserving the exact wire contracts so the Flutter app, iOS widget, and Health Shortcut need no change.

**Architecture:** A new `server/worker/` directory is the real Worker (the `server/spike/` benchmark is left untouched and dies in Phase 7). It reuses the pure Zod schemas from `server/src/schemas.ts` and `extractBearer` from `server/src/auth.ts` via relative import; D1-backed stores live in `server/worker/src/stores/` (token + memory adapted verbatim from the proven spike; health + widget newly ported from the Node `better-sqlite3` versions). Native-`fetch` routing, no framework. Pal/LLM routes are Phase 3; native email is Phase 4 — **out of scope here**.

**Tech Stack:** Cloudflare Workers (native `fetch`), D1 (SQLite), Wrangler 4.x, Zod (reused), Vitest + `@cloudflare/vitest-pool-workers` with a local D1, Cloudflare Rate Limiting binding.

## Global Constraints

- **Scope = non-LLM state endpoints only:** `GET /healthz`, `POST /v1/register`, `GET /v1/memory`, `DELETE /v1/memory/facts/:id`, `DELETE /v1/memory`, `POST /v1/health/ingest`, `GET /v1/health/day`, `POST /v1/widget/snapshot`, `GET /v1/widget/snapshot`. **Excluded (later phases):** every Pal route, `POST /v1/memory/refresh` (calls the LLM → Phase 3), and all `/v1/email/*` (Phase 4).
- **No HTTP framework, no ORM.** Native `fetch` + method/path dispatch; prepared D1 statements only.
- **Do not modify `server/spike/`.** Do not modify `server/src/` except the one bounded schema tightening in Task 2 (registerBody), and run the Node suite after it.
- **Preserve contracts verbatim** (from `docs/migration-phase-0-findings.md` §3): error envelope `{ error: { code: string, message: string, details?: string[] } }`; status catalog for these routes: 200 · 204 (CORS preflight) · 400 `bad_request` · 401 `unauthorized` · 404 `not_found` · 429 (rate-limited) · 500 `upstream`.
- **Auth:** bearer token on every `/v1/*` route except `/v1/register` (which authenticates via `provisioningKey` in the body). Reuse `extractBearer`.
- **Rate limit:** 60 requests / 60 s, keyed by device token, falling back to `CF-Connecting-IP`. `/healthz` is unlimited. Cloudflare's limiter is per-location and permissive — the OpenRouter credit cap remains the hard financial safeguard (no OpenRouter here, but the principle stands for later phases).
- **Constants (from `server/src/memory.ts`):** `MAX_FACTS = 20`, `MAX_PATTERNS = 5`. Redeclared in the D1 memory store (as the spike did).
- **Reuse import paths:** the worker lives at `server/worker/src/`, source at `server/src/`, so shared imports use `../../src/<mod>.js` (from `src/stores/` it is `../../../src/<mod>.js`).
- **Env is hand-declared** as `export interface Env` in `worker.ts` (matches the spike). `wrangler types` may be used to regenerate, but the plan does not depend on it.
- **Toolchain:** this environment has Node 22.14 + npm; `npm install`, `npm test` (vitest-pool-workers + local D1), and `wrangler deploy --dry-run` run locally. The **staging deploy** (real `workers.dev` URL + remote D1) is owner-run (Task 6). Flutter/Dart is not installed and must not be — client-side changes are a separate handoff.

---

### Task 1: Scaffold `server/worker/`, D1 migration, CORS, and `/healthz`

**Files:**
- Create: `server/worker/package.json`
- Create: `server/worker/tsconfig.json`
- Create: `server/worker/wrangler.toml`
- Create: `server/worker/vitest.config.ts`
- Create: `server/worker/.gitignore`
- Create: `server/worker/migrations/0001_init.sql`
- Create: `server/worker/src/http.ts`
- Create: `server/worker/src/cors.ts`
- Create: `server/worker/src/worker.ts` (minimal: healthz + CORS + 404)
- Create: `server/worker/test/healthz.test.ts`

**Interfaces:**
- Produces: `export default { fetch(request: Request, env: Env): Promise<Response> }`; `interface Env { DB: D1Database; RL: RateLimit; PAL_PROVISIONING_KEY: string; CORS_ORIGINS?: string }`; `json(data, status?)`, `error(code, message, status, details?)` in `http.ts`; `parseOrigins(csv?)`, `preflight(request, origins)`, `withCors(response, request, origins)` in `cors.ts`.

- [ ] **Step 1: Write `server/worker/package.json`**

```json
{
  "name": "opal-worker",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "wrangler dev",
    "test": "vitest run",
    "deploy": "wrangler deploy",
    "size": "wrangler deploy --dry-run --outdir=dist"
  },
  "dependencies": {
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "@cloudflare/vitest-pool-workers": "^0.5.0",
    "@cloudflare/workers-types": "^4.20240000.0",
    "typescript": "^5.7.0",
    "vitest": "^2.1.0",
    "wrangler": "^4.112.0"
  }
}
```

- [ ] **Step 2: Write `server/worker/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "es2022",
    "module": "es2022",
    "moduleResolution": "bundler",
    "lib": ["es2022"],
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "noEmit": true,
    "skipLibCheck": true
  },
  "include": ["src", "test", "../src"]
}
```

- [ ] **Step 3: Write `server/worker/wrangler.toml`**

`nodejs_compat` is kept for forward-compatibility with Phase 3 (pal.ts). `database_id` is filled by the owner in Task 6 after `wrangler d1 create opal`; local dev/Vitest use a local D1 and ignore it. The rate-limit `namespace_id` is any integer unique to the account.

```toml
name = "opal-worker"
main = "src/worker.ts"
compatibility_date = "2026-07-01"
compatibility_flags = ["nodejs_compat"]

[vars]
CORS_ORIGINS = ""

[[d1_databases]]
binding = "DB"
database_name = "opal"
database_id = "PLACEHOLDER_SET_BY_WRANGLER_D1_CREATE"
migrations_dir = "migrations"

[[ratelimits]]
name = "RL"
namespace_id = "2001"
simple = { limit = 60, period = 60 }
```

- [ ] **Step 4: Write `server/worker/vitest.config.ts`**

`readD1Migrations` loads the SQL so tests can apply it to the local D1 per-test. `PAL_PROVISIONING_KEY` is set here for the register tests (Task 2).

```ts
import { defineWorkersConfig, readD1Migrations } from '@cloudflare/vitest-pool-workers/config'

const migrations = await readD1Migrations('./migrations')

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.toml' },
        miniflare: {
          d1Databases: ['DB'],
          bindings: { TEST_MIGRATIONS: migrations, PAL_PROVISIONING_KEY: 'test-prov-key' },
        },
      },
    },
  },
})
```

- [ ] **Step 5: Write `server/worker/.gitignore`**

```
node_modules/
dist/
.wrangler/
```

- [ ] **Step 6: Write `server/worker/migrations/0001_init.sql`** (all five production tables; mirrors `store.ts`, `memory.ts`, `health.ts`, `widget.ts`)

```sql
CREATE TABLE IF NOT EXISTS device_tokens (
  token      TEXT PRIMARY KEY,
  device_id  TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS pal_facts (
  id         TEXT PRIMARY KEY,
  token      TEXT NOT NULL,
  text       TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_pal_facts_token ON pal_facts(token, created_at);

CREATE TABLE IF NOT EXISTS pal_patterns (
  token      TEXT PRIMARY KEY,
  json       TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS health_metrics (
  date        TEXT NOT NULL,
  metric      TEXT NOT NULL,
  value       REAL NOT NULL,
  unit        TEXT NOT NULL,
  captured_at TEXT NOT NULL,
  PRIMARY KEY (date, metric)
);

CREATE TABLE IF NOT EXISTS widget_snapshot (
  id         INTEGER PRIMARY KEY CHECK (id = 1),
  data       TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
```

- [ ] **Step 7: Write `server/worker/src/http.ts`** (error envelope + a bad-request helper matching `app.ts`)

```ts
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
```

- [ ] **Step 8: Write `server/worker/src/cors.ts`** (ports the `app.ts` onRequest CORS hook)

```ts
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

// 204 preflight for unmatched OPTIONS (matches app.ts: preflight never reaches routes).
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
```

- [ ] **Step 9: Write the minimal `server/worker/src/worker.ts`**

```ts
import { error } from './http.js'
import { parseOrigins, preflight, withCors } from './cors.js'

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
  const { pathname } = new URL(request.url)
  if (pathname === '/healthz') return new Response('ok')
  return error('not_found', 'no such route', 404)
}
```

- [ ] **Step 10: Write the failing test `server/worker/test/healthz.test.ts`**

```ts
import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test'
import { describe, it, expect } from 'vitest'
import worker from '../src/worker'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, createExecutionContext())

describe('healthz + baseline', () => {
  it('returns ok', async () => {
    const res = await call('/healthz')
    expect(res.status).toBe(200)
    expect(await res.text()).toBe('ok')
  })

  it('unknown route is 404 with the error envelope', async () => {
    const res = await call('/nope')
    expect(res.status).toBe(404)
    expect((await res.json() as any).error.code).toBe('not_found')
  })

  it('OPTIONS preflight is 204', async () => {
    const res = await call('/v1/register', { method: 'OPTIONS' })
    expect(res.status).toBe(204)
  })
})
```

- [ ] **Step 11: Install and run**

Run: `cd server/worker && npm install && npm test`
Expected: 3 tests PASS. (If `npm install` is blocked, this is an owner handoff — note it and continue authoring; do not fake a pass.)

- [ ] **Step 12: Commit**

```bash
git add server/worker
git commit -m "feat(worker): scaffold cloudflare worker, d1 migration, cors, healthz"
```

---

### Task 2: Token store, `POST /v1/register`, bearer guard, rate limiting

**Files:**
- Create: `server/worker/src/stores/tokens.ts`
- Modify: `server/worker/src/worker.ts` (rate-limit gate, register route, bearer guard, `routeAuthed` stub)
- Modify: `server/src/schemas.ts` (tighten `registerBody` bounds — the one allowed `server/src` edit)
- Create: `server/worker/test/register.test.ts`

**Interfaces:**
- Consumes: `Env` (Task 1); `extractBearer` from `../../src/auth.js`; `registerBody` from `../../src/schemas.js`; `json`, `error` from `./http.js`.
- Produces: `class D1TokenStore { constructor(db: D1Database); issue(deviceId: string): Promise<string>; isValid(token: string): Promise<boolean> }`; `routeAuthed(request, env, url, method, token): Promise<Response>` (stub here, filled in Tasks 3–5).

- [ ] **Step 1: Tighten `registerBody` in `server/src/schemas.ts`** (explicit bounds; generous, above real usage)

Replace lines 13–16:

```ts
export const registerBody = z.object({
  provisioningKey: z.string().min(1).max(500),
  deviceId: z.string().min(1).max(200),
})
```

- [ ] **Step 2: Run the Node suite to confirm no regression**

Run: `cd server && npm test`
Expected: PASS (the existing `app.test.ts` register cases use short values well under the new caps).

- [ ] **Step 3: Write the failing test `server/worker/test/register.test.ts`**

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, {} as any)

const register = (body: unknown) =>
  call('/v1/register', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('register + bearer guard', () => {
  it('issues a stable 64-char token for the right provisioning key', async () => {
    const a = await register({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' })
    expect(a.status).toBe(200)
    const t1 = (await a.json() as any).token
    expect(t1).toHaveLength(64)
    const b = await register({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' })
    expect((await b.json() as any).token).toBe(t1) // same device -> same token
  })

  it('rejects a bad provisioning key with 401', async () => {
    const res = await register({ provisioningKey: 'wrong', deviceId: 'd1' })
    expect(res.status).toBe(401)
    expect((await res.json() as any).error.code).toBe('unauthorized')
  })

  it('rejects a malformed body with 400', async () => {
    const res = await register({ deviceId: 'd1' })
    expect(res.status).toBe(400)
  })

  it('rejects a /v1 route with no bearer token', async () => {
    const res = await call('/v1/memory')
    expect(res.status).toBe(401)
  })

  it('accepts a valid bearer token (routeAuthed reached -> 404 for the stub path)', async () => {
    const reg = await register({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd2' })
    const token = (await reg.json() as any).token
    const res = await call('/v1/does-not-exist', { headers: { authorization: `Bearer ${token}` } })
    expect(res.status).toBe(404) // authenticated, but no such route
  })
})
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `cd server/worker && npm test -- register`
Expected: FAIL — register route not implemented.

- [ ] **Step 5: Write `server/worker/src/stores/tokens.ts`** (verbatim port of the spike; import path is `../../../src` if it needs siblings — it needs none)

```ts
// Async D1 port of server/src/store.ts TokenStore. Prepared statements; Web Crypto for the token.
function hex(bytes: number): string {
  const b = new Uint8Array(bytes)
  crypto.getRandomValues(b)
  return Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('')
}

export class D1TokenStore {
  constructor(private readonly db: D1Database) {}

  async issue(deviceId: string): Promise<string> {
    const existing = await this.db
      .prepare('SELECT token FROM device_tokens WHERE device_id = ?').bind(deviceId)
      .first<{ token: string }>()
    if (existing) return existing.token
    const token = hex(32) // 64 hex chars
    await this.db
      .prepare('INSERT INTO device_tokens (token, device_id, created_at) VALUES (?, ?, ?)')
      .bind(token, deviceId, Date.now()).run()
    return token
  }

  async isValid(token: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT 1 AS ok FROM device_tokens WHERE token = ?').bind(token).first()
    return row !== null
  }
}
```

- [ ] **Step 6: Rewrite `server/worker/src/worker.ts`'s `route` with rate-limit, register, and the bearer guard**

Replace the imports and the `route` function (keep the `fetch` handler and `Env` from Task 1):

```ts
import { json, error } from './http.js'
import { parseOrigins, preflight, withCors } from './cors.js'
import { extractBearer } from '../../src/auth.js'
import { registerBody } from '../../src/schemas.js'
import { D1TokenStore } from './stores/tokens.js'

// ...Env interface and default export fetch handler unchanged from Task 1...

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

// filled in Tasks 3–5.
async function routeAuthed(
  _request: Request, _env: Env, _url: URL, _method: string, _token: string,
): Promise<Response> {
  return error('not_found', 'no such route', 404)
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `cd server/worker && npm test -- register`
Expected: PASS (5 cases). Note: if `@cloudflare/vitest-pool-workers` does not simulate the `RL` binding locally, `env.RL.limit` will throw and these tests fail with a binding error. If so, guard the call — `const { success } = env.RL ? await env.RL.limit({ key: rlKey }) : { success: true }` — and verify real 429 behavior on staging in Task 6. Record this deviation in the commit body; do not remove the guard silently.

- [ ] **Step 8: Commit**

```bash
git add server/worker/src server/worker/test/register.test.ts server/src/schemas.ts
git commit -m "feat(worker): token store, register, bearer guard, rate limiting"
```

---

### Task 3: Memory store + memory routes (GET, DELETE fact, DELETE all)

**Files:**
- Create: `server/worker/src/stores/memory.ts`
- Modify: `server/worker/src/worker.ts` (`routeAuthed` memory branches)
- Create: `server/worker/test/memory.test.ts`

**Interfaces:**
- Consumes: `Env.DB`.
- Produces: `interface MemoryFact { id: string; text: string }`, `interface MemoryPattern { colorToken: string; title: string; detail: string }`, `interface MemoryDigest { facts: MemoryFact[]; patterns: MemoryPattern[] }`; `class D1MemoryStore { constructor(db); addFact(token, text): Promise<MemoryFact>; forgetFact(token, id): Promise<void>; getPatterns(token): Promise<MemoryPattern[]>; setPatterns(token, patterns): Promise<void>; digest(token): Promise<MemoryDigest>; wipe(token): Promise<void> }`. (`addFact`/`setPatterns` are unused by Phase 2 routes but ported now for Phase 3 and to keep the store whole; tested here.)

- [ ] **Step 1: Write the failing test `server/worker/test/memory.test.ts`**

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'
import { D1MemoryStore } from '../src/stores/memory'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, {} as any)

async function token(deviceId = 'd1'): Promise<string> {
  const res = await call('/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId }),
  })
  return (await res.json() as any).token
}

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('D1MemoryStore', () => {
  it('caps facts at 20, keeping the newest', async () => {
    const m = new D1MemoryStore(env.DB)
    for (let i = 0; i < 25; i++) await m.addFact('t', `fact ${i}`)
    const d = await m.digest('t')
    expect(d.facts).toHaveLength(20)
    expect(d.facts.at(-1)!.text).toBe('fact 24')
  })
})

describe('memory routes', () => {
  const auth = (tok: string, init: RequestInit = {}) =>
    ({ ...init, headers: { ...(init.headers ?? {}), authorization: `Bearer ${tok}` } })

  it('GET /v1/memory returns the digest shape', async () => {
    const tok = await token()
    const res = await call('/v1/memory', auth(tok))
    expect(res.status).toBe(200)
    const b = await res.json() as any
    expect(Array.isArray(b.facts)).toBe(true)
    expect(Array.isArray(b.patterns)).toBe(true)
  })

  it('DELETE /v1/memory/facts/:id removes the fact and returns the digest', async () => {
    const tok = await token()
    const m = new D1MemoryStore(env.DB)
    const f = await m.addFact(tok, 'keep-or-not')
    const res = await call(`/v1/memory/facts/${f.id}`, auth(tok, { method: 'DELETE' }))
    expect(res.status).toBe(200)
    expect((await res.json() as any).facts.map((x: any) => x.text)).not.toContain('keep-or-not')
  })

  it('DELETE /v1/memory wipes and returns { ok: true }', async () => {
    const tok = await token()
    const m = new D1MemoryStore(env.DB)
    await m.addFact(tok, 'x')
    const res = await call('/v1/memory', auth(tok, { method: 'DELETE' }))
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ ok: true })
    expect((await m.digest(tok)).facts).toHaveLength(0)
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd server/worker && npm test -- memory`
Expected: FAIL — `D1MemoryStore` not found / memory routes 404.

- [ ] **Step 3: Write `server/worker/src/stores/memory.ts`** (verbatim port of the spike memory store)

```ts
// Async D1 port of server/src/memory.ts MemoryStore. Prepared statements; Web Crypto for ids.
const MAX_FACTS = 20   // server/src/memory.ts
const MAX_PATTERNS = 5 // server/src/memory.ts

function hex(bytes: number): string {
  const b = new Uint8Array(bytes)
  crypto.getRandomValues(b)
  return Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('')
}

export interface MemoryFact { id: string; text: string }
export interface MemoryPattern { colorToken: string; title: string; detail: string }
export interface MemoryDigest { facts: MemoryFact[]; patterns: MemoryPattern[] }

export class D1MemoryStore {
  constructor(private readonly db: D1Database) {}

  async addFact(token: string, text: string): Promise<MemoryFact> {
    const id = `f-${hex(8)}`
    await this.db.prepare('INSERT INTO pal_facts (id, token, text, created_at) VALUES (?, ?, ?, ?)')
      .bind(id, token, text, Date.now()).run()
    await this.db.prepare(`
      DELETE FROM pal_facts WHERE token = ? AND id NOT IN (
        SELECT id FROM pal_facts WHERE token = ? ORDER BY rowid DESC LIMIT ?
      )`).bind(token, token, MAX_FACTS).run()
    return { id, text }
  }

  async listFacts(token: string): Promise<MemoryFact[]> {
    const { results } = await this.db
      .prepare('SELECT id, text FROM pal_facts WHERE token = ? ORDER BY rowid ASC')
      .bind(token).all<MemoryFact>()
    return results
  }

  async forgetFact(token: string, id: string): Promise<void> {
    await this.db.prepare('DELETE FROM pal_facts WHERE token = ? AND id = ?').bind(token, id).run()
  }

  async getPatterns(token: string): Promise<MemoryPattern[]> {
    const row = await this.db.prepare('SELECT json FROM pal_patterns WHERE token = ?')
      .bind(token).first<{ json: string }>()
    return row ? (JSON.parse(row.json) as MemoryPattern[]) : []
  }

  async setPatterns(token: string, patterns: MemoryPattern[]): Promise<void> {
    const capped = patterns.slice(0, MAX_PATTERNS)
    await this.db.prepare(`
      INSERT INTO pal_patterns (token, json, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(token) DO UPDATE SET json = excluded.json, updated_at = excluded.updated_at
    `).bind(token, JSON.stringify(capped), Date.now()).run()
  }

  async digest(token: string): Promise<MemoryDigest> {
    return { facts: await this.listFacts(token), patterns: await this.getPatterns(token) }
  }

  async wipe(token: string): Promise<void> {
    await this.db.prepare('DELETE FROM pal_facts WHERE token = ?').bind(token).run()
    await this.db.prepare('DELETE FROM pal_patterns WHERE token = ?').bind(token).run()
  }
}
```

- [ ] **Step 4: Add the memory branches to `routeAuthed` in `server/worker/src/worker.ts`**

Add the import and replace the `routeAuthed` stub body:

```ts
import { D1MemoryStore } from './stores/memory.js'

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

  return error('not_found', 'no such route', 404)
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd server/worker && npm test -- memory`
Expected: PASS (4 cases).

- [ ] **Step 6: Commit**

```bash
git add server/worker/src server/worker/test/memory.test.ts
git commit -m "feat(worker): d1 memory store and memory read/delete routes"
```

---

### Task 4: Health store + health routes (POST ingest, GET day)

**Files:**
- Create: `server/worker/src/stores/health.ts`
- Modify: `server/worker/src/worker.ts` (`routeAuthed` health branches)
- Create: `server/worker/test/health.test.ts`

**Interfaces:**
- Consumes: `Env.DB`; `healthIngestBody`, `healthDayQuery` from `../../src/schemas.js`.
- Produces: `interface Metric { value: number; unit: string }`; `class D1HealthStore { constructor(db); upsert(date: string, metrics: Record<string, Metric>, capturedAt: string): Promise<number>; getDay(date: string): Promise<Record<string, Metric>> }`.

- [ ] **Step 1: Write the failing test `server/worker/test/health.test.ts`**

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'
import { D1HealthStore } from '../src/stores/health'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, {} as any)

async function token(): Promise<string> {
  const res = await call('/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  })
  return (await res.json() as any).token
}

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('D1HealthStore', () => {
  it('upserts a day and overwrites on re-ingest', async () => {
    const s = new D1HealthStore(env.DB)
    expect(await s.upsert('2026-07-01', { steps: { value: 100, unit: 'count' } }, 'cap1')).toBe(1)
    await s.upsert('2026-07-01', { steps: { value: 200, unit: 'count' } }, 'cap2')
    expect((await s.getDay('2026-07-01')).steps).toEqual({ value: 200, unit: 'count' })
  })
})

describe('health routes', () => {
  const auth = (tok: string, init: RequestInit = {}) =>
    ({ ...init, headers: { ...(init.headers ?? {}), authorization: `Bearer ${tok}`, 'content-type': 'application/json' } })

  it('POST /v1/health/ingest returns { upserted } and GET /v1/health/day reads it back', async () => {
    const tok = await token()
    const ing = await call('/v1/health/ingest', auth(tok, {
      method: 'POST',
      body: JSON.stringify({ date: '2026-07-02', metrics: { steps: { value: 5000, unit: 'count' }, activeEnergy: { value: 300, unit: 'kcal' } } }),
    }))
    expect(ing.status).toBe(200)
    expect((await ing.json() as any).upserted).toBe(2)

    const day = await call('/v1/health/day?date=2026-07-02', auth(tok))
    expect(day.status).toBe(200)
    const b = await day.json() as any
    expect(b.date).toBe('2026-07-02')
    expect(b.metrics.steps).toEqual({ value: 5000, unit: 'count' })
  })

  it('rejects an unknown metric key with 400', async () => {
    const tok = await token()
    const res = await call('/v1/health/ingest', auth(tok, {
      method: 'POST', body: JSON.stringify({ date: '2026-07-02', metrics: { bogus: { value: 1, unit: 'x' } } }),
    }))
    expect(res.status).toBe(400)
  })

  it('rejects a malformed date query with 400', async () => {
    const tok = await token()
    const res = await call('/v1/health/day?date=not-a-date', auth(tok))
    expect(res.status).toBe(400)
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd server/worker && npm test -- health`
Expected: FAIL — `D1HealthStore` not found / routes 404.

- [ ] **Step 3: Write `server/worker/src/stores/health.ts`** (ports `server/src/health.ts`; `db.batch` gives the single-transaction upsert the Node `tx()` provided)

```ts
export interface Metric { value: number; unit: string }

export class D1HealthStore {
  constructor(private readonly db: D1Database) {}

  // returns the number of metrics written. one D1 batch = one transaction.
  async upsert(date: string, metrics: Record<string, Metric>, capturedAt: string): Promise<number> {
    const entries = Object.entries(metrics)
    if (entries.length === 0) return 0
    const stmt = this.db.prepare(`
      INSERT INTO health_metrics (date, metric, value, unit, captured_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(date, metric) DO UPDATE SET
        value = excluded.value, unit = excluded.unit, captured_at = excluded.captured_at`)
    await this.db.batch(entries.map(([metric, m]) => stmt.bind(date, metric, m.value, m.unit, capturedAt)))
    return entries.length
  }

  async getDay(date: string): Promise<Record<string, Metric>> {
    const { results } = await this.db
      .prepare('SELECT metric, value, unit FROM health_metrics WHERE date = ?')
      .bind(date).all<{ metric: string; value: number; unit: string }>()
    const out: Record<string, Metric> = {}
    for (const r of results) out[r.metric] = { value: r.value, unit: r.unit }
    return out
  }
}
```

- [ ] **Step 4: Add the health branches to `routeAuthed`** (before the final `not_found`)

Add the imports and branches:

```ts
import { healthIngestBody, healthDayQuery } from '../../src/schemas.js'
import { D1HealthStore } from './stores/health.js'
import { badRequest } from './http.js'

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
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd server/worker && npm test -- health`
Expected: PASS (4 cases).

- [ ] **Step 6: Commit**

```bash
git add server/worker/src server/worker/test/health.test.ts
git commit -m "feat(worker): d1 health store and health ingest/day routes"
```

---

### Task 5: Widget store + widget routes (POST snapshot, GET snapshot)

**Files:**
- Create: `server/worker/src/stores/widget.ts`
- Modify: `server/worker/src/worker.ts` (`routeAuthed` widget branches)
- Create: `server/worker/test/widget.test.ts`

**Interfaces:**
- Consumes: `Env.DB`; `widgetSnapshotBody` from `../../src/schemas.js`.
- Produces: `type WidgetSnapshot = z.infer<typeof widgetSnapshotBody>`; `class D1WidgetStore { constructor(db); set(snapshot: WidgetSnapshot, updatedAt: number): Promise<void>; get(): Promise<WidgetSnapshot | null> }`.

- [ ] **Step 1: Write the failing test `server/worker/test/widget.test.ts`**

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, {} as any)

async function token(): Promise<string> {
  const res = await call('/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  })
  return (await res.json() as any).token
}

const SNAP = {
  moneyRing: 0.5, moveRing: 0.8, ritualsRing: 0.33, moneySpent: 42000, dailyBudget: 100000,
  moveKcal: 320, dailyMoveKcal: 600, ritualsDone: 1, dailyRitualTarget: 3,
}

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('widget routes', () => {
  const auth = (tok: string, init: RequestInit = {}) =>
    ({ ...init, headers: { ...(init.headers ?? {}), authorization: `Bearer ${tok}`, 'content-type': 'application/json' } })

  it('GET returns 404 before any snapshot', async () => {
    const tok = await token()
    const res = await call('/v1/widget/snapshot', auth(tok))
    expect(res.status).toBe(404)
    expect((await res.json() as any).error.code).toBe('not_found')
  })

  it('POST stores and GET reads back the exact snapshot', async () => {
    const tok = await token()
    const post = await call('/v1/widget/snapshot', auth(tok, { method: 'POST', body: JSON.stringify(SNAP) }))
    expect(post.status).toBe(200)
    expect(await post.json()).toEqual({ ok: true })
    const get = await call('/v1/widget/snapshot', auth(tok))
    expect(get.status).toBe(200)
    expect(await get.json()).toEqual(SNAP)
  })

  it('rejects a snapshot with a non-finite ring with 400', async () => {
    const tok = await token()
    const res = await call('/v1/widget/snapshot', auth(tok, { method: 'POST', body: JSON.stringify({ ...SNAP, moneyRing: 'x' }) }))
    expect(res.status).toBe(400)
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd server/worker && npm test -- widget`
Expected: FAIL — routes 404 on POST/GET.

- [ ] **Step 3: Write `server/worker/src/stores/widget.ts`** (ports `server/src/widget.ts`; JSON-blob single row keeps the field set in the zod schema only)

```ts
import type { z } from 'zod'
import type { widgetSnapshotBody } from '../../../src/schemas.js'

export type WidgetSnapshot = z.infer<typeof widgetSnapshotBody>

export class D1WidgetStore {
  constructor(private readonly db: D1Database) {}

  async set(snapshot: WidgetSnapshot, updatedAt: number): Promise<void> {
    await this.db.prepare(`
      INSERT INTO widget_snapshot (id, data, updated_at) VALUES (1, ?, ?)
      ON CONFLICT(id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at
    `).bind(JSON.stringify(snapshot), updatedAt).run()
  }

  async get(): Promise<WidgetSnapshot | null> {
    const row = await this.db.prepare('SELECT data FROM widget_snapshot WHERE id = 1')
      .first<{ data: string }>()
    return row ? (JSON.parse(row.data) as WidgetSnapshot) : null
  }
}
```

- [ ] **Step 4: Add the widget branches to `routeAuthed`** (before the final `not_found`)

```ts
import { widgetSnapshotBody } from '../../src/schemas.js'
import { D1WidgetStore } from './stores/widget.js'

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
```

- [ ] **Step 5: Run the widget test, then the full suite**

Run: `cd server/worker && npm test -- widget`
Expected: PASS (3 cases).
Run: `cd server/worker && npm test`
Expected: ALL suites PASS (healthz, register, memory, health, widget).

- [ ] **Step 6: Measure the bundle**

Run: `cd server/worker && npm run size`
Expected: `Total Upload ... gzip: <size>` well under 3 MB (the spike with more code was 37 KiB).

- [ ] **Step 7: Commit**

```bash
git add server/worker/src server/worker/test/widget.test.ts
git commit -m "feat(worker): d1 widget store and widget snapshot routes"
```

---

### Task 6: Staging deploy + contract verification (owner-gated — the Phase 2 exit condition)

**Files:**
- Modify: `server/worker/wrangler.toml` (real `database_id` — owner, uncommitted or committed per preference)

This task runs on Cloudflare and needs the owner's login. It proves the roadmap Phase 2 exit: "non-LLM state endpoints pass contract tests locally and on a staging `workers.dev` URL."

- [ ] **Step 1: Create the production D1 and wire its id**

```bash
cd server/worker
npx wrangler d1 create opal          # paste database_id into wrangler.toml [[d1_databases]]
npx wrangler d1 migrations apply opal --remote
```

- [ ] **Step 2: Provision config**

```bash
npx wrangler secret put PAL_PROVISIONING_KEY   # the real production provisioning key
# CORS_ORIGINS stays "" unless the chrome preview origin is needed; set via [vars] or a secret.
```

- [ ] **Step 3: Deploy to staging (`workers.dev`)**

```bash
npx wrangler deploy                   # note the *.workers.dev URL
```

- [ ] **Step 4: Run the contract smoke against staging**

Register, then round-trip memory, health, and widget. Expected: register → 200 + 64-char token; health ingest → `{ upserted: N }`; health day → the ingested metrics; widget POST → `{ ok: true }`; widget GET → the exact snapshot; a second `/v1/register` for the same deviceId → the same token.

```bash
BASE=https://opal-worker.<subdomain>.workers.dev
TOK=$(curl -s -X POST "$BASE/v1/register" -H 'content-type: application/json' \
  -d '{"provisioningKey":"<prod key>","deviceId":"contract-check"}' | node -e "process.stdin.once('data',d=>console.log(JSON.parse(d).token))")
curl -s -X POST "$BASE/v1/health/ingest" -H "authorization: Bearer $TOK" -H 'content-type: application/json' \
  -d '{"date":"2026-07-23","metrics":{"steps":{"value":5000,"unit":"count"}}}'
curl -s "$BASE/v1/health/day?date=2026-07-23" -H "authorization: Bearer $TOK"
curl -s -X POST "$BASE/v1/widget/snapshot" -H "authorization: Bearer $TOK" -H 'content-type: application/json' \
  -d '{"moneyRing":0.5,"moveRing":0.8,"ritualsRing":0.3,"moneySpent":42000,"dailyBudget":100000,"moveKcal":320,"dailyMoveKcal":600,"ritualsDone":1,"dailyRitualTarget":3}'
curl -s "$BASE/v1/widget/snapshot" -H "authorization: Bearer $TOK"
```

- [ ] **Step 5: Verify rate limiting on the real runtime** (local pool may not simulate the `RL` binding)

Fire > 60 requests within 60 s at one authenticated route and confirm a `429` with `{ error: { code: "rate_limited" } }` appears. If Task 2 added the `env.RL ?` guard, this is where real 429 behavior is confirmed.

- [ ] **Step 6: Record the outcome**

Append a short "Phase 2 staging verification" note to `docs/migration-phase-0-findings.md` or a new `docs/migration-phase-2-verification.md`: the staging URL, which contracts passed, and the observed 429 behavior. Do not record secrets.

- [ ] **Step 7: Commit any doc/config changes**

```bash
git add docs server/worker/wrangler.toml
git commit -m "docs(worker): phase 2 staging verification"
```

---

## Notes carried from the roadmap

- **`/v1/memory/refresh` is deliberately absent** — it calls `pal.refreshPatterns` (LLM) and belongs to Phase 3. The `D1MemoryStore.setPatterns` method is ported now so Phase 3 only adds the route.
- **Data migration is Phase 6**, not here. Staging starts from an empty `opal` D1; that is expected. Existing clients recover auth via their 401-clear-and-register flow.
- **The old DigitalOcean Node deployment stays live and untouched** through Phases 2–6. This plan adds a parallel Worker; nothing is cut over.
- **`Date.now()` / `new Date()` are fine in the Worker runtime** (the ban is only inside workflow orchestration scripts). Workers freezes the clock to the last I/O, which is correct for `created_at` / `updated_at` / `captured_at`.
- **Rate-limit binding local support:** if `@cloudflare/vitest-pool-workers` does not expose `RL`, keep the Task 2 `env.RL ?` guard and rely on Task 6 Step 5 for real verification. Flag it; never let it silently no-op in production.

## Self-Review

- **Spec coverage (roadmap Phase 2 bullets):** Worker config + local dev + initial D1 migration → Task 1. Method/path routing, JSON, CORS, structured errors, health endpoint → Tasks 1–2. Typed bindings (replace `process.env`) → `Env` in Task 1 (no `process.env` anywhere). D1 token/memory/health/widget stores → Tasks 2–5. Bearer auth + per-token rate limiting → Task 2. Explicit bounds on externally-supplied schemas → Task 2 (registerBody; the other Phase-2 schemas — healthIngestBody enum+regex+finite, healthDayQuery regex, widgetSnapshotBody finite/int — are already bounded at source). Exit condition (local + staging contract tests) → Tasks 1–5 local, Task 6 staging.
- **Out-of-scope confirmed excluded:** Pal/LLM routes, `/v1/memory/refresh`, `/v1/email/*` — none implemented.
- **Type consistency:** `Env`, `json`/`error`/`badRequest`, `D1TokenStore.issue/isValid`, `D1MemoryStore.{addFact,forgetFact,getPatterns,setPatterns,digest,wipe}`, `D1HealthStore.{upsert,getDay}`, `D1WidgetStore.{set,get}`, `routeAuthed(request, env, url, method, token)` are used consistently across tasks.
- **Placeholder scan:** none — every code and test step is complete; the only `PLACEHOLDER` is the D1 `database_id`, which is intentionally owner-filled in Task 6 (documented).

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-23-cloudflare-phase-2-foundation.md`. Two execution options:

1. **Subagent-Driven (recommended)** — a fresh subagent per task, two-stage review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session with checkpoints for review.

Which approach?
