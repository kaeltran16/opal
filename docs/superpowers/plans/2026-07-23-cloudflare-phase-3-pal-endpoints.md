# Cloudflare Phase 3 — Pal / LLM Endpoints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port Opal's **Pal/LLM endpoints** onto the existing Cloudflare Worker (`server/worker/`) built in Phase 2, reusing `server/src/pal.ts` (OpenRouter client + Pal logic), prompts, and product vocabulary **verbatim** via relative import. Preserve every wire contract so `HttpPalService` in the Flutter app needs no change.

**Architecture:** The Phase 2 Worker already owns routing, auth, rate-limit, CORS, the error envelope, and the D1 stores. Phase 3 adds a Pal seam: a `makePal(env)` factory builds a per-request `Pal` wrapping the real `OpenRouterClient` (imported from `../../src/pal.js`); a new `routePal(...)` dispatches the 11 Pal routes, mapping `OpenRouterError → 502` and any other throw `→ 500` with the existing `upstream` envelope. `pal.ts` value-imports `MAX_PATTERNS` from `memory.ts`, which imports the native `better-sqlite3`; a wrangler/vitest **alias to a throwing stub** (proven in the spike) keeps that dead-code path out of the bundle. LLM stubbing for tests is done by **dependency injection** (`handle(request, env, { pal })`), not a production `STUB_LLM` flag — production always builds the real client.

**Tech Stack:** Same as Phase 2 (Workers native `fetch`, D1, Wrangler 4.x, Zod reused, Vitest + `@cloudflare/vitest-pool-workers`). Adds OpenRouter over `fetch` (already in `pal.ts`) and the `better-sqlite3` bundling alias.

## Global Constraints

- **Scope = the 11 non-email Pal routes only:** `POST /v1/chat`, `POST /v1/parse`, `POST /v1/nutrition/estimate`, `POST /v1/review`, `POST /v1/insights`, `POST /v1/suggest-workout`, `POST /v1/post-workout-note`, `POST /v1/routine`, `POST /v1/agenda`, `POST /v1/suggestions`, `POST /v1/memory/refresh`. **Excluded (Phase 4):** every `/v1/email/*` route including `/v1/email/extract`, and therefore `receipts.ts`/`redact.ts`/`imap.ts` are NOT imported this phase.
- **Zero `server/src` edits.** All Pal modules are imported as-is. (The one Phase 2 exception — `registerBody` — is already done.) The `MAX_*`-constant relocation "clean fix" noted in the roadmap is explicitly **deferred**; the alias stub is used instead to avoid touching stable Node LLM/storage code that the live DigitalOcean deployment still runs through Phase 6.
- **Preserve contracts verbatim** (from Phase 0 findings §3 and `server/src/app.ts`). Pal error mapping: `OpenRouterError → 502`, any other error `→ 500`, both with `{ error: { code: "upstream", message: "pal request failed" } }`. Bad body `→ 400` `bad_request` with `details` (the existing `badRequest` helper). Auth/rate-limit/CORS are unchanged from Phase 2.
- **No production `STUB_LLM`.** `makePal(env)` always constructs the real `OpenRouterClient`. Tests inject a stub `Pal` through the `handle(request, env, { pal })` seam. `StubClient` lives under `test/support/`, never in `src/`.
- **Cost visibility without PII.** `makePal` wires `OpenRouterClient`'s `CompletionLogger` to `console`, which logs only `{ ms, model, usage, cost, finish_reason }` (see `pal.ts` `logUsage`). Never log prompts, memory facts, Health values, or secrets.
- **CPU: measure, do not pre-optimize.** Phase 1 passed with zero `1102` kills; chat is the thin-margin case. Do **not** add speculative tool-call/history caps (the 20-message cap already exists). Only add a lever if a real `1102` appears in Task 5.
- **Reuse import paths:** worker at `server/worker/src/`, source at `server/src/`, so `../../src/<mod>.js` from `src/`, `../../../src/<mod>.js` from `src/stores/` or `test/support/`.
- **Bindings/config.** Add to `Env`: `OPENROUTER_API_KEY: string` (secret), `OPENROUTER_BASE_URL?: string`, `PAL_MODEL?: string`, `PAL_REQUEST_TIMEOUT_MS?: string`. Non-secret vars go in `wrangler.toml [vars]`; `OPENROUTER_API_KEY` is an owner-set secret (Task 5).
- **Toolchain:** unchanged from Phase 2 (Node 22.14, `npm install`/`npm test`/`wrangler deploy` run locally). The **staging deploy + real-LLM smoke** (Task 5) is owner-gated — it needs the owner's OpenRouter key with a credit cap. Flutter/Dart is not installed and must not be.

