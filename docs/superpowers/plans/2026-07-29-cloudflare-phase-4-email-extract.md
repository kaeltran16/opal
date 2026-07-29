# Cloudflare Phase 4 — Email Extraction Endpoint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement Part A task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Part B is a handoff spec, not executable in this environment** (no Flutter/Dart toolchain) — do not attempt it here.

**Goal:** Add a stateless `POST /v1/email/extract` endpoint to the Phase 2/3 Worker that turns one bounded batch of *sanitized* receipt candidates into importable expense entries, so email sync can move off server-side IMAP without changing the client's import wire shape.

**Architecture:** The native client (Part B, handoff) owns IMAP transport, MIME parsing, sender filtering, dedup, body bounds, and PII redaction, then submits ≤8 sanitized candidates per request. The Worker runs exactly one `extractReceipts` LLM call per request (reused verbatim from `server/src/receipts.ts`), re-redacts as defense-in-depth, maps results to the existing `EmailImportDto` shape, and returns them. Batching, concurrency, and per-batch failure isolation live in the client sync loop — the Worker stays stateless and bounded for the Free-tier CPU budget.

**Tech Stack:** Same as Phase 2/3 — Workers native `fetch`, D1, Wrangler 4.x, reused Zod, Vitest + `@cloudflare/vitest-pool-workers`. Reuses `receipts.ts` (`extractReceipts`, `resolveReceivedAt`, `BATCH_SIZE`, `RECEIPT_CATEGORIES`), `redact.ts` (transitively), `prompts.ts` (`receiptsBatchPrompt`), and the OpenRouter client from Phase 3.

## Global Constraints

- **Scope = one new route only:** `POST /v1/email/extract`. The old `POST /v1/email/test` and `POST /v1/email/sync` are **not** ported (they become native-client responsibilities; their removal from the Node app is Phase 7, after cutover). `imap.ts`, `imapflow`, and `mailparser` are never imported into the Worker.
- **Client owns the sync loop.** One request == one batch == one `extractReceipts` LLM call, bounded to `BATCH_SIZE` (8) candidates. The Worker does no chunking, no concurrency, no cross-request state. A single request's upstream failure surfaces as `502` and the client's loop isolates it.
- **Zero `server/src` edits.** Reuse `receipts.ts` and `pal.ts` as-is via relative import (`../../src/*.js`). The new Phase-4 wire schema (`emailExtractBody`) and glue live in a new **worker-side** module, `server/worker/src/email.ts`, not in `server/src/schemas.ts`. This keeps the stable Node modules the live DigitalOcean deployment still runs (through Phase 6) untouched.
- **Preserve the client import contract verbatim.** The response item shape must equal `server/src/email.ts` `EmailImportDto`: `{ id, merchant, amount, receivedAt, category }`, `amount` negative (expense), `receivedAt` ISO 8601, `category` a `RECEIPT_CATEGORIES` value or `null`. Response envelope: `{ items: EmailImportDto[] }`.
- **Error mapping matches every other LLM route.** `OpenRouterError → 502`, any other throw `→ 500`, both `{ error: { code: "upstream", message: "pal request failed" } }` via the existing `runPal` helper. Malformed body `→ 400` `bad_request` with `details` via the existing `badRequest` helper. Auth/rate-limit/CORS are unchanged (shared `/v1/*` guard).
- **Security boundary.** The Worker never receives IMAP credentials. `extractReceipts` already re-applies `redactPii` to `subject`/`text` (idempotent) before the body leaves for the model — defense-in-depth even though the client redacts first. The `from` field is the merchant sender address (not user PII) and is intentionally left unredacted for merchant inference. Log only usage/latency/cost (the Phase 3 `usageLogger`); never log candidate bodies, subjects, or merchants.
- **Explicit request/string bounds** on every candidate field (roadmap security requirement): array `min(1).max(BATCH_SIZE)`, `id ≤ 998`, `from ≤ 320`, `subject ≤ 1000`, `text ≤ 8000`, `envelopeDate` must be `Date.parse`-able.
- **No production LLM stub.** The route builds the real client via `makeClient(env)`. Tests inject a `TextCompleter` through a new `handle(request, env, { completer })` seam, mirroring the Phase 3 `{ pal }` seam.
- **Toolchain:** Node 22.14, `npm test` / `wrangler dev` / `wrangler deploy` run locally from `server/worker/`. The **`wrangler dev` real-LLM smoke and staging deploy (Task 5) are owner-gated** — they need the owner's OpenRouter key with a credit cap. Flutter/Dart is not installed and must not be.

