# Cloudflare Phase 1 Feasibility Spike — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an isolated Cloudflare Worker + D1 spike that benchmarks worst-case Opal request CPU on the Free plan and produces the go/no-go evidence.

**Architecture:** A native-`fetch` Worker under `server/spike/` reuses the pure Pal modules from `server/src/` (imported, not copied), backs auth/memory with D1, and exposes the five worst-case benchmark endpoints. A Node driver hammers the deployed URL, flags CPU-limit failures, and reads CPU quantiles from the GraphQL Analytics API. The spike is disposable: a pass seeds Phase 2, a fail ends the $0 direction.

**Tech Stack:** Cloudflare Workers (native `fetch`, no framework), D1 (SQLite), Wrangler 4.x, Zod, Vitest + `@cloudflare/vitest-pool-workers`, Node driver over `fetch`, Cloudflare GraphQL Analytics API.

**Environment note:** Node `v24` and `wrangler 4.112` are present in the dev environment. Local `wrangler dev` + local D1 + Vitest run here. The **deployed** benchmark (the actual CPU gate) is owner-run — `wrangler deploy`, `wrangler secret put`, and the driver against the live `*.workers.dev` URL. Local emulation does not prove Cloudflare CPU accounting.

## Global Constraints

- Workers Free limits (verified 2026-07-20): **10 ms CPU/invocation**, 100k req/day, **128 MB** memory, **3 MB** gzipped bundle. D1 Free: 500 MB, 50 queries/invocation, 7-day Time Travel.
- **No HTTP framework** — native `fetch` handler + method/path switch.
- **No ORM** — prepared D1 statements only.
- **No changes to `server/src/`** — reuse via relative import; work around the `better-sqlite3` transitive import with build config, not source edits.
- Reused portable modules: `pal.ts`, `prompts.ts`, `product.ts`, `schemas.ts`, `receipts.ts`, `redact.ts`, `auth.ts`.
- Error envelope on every failure: `{ error: { code: string, message: string, details?: string[] } }`.
- Bearer auth on all `/v1/*` except `/v1/register` (which authenticates via `provisioningKey` in the body). `extractBearer` is reused from `server/src/auth.ts`.
- Secrets: `OPENROUTER_API_KEY` (the capped prod key), `PAL_PROVISIONING_KEY`. Vars: `OPENROUTER_BASE_URL`, `PAL_MODEL`, `PAL_REQUEST_TIMEOUT_MS`, `CORS_ORIGINS`, `STUB_LLM` (`"1"` enables stub mode).
- Constants copied verbatim from source: `MAX_HISTORY_MESSAGES=20`, `MAX_TOKENS=1024`, `INSIGHTS_MAX_TOKENS=2048`, `ROUTINE_MAX_TOKENS=4096`, `MAX_FACTS=20`, `MAX_PATTERNS=5`, `BATCH_SIZE=8`, `CATALOG_N=36`.
- Reused-module import path: the spike lives at `server/spike/`, source at `server/src/`, so imports use `../../src/<mod>.js`.

---

### Task 1: Scaffold the spike, build config, and `/healthz`

**Files:**
- Create: `server/spike/package.json`
- Create: `server/spike/tsconfig.json`
- Create: `server/spike/wrangler.toml`
- Create: `server/spike/stubs/better-sqlite3.js` (alias target for the dead native import)
- Create: `server/spike/vitest.config.ts`
- Create: `server/spike/src/worker.ts` (minimal)
- Create: `server/spike/test/healthz.test.ts`
- Create: `server/spike/.gitignore`

**Interfaces:**
- Produces: `export default { fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> }`; `interface Env { DB: D1Database; OPENROUTER_API_KEY: string; PAL_PROVISIONING_KEY: string; OPENROUTER_BASE_URL?: string; PAL_MODEL?: string; PAL_REQUEST_TIMEOUT_MS?: string; CORS_ORIGINS?: string; STUB_LLM?: string }`

- [ ] **Step 1: Write `server/spike/package.json`**

```json
{
  "name": "opal-spike",
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

- [ ] **Step 2: Write `server/spike/tsconfig.json`**

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

- [ ] **Step 3: Write the empty `better-sqlite3` alias stub**

`server/spike/stubs/better-sqlite3.js` — `memory.ts`/`store.ts` are pulled transitively (pal.ts value-imports `MAX_PATTERNS`) but their `Database` class is never constructed in the Worker.

```js
// Alias target for better-sqlite3. The MemoryStore/TokenStore classes that use it
// are dead code in the Worker (D1 stores replace them). Constructing this throws,
// which is correct: it must never run in the Worker.
export default class Database {
  constructor() {
    throw new Error('better-sqlite3 is not available in the Worker (dead code path)')
  }
}
```

- [ ] **Step 4: Write `server/spike/wrangler.toml`**

```toml
name = "opal-spike"
main = "src/worker.ts"
compatibility_date = "2026-07-01"
compatibility_flags = ["nodejs_compat"]

# pal.ts -> memory.ts value-imports MAX_PATTERNS; memory.ts imports the native
# better-sqlite3. Alias it to an empty stub so the Worker bundles (the class is
# dead code here). node:crypto (randomBytes in the same dead code) is covered by
# nodejs_compat above.
alias = { "better-sqlite3" = "./stubs/better-sqlite3.js" }