---

### Task 1: Pal foundation — bundling alias, `makePal` factory, error seam, `applyOps`

**Files:**
- Create: `server/worker/stubs/better-sqlite3.js`
- Create: `server/worker/src/pal-factory.ts`
- Create: `server/worker/test/support/stub-client.ts`
- Modify: `server/worker/wrangler.toml` (alias + Pal `[vars]`)
- Modify: `server/worker/vitest.config.ts` (add `better-sqlite3` alias)
- Modify: `server/worker/src/worker.ts` (`Env` fields, `handle()` DI seam, `route`/`routeAuthed` threading, `makePal` wiring, `runPal` helper, empty `routePal`)
- Modify: `server/worker/src/stores/memory.ts` (add `applyOps`)
- Create: `server/worker/test/pal-foundation.test.ts`

**Interfaces:**
- Produces: `makePal(env: Env): Pal` in `pal-factory.ts`; `handle(request: Request, env: Env, overrides?: { pal?: Pal }): Promise<Response>` and `routePal(request, env, url, method, token, pal, memory): Promise<Response>` in `worker.ts`; `D1MemoryStore.applyOps(token: string, ops: MemoryOp[]): Promise<void>`; `StubClient` in `test/support/stub-client.ts`.
- Consumes: `Pal`, `OpenRouterClient`, `OpenRouterError`, `CompletionClient`, `CompletionResult`, `CompletionLogger` from `../../src/pal.js`; `MemoryOp` (type) from `../../src/memory.js`.

- [ ] **Step 1: Write `server/worker/stubs/better-sqlite3.js`** (verbatim from the spike — dead-code guard)

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

- [ ] **Step 2: Add the alias + Pal vars to `server/worker/wrangler.toml`**

Add the `alias` line under the `compatibility_flags` line, and the Pal vars under `[vars]`. `pal.ts` value-imports `MAX_PATTERNS` from `memory.ts`, which imports native `better-sqlite3`; the Node app's `server/node_modules/better-sqlite3` would otherwise be bundled (a native `.node` binary → deploy fails). `nodejs_compat` (already set) covers the dead `node:crypto` import in the same module. `zod` is aliased too for a single bundled instance.

```toml
alias = { "better-sqlite3" = "./stubs/better-sqlite3.js", "zod" = "./node_modules/zod/index.js" }
```

```toml
[vars]
CORS_ORIGINS = ""
OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
PAL_MODEL = "deepseek/deepseek-v4-flash"
PAL_REQUEST_TIMEOUT_MS = "30000"
```

- [ ] **Step 3: Add the `better-sqlite3` alias to `server/worker/vitest.config.ts`**

Extend the existing `resolve.alias` array (keep the `zod` alias):

```ts
  resolve: {
    alias: [
      { find: /^zod$/, replacement: abs('./node_modules/zod/index.js') },
      { find: /^better-sqlite3$/, replacement: abs('./stubs/better-sqlite3.js') },
    ],
  },
```

- [ ] **Step 4: Write `server/worker/src/pal-factory.ts`**