---

# Part A — Worker endpoint (executable here)

### Task 1: Pure email-extract module (`email.ts`)

**Files:**
- Create: `server/worker/src/email.ts`
- Modify: `server/worker/test/support/stub-client.ts` (add `StubCompleter`)
- Test: `server/worker/test/email.test.ts`

**Interfaces:**
- Consumes: `extractReceipts(emails: RawEmail[], client: TextCompleter): Promise<(ReceiptFields|null)[]>`, `resolveReceivedAt(text: string, envelope: Date): Date`, `BATCH_SIZE: number` from `../../src/receipts.js`; `TextCompleter` (type) from `../../src/pal.js`. `RawEmail` fields consumed: `{ messageId, from, fromName, subject, date, text }`. `ReceiptFields` fields consumed: `{ merchant, amount, category }`.
- Produces: `interface EmailImportDto { id: string; merchant: string; amount: number; receivedAt: string; category: string | null }`; `emailCandidate` (Zod), `type EmailCandidate`; `emailExtractBody` (Zod, `{ candidates: EmailCandidate[] }`), `type EmailExtractBody`; `extractFromCandidates(candidates: EmailCandidate[], completer: TextCompleter): Promise<EmailImportDto[]>`; `class StubCompleter` with `lastMessages: Array<{ role: string; content: string }>`.

- [ ] **Step 1: Write `server/worker/test/support/stub-client.ts` addition — `StubCompleter`**

Append to the existing file (keep `StubClient` / `stubPal`):

```ts
import type { TextCompleter } from '../../../src/pal.js'

// canned TextCompleter for email-extract tests: captures the messages it was
// called with (so redaction can be asserted) and returns fixed text, or throws
// to exercise the 502/500 mapping. `error` takes precedence when set.
export class StubCompleter implements TextCompleter {
  lastMessages: Array<{ role: string; content: string }> = []
  constructor(private readonly canned: { text?: string; error?: Error }) {}
  async complete(messages: Array<{ role: string; content: string }>): Promise<string> {
    this.lastMessages = messages
    if (this.canned.error) throw this.canned.error
    return this.canned.text ?? '{}'
  }
}
```

- [ ] **Step 2: Write the failing test `server/worker/test/email.test.ts`**