[vars]
OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
PAL_MODEL = "deepseek/deepseek-v4-flash"
PAL_REQUEST_TIMEOUT_MS = "30000"
CORS_ORIGINS = ""
STUB_LLM = "1"

[[d1_databases]]
binding = "DB"
database_name = "opal-spike"
database_id = "PLACEHOLDER_SET_BY_WRANGLER_D1_CREATE"
migrations_dir = "migrations"
```

Note: `database_id` is filled by the owner after `wrangler d1 create opal-spike` (Task 7 / README). For local `wrangler dev` and Vitest, the local D1 is used and the id is not required.

- [ ] **Step 5: Write `server/spike/vitest.config.ts`**

```ts
import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config'

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.toml' },
        miniflare: { d1Databases: ['DB'] },
      },
    },
  },
})
```

- [ ] **Step 6: Write the minimal `server/spike/src/worker.ts`**

```ts
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

export default {
  async fetch(request: Request, _env: Env): Promise<Response> {
    const { pathname } = new URL(request.url)
    if (pathname === '/healthz') return new Response('ok')
    return new Response('not found', { status: 404 })
  },
}
```

- [ ] **Step 7: Write `server/spike/.gitignore`**

```
node_modules/
dist/
.wrangler/
bench/results.md
```

- [ ] **Step 8: Write the failing test `server/spike/test/healthz.test.ts`**

```ts
import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test'
import { describe, it, expect } from 'vitest'
import worker from '../src/worker'

describe('healthz', () => {
  it('returns ok', async () => {
    const ctx = createExecutionContext()
    const res = await worker.fetch(new Request('https://x/healthz'), env as any, ctx)
    await waitOnExecutionContext(ctx)
    expect(res.status).toBe(200)
    expect(await res.text()).toBe('ok')
  })
})
```

- [ ] **Step 9: Install and run the test**

Run: `cd server/spike && npm install && npm test`
Expected: `healthz > returns ok` PASSES. (If `npm install`/native build is blocked in this environment, this task's verification is an owner handoff — note it and continue authoring; do not fake a pass.)

- [ ] **Step 10: Commit**

```bash
git add server/spike
git commit -m "feat(spike): scaffold cloudflare worker + d1 build config"
```

---

### Task 2: D1 migration and async token + memory stores

**Files:**
- Create: `server/spike/migrations/0001_init.sql`
- Create: `server/spike/src/stores.ts`
- Create: `server/spike/test/stores.test.ts`

**Interfaces:**
- Consumes: `Env.DB` (D1Database).
- Produces:
  - `class D1TokenStore { constructor(db: D1Database); issue(deviceId: string): Promise<string>; isValid(token: string): Promise<boolean> }`
  - `interface MemoryFact { id: string; text: string }`, `interface MemoryPattern { colorToken: string; title: string; detail: string }`, `interface MemoryDigest { facts: MemoryFact[]; patterns: MemoryPattern[] }`, `type MemoryOp = { op: 'remember'; text: string } | { op: 'forget'; id: string }`
  - `class D1MemoryStore { constructor(db: D1Database); digest(token: string): Promise<MemoryDigest>; addFact(token: string, text: string): Promise<MemoryFact>; forgetFact(token: string, id: string): Promise<void>; setPatterns(token: string, patterns: MemoryPattern[]): Promise<void>; applyOps(token: string, ops: MemoryOp[]): Promise<void>; wipe(token: string): Promise<void> }`

The interfaces mirror `server/src/store.ts` and `server/src/memory.ts` exactly, made async for D1. `MAX_FACTS`/`MAX_PATTERNS` are re-declared here (they cannot be value-imported from `memory.ts` without pulling `better-sqlite3`).

- [ ] **Step 1: Write the migration `server/spike/migrations/0001_init.sql`**

```sql
-- Mirrors server/src/store.ts and server/src/memory.ts schemas.
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
```

- [ ] **Step 2: Write the failing test `server/spike/test/stores.test.ts`**

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import { D1TokenStore, D1MemoryStore } from '../src/stores'

beforeEach(async () => {
  await applyD1Migrations(env.DB, env.TEST_MIGRATIONS)
})

describe('D1TokenStore', () => {
  it('issues one stable token per device and validates it', async () => {
    const s = new D1TokenStore(env.DB)
    const a = await s.issue('device-1')
    const b = await s.issue('device-1')
    expect(a).toBe(b)
    expect(a).toHaveLength(64)
    expect(await s.isValid(a)).toBe(true)
    expect(await s.isValid('nope')).toBe(false)
  })
})

describe('D1MemoryStore', () => {
  it('caps facts at 20, keeping the newest', async () => {
    const m = new D1MemoryStore(env.DB)
    for (let i = 0; i < 25; i++) await m.addFact('t', `fact ${i}`)
    const d = await m.digest('t')
    expect(d.facts).toHaveLength(20)
    expect(d.facts.at(-1)!.text).toBe('fact 24')
  })

  it('applies remember/forget ops and wipes', async () => {
    const m = new D1MemoryStore(env.DB)
    const f = await m.addFact('t', 'keep me')
    await m.applyOps('t', [{ op: 'remember', text: 'new fact' }, { op: 'forget', id: f.id }])
    let d = await m.digest('t')
    expect(d.facts.map((x) => x.text)).toEqual(['new fact'])
    await m.setPatterns('t', Array.from({ length: 8 }, (_, i) => ({ colorToken: 'money', title: `p${i}`, detail: 'd' })))
    d = await m.digest('t')
    expect(d.patterns).toHaveLength(5)
    await m.wipe('t')
    d = await m.digest('t')
    expect(d).toEqual({ facts: [], patterns: [] })
  })
})
```