```ts
import { OpenRouterClient, Pal, type CompletionLogger } from '../../src/pal.js'
import type { Env } from './worker.js'

// logs only usage/latency/cost — never prompts, memory, or Health values.
const usageLogger: CompletionLogger = {
  info: (obj, msg) => console.log(JSON.stringify({ msg, ...(obj as Record<string, unknown>) })),
}

// a fresh Pal per request; the OpenRouterClient holds only config, no per-request state.
export function makePal(env: Env): Pal {
  const client = new OpenRouterClient(
    env.OPENROUTER_API_KEY,
    env.PAL_MODEL ?? 'deepseek/deepseek-v4-flash',
    env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1',
    fetch,
    Number(env.PAL_REQUEST_TIMEOUT_MS ?? 30_000),
    usageLogger,
  )
  return new Pal(client)
}
```

- [ ] **Step 5: Write `server/worker/test/support/stub-client.ts`** (test-only `CompletionClient`)

```ts
import type { CompletionClient, CompletionResult } from '../../../src/pal.js'
import { Pal } from '../../../src/pal.js'

// canned client for route tests: returns a fixed completion, or throws to exercise
// the 502/500 error mapping. `error` takes precedence when set.
export class StubClient implements CompletionClient {
  constructor(private readonly canned: { text?: string; tool?: CompletionResult; error?: Error }) {}
  async complete(): Promise<string> {
    if (this.canned.error) throw this.canned.error
    return this.canned.text ?? '{}'
  }
  async completeWithTools(): Promise<CompletionResult> {
    if (this.canned.error) throw this.canned.error
    return this.canned.tool ?? { content: '', toolCalls: [] }
  }
}

export const stubPal = (canned: { text?: string; tool?: CompletionResult; error?: Error }): Pal =>
  new Pal(new StubClient(canned))
```

- [ ] **Step 6: Extend `server/worker/src/stores/memory.ts` with `applyOps`**

Add the `MemoryOp` type import (type-only; erased, no runtime pull) and the method. Mirrors `server/src/memory.ts` `applyOps`.

```ts
import type { MemoryOp } from '../../../src/memory.js'
```

```ts
  async applyOps(token: string, ops: MemoryOp[]): Promise<void> {
    for (const op of ops) {
      if (op.op === 'remember') await this.addFact(token, op.text)
      else await this.forgetFact(token, op.id)
    }
  }
```

- [ ] **Step 7: Rewire `server/worker/src/worker.ts` for the Pal seam**

Add imports, extend `Env`, add the `handle()` export + DI thread, and an empty `routePal`. Keep everything from Phase 2; changes are additive.

Imports (add):
```ts
import { makePal } from './pal-factory.js'
import { OpenRouterError, type Pal } from '../../src/pal.js'
import {
  chatBody, parseBody, nutritionEstimateBody, reviewBody, insightsBody, suggestBody,
  postWorkoutBody, routineBody, agendaBody, suggestionsBody, memoryRefreshBody,
} from '../../src/schemas.js'
```

`Env` (add fields):
```ts
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
```

Default export + `handle` seam (replace the `export default { fetch ... }` block):
```ts
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
    res = error('upstream', 'request failed', 500)
  }
  return withCors(res, request, origins)
}
```

Thread `overrides` through `route` → `routeAuthed`: add `overrides?: { pal?: Pal }` as the last param of both, and change the authed delegation:
```ts
    return routeAuthed(request, env, url, method, token, overrides)
```

At the end of `routeAuthed`, replace the final `return error('not_found', ...)` with a delegation to `routePal` (state routes are tried first, exactly as today):
```ts
  const pal = overrides?.pal ?? makePal(env)
  return routePal(request, env, url, method, token, pal, memory)
```

Add the error-mapping helper and the (initially empty) `routePal`:
```ts
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
  // Pal routes are filled in Tasks 2–4.
  return error('not_found', 'no such route', 404)
}
```

(`badRequest` is already imported from Phase 2. `D1MemoryStore` type is already in scope.)

- [ ] **Step 8: Write `server/worker/test/pal-foundation.test.ts`**

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import worker, { handle } from '../src/worker'
import { makePal } from '../src/pal-factory'
import { stubPal } from './support/stub-client'
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