```ts
import { describe, it, expect } from 'vitest'
import { extractFromCandidates, emailExtractBody } from '../src/email'
import { StubCompleter } from './support/stub-client'
import { OpenRouterError } from '../../src/pal'

// one model result object per candidate index; extractReceipts maps back by index.
const modelResults = (results: unknown[]) => JSON.stringify({ results })

const CAND = {
  id: 'msg-1',
  from: 'billing@cafe.com',
  subject: 'Your receipt',
  text: 'Total $5 on 06 Jan 2026 11:27',
  envelopeDate: '2026-01-08T09:00:00.000Z',
}

describe('extractFromCandidates', () => {
  it('maps a receipt to the import wire shape (negative amount, body txn date)', async () => {
    const completer = new StubCompleter({
      text: modelResults([{ index: 0, isReceipt: true, merchant: 'Cafe', amount: 5, category: 'Food & Drink' }]),
    })
    const items = await extractFromCandidates([CAND], completer)
    expect(items).toEqual([{
      id: 'msg-1', merchant: 'Cafe', amount: -5,
      receivedAt: '2026-01-06T11:27:00.000Z', category: 'Food & Drink',
    }])
  })

  it('drops candidates the model marks non-receipt, preserving order', async () => {
    const completer = new StubCompleter({
      text: modelResults([
        { index: 0, isReceipt: false, merchant: null, amount: null, category: null },
        { index: 1, isReceipt: true, merchant: 'Shop', amount: 12, category: 'Shopping' },
      ]),
    })
    const items = await extractFromCandidates([CAND, { ...CAND, id: 'msg-2' }], completer)
    expect(items).toHaveLength(1)
    expect(items[0].id).toBe('msg-2')
    expect(items[0].amount).toBe(-12)
  })

  it('re-redacts PII in the body before it reaches the model (defense in depth)', async () => {
    const completer = new StubCompleter({
      text: modelResults([{ index: 0, isReceipt: false, merchant: null, amount: null, category: null }]),
    })
    const dirty = { ...CAND, text: 'Paid by user@example.com card 4111 1111 1111 1111 total $5' }
    await extractFromCandidates([dirty], completer)
    const prompt = completer.lastMessages[0].content
    expect(prompt).toContain('[email]')
    expect(prompt).toContain('[card]')
    expect(prompt).not.toContain('user@example.com')
    expect(prompt).not.toContain('4111 1111 1111 1111')
  })

  it('propagates an OpenRouterError from the completer', async () => {
    const completer = new StubCompleter({ error: new OpenRouterError(502, 'boom') })
    await expect(extractFromCandidates([CAND], completer)).rejects.toBeInstanceOf(OpenRouterError)
  })
})

describe('emailExtractBody', () => {
  it('accepts 1..BATCH_SIZE candidates', () => {
    expect(emailExtractBody.safeParse({ candidates: [CAND] }).success).toBe(true)
  })
  it('rejects an empty batch', () => {
    expect(emailExtractBody.safeParse({ candidates: [] }).success).toBe(false)
  })
  it('rejects more than BATCH_SIZE candidates', () => {
    expect(emailExtractBody.safeParse({ candidates: Array(9).fill(CAND) }).success).toBe(false)
  })
  it('rejects an unparseable envelopeDate', () => {
    expect(emailExtractBody.safeParse({ candidates: [{ ...CAND, envelopeDate: 'not-a-date' }] }).success).toBe(false)
  })
})
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd server/worker && npx vitest run test/email.test.ts`
Expected: FAIL — cannot find module `../src/email`.

- [ ] **Step 4: Write `server/worker/src/email.ts`**

```ts
import { z } from 'zod'
import { extractReceipts, resolveReceivedAt, BATCH_SIZE } from '../../src/receipts.js'
import type { TextCompleter } from '../../src/pal.js'

// Wire shape returned to the client; kept 1:1 with server/src/email.ts
// EmailImportDto so the client's import path (EmailImportItem) needs no change.
export interface EmailImportDto {
  id: string
  merchant: string
  amount: number // negative = expense (client convention)
  receivedAt: string // ISO 8601
  category: string | null
}

// One sanitized receipt candidate. The native client owns IMAP, MIME parsing,
// sender filtering, dedup, body bounds, and PII redaction — the Worker never
// sees credentials or unredacted bodies. `envelopeDate` is the IMAP envelope
// date; the transaction date is re-derived server-side from `text`. `from` is
// the merchant sender address (not user PII) and is left intact for merchant
// inference. Bounds are defensive: the client already caps body size.
export const emailCandidate = z.object({
  id: z.string().min(1).max(998),
  from: z.string().max(320),
  subject: z.string().max(1000),
  text: z.string().max(8000),
  envelopeDate: z.string().refine((s) => !Number.isNaN(Date.parse(s)), 'invalid date'),
})
export type EmailCandidate = z.infer<typeof emailCandidate>

// One request == one batch == one LLM call. Bounded to BATCH_SIZE so a request
// maps to a single extractReceipts call; the client owns the loop across batches.
export const emailExtractBody = z.object({
  candidates: z.array(emailCandidate).min(1).max(BATCH_SIZE),
})
export type EmailExtractBody = z.infer<typeof emailExtractBody>

// Model-extract receipts for one sanitized batch and map each hit onto the
// client import wire shape. extractReceipts re-applies redactPii (idempotent)
// as defense-in-depth, gates isReceipt, and returns one slot per input in order.
export async function extractFromCandidates(
  candidates: EmailCandidate[],
  completer: TextCompleter,
): Promise<EmailImportDto[]> {
  const emails = candidates.map((c) => ({
    messageId: c.id,
    from: c.from,
    fromName: '',
    subject: c.subject,
    date: new Date(c.envelopeDate),
    text: c.text,
  }))
  const fields = await extractReceipts(emails, completer)
  const items: EmailImportDto[] = []
  fields.forEach((f, i) => {
    if (!f) return
    const c = candidates[i]
    items.push({
      id: c.id,
      merchant: f.merchant,
      amount: -Math.abs(f.amount), // receipts are expenses
      receivedAt: resolveReceivedAt(c.text, new Date(c.envelopeDate)).toISOString(),
      category: f.category,
    })
  })
  return items
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd server/worker && npx vitest run test/email.test.ts`
Expected: PASS (8 tests).