Add `TEST_MIGRATIONS` to the Vitest env by appending to `vitest.config.ts`'s `miniflare` block:

```ts
        miniflare: {
          d1Databases: ['DB'],
          bindings: { TEST_MIGRATIONS: [] }, // replaced below via readD1Migrations
        },
```

and at the top of `vitest.config.ts`:

```ts
import { readD1Migrations } from '@cloudflare/vitest-pool-workers/config'
const migrations = await readD1Migrations('./migrations')
// ...then set bindings: { TEST_MIGRATIONS: migrations }
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd server/spike && npm test -- stores`
Expected: FAIL — `D1TokenStore`/`D1MemoryStore` not found.

- [ ] **Step 4: Write `server/spike/src/stores.ts`**

```ts
// Async D1 ports of server/src/store.ts (TokenStore) and server/src/memory.ts
// (MemoryStore). Prepared statements only. randomBytes -> Web Crypto.

const MAX_FACTS = 20   // server/src/memory.ts
const MAX_PATTERNS = 5 // server/src/memory.ts

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

export interface MemoryFact { id: string; text: string }
export interface MemoryPattern { colorToken: string; title: string; detail: string }
export interface MemoryDigest { facts: MemoryFact[]; patterns: MemoryPattern[] }
export type MemoryOp = { op: 'remember'; text: string } | { op: 'forget'; id: string }

export class D1MemoryStore {
  constructor(private readonly db: D1Database) {}

  async addFact(token: string, text: string): Promise<MemoryFact> {
    const id = `f-${hex(8)}`
    await this.db.prepare('INSERT INTO pal_facts (id, token, text, created_at) VALUES (?, ?, ?, ?)')
      .bind(id, token, text, Date.now()).run()
    // cap: drop oldest beyond MAX_FACTS by monotonic rowid (matches source rationale)
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

  async applyOps(token: string, ops: MemoryOp[]): Promise<void> {
    for (const op of ops) {
      if (op.op === 'remember') await this.addFact(token, op.text)
      else await this.forgetFact(token, op.id)
    }
  }

  async wipe(token: string): Promise<void> {
    await this.db.prepare('DELETE FROM pal_facts WHERE token = ?').bind(token).run()
    await this.db.prepare('DELETE FROM pal_patterns WHERE token = ?').bind(token).run()
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd server/spike && npm test -- stores`
Expected: PASS (both suites).

- [ ] **Step 6: Commit**

```bash
git add server/spike/migrations server/spike/src/stores.ts server/spike/test/stores.test.ts server/spike/vitest.config.ts
git commit -m "feat(spike): d1 token + memory stores with migration"
```

---

### Task 3: Router, error envelope, bearer guard, register + memory routes

**Files:**
- Modify: `server/spike/src/worker.ts` (replace the minimal handler)
- Create: `server/spike/src/http.ts` (response helpers)
- Create: `server/spike/test/routes.test.ts`

**Interfaces:**
- Consumes: `D1TokenStore`, `D1MemoryStore` (Task 2); `extractBearer` from `../../src/auth.js`.
- Produces: `json(data, status?)`, `error(code, message, status, details?)` in `http.ts`; the routed `worker.fetch`. Route table: `GET /healthz`, `POST /v1/register`, `GET /v1/memory`, `POST /v1/memory/refresh` (added in Task 4), `DELETE /v1/memory`, `DELETE /v1/memory/facts/:id`.

- [ ] **Step 1: Write `server/spike/src/http.ts`**

```ts
export const json = (data: unknown, status = 200): Response =>
  new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json' } })

export const error = (code: string, message: string, status: number, details?: string[]): Response =>
  json({ error: details ? { code, message, details } : { code, message } }, status)
```

- [ ] **Step 2: Write the failing test `server/spike/test/routes.test.ts`**

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'

const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request(`https://x${path}`, init), env as any, {} as any)

beforeEach(async () => { await applyD1Migrations(env.DB, env.TEST_MIGRATIONS) })

describe('register + auth', () => {
  it('issues a token with the right provisioning key', async () => {
    const res = await call('/v1/register', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
    })
    expect(res.status).toBe(200)
    expect((await res.json() as any).token).toHaveLength(64)
  })

  it('rejects a bad provisioning key with 401', async () => {
    const res = await call('/v1/register', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ provisioningKey: 'wrong', deviceId: 'd1' }),
    })
    expect(res.status).toBe(401)
  })

  it('rejects a /v1 route with no bearer token', async () => {
    const res = await call('/v1/memory')
    expect(res.status).toBe(401)
  })
})
```

Set `PAL_PROVISIONING_KEY` for tests in `vitest.config.ts` `miniflare.bindings`: `PAL_PROVISIONING_KEY: 'test-prov-key'`.

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd server/spike && npm test -- routes`
Expected: FAIL — register route not implemented (404s).

- [ ] **Step 4: Rewrite `server/spike/src/worker.ts` with the router**