describe('pal foundation', () => {
  it('makePal builds a Pal without touching the network', () => {
    const pal = makePal({ ...(env as any), OPENROUTER_API_KEY: 'x' })
    expect(typeof pal.chat).toBe('function')
  })

  it('D1MemoryStore.applyOps applies remember/forget', async () => {
    const m = new D1MemoryStore(env.DB)
    await m.applyOps('t', [{ op: 'remember', text: 'likes coffee' }])
    const d = await m.digest('t')
    expect(d.facts.map((f) => f.text)).toContain('likes coffee')
    await m.applyOps('t', [{ op: 'forget', id: d.facts[0].id }])
    expect((await m.digest('t')).facts).toHaveLength(0)
  })

  it('an unknown authed route still 404s through routePal', async () => {
    const tok = await token()
    const res = await handle(
      new Request('https://x/v1/nope', { headers: { authorization: `Bearer ${tok}` } }),
      env as any,
      { pal: stubPal({ text: '{}' }) },
    )
    expect(res.status).toBe(404)
  })
})
```

- [ ] **Step 9: Install nothing new; run the suite + bundle**

Run: `cd server/worker && npm test`
Expected: all Phase 2 suites (19) still pass **plus** `pal-foundation` (3). If the `better-sqlite3` alias is wrong, importing `pal.ts` fails here.
Run: `cd server/worker && npm run size`
Expected: bundle builds and stays well under 3 MB (spike with more code was 37 KiB gzip). A native-module error here means the alias didn't take.

- [ ] **Step 10: Commit** — hold for owner approval (batch per the session's git policy; do not auto-commit).

---

### Task 2: Stateless Pal routes — parse, nutrition/estimate, suggest-workout, post-workout-note, suggestions

**Files:**
- Modify: `server/worker/src/worker.ts` (`routePal` branches)
- Create: `server/worker/test/pal-stateless.test.ts`

**Interfaces:** consumes `pal.parse`, `pal.estimateMeal`, `pal.suggestWorkout`, `pal.postWorkoutNote`, `pal.suggestions`. None are memory-backed.

- [ ] **Step 1: Write the failing test `server/worker/test/pal-stateless.test.ts`**

Cover: correct wire shape per route (via `stubPal` canned JSON / tool result), `400` on malformed body, `502` when the client throws `OpenRouterError`, `500` when it throws a generic error. Example spine (fill all five routes):

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import { handle } from '../src/worker'
import { stubPal } from './support/stub-client'
import { OpenRouterError } from '../../src/pal'

async function token(): Promise<string> {
  const res = await handle(new Request('https://x/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  }), env as any)
  return (await res.json() as any).token
}

const post = (tok: string, path: string, body: unknown, pal?: any) =>
  handle(new Request(`https://x${path}`, {
    method: 'POST', headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  }), env as any, pal ? { pal } : undefined)

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('stateless pal routes', () => {
  it('POST /v1/parse returns the parsed entry shape', async () => {
    const tok = await token()
    const canned = JSON.stringify({ type: 'money', amount: 5000, duration: null, category: 'Coffee', title: 'coffee', note: null, direction: 'expense' })
    const res = await post(tok, '/v1/parse', { text: 'coffee 5k' }, stubPal({ text: canned }))
    expect(res.status).toBe(200)
    expect((await res.json() as any).type).toBe('money')
  })

  it('POST /v1/nutrition/estimate returns the estimate shape', async () => {
    const tok = await token()
    const canned = JSON.stringify({ name: 'burrito', calLo: 400, calHi: 700, confidence: 'med' })
    const res = await post(tok, '/v1/nutrition/estimate', { text: 'a burrito' }, stubPal({ text: canned }))
    expect(await res.json()).toMatchObject({ name: 'burrito', calLo: 400, calHi: 700 })
  })

  it('POST /v1/suggest-workout returns { routineId, reason }', async () => {
    const tok = await token()
    const canned = JSON.stringify({ routineId: 'r1', reason: 'legs are fresh' })
    const res = await post(tok, '/v1/suggest-workout', { another: false, context: SUGGEST_CTX }, stubPal({ text: canned }))
    expect(await res.json()).toEqual({ routineId: 'r1', reason: 'legs are fresh' })
  })

  it('POST /v1/post-workout-note wraps the note string', async () => {
    const tok = await token()
    const res = await post(tok, '/v1/post-workout-note', { context: POST_WORKOUT_CTX }, stubPal({ text: 'strong session' }))
    expect(await res.json()).toEqual({ note: 'strong session' })
  })

  it('POST /v1/suggestions returns derived chips', async () => {
    const tok = await token()
    const canned = JSON.stringify({ suggestions: [{ kind: 'log_money', colorToken: 'money', label: 'Log spend', entry: null }] })
    const res = await post(tok, '/v1/suggestions', { surface: 'composer', context: CHAT_CTX }, stubPal({ text: canned }))
    expect((await res.json() as any).suggestions[0].icon).toBe('dollarsign.circle.fill')
  })

  it('400 on malformed body', async () => {
    const tok = await token()
    const res = await post(tok, '/v1/parse', { notText: 1 }, stubPal({ text: '{}' }))
    expect(res.status).toBe(400)
  })

  it('502 on OpenRouterError, 500 on generic error', async () => {
    const tok = await token()
    const r502 = await post(tok, '/v1/parse', { text: 'x' }, stubPal({ error: new OpenRouterError(500, 'boom') }))
    expect(r502.status).toBe(502)
    expect((await r502.json() as any).error.code).toBe('upstream')
    const r500 = await post(tok, '/v1/parse', { text: 'x' }, stubPal({ error: new Error('nope') }))
    expect(r500.status).toBe(500)
  })
})
```

Define minimal valid `SUGGEST_CTX`, `POST_WORKOUT_CTX`, `CHAT_CTX` fixtures at the top of the file, matching `suggestContext`/`postWorkoutContext`/`chatContext` in `schemas.ts` (all-numeric/array fields present). Keep them small but schema-valid.

- [ ] **Step 2: Run to verify it fails** — `npm test -- pal-stateless` → FAIL (routes 404 / not wired).

- [ ] **Step 3: Add the five branches to `routePal`** (before the final `not_found`)

```ts
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
```

- [ ] **Step 4: Run to verify it passes** — `npm test -- pal-stateless` → PASS.
- [ ] **Step 5: Commit** — hold for owner approval.

---

### Task 3: Memory-backed read routes — review, insights, agenda, routine

**Files:**
- Modify: `server/worker/src/worker.ts` (`routePal` branches)
- Create: `server/worker/test/pal-memory-read.test.ts`

**Interfaces:** each reads `await memory.digest(token)` and passes it to the Pal method; none writes memory.

- [ ] **Step 1: Write the failing test `server/worker/test/pal-memory-read.test.ts`**

Cover wire shape per route + that the digest is loaded (register a token, `addFact` a fact, assert the route still returns 200 — the fact rides in the prompt, not the response). Routes and shapes:
- `/v1/review` → `{ text: string }` (stub `{ text: 'weekly recap' }`).
- `/v1/insights` → `Insights` object (stub canned JSON with `headline`, `wins`, `patterns`).
- `/v1/agenda` → `AgendaResult` with derived `icon`/`action` and echoed `streakDays` (assert `proposals[0].icon` derived from `kind`).
- `/v1/routine` → `GeneratedRoutine`; assert non-catalog exercise ids are dropped (canned includes one id in `exercises` catalog and one invented; only the known one survives).

Use `stubPal({ text: canned })` for each. Reuse the `post`/`token` helpers pattern from Task 2.

- [ ] **Step 2: Run to verify it fails** — `npm test -- pal-memory-read` → FAIL.

- [ ] **Step 3: Add the four branches to `routePal`**

```ts
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
```

- [ ] **Step 4: Run to verify it passes** — `npm test -- pal-memory-read` → PASS.
- [ ] **Step 5: Commit** — hold for owner approval.

---

### Task 4: Memory-writing routes — chat, memory/refresh

**Files:**
- Modify: `server/worker/src/worker.ts` (`routePal` branches)
- Create: `server/worker/test/pal-memory-write.test.ts`

**Interfaces:** `chat` reads digest, calls `pal.chat`, applies `res.memoryOps` server-side via `memory.applyOps`, returns `{ reply, actions }` (memoryOps never on the wire). `memory/refresh` reads digest, calls `pal.refreshPatterns`, persists via `memory.setPatterns`, returns the fresh digest.

- [ ] **Step 1: Write the failing test `server/worker/test/pal-memory-write.test.ts`**

Cover:
- `/v1/chat` with a plain text reply (stub `{ tool: { content: 'hi there', toolCalls: [] } }`) → `{ reply: 'hi there', actions: [] }`, and no `memoryOps` field on the body.
- `/v1/chat` with a `remember` tool call → `actions: []` but a follow-up `GET /v1/memory` shows the new fact (proves `applyOps` ran). Build the tool result: `{ tool: { content: '', toolCalls: [{ name: 'remember', arguments: JSON.stringify({ fact: 'likes espresso' }) }] } }`.
- `/v1/chat` with a `log_expense` tool call → `actions[0].kind === 'log_expense'` and no memory fact written.
- `/v1/memory/refresh` → persists patterns and returns a digest whose `patterns` reflect the canned model output. Stub `{ text: JSON.stringify({ patterns: [{ colorToken: 'money', title: 'Coffee habit', detail: '...' }] }) }`; assert the response `patterns[0].title` and that a second `GET /v1/memory` also shows them.
- `502`/`500` mapping on `/v1/chat` via `stubPal({ error })`.

Use a valid `chatContext` fixture (all numeric/array fields) and `insightsContext` fixture for refresh.

- [ ] **Step 2: Run to verify it fails** — `npm test -- pal-memory-write` → FAIL.

- [ ] **Step 3: Add the two branches to `routePal`**

```ts
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
```

- [ ] **Step 4: Run the group, then the full suite** — `npm test -- pal-memory-write` → PASS; then `npm test` → ALL suites pass (Phase 2 + foundation + stateless + memory-read + memory-write).
- [ ] **Step 5: Measure the bundle** — `npm run size` → builds, gzip well under 3 MB.
- [ ] **Step 6: Commit** — hold for owner approval.

---

### Task 5: Staging deploy + real-LLM verification (owner-gated — the Phase 3 exit condition)

This runs on Cloudflare against the Phase 2 `opal-worker` and needs the owner's OpenRouter key **with a credit cap**. It proves the roadmap Phase 3 exit ("all non-email Flutter Pal features pass against staging without client contract changes") and retires the Phase 1 "live smoke not yet done" gap.

- [ ] **Step 1: Owner sets the OpenRouter secret** (value never passes through the assistant)

```bash
cd server/worker
npx wrangler secret put OPENROUTER_API_KEY   # a key with a hard daily/monthly credit cap
```

- [ ] **Step 2: Deploy** — `npx wrangler deploy` (the Pal `[vars]` and `alias` from Task 1 ship with it; confirm the deploy output lists `OPENROUTER_API_KEY` among the bindings and the bundle is < 3 MB).

- [ ] **Step 3: Real-LLM contract smoke** on a representative subset (spends a little real credit). Register, then:
  - `POST /v1/parse` `{ "text": "coffee 5k" }` → 200, a `ParsedEntry` with `type` set.
  - `POST /v1/chat` a simple message with a valid context → 200, `{ reply, actions }`.
  - `POST /v1/insights` with a valid context → 200, an `Insights` object.
  Confirm shapes match what `HttpPalService` expects; a malformed body still returns 400.

- [ ] **Step 4: Cost/latency visibility + timeout survival** — `npx wrangler tail` during the smoke; confirm each Pal call logs `{ ms, model, usage, cost, finish_reason }` and that **no prompt text, memory, or Health values appear**. This is also the `STUB_LLM=0` live proof that the 30 s timeout + one retry survive the real runtime.

- [ ] **Step 5: CPU sanity** — watch `wrangler tail` / the Workers dashboard for any `1102`/`1027` during the smoke (chat is the thin-margin case). If any appear, apply the recorded lever (cap parsed tool-calls) — a bounded `server/src`/worker change made only on evidence — and re-verify. Expect none (Phase 1 saw zero).

- [ ] **Step 6: Record the outcome** — append a "Phase 3 verification" section to `docs/migration-phase-2-verification.md` (or a new `docs/migration-phase-3-verification.md`): which Pal routes were smoked, the observed cost-log shape (no PII), and any CPU observations. No secrets.

- [ ] **Step 7: Commit** — hold for owner approval.

---

## Notes carried from the roadmap

- **Email/`/v1/email/extract` stays Phase 4.** `receipts.ts`/`redact.ts`/`imap.ts` are not imported here; the native-client email boundary is a separate phase.
- **The `MAX_*`-constant relocation is deferred.** The `better-sqlite3` alias keeps `server/src` untouched, which is safest while the DigitalOcean Node deployment stays live (through Phase 6). If a later phase does the clean relocation, the worker D1 stores can then import the shared constants and drop their local redeclarations.
- **`Date.now()` / `setTimeout` / `AbortSignal.timeout` are fine in the Worker runtime** — `pal.ts` uses only these; no Node-specific timing.
- **Rate limit + auth + CORS unchanged.** Pal routes sit behind the same per-token rate limit and bearer guard from Phase 2; the 300-wide-burst 429 behavior already verified applies.
- **CPU margin is thin, not failing.** Phase 1: zero `1102` across 800 worst-case requests, chat p90 ~7 ms. No speculative optimization; Task 5 is the real-runtime check.

## Self-Review

- **Spec coverage (roadmap Phase 3 bullets):** reuse prompts/product/action-conversion/memory-ops/OpenRouter-retry/Zod validation → all via importing `pal.ts` verbatim (Task 1). Port routes in small contract-tested groups → Tasks 2 (stateless ×5), 3 (memory-read ×4), 4 (memory-write ×2). Preserve status codes/bodies for `HttpPalService` → `runPal` 502/500 mapping + per-route wire shapes (Tasks 2–4), verified against `app.ts`. Cost visible without logging prompts/secrets/PII → `usageLogger` (Task 1) + tail check (Task 5). Exit condition (staging, no client changes) → Task 5.
- **Out-of-scope confirmed excluded:** all `/v1/email/*` including `/v1/email/extract`; no `receipts`/`redact`/`imap` imports.
- **Contract fidelity checked against `pal.ts` + `app.ts`:** chat returns `{reply,actions}` and applies `memoryOps` server-side; review/post-workout-note wrap a string; insights/agenda/suggestions carry server-derived icons/actions; routine drops non-catalog ids; memory/refresh persists patterns and returns the digest. `OpenRouterError → 502`, else `500`, `{error:{code:'upstream',message:'pal request failed'}}`; bad body `400` with `details`.
- **Type consistency:** `makePal(env): Pal`, `handle(request, env, {pal?})`, `runPal(fn)`, `routePal(request, env, url, method, token, pal, memory)`, `D1MemoryStore.applyOps(token, ops)` used consistently across tasks.
- **Placeholder scan:** none — every code and test step is concrete. The only owner-gated value is the `OPENROUTER_API_KEY` secret (Task 5), never written to a file.
- **Bundling risk called out:** the `better-sqlite3` alias is the single point that makes `pal.ts` importable; Task 1 Step 9 fails loudly if it's misconfigured, before any route work.