- [ ] **Step 6: Commit**

```bash
git add server/worker/src/email.ts server/worker/test/email.test.ts server/worker/test/support/stub-client.ts
git commit -m "feat(worker): email extraction module + candidate schema (phase 4)"
```

---

### Task 2: `makeClient` factory export

**Files:**
- Modify: `server/worker/src/pal-factory.ts`

**Interfaces:**
- Produces: `makeClient(env: Env): OpenRouterClient` (shared by `makePal` and the email route).
- Consumes: `OpenRouterClient` from `../../src/pal.js`.

This is a pure refactor with no behavior change — `makePal` keeps returning the same `Pal`. It is folded into Part A because the email route (Task 3) needs a raw `TextCompleter`, which `makePal` (returning `Pal`) does not expose. Verified by the existing Phase 3 suite staying green (no new test).

- [ ] **Step 1: Replace the body of `pal-factory.ts` `makePal` with a shared `makeClient`**

```ts
import { OpenRouterClient, Pal, type CompletionLogger } from '../../src/pal.js'
import type { Env } from './worker.js'

// logs only usage/latency/cost — never prompts, memory, or Health values.
const usageLogger: CompletionLogger = {
  info: (obj, msg) => console.log(JSON.stringify({ msg, ...(obj as Record<string, unknown>) })),
}

// a fresh OpenRouter client per request; it holds only config, no per-request state.
export function makeClient(env: Env): OpenRouterClient {
  return new OpenRouterClient(
    env.OPENROUTER_API_KEY,
    env.PAL_MODEL ?? 'deepseek/deepseek-v4-flash',
    env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1',
    // bind to globalThis: OpenRouterClient calls fetchImpl as a method, and workerd
    // throws "Illegal invocation" if fetch runs with a non-global `this` (Node tolerates it).
    fetch.bind(globalThis),
    Number(env.PAL_REQUEST_TIMEOUT_MS ?? 30_000),
    usageLogger,
  )
}

export function makePal(env: Env): Pal {
  return new Pal(makeClient(env))
}
```

- [ ] **Step 2: Verify the existing suite still compiles and passes**

Run: `cd server/worker && npx vitest run`
Expected: PASS — the full Phase 2/3 suite plus Task 1's `email.test.ts`, unchanged count except the new email tests.

- [ ] **Step 3: Commit**

```bash
git add server/worker/src/pal-factory.ts
git commit -m "refactor(worker): extract makeClient from makePal (phase 4)"
```

---

### Task 3: Wire `POST /v1/email/extract` into the Worker

**Files:**
- Modify: `server/worker/src/worker.ts`
- Test: `server/worker/test/email-extract.test.ts`

**Interfaces:**
- Consumes: `emailExtractBody`, `extractFromCandidates` from `./email.js`; `makeClient` from `./pal-factory.js`; `TextCompleter` (type) from `../../src/pal.js`; existing `runPal`, `badRequest`, `json`, `error`.
- Produces: route `POST /v1/email/extract → { items: EmailImportDto[] }`; extended DI seam `handle(request, env, overrides?: { pal?: Pal; completer?: TextCompleter })`.

- [ ] **Step 1: Write the failing route contract test `server/worker/test/email-extract.test.ts`**