```ts
import { z } from 'zod'
import { extractBearer } from '../../src/auth.js'
import { D1TokenStore, D1MemoryStore } from './stores.js'
import { json, error } from './http.js'

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

  // LLM routes are added in Task 4.
  return error('not_found', 'no such route', 404)
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd server/spike && npm test -- routes`
Expected: PASS (3 cases).

- [ ] **Step 6: Commit**

```bash
git add server/spike/src/worker.ts server/spike/src/http.ts server/spike/test/routes.test.ts server/spike/vitest.config.ts
git commit -m "feat(spike): native router, error envelope, bearer guard, memory routes"
```

---

### Task 4: Pal wiring, stub client, and LLM benchmark routes

**Files:**
- Create: `server/spike/src/pal-factory.ts`
- Create: `server/spike/src/stub.ts`
- Modify: `server/spike/src/worker.ts` (wire `/v1/chat`, `/v1/insights`, `/v1/routine`, `/v1/email/extract` into `routeAuthed`)
- Create: `server/spike/test/llm-routes.test.ts`

**Interfaces:**
- Consumes: `Pal`, `OpenRouterClient`, `CompletionClient`, `CompletionResult`, `ToolCall` from `../../src/pal.js`; `extractReceipts` from `../../src/receipts.js`; request schemas from `../../src/schemas.js`; `RawEmail` type from `../../src/imap.js`.
- Produces: `makePal(env: Env, canned?: Canned): Pal`; `interface Canned { text?: string; tool?: CompletionResult }`; `class StubClient implements CompletionClient`.

- [ ] **Step 1: Write `server/spike/src/stub.ts`**

```ts
import type { ChatMessage, CompletionClient, CompletionResult } from '../../src/pal.js'

// A per-request stub of the OpenRouter client. Returns a canned worst-case
// completion so the Worker's deterministic CPU (extractJson + zod validation +
// tool-call parsing) is exercised without a network call or spend.
export interface Canned { text?: string; tool?: CompletionResult }

export class StubClient implements CompletionClient {
  constructor(private readonly canned: Canned) {}

  async complete(_messages: ChatMessage[], _opts?: unknown): Promise<string> {
    return this.canned.text ?? '{}'
  }

  async completeWithTools(_messages: ChatMessage[], _tools: unknown[]): Promise<CompletionResult> {
    return this.canned.tool ?? { content: '', toolCalls: [] }
  }
}
```

- [ ] **Step 2: Write `server/spike/src/pal-factory.ts`**

```ts
import { Pal, OpenRouterClient } from '../../src/pal.js'
import { StubClient, type Canned } from './stub.js'
import type { Env } from './worker.js'

// Stub mode isolates Worker CPU (no network, no spend); live mode proves the
// 30s timeout + one retry survive the runtime. Fresh instance per request so the
// canned payload is never shared across concurrent invocations.
export function makePal(env: Env, canned?: Canned): Pal {
  if (env.STUB_LLM === '1' && canned) return new Pal(new StubClient(canned))
  const client = new OpenRouterClient(
    env.OPENROUTER_API_KEY,
    env.PAL_MODEL ?? 'deepseek/deepseek-v4-flash',
    env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1',
    fetch,
    Number(env.PAL_REQUEST_TIMEOUT_MS ?? 30_000),
  )
  return new Pal(client)
}
```

- [ ] **Step 3: Write the failing test `server/spike/test/llm-routes.test.ts`**

Stub mode is on by default in tests. The canned payloads come from `bench/fixtures` (Task 5) but the routes must accept a per-request canned override via header `x-stub-case` for testing; simplest is to let the worker import the fixtures. To keep Task 4 self-contained, the test asserts the *contract shape* using minimal canned payloads baked into the worker's stub-case map (added in this task, expanded in Task 5).

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker from '../src/worker'

beforeEach(async () => { await applyD1Migrations(env.DB, env.TEST_MIGRATIONS) })

async function token(): Promise<string> {
  const res = await worker.fetch(new Request('https://x/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  }), env as any, {} as any)
  return (await res.json() as any).token
}

const post = (path: string, tok: string, body: unknown) =>
  worker.fetch(new Request(`https://x${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${tok}` },
    body: JSON.stringify(body),
  }), env as any, {} as any)

describe('LLM routes (stub mode)', () => {
  it('chat returns { reply, actions }', async () => {
    const tok = await token()
    const res = await post('/v1/chat', tok, {
      history: [], message: 'log 12k coffee',
      context: { userName: 'K', todayEntries: [], dailyBudget: 100, moveGoalKcal: 500, ritualGoal: 3,
        spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 700,
        weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 21, moveStreakDays: 0, hourOfDay: 9, weekday: 1 },
    })
    expect(res.status).toBe(200)
    const b = await res.json() as any
    expect(b).toHaveProperty('reply')
    expect(Array.isArray(b.actions)).toBe(true)
  })

  it('routine returns a validated routine', async () => {
    const tok = await token()
    const res = await post('/v1/routine', tok, {
      goal: 'push day',
      exercises: [{ id: 'bench', name: 'Barbell Bench Press', group: 'Push', equipment: 'Barbell' }],
    })
    expect(res.status).toBe(200)
    expect(await res.json()).toHaveProperty('name')
  })
})
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `cd server/spike && npm test -- llm-routes`
Expected: FAIL — `/v1/chat` and `/v1/routine` 404.