```ts
import { env, applyD1Migrations } from 'cloudflare:test'
import { beforeEach, describe, it, expect } from 'vitest'
import { handle } from '../src/worker'
import { StubCompleter } from './support/stub-client'
import { OpenRouterError } from '../../src/pal'

const modelResults = (results: unknown[]) => JSON.stringify({ results })

const CAND = {
  id: 'msg-1', from: 'billing@cafe.com', subject: 'Your receipt',
  text: 'Total $5 on 06 Jan 2026 11:27', envelopeDate: '2026-01-08T09:00:00.000Z',
}

async function token(): Promise<string> {
  const res = await handle(new Request('https://x/v1/register', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ provisioningKey: env.PAL_PROVISIONING_KEY, deviceId: 'd1' }),
  }), env as any)
  return (await res.json() as any).token
}

const post = (tok: string, body: unknown, completer?: any) =>
  handle(new Request('https://x/v1/email/extract', {
    method: 'POST', headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  }), env as any, completer ? { completer } : undefined)

beforeEach(async () => { await applyD1Migrations(env.DB, (env as any).TEST_MIGRATIONS) })

describe('POST /v1/email/extract', () => {
  it('returns the mapped import items', async () => {
    const tok = await token()
    const canned = modelResults([{ index: 0, isReceipt: true, merchant: 'Cafe', amount: 5, category: 'Food & Drink' }])
    const res = await post(tok, { candidates: [CAND] }, new StubCompleter({ text: canned }))
    expect(res.status).toBe(200)
    const body = await res.json() as any
    expect(body.items).toEqual([{
      id: 'msg-1', merchant: 'Cafe', amount: -5,
      receivedAt: '2026-01-06T11:27:00.000Z', category: 'Food & Drink',
    }])
  })

  it('returns an empty batch when nothing is a receipt', async () => {
    const tok = await token()
    const canned = modelResults([{ index: 0, isReceipt: false, merchant: null, amount: null, category: null }])
    const res = await post(tok, { candidates: [CAND] }, new StubCompleter({ text: canned }))
    expect(res.status).toBe(200)
    expect((await res.json() as any).items).toEqual([])
  })

  it('400 on malformed body', async () => {
    const tok = await token()
    const res = await post(tok, { candidates: [] }, new StubCompleter({ text: '{}' }))
    expect(res.status).toBe(400)
    expect((await res.json() as any).error.code).toBe('bad_request')
  })

  it('401 without a valid token', async () => {
    const res = await handle(new Request('https://x/v1/email/extract', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ candidates: [CAND] }),
    }), env as any)
    expect(res.status).toBe(401)
  })

  it('502 on OpenRouterError, 500 on a generic error', async () => {
    const tok = await token()
    const r502 = await post(tok, { candidates: [CAND] }, new StubCompleter({ error: new OpenRouterError(500, 'boom') }))
    expect(r502.status).toBe(502)
    expect((await r502.json() as any).error.code).toBe('upstream')
    const r500 = await post(tok, { candidates: [CAND] }, new StubCompleter({ error: new Error('nope') }))
    expect(r500.status).toBe(500)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server/worker && npx vitest run test/email-extract.test.ts`
Expected: FAIL — `POST /v1/email/extract` returns `404 not_found` (route not wired), so the 200 assertions fail.

- [ ] **Step 3: Extend the DI seam and add the route in `worker.ts`**

Change the three `overrides` type annotations (in `handle`, `route`, `routeAuthed`) from `{ pal?: Pal }` to `{ pal?: Pal; completer?: TextCompleter }`. The bodies already thread `overrides` through unchanged.

Update the imports:

```ts
import { makePal, makeClient } from './pal-factory.js'
import { OpenRouterError, type Pal, type TextCompleter } from '../../src/pal.js'
import { emailExtractBody, extractFromCandidates } from './email.js'
```

Add this block inside `routeAuthed`, immediately before the `const pal = overrides?.pal ?? makePal(env)` line (i.e. after the widget routes, before the Pal fallthrough):

```ts
  if (pathname === '/v1/email/extract' && method === 'POST') {
    const raw = await request.json().catch(() => null)
    const parsed = emailExtractBody.safeParse(raw)
    if (!parsed.success) return badRequest(parsed.error, raw)
    // stateless: one request == one batch == one LLM call. The client owns the
    // sync loop, concurrency, and per-batch failure isolation.
    const completer = overrides?.completer ?? makeClient(env)
    return runPal(async () => ({ items: await extractFromCandidates(parsed.data.candidates, completer) }))
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server/worker && npx vitest run test/email-extract.test.ts`
Expected: PASS (5 tests).

- [ ] **Step 5: Run the whole Worker suite + typecheck**

Run: `cd server/worker && npx vitest run && npx tsc --noEmit`
Expected: all suites green (Phase 2 + Phase 3 + Task 1 `email` + Task 3 `email-extract`); `tsc --noEmit` exits 0.

- [ ] **Step 6: Commit**

```bash
git add server/worker/src/worker.ts server/worker/test/email-extract.test.ts
git commit -m "feat(worker): POST /v1/email/extract route + completer DI seam (phase 4)"
```

---

### Task 4: Bundle-size guard

**Files:** none (measurement only).

`receipts.ts` pulls `redact.ts` (new to the bundle, pure regex) but no native deps — `imap.ts` is a type-only import and erased. Confirm the deploy bundle stays well under the 3 MB Worker limit and that `better-sqlite3`/`imapflow`/`mailparser` are absent.

- [ ] **Step 1: Dry-run the deploy build and read the reported bundle size**

Run: `cd server/worker && npx wrangler deploy --dry-run --outdir dist`
Expected: succeeds; reported `Total Upload` size is a few hundred KiB (Phase 3 was 185 KiB), far under 3 MB.

- [ ] **Step 2: Confirm no forbidden module was bundled**

Run: `cd server/worker && grep -c -E "imapflow|mailparser|better_sqlite3|better-sqlite3" dist/*.js`
Expected: `0` for each (the `better-sqlite3` alias stub may appear as the throwing shim; `imapflow`/`mailparser` must be `0`).

- [ ] **Step 3: No commit** (build artifacts are git-ignored). If the size regressed materially, stop and investigate the new import graph before Task 5.

---

### Task 5 (owner-gated): `wrangler dev` real-LLM smoke + staging deploy + verification doc

**Files:**
- Create: `docs/migration-phase-4-verification.md`

Requires the owner's OpenRouter key with a credit cap (same gate as Phase 3, Task 5). The agent prepares the exact commands and the verification-doc skeleton; the owner runs the live calls and pastes results.

- [ ] **Step 1: Local live smoke against `wrangler dev` (real workerd + real OpenRouter)**

```bash
cd server/worker && npx wrangler dev
# in a second shell (replace TOKEN from a real /v1/register call):
curl -s -X POST localhost:8787/v1/email/extract \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"candidates":[{"id":"m1","from":"billing@grab.com","subject":"Grab receipt","text":"Total 45,000d GrabFood on 06 Jan 2026 11:27","envelopeDate":"2026-01-08T09:00:00.000Z"}]}'
```
Expected: `200 { "items": [ { "id":"m1","merchant":...,"amount":<negative>,"receivedAt":"2026-01-06T11:27:00.000Z","category":... } ] }`. Confirm the `wrangler dev` log shows exactly one `openrouter completion` line with `{ ms, model, usage, cost, finish_reason }` and **no candidate body/subject/merchant text**.

- [ ] **Step 2: Deploy to staging and re-smoke against the `workers.dev` URL**

```bash
cd server/worker && npx wrangler deploy
```
Re-run the Step 1 curl against `https://opal-worker.piskael03.workers.dev/v1/email/extract`. Expected: same `200 { items }`. Watch `npx wrangler tail` for `ok` outcome and no `1102` CPU kill (batch of 8 is the worst case — smoke a full 8-candidate batch too).

- [ ] **Step 3: Write `docs/migration-phase-4-verification.md`**

Record: unit suite count, dry-run bundle size, the local + staging smoke results table, the PII-free log scan, and the batch-of-8 CPU/`finish_reason`/`ms` observation. Mirror the structure of `docs/migration-phase-3-verification.md`. Note the Phase 4 exit condition is **partially** met here — the Worker half is proven; the native adapter (Part B) and true end-to-end sync remain a handoff.