- [ ] **Step 5: Wire the LLM routes into `routeAuthed` in `server/spike/src/worker.ts`**

Add imports at the top of `worker.ts`:

```ts
import { makePal } from './pal-factory.js'
import { STUB } from '../bench/fixtures.js' // canned worst-case outputs, keyed by case
import { chatBody, routineBody, insightsBody } from '../../src/schemas.js'
import { extractReceipts } from '../../src/receipts.js'
import type { RawEmail } from '../../src/imap.js'
```

Add a sanitized-candidate schema near the top of `worker.ts`:

```ts
// The Worker receives ALREADY-sanitized candidates (redaction is client-side in
// the target). Only the fields receipt extraction reads are accepted.
const emailExtractBody = z.object({
  candidates: z.array(z.object({
    from: z.string(),
    subject: z.string(),
    text: z.string().max(8000),
  })).max(8),
})
```

Add these branches inside `routeAuthed` (before the final `not_found`):

```ts
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
```

Add to `worker.ts` imports (used by the extract branch above): `import { StubClient } from './stub.js'` and `import { OpenRouterClient } from '../../src/pal.js'`.

Add the `badRequest` helper to `worker.ts` (mirrors `server/src/app.ts`):

```ts
import type { z as zt } from 'zod'
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
```

`routeAuthed` must receive `env` — update its signature to `routeAuthed(request, env, url, method, token, memory)` and the call site to pass `env` (already passed in the Task 3 code).

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd server/spike && npm test -- llm-routes`
Expected: PASS. Dependency note: the LLM routes import `STUB` and `emailExtractBody`'s canned outputs from `bench/fixtures.ts`. Create that file now using the full content in **Task 5, Step 1** — it depends only on the `Canned` type from `stub.js` (already created in Step 1 of this task), so there is no forward code dependency. Task 5 then adds the fixtures test that guards its worst-case sizes.

- [ ] **Step 7: Commit**

```bash
git add server/spike/src
git commit -m "feat(spike): pal factory, stub client, llm benchmark routes"
```

---

### Task 5: Worst-case benchmark fixtures

**Files:**
- Create: `server/spike/bench/fixtures.ts` (canned stub outputs `STUB` + request payload builders)
- Create: `server/spike/test/fixtures.test.ts`

**Interfaces:**
- Consumes: `PalAction`, `Insights`, `GeneratedRoutine` types from `../../src/pal.js` (type-only).
- Produces:
  - `export const STUB: { chat: Canned; insights: Canned; routine: Canned; receipts: Canned }` — worst-case canned completions.
  - `export const CATALOG_N = 36`
  - `export function chatPayload(): unknown`, `insightsPayload(): unknown`, `routinePayload(): unknown`, `emailExtractPayload(): unknown` — worst-case request bodies for the driver.

- [ ] **Step 1: Write `server/spike/bench/fixtures.ts`**

```ts
import type { Canned } from '../src/stub.js'

export const CATALOG_N = 36 // full built-in catalog, lib/data/seed/seed_data.dart

const long = (n: number) => 'x'.repeat(n)

// --- Worst-case canned completions (drive the deterministic validation path) ---

// chat uses completeWithTools; return the max tool calls chat parses (actions +
// memory ops), each with realistic args, plus a long reply.
const chatToolCalls = [
  ...Array.from({ length: 8 }, (_, i) => ({ name: 'log_expense', arguments: JSON.stringify({ amount: 12000 + i, category: 'Food & Drink', title: 'coffee', note: long(40) }) })),
  { name: 'set_daily_budget', arguments: JSON.stringify({ dailyBudget: 100000 }) },
  { name: 'create_routine', arguments: JSON.stringify({ goal: long(60), name: 'push' }) },
  ...Array.from({ length: 5 }, (_, i) => ({ name: 'remember', arguments: JSON.stringify({ fact: `fact ${i} ${long(60)}` }) })),
]

// routine: all CATALOG_N exercises, each with 5 sets — maxes the 4096-token budget.
const CATALOG_N_LOCAL = 36
const routineJson = JSON.stringify({
  name: 'Full Program', tag: 'full', estMin: 60, rationale: long(200),
  exercises: Array.from({ length: CATALOG_N_LOCAL }, (_, i) => ({
    exerciseId: `ex-${i}`,
    sets: Array.from({ length: 5 }, () => ({ reps: 10, weight: 60, duration: null })),
  })),
})

// insights: max wins + patterns + long prose.
const insightsJson = JSON.stringify({
  headline: long(80), lede: long(200), suggestion: long(160), correlationNarration: long(200),
  wins: Array.from({ length: 6 }, (_, i) => ({ colorToken: 'money', title: `win ${i}`, sub: long(60) })),
  patterns: Array.from({ length: 6 }, (_, i) => ({ colorToken: 'move', title: `pat ${i}`, detail: long(80) })),
})

// receipts: BATCH_SIZE results, all receipts.
const receiptsJson = JSON.stringify({
  results: Array.from({ length: 8 }, (_, i) => ({ index: i, isReceipt: true, merchant: long(30), amount: 12345 + i, category: 'Shopping' })),
})