- [ ] **Step 4: Commit**

```bash
git add docs/migration-phase-4-verification.md
git commit -m "docs(worker): phase 4 email-extract staging verification"
```

---

# Part B — Native email adapter (HANDOFF — not executable in this environment)

> This section is a requirements spec for a Flutter/Dart-capable session (the owner's Mac). It is **not** a TDD task list and must not be attempted in the Windows/Node environment (the roadmap forbids installing Flutter/Dart/Node tooling here). It exists so the handoff is unambiguous and the client half targets the exact contract Part A ships.

**Goal:** Replace server-side IMAP sync with a native mailbox adapter behind the existing `EmailSyncService` interface, feeding sanitized candidates to `POST /v1/email/extract`.

**The wire contract Part A ships (client must match):**

```
POST /v1/email/extract   (Bearer device token)
Request:  { candidates: [ { id, from, subject, text, envelopeDate }, ... 1..8 ] }
Response: { items: [ { id, merchant, amount(negative), receivedAt(ISO), category|null }, ... ] }
Errors:   400 bad_request | 401 unauthorized | 429 rate_limited | 502/500 upstream
```

**Deterministic logic to port to Dart (from `server/src`, so the Worker never needs credentials):**
- `filterBySender` (`receipts.ts`) — sender allowlist.
- `isLikelyNonReceipt` + `NON_RECEIPT_MARKERS` + `PROMO_SUBJECT_MARKERS` (`receipts.ts`) — pre-LLM gate. Port the marker lists **verbatim** (including the Vietnamese entries).
- `redactPii` + all four regexes (`redact.ts`) — mask email/card/phone/long-number **on-device** before sending.
- Message-ID dedup within a sync.
- Body-size bound (client cap; Worker also caps `text` at 8000 — keep the client cap ≤ that).
- `resolveReceivedAt`/`extractTxnDate` stay **server-side** (Part A already runs them); the client only supplies `text` + `envelopeDate`.

**Client sync loop (owns batching + isolation, per the Phase 4 batch-ownership decision):**
1. Read Gmail app password from the device keychain; connect IMAP; fetch recent INBOX (date + count bounds).
2. Extract minimal MIME text/headers; apply sender filter, dedup, non-receipt gate, body bound, redaction.
3. Chunk survivors into batches of ≤8; `POST /v1/email/extract` per batch.
4. Isolate failures per batch: a `502`/timeout skips that batch's candidates, never the others. Dedup returned items by `id`.
5. Persist through the existing repository + `sourceRef` dedup path.

**Other handoff requirements:**
- Disable real email sync on Flutter web (explicit unavailable state or current mock) — browsers cannot open IMAP.
- Keep IMAP credentials on-device only; never send them to the Worker.
- Choose the native IMAP/MIME dependency at implementation time (maintained Flutter package vs. small native iOS adapter); do not write an IMAP protocol client.
- Verification is a device/account test (live Gmail) plus adapter unit tests with recorded MIME fixtures and a fake transport, asserting sanitized requests carry no app password and no redaction-excluded fields.

**Phase 4 exit condition (owner, on Mac):** native test-connection, sync, extraction, local persistence, and duplicate suppression work end-to-end without sending IMAP credentials to Cloudflare.

---

## Self-review notes

- **Spec coverage (roadmap Phase 4):** extract endpoint + sanitized-candidate seam (Tasks 1–3); explicit request/string bounds (Task 1 schema); redaction defense-in-depth (Task 1/3 tests); PII-free cost logging (reused Phase 3 `usageLogger`, Task 5 scan); bundle exclusion of IMAP/MIME (Task 4); batch-failure isolation + web-disable + native adapter (Part B handoff). Removal of `/v1/email/{test,sync}` is deferred to Phase 7 (noted in Global Constraints).
- **Out of scope / housekeeping:** the uncommitted `server/spike/wrangler.toml` `database_id` change is a leftover from the Phase 1 spike, unrelated to this phase — leave it for the owner to commit or discard.