export const STUB: { chat: Canned; insights: Canned; routine: Canned; receipts: Canned } = {
  chat: { tool: { content: long(300), toolCalls: chatToolCalls } },
  insights: { text: insightsJson },
  routine: { text: routineJson },
  receipts: { text: receiptsJson },
}

// --- Worst-case request payloads (what the driver POSTs) ---

const fullContext = {
  userName: 'Kael', todayEntries: Array.from({ length: 30 }, (_, i) => `entry ${i} ${long(40)}`),
  dailyBudget: 100000, moveGoalKcal: 600, ritualGoal: 4, spentToday: 42000, movedTodayKcal: 320,
  ritualsDoneToday: 2, weekSpent: 300000, weekBudget: 700000, weekMovedKcal: 2200, weekRitualsDone: 12,
  weekRitualGoal: 28, moveStreakDays: 9, hourOfDay: 14, weekday: 3,
}

export function chatPayload() {
  return {
    history: Array.from({ length: 20 }, (_, i) => ({ role: i % 2 === 0 ? 'user' : 'assistant', text: long(200) })),
    message: long(300), context: fullContext,
  }
}

export function insightsPayload() {
  return {
    context: {
      range: 'month', spent: 300000, budget: 700000, moveKcal: 2200, moveTargetKcal: 3000,
      ritualsKept: 12, ritualsTarget: 28, activeDays: 18, streakDays: 9,
      topCategory: 'Food & Drink', topCategoryPct: 34,
      spendByWeekday: [10, 20, 30, 40, 50, 60, 70], entries: Array.from({ length: 60 }, (_, i) => `entry ${i} ${long(50)}`),
      correlation: { summary: long(200) },
    },
  }
}

export function routinePayload() {
  return {
    goal: 'balanced full-body program', // backend selects from the catalog
    exercises: Array.from({ length: CATALOG_N }, (_, i) => ({
      id: `ex-${i}`, name: `Exercise ${i} ${long(20)}`, group: ['Push', 'Pull', 'Legs', 'Core', 'Cardio'][i % 5], equipment: 'Barbell',
    })),
  }
}

export function emailExtractPayload() {
  return { candidates: Array.from({ length: 8 }, (_, i) => ({ from: `merchant${i}@shop.example`, subject: long(120), text: long(8000) })) }
}
```

- [ ] **Step 2: Write `server/spike/test/fixtures.test.ts`** (guards the worst-case sizes and that canned outputs validate)

```ts
import { describe, it, expect } from 'vitest'
import { STUB, CATALOG_N, chatPayload, routinePayload, emailExtractPayload } from '../bench/fixtures'
import { extractJson, routineSchema, insightsSchema } from '../../src/pal'

describe('fixtures worst-case sizing', () => {
  it('chat history is the retained max of 20', () => {
    expect((chatPayload() as any).history).toHaveLength(20)
  })
  it('routine payload sends the full catalog', () => {
    expect((routinePayload() as any).exercises).toHaveLength(CATALOG_N)
  })
  it('email extract sends 8 max-size candidates', () => {
    const p = emailExtractPayload() as any
    expect(p.candidates).toHaveLength(8)
    expect(p.candidates[0].text.length).toBe(8000)
  })
  it('canned routine + insights outputs pass their schemas', () => {
    expect(() => routineSchema.parse(extractJson(STUB.routine.text!))).not.toThrow()
    expect(() => insightsSchema.parse(extractJson(STUB.insights.text!))).not.toThrow()
  })
})
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `cd server/spike && npm test -- fixtures`
Expected: PASS. (This also retro-validates that Task 4's routes work with the real `STUB`.)

- [ ] **Step 4: Run the full suite**

Run: `cd server/spike && npm test`
Expected: all suites PASS.

- [ ] **Step 5: Commit**

```bash
git add server/spike/bench/fixtures.ts server/spike/test/fixtures.test.ts
git commit -m "feat(spike): worst-case benchmark fixtures and canned stub outputs"
```

---

### Task 6: Node benchmark driver

**Files:**
- Create: `server/spike/bench/drive.mjs`
- Create: `server/spike/bench/results.template.md`

**Interfaces:**
- Consumes (env vars): `BASE_URL` (deployed worker), `PROVISIONING_KEY`, `REPS` (default 50), `CATALOG_N` (default 36), `CF_API_TOKEN`, `CF_ACCOUNT_ID`, `WORKER_NAME` (default `opal-spike`).
- Produces: `bench/results.md` — per-case wall-time stats, 1102/1027 counts, and CPU P50/P99 from GraphQL; a GO/NO-GO verdict line.

- [ ] **Step 1: Write `server/spike/bench/drive.mjs`**

```js
// Node driver: hammers the deployed spike, flags CPU-limit failures (1102/1027),
// then reads CPU quantiles from the Cloudflare GraphQL Analytics API.
// Run: node bench/drive.mjs   (env vars documented in README.md)
import { chatPayload, insightsPayload, routinePayload, emailExtractPayload } from './fixtures.js'

const BASE = req('BASE_URL')
const PROV = req('PROVISIONING_KEY')
const REPS = Number(process.env.REPS ?? 50)
const CF_TOKEN = req('CF_API_TOKEN')
const CF_ACCOUNT = req('CF_ACCOUNT_ID')
const WORKER = process.env.WORKER_NAME ?? 'opal-spike'
const CPU_LIMIT_MS = 10

function req(name) { const v = process.env[name]; if (!v) throw new Error(`missing env ${name}`); return v }

const CASES = [
  { name: 'chat', path: '/v1/chat', body: chatPayload() },
  { name: 'insights', path: '/v1/insights', body: insightsPayload() },
  { name: 'routine', path: '/v1/routine', body: routinePayload() },
  { name: 'email-extract', path: '/v1/email/extract', body: emailExtractPayload() },
]

async function register() {
  const res = await fetch(`${BASE}/v1/register`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: PROV, deviceId: 'bench-driver' }),
  })
  if (!res.ok) throw new Error(`register failed ${res.status}`)
  return (await res.json()).token
}

// A CPU-limit kill surfaces as a 5xx whose body names error 1102/1027.
function isCpuLimit(status, text) {
  return status >= 500 && /\b(1102|1027)\b|exceeded (its )?(cpu|resource)/i.test(text)
}

async function runCase(token, c) {
  const walls = []
  let cpuFails = 0, otherFails = 0
  for (let i = 0; i < REPS; i++) {
    const t0 = performance.now()
    const res = await fetch(`${BASE}${c.path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify(c.body),
    })
    const text = await res.text()
    walls.push(performance.now() - t0)
    if (isCpuLimit(res.status, text)) cpuFails++
    else if (!res.ok) otherFails++
  }
  walls.sort((a, b) => a - b)
  const pct = (p) => walls[Math.min(walls.length - 1, Math.floor((p / 100) * walls.length))]
  return { name: c.name, reps: REPS, cpuFails, otherFails, wallP50: pct(50), wallP99: pct(99) }
}

// CPU quantiles from the GraphQL Analytics API. Field names per the
// workersInvocationsAdaptiveGroups dataset — verify against the current schema at
// https://developers.cloudflare.com/analytics/graphql-api/ if a field is rejected.
async function cpuQuantiles(sinceIso) {
  const query = `query($account:String!,$script:String!,$since:Time!){
    viewer{ accounts(filter:{accountTag:$account}){
      workersInvocationsAdaptiveGroups(limit:1, filter:{scriptName:$script, datetime_geq:$since}){
        quantiles{ cpuTimeP50 cpuTimeP99 }
        sum{ requests errors }
      }
    }}}`
  const res = await fetch('https://api.cloudflare.com/client/v4/graphql', {
    method: 'POST',
    headers: { authorization: `Bearer ${CF_TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({ query, variables: { account: CF_ACCOUNT, script: WORKER, since: sinceIso } }),
  })
  const j = await res.json()
  const g = j?.data?.viewer?.accounts?.[0]?.workersInvocationsAdaptiveGroups?.[0]
  if (!g) return { note: `no analytics rows yet (errors: ${JSON.stringify(j.errors ?? 'none')})` }
  // cpuTime quantiles are microseconds in this dataset; convert to ms.
  return { p50ms: g.quantiles.cpuTimeP50 / 1000, p99ms: g.quantiles.cpuTimeP99 / 1000, requests: g.sum.requests }
}

async function main() {
  const since = new Date(Date.now() - 60_000).toISOString()
  const token = await register()
  const rows = []
  for (const c of CASES) { const r = await runCase(token, c); rows.push(r); console.log(r) }
  // let analytics settle, then read CPU.
  await new Promise((r) => setTimeout(r, 60_000))
  const cpu = await cpuQuantiles(since)

  const anyCpuFail = rows.some((r) => r.cpuFails > 0)
  const verdict = anyCpuFail
    ? 'NO-GO — CPU-limit (1102/1027) failures observed'
    : (cpu.p99ms !== undefined && cpu.p99ms < CPU_LIMIT_MS)
      ? `GO — worst-case CPU P99 ${cpu.p99ms.toFixed(2)} ms < ${CPU_LIMIT_MS} ms limit`
      : 'REVIEW — no 1102s, but confirm CPU P99 margin from analytics'

  const md = [
    `# Phase 1 benchmark results`, ``,
    `Base: ${BASE} · reps/case: ${REPS} · worker: ${WORKER}`, ``,
    `## Per-case (wall time, ms)`, ``,
    `| case | reps | cpuFails | otherFails | wallP50 | wallP99 |`,
    `| --- | ---: | ---: | ---: | ---: | ---: |`,
    ...rows.map((r) => `| ${r.name} | ${r.reps} | ${r.cpuFails} | ${r.otherFails} | ${r.wallP50.toFixed(0)} | ${r.wallP99.toFixed(0)} |`),
    ``, `## CPU time (GraphQL analytics)`, ``, '```json', JSON.stringify(cpu, null, 2), '```', ``,
    `## Verdict`, ``, `**${verdict}**`, ``,
  ].join('\n')

  // write next to this script
  const { writeFile } = await import('node:fs/promises')
  const { fileURLToPath } = await import('node:url')
  const out = fileURLToPath(new URL('./results.md', import.meta.url))
  await writeFile(out, md)
  console.log(`\nwrote ${out}\n${verdict}`)
}

main().catch((e) => { console.error(e); process.exit(1) })
```

- [ ] **Step 2: Write `server/spike/bench/results.template.md`** (committed; `results.md` is gitignored)

```markdown
# Phase 1 benchmark results (template)

Produced by `node bench/drive.mjs`. Records per-case wall time, CPU-limit (1102/1027)
failures, CPU P50/P99 from GraphQL analytics, bundle size vs 3 MB, and the GO/NO-GO verdict.

Go: worst-case CPU P99 < 10 ms with a documented margin, zero 1102s, bundle < 3 MB.
No-go: any 1102, or CPU cannot fit reliably — stop the $0 migration (roadmap).
```

- [ ] **Step 3: Smoke the driver locally against `wrangler dev` (correctness, not the CPU gate)**

Run (two shells): `cd server/spike && npm run dev` then in another shell
`cd server/spike && BASE_URL=http://localhost:8787 PROVISIONING_KEY=test-prov-key REPS=3 CF_API_TOKEN=x CF_ACCOUNT_ID=x node bench/drive.mjs`
Expected: per-case rows print with `cpuFails=0, otherFails=0`; the GraphQL call returns a `note` (local has no analytics) — that is fine for the local smoke. If the driver errors on the analytics call, confirm it still wrote per-case rows.

- [ ] **Step 4: Commit**

```bash
git add server/spike/bench/drive.mjs server/spike/bench/results.template.md
git commit -m "feat(spike): benchmark driver with cpu-limit detection and graphql readout"
```

---

### Task 7: README, deploy runbook, and go/no-go handoff

**Files:**
- Create: `server/spike/README.md`

- [ ] **Step 1: Write `server/spike/README.md`**

````markdown
# Opal Phase 1 feasibility spike

Isolated Cloudflare Worker + D1 that benchmarks worst-case Opal request CPU on the
Workers Free plan (10 ms/invocation limit). See
`docs/roadmap-cloudflare-workers-d1.md` and `docs/superpowers/plans/2026-07-20-cloudflare-phase-1-spike.md`.

The spike is disposable: a pass seeds Phase 2, a fail ends the $0 direction.

## Local (correctness only — NOT the CPU gate)

```bash
cd server/spike
npm install
npm test          # vitest + local D1
npm run dev       # wrangler dev on http://localhost:8787
```

## Deploy + run the CPU gate (owner)

Local emulation does not prove Cloudflare CPU accounting. The gate runs on the deployed Worker.

```bash
cd server/spike
npx wrangler d1 create opal-spike           # paste database_id into wrangler.toml
npx wrangler d1 migrations apply opal-spike --remote
npx wrangler secret put OPENROUTER_API_KEY  # the credit-capped prod key
npx wrangler secret put PAL_PROVISIONING_KEY
npx wrangler deploy                          # note the *.workers.dev URL
npm run size                                 # bundle size vs the 3 MB gzip limit
```

Run the benchmark (STUB_LLM=1 is the deployed default → CPU-isolation run, $0):

```bash
BASE_URL=https://opal-spike.<subdomain>.workers.dev \
PROVISIONING_KEY=<same as the secret> \
REPS=50 CATALOG_N=36 \
CF_API_TOKEN=<Account Analytics: Read token> \
CF_ACCOUNT_ID=<account id> WORKER_NAME=opal-spike \
node bench/drive.mjs           # writes bench/results.md
```

Live-smoke (proves the 30 s timeout + one retry on the real runtime, uses the capped key):
redeploy once with `STUB_LLM=0` (or `wrangler deploy --var STUB_LLM:0`) and run the driver with `REPS=3`.

## Go / no-go

- **Go:** worst-case CPU P99 < 10 ms with a documented margin, zero 1102/1027, bundle < 3 MB.
  → proceed to Phase 2 (route porting), seeded from this spike.
- **No-go:** any 1102/1027, or CPU cannot fit reliably. Measure which deterministic step
  dominates, trim only where the measurement supports it, re-run. If it still cannot fit,
  stop the $0 migration and reconsider a paid always-on service (roadmap).
````

- [ ] **Step 2: Verify the docs cross-links resolve**

Run: `ls docs/roadmap-cloudflare-workers-d1.md docs/superpowers/plans/2026-07-20-cloudflare-phase-1-spike.md`
Expected: both exist.

- [ ] **Step 3: Commit**

```bash
git add server/spike/README.md
git commit -m "docs(spike): deploy runbook and go/no-go handoff"
```

---

## Notes carried from the spec

- The `/v1/email/extract` handler reuses `extractReceipts`, which re-runs `redactPii` on
  already-sanitized text. This is a deliberate, DRY, **conservative** CPU over-count vs the target
  (where redaction is client-side) — if the gate passes with it, it passes without it.
- `pal.ts` value-imports `MAX_PATTERNS` from `memory.ts` (which imports native `better-sqlite3`). The
  Worker aliases `better-sqlite3` to an empty stub (dead code) and enables `nodejs_compat`. The clean
  Phase-2 fix is to relocate the shared `MAX_*` constants out of `memory.ts`; the spike does not touch
  `server/src`.
- `CATALOG_N=36` is the built-in catalog; users can add custom exercises, so the driver exposes
  `CATALOG_N` as an env override for headroom testing.
- CPU-limit failures are detected at the HTTP layer (5xx + 1102/1027 body match); CPU **margin** comes
  from GraphQL analytics. Verify the `cpuTime*` field names against the current GraphQL schema if the
  query is rejected.
