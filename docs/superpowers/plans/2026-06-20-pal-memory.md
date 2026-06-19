# Persistent Pal Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Pal a persistent, per-device memory of explicit user facts and learned behavioral patterns, injected into the surfaces that benefit and surfaced for the user to view and delete.

**Architecture:** A new server-side `MemoryStore` (SQLite, keyed by device token) holds two record types: user-authored *facts* and derived *patterns*. Facts are captured inline during chat via `remember`/`forget` tool-calls; patterns are rewritten by a dedicated `/v1/memory/refresh` endpoint. A compact digest is injected into chat, agenda, insights, recap, and routine prompts. `Pal` stays store-free and testable: `chat` returns `memoryOps` that the route handler applies to the store. The client repoints the existing Pal Home "What Pal remembers" section to `GET /v1/memory` with per-fact delete and wipe-all.

**Tech Stack:** TypeScript / Fastify / better-sqlite3 / zod / vitest (server); Dart / Flutter / Riverpod (riverpod_generator via build_runner) / flutter_test (app).

## Global Constraints

- Server is **stateless except for SQLite**; every store is constructed with `config.sqlitePath` and owns its tables via `CREATE TABLE IF NOT EXISTS` (mirror `TokenStore`).
- Memory is **per device token**. The bearer token is the partition key for every memory operation.
- **Caps:** facts ≤ 20 (drop oldest on overflow); patterns ≤ 5 (full rewrite, never appended). No auto-expiry.
- Pattern shape reuses the insights pattern shape exactly: `{ colorToken: 'money'|'move'|'rituals', title: string, detail: string }`.
- **Memory never blocks a user-facing call.** A digest read failure injects empty memory; a memory write failure logs and is swallowed. Only `/v1/memory/refresh` may surface an LLM error (502).
- **Never inject memory** into Parse, Post-workout, or Receipts prompts.
- Memory tool-calls (`remember`/`forget`) are applied server-side and are **never** returned in the `/v1/chat` `actions` array.
- No emojis in code, comments, or copy. Comments explain "why," lower case, only when necessary.
- Server tests: `npm test` (from `server/`) runs `vitest run`. Single file: `npx vitest run src/<file>.test.ts`.
- App tests: `flutter test <path>`. After adding/removing a `@riverpod` provider, regenerate: `dart run build_runner build --delete-conflicting-outputs`.
- Do not commit until the very end is **not** in force here — this plan commits per task (the user batches the design-doc commit separately; per-task commits during implementation are expected by the TDD flow). If the user has restated a batch-only rule at execution time, collapse the per-task commits into one at the end.

---

## File Structure

**Server (create):**
- `server/src/memory.ts` — `MemoryStore` + memory types (`MemoryFact`, `MemoryPattern`, `MemoryDigest`, `MemoryOp`).
- `server/src/memory.test.ts` — store unit tests.

**Server (modify):**
- `server/src/prompts.ts` — `memoryBlock()` helper, `memoryPatternsPrompt()`, optional `memory` param on chat/agenda/insights/review/routine prompts.
- `server/src/pal.ts` — `remember`/`forget` tools, `toolCallsToMemoryOps()`, `ChatResult.memoryOps`, `memoryPatternsSchema`, `Pal.refreshPatterns()`, memory param on `chat`/`agenda`/`insights`/`review`/`generateRoutine`; remove fabricated `memory` from agenda.
- `server/src/schemas.ts` — `memoryRefreshBody`.
- `server/src/app.ts` — `guardTok` helper, `AppDeps.memory`, memory CRUD routes, digest wiring into chat/agenda/insights/review/routine.
- `server/src/server.ts` — construct `MemoryStore`, pass to `buildApp`.
- `server/src/prompts.test.ts`, `server/src/pal.test.ts`, `server/src/app.test.ts` — new tests.

**App (modify):**
- `lib/services/pal/pal_service.dart` — `PalFact`, `PalMemoryDigest` models; `memory()`/`refreshMemory()`/`deleteFact()`/`clearMemory()` on `PalService`; remove `PalMemory` + `PalAgenda.memory`.
- `lib/services/pal/http_pal_service.dart` — `_get`/`_delete` helpers; memory method impls; drop agenda `memory` decode.
- `lib/services/pal/mock_pal_service.dart` — in-memory facts + canned patterns; drop agenda `memory`.
- `lib/controllers/pal_memory_controller.dart` (create) — `palMemoryProvider`.
- `lib/screens/pal/pal_home_screen.dart` — repoint `_MemoryCard` to the digest; per-fact delete; wipe-all.
- Test files alongside each.

---

## Task 1: MemoryStore (SQLite)

**Files:**
- Create: `server/src/memory.ts`
- Test: `server/src/memory.test.ts`

**Interfaces:**
- Consumes: `better-sqlite3` (already a dependency), `node:crypto`.
- Produces:
  - `interface MemoryFact { id: string; text: string }`
  - `interface MemoryPattern { colorToken: string; title: string; detail: string }`
  - `interface MemoryDigest { facts: MemoryFact[]; patterns: MemoryPattern[] }`
  - `type MemoryOp = { op: 'remember'; text: string } | { op: 'forget'; id: string }`
  - `class MemoryStore` with: `addFact(token: string, text: string): MemoryFact`, `listFacts(token: string): MemoryFact[]`, `forgetFact(token: string, id: string): void`, `getPatterns(token: string): MemoryPattern[]`, `setPatterns(token: string, patterns: MemoryPattern[]): void`, `digest(token: string): MemoryDigest`, `applyOps(token: string, ops: MemoryOp[]): void`, `wipe(token: string): void`
  - `const MAX_FACTS = 20`, `const MAX_PATTERNS = 5`

- [ ] **Step 1: Write the failing test**

```ts
// server/src/memory.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { MemoryStore, MAX_FACTS } from './memory.js'

describe('MemoryStore', () => {
  let store: MemoryStore
  beforeEach(() => { store = new MemoryStore(':memory:') })

  it('adds and lists facts per token', () => {
    const f = store.addFact('tok-1', 'training for a marathon in October')
    expect(f.id).toBeTruthy()
    expect(store.listFacts('tok-1')).toEqual([f])
    expect(store.listFacts('tok-2')).toEqual([]) // isolated per token
  })

  it('forgets a fact by id', () => {
    const f = store.addFact('tok-1', 'vegetarian')
    store.forgetFact('tok-1', f.id)
    expect(store.listFacts('tok-1')).toEqual([])
  })

  it('caps facts at MAX_FACTS, dropping the oldest', () => {
    for (let i = 0; i < MAX_FACTS + 3; i++) store.addFact('tok-1', `fact ${i}`)
    const facts = store.listFacts('tok-1')
    expect(facts).toHaveLength(MAX_FACTS)
    expect(facts[0].text).toBe('fact 3')      // 0,1,2 dropped
    expect(facts[facts.length - 1].text).toBe(`fact ${MAX_FACTS + 2}`)
  })

  it('fully rewrites patterns (does not append)', () => {
    store.setPatterns('tok-1', [{ colorToken: 'money', title: 'a', detail: 'x' }])
    store.setPatterns('tok-1', [{ colorToken: 'move', title: 'b', detail: 'y' }])
    expect(store.getPatterns('tok-1')).toEqual([{ colorToken: 'move', title: 'b', detail: 'y' }])
  })

  it('assembles a digest and wipes all memory for a token', () => {
    store.addFact('tok-1', 'rent due on the 1st')
    store.setPatterns('tok-1', [{ colorToken: 'rituals', title: 'b', detail: 'y' }])
    const d = store.digest('tok-1')
    expect(d.facts).toHaveLength(1)
    expect(d.patterns).toHaveLength(1)
    store.wipe('tok-1')
    expect(store.digest('tok-1')).toEqual({ facts: [], patterns: [] })
  })

  it('applies remember/forget ops in order', () => {
    const facts = store.listFacts('tok-1')
    expect(facts).toEqual([])
    store.applyOps('tok-1', [{ op: 'remember', text: 'keeps a dog' }])
    const f = store.listFacts('tok-1')[0]
    store.applyOps('tok-1', [{ op: 'forget', id: f.id }, { op: 'remember', text: 'two dogs' }])
    expect(store.listFacts('tok-1').map((x) => x.text)).toEqual(['two dogs'])
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/memory.test.ts`
Expected: FAIL — cannot find module `./memory.js`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/memory.ts
import Database from 'better-sqlite3'
import { randomBytes } from 'node:crypto'

export const MAX_FACTS = 20
export const MAX_PATTERNS = 5

export interface MemoryFact { id: string; text: string }
export interface MemoryPattern { colorToken: string; title: string; detail: string }
export interface MemoryDigest { facts: MemoryFact[]; patterns: MemoryPattern[] }

// A mutation Pal asked for in chat, applied server-side (never a client action).
export type MemoryOp = { op: 'remember'; text: string } | { op: 'forget'; id: string }

// Per-device memory: user-authored facts + derived patterns, keyed by device token.
export class MemoryStore {
  private db: Database.Database

  constructor(path: string) {
    this.db = new Database(path)
    this.db.pragma('journal_mode = WAL')
    this.db.exec(`
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
    `)
  }

  addFact(token: string, text: string): MemoryFact {
    const id = `f-${randomBytes(8).toString('hex')}`
    this.db.prepare('INSERT INTO pal_facts (id, token, text, created_at) VALUES (?, ?, ?, ?)')
      .run(id, token, text, Date.now())
    // enforce the cap: drop the oldest beyond MAX_FACTS for this token.
    this.db.prepare(`
      DELETE FROM pal_facts WHERE token = ? AND id NOT IN (
        SELECT id FROM pal_facts WHERE token = ? ORDER BY created_at DESC, id DESC LIMIT ?
      )`).run(token, token, MAX_FACTS)
    return { id, text }
  }

  listFacts(token: string): MemoryFact[] {
    return this.db.prepare('SELECT id, text FROM pal_facts WHERE token = ? ORDER BY created_at ASC, id ASC')
      .all(token) as MemoryFact[]
  }

  forgetFact(token: string, id: string): void {
    this.db.prepare('DELETE FROM pal_facts WHERE token = ? AND id = ?').run(token, id)
  }

  getPatterns(token: string): MemoryPattern[] {
    const row = this.db.prepare('SELECT json FROM pal_patterns WHERE token = ?').get(token) as { json: string } | undefined
    return row ? (JSON.parse(row.json) as MemoryPattern[]) : []
  }

  setPatterns(token: string, patterns: MemoryPattern[]): void {
    const capped = patterns.slice(0, MAX_PATTERNS)
    this.db.prepare(`
      INSERT INTO pal_patterns (token, json, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(token) DO UPDATE SET json = excluded.json, updated_at = excluded.updated_at
    `).run(token, JSON.stringify(capped), Date.now())
  }

  digest(token: string): MemoryDigest {
    return { facts: this.listFacts(token), patterns: this.getPatterns(token) }
  }

  applyOps(token: string, ops: MemoryOp[]): void {
    for (const op of ops) {
      if (op.op === 'remember') this.addFact(token, op.text)
      else this.forgetFact(token, op.id)
    }
  }

  wipe(token: string): void {
    this.db.prepare('DELETE FROM pal_facts WHERE token = ?').run(token)
    this.db.prepare('DELETE FROM pal_patterns WHERE token = ?').run(token)
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/memory.test.ts`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add server/src/memory.ts server/src/memory.test.ts
git commit -m "feat(server): add per-device MemoryStore for Pal facts + patterns"
```

---

## Task 2: Memory digest types + `memoryBlock` prompt helper

**Files:**
- Modify: `server/src/prompts.ts`
- Test: `server/src/prompts.test.ts`

**Interfaces:**
- Consumes: `MemoryDigest`, `MemoryFact`, `MemoryPattern` from `./memory.js` (Task 1).
- Produces: `function memoryBlock(digest: MemoryDigest | undefined, opts?: { withIds?: boolean }): string` — returns `''` when the digest is absent or empty; otherwise a compact block. With `withIds`, each fact is prefixed `[id] text` so chat can address `forget`.

- [ ] **Step 1: Write the failing test**

```ts
// add to server/src/prompts.test.ts
import { memoryBlock } from './prompts.js'

describe('memoryBlock', () => {
  const digest = {
    facts: [{ id: 'f-1', text: 'marathon in October' }, { id: 'f-2', text: 'vegetarian' }],
    patterns: [{ colorToken: 'money', title: 'Fridays cost most', detail: 'dining out' }],
  }

  it('returns empty string for absent or empty memory', () => {
    expect(memoryBlock(undefined)).toBe('')
    expect(memoryBlock({ facts: [], patterns: [] })).toBe('')
  })

  it('renders facts and patterns without ids by default', () => {
    const out = memoryBlock(digest)
    expect(out).toContain('marathon in October')
    expect(out).toContain('Fridays cost most')
    expect(out).not.toContain('f-1') // no ids unless asked
  })

  it('includes fact ids when withIds is set (for forget)', () => {
    const out = memoryBlock(digest, { withIds: true })
    expect(out).toContain('[f-1]')
    expect(out).toContain('[f-2]')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/prompts.test.ts`
Expected: FAIL — `memoryBlock` is not exported.

- [ ] **Step 3: Write minimal implementation**

Add to the top of `server/src/prompts.ts` (after existing imports add the type import):

```ts
import type { MemoryDigest } from './memory.js'
```

Add the helper (place it above `chatSystemPrompt`):

```ts
// Renders Pal's stored memory as a compact block for prompt injection. Returns
// '' when there is nothing to inject so callers can prepend unconditionally.
// `withIds` exposes fact ids so the chat model can target them with `forget`.
export function memoryBlock(digest: MemoryDigest | undefined, opts?: { withIds?: boolean }): string {
  if (!digest || (digest.facts.length === 0 && digest.patterns.length === 0)) return ''
  const facts = digest.facts.map((f) => (opts?.withIds ? `[${f.id}] ${f.text}` : `- ${f.text}`))
  const patterns = digest.patterns.map((p) => `- ${p.title}: ${p.detail}`)
  const parts: string[] = ['What you already know about this user:']
  if (facts.length) parts.push('Facts they told you:', ...facts)
  if (patterns.length) parts.push('Patterns you have observed:', ...patterns)
  return parts.join('\n')
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/prompts.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/prompts.ts server/src/prompts.test.ts
git commit -m "feat(server): add memoryBlock prompt helper"
```

---

## Task 3: Inject memory into the consuming prompts

**Files:**
- Modify: `server/src/prompts.ts`
- Test: `server/src/prompts.test.ts`

**Interfaces:**
- Consumes: `memoryBlock` (Task 2), `MemoryDigest` (Task 1).
- Produces (new optional trailing param, default omitted so existing callers compile):
  - `chatSystemPrompt(c: ChatContext, memory?: MemoryDigest): string`
  - `agendaPrompt(c: ChatContext, memory?: MemoryDigest): string`
  - `insightsPrompt(c: InsightsContext, memory?: MemoryDigest): string`
  - `reviewPrompt(c: ReviewContext, memory?: MemoryDigest): string`
  - `routinePrompt(goal: string, exercises: RoutineExercise[], memory?: MemoryDigest): string`
  - `memoryPatternsPrompt(c: InsightsContext, digest: MemoryDigest): string`
- Unchanged (must NOT gain a memory param): `parsePrompt`, `postWorkoutPrompt`, `receiptsBatchPrompt`, `suggestPrompt`.

- [ ] **Step 1: Write the failing test**

```ts
// add to server/src/prompts.test.ts
import {
  chatSystemPrompt, agendaPrompt, insightsPrompt, reviewPrompt, routinePrompt,
  parsePrompt, postWorkoutPrompt, memoryPatternsPrompt,
} from './prompts.js'

const mem = {
  facts: [{ id: 'f-1', text: 'training for a marathon in October' }],
  patterns: [{ colorToken: 'move', title: 'Trains mornings', detail: 'most sessions before noon' }],
}
const chatCtx = {
  userName: 'Sam', todayEntries: [], dailyBudget: 80, moveGoalKcal: 500, ritualGoal: 5,
  spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 560,
  weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 3,
}
const insightsCtx = {
  range: 'week' as const, spent: 0, budget: 0, moveKcal: 0, moveTargetKcal: 0,
  ritualsKept: 0, ritualsTarget: 0, activeDays: 0, streakDays: 0, topCategory: 'Dining',
  topCategoryPct: 0, spendByWeekday: [], entries: [],
}

describe('memory injection', () => {
  it('chat includes facts with ids (so forget can target them)', () => {
    expect(chatSystemPrompt(chatCtx, mem)).toContain('[f-1]')
  })
  it('insights includes memory without ids', () => {
    const out = insightsPrompt(insightsCtx, mem)
    expect(out).toContain('training for a marathon')
    expect(out).not.toContain('[f-1]')
  })
  it('omits the block entirely when no memory is given', () => {
    expect(chatSystemPrompt(chatCtx)).not.toContain('already know about this user')
    expect(insightsPrompt(insightsCtx)).not.toContain('already know about this user')
  })
  it('never injects memory into parse or post-workout (no memory param)', () => {
    // these signatures take no memory arg; calling with one is a type error.
    expect(parsePrompt('add $5 coffee')).not.toContain('already know about this user')
  })
  it('memoryPatternsPrompt frames current patterns as prior knowledge to revise', () => {
    const out = memoryPatternsPrompt(insightsCtx, mem)
    expect(out).toContain('Trains mornings')           // current patterns shown
    expect(out.toLowerCase()).toContain('revise')      // framed as revision, not fresh
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/prompts.test.ts`
Expected: FAIL — `memoryPatternsPrompt` missing; prompts don't contain the block.

- [ ] **Step 3: Write minimal implementation**

In `server/src/prompts.ts`, thread the block into each consuming prompt. For `chatSystemPrompt`, add the param and prepend the block with ids:

```ts
export function chatSystemPrompt(c: ChatContext, memory?: MemoryDigest): string {
  const entries = c.todayEntries.length ? c.todayEntries.join('\n') : '(none yet)'
  const heading = c.userName ? `Today's entries for ${c.userName}:` : "Today's entries:"
  const mem = memoryBlock(memory, { withIds: true })
  const memSection = mem ? `${mem}\nWhen the user states a durable fact about themselves, call remember. When a remembered fact is wrong or obsolete, call forget with its id.\n\n` : ''
  return `You are Pal, a gentle, concise coach in an iOS app that tracks money, movement and daily rituals.

${memSection}${heading}
${entries}
${/* ...rest of the existing prompt unchanged... */ ''}`
}
```

Apply the existing body verbatim after `${memSection}` — do not alter the existing copy; only prepend `${memSection}` right after the opening line. For `agendaPrompt`, `insightsPrompt`, `reviewPrompt`, prepend `const mem = memoryBlock(memory)` (no ids) and insert `${mem ? mem + '\n\n' : ''}` immediately after each prompt's first line. For `routinePrompt`, insert the same after the goal line.

Then add the extraction prompt at the end of the file:

```ts
// Rewrites Pal's learned patterns from the latest data. The current facts +
// patterns are handed in as prior knowledge to REVISE, not to restate fresh, so
// the model doesn't echo the same observations every refresh.
export function memoryPatternsPrompt(c: InsightsContext, digest: MemoryDigest): string {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
  const byDay = weekdays.map((d, i) => `${d} $${c.spendByWeekday[i] ?? 0}`).join(', ')
  const entries = c.entries.length ? c.entries.join('\n') : '(none)'
  const prior = memoryBlock(digest) || '(nothing learned yet)'
  const shape = `{"patterns":[{"colorToken":"money"|"move"|"rituals","title":string,"detail":string}]}`
  return `You maintain a small set of durable patterns Pal has learned about this user.

${prior}

Revise that set against the latest data below. Keep what still holds, drop what no longer does, add at most a few genuinely new ones. Return at most 5 patterns total. Ground every pattern in the data; do not invent numbers you cannot derive.

Data: $${c.spent} of $${c.budget} budget, ${c.moveKcal} of ${c.moveTargetKcal} move kcal, ${c.ritualsKept}/${c.ritualsTarget} rituals kept, ${c.activeDays} active days, ${c.streakDays}-day move streak. Top category: ${c.topCategory} ${c.topCategoryPct}%.
Spend by weekday: ${byDay}.
Entries:
${entries}

Return strictly this JSON shape; "patterns" must be present (use [] when nothing holds): ${shape}
No prose, no code fence. Output only the JSON object.`
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/prompts.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/prompts.ts server/src/prompts.test.ts
git commit -m "feat(server): inject memory into chat/agenda/insights/recap/routine prompts"
```

---

## Task 4: Chat `remember`/`forget` tools + memory ops

**Files:**
- Modify: `server/src/pal.ts`
- Test: `server/src/pal.test.ts`

**Interfaces:**
- Consumes: `MemoryOp`, `MemoryDigest` from `./memory.js`; `memoryBlock` injection from Task 3.
- Produces:
  - `CHAT_TOOLS` gains `remember` and `forget` tool specs.
  - `function toolCallsToMemoryOps(calls: ToolCall[]): MemoryOp[]`
  - `interface ChatResult { reply: string; actions: PalAction[]; memoryOps: MemoryOp[] }`
  - `Pal.chat(history, message, ctx, memory?: MemoryDigest): Promise<ChatResult>` — passes `memory` into `chatSystemPrompt`, returns `memoryOps` extracted from the tool calls. Memory tools must NOT appear in `actions`.

- [ ] **Step 1: Write the failing test**

```ts
// add to server/src/pal.test.ts — assumes the existing fake CompletionClient pattern.
// Build a client whose completeWithTools returns the given tool calls.
function toolClient(toolCalls: Array<{ name: string; arguments: string }>): CompletionClient {
  return {
    complete: async () => '',
    completeWithTools: async () => ({ content: '', toolCalls }),
  }
}

describe('chat memory ops', () => {
  it('extracts remember/forget as memoryOps, not client actions', async () => {
    const pal = new Pal(toolClient([
      { name: 'remember', arguments: JSON.stringify({ fact: 'training for a marathon' }) },
      { name: 'forget', arguments: JSON.stringify({ id: 'f-9' }) },
      { name: 'log_expense', arguments: JSON.stringify({ amount: 5 }) },
    ]))
    const res = await pal.chat([], 'hi', chatCtxFixture)
    expect(res.memoryOps).toEqual([
      { op: 'remember', text: 'training for a marathon' },
      { op: 'forget', id: 'f-9' },
    ])
    // the expense is still a client action; memory tools are not.
    expect(res.actions).toHaveLength(1)
    expect(res.actions[0]).toMatchObject({ kind: 'log_expense' })
  })

  it('drops malformed memory tool calls', () => {
    const ops = toolCallsToMemoryOps([
      { name: 'remember', arguments: '{bad json' },
      { name: 'remember', arguments: JSON.stringify({ fact: '' }) }, // empty -> dropped
      { name: 'forget', arguments: JSON.stringify({}) },             // no id -> dropped
    ])
    expect(ops).toEqual([])
  })
})
```

Add `chatCtxFixture` to the test file if not already present (any valid `ChatContext`).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/pal.test.ts`
Expected: FAIL — `toolCallsToMemoryOps` missing; `memoryOps` undefined.

- [ ] **Step 3: Write minimal implementation**

In `server/src/pal.ts`:

```ts
import type { MemoryOp, MemoryDigest } from './memory.js'
```

Add tool specs to `CHAT_TOOLS` (append):

```ts
  tool('remember', 'Persist a durable fact the user states about themselves (e.g. a goal, a constraint, a preference, a recurring date). Use only for lasting facts, not one-off logs.',
    obj({ fact: strProp('the durable fact, one short sentence') }, ['fact'])),
  tool('forget', 'Drop a previously remembered fact that is now wrong or obsolete. Use the id shown in brackets next to the fact.',
    obj({ id: strProp('the id of the fact to forget, e.g. f-1a2b') }, ['id'])),
```

Add the extractor and extend `ChatResult` + `chat`:

```ts
// Memory tool calls are applied server-side; they never become client PalActions.
export function toolCallsToMemoryOps(calls: ToolCall[]): MemoryOp[] {
  const ops: MemoryOp[] = []
  for (const call of calls) {
    try {
      const args = JSON.parse(call.arguments)
      if (call.name === 'remember') {
        const fact = z.string().trim().min(1).parse(args.fact)
        ops.push({ op: 'remember', text: fact })
      } else if (call.name === 'forget') {
        const id = z.string().trim().min(1).parse(args.id)
        ops.push({ op: 'forget', id })
      }
    } catch {
      // malformed args or non-JSON — skip this op
    }
  }
  return ops
}
```

```ts
export interface ChatResult {
  reply: string
  actions: PalAction[]
  memoryOps: MemoryOp[]
}
```

```ts
  async chat(history: Array<{ role: 'user' | 'assistant'; text: string }>, message: string, ctx: ChatContext, memory?: MemoryDigest): Promise<ChatResult> {
    const recent = history.slice(-MAX_HISTORY_MESSAGES)
    const messages: ChatMessage[] = [
      { role: 'system', content: chatSystemPrompt(ctx, memory) },
      ...recent.map((m) => ({ role: m.role, content: m.text })),
      { role: 'user', content: message },
    ]
    const res = await this.client.completeWithTools(messages, CHAT_TOOLS)
    const actions = toolCallsToActions(res.toolCalls)
    const memoryOps = toolCallsToMemoryOps(res.toolCalls)
    const reply = res.content || synthReply(actions)
    return { reply, actions, memoryOps }
  }
```

Note: `toolCallsToActions` already drops unknown tool names, so `remember`/`forget` won't leak into `actions` — no change needed there.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/pal.test.ts`
Expected: PASS. (Also run the whole suite — `npm test` — to confirm `chatSystemPrompt`'s new optional param didn't break existing chat tests.)

- [ ] **Step 5: Commit**

```bash
git add server/src/pal.ts server/src/pal.test.ts
git commit -m "feat(server): add remember/forget chat tools and memoryOps"
```

---

## Task 5: Pattern refresh — schema + `Pal.refreshPatterns`

**Files:**
- Modify: `server/src/pal.ts`
- Test: `server/src/pal.test.ts`

**Interfaces:**
- Consumes: `memoryPatternsPrompt` (Task 3), `MemoryDigest`, `MemoryPattern`, `MAX_PATTERNS` from `./memory.js`.
- Produces:
  - `memoryPatternsSchema` (zod) validating `{ patterns: MemoryPattern[] }`.
  - `Pal.refreshPatterns(ctx: InsightsContext, digest: MemoryDigest): Promise<MemoryPattern[]>` — runs the extraction prompt at `temperature: 0`, validates, returns at most `MAX_PATTERNS`.

- [ ] **Step 1: Write the failing test**

```ts
// add to server/src/pal.test.ts
describe('refreshPatterns', () => {
  it('parses and caps patterns from the model', async () => {
    const many = Array.from({ length: 8 }, (_, i) => ({ colorToken: 'money', title: `t${i}`, detail: 'd' }))
    const client: CompletionClient = {
      complete: async () => JSON.stringify({ patterns: many }),
      completeWithTools: async () => ({ content: '', toolCalls: [] }),
    }
    const pal = new Pal(client)
    const out = await pal.refreshPatterns(insightsCtxFixture, { facts: [], patterns: [] })
    expect(out).toHaveLength(5) // MAX_PATTERNS
    expect(out[0]).toEqual({ colorToken: 'money', title: 't0', detail: 'd' })
  })

  it('coerces an off-list colorToken', async () => {
    const client: CompletionClient = {
      complete: async () => JSON.stringify({ patterns: [{ colorToken: 'bogus', title: 't', detail: 'd' }] }),
      completeWithTools: async () => ({ content: '', toolCalls: [] }),
    }
    const out = await new Pal(client).refreshPatterns(insightsCtxFixture, { facts: [], patterns: [] })
    expect(['money', 'move', 'rituals']).toContain(out[0].colorToken)
  })
})
```

Add `insightsCtxFixture` (any valid `InsightsContext`) to the test file.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/pal.test.ts`
Expected: FAIL — `refreshPatterns` missing.

- [ ] **Step 3: Write minimal implementation**

In `server/src/pal.ts` add the schema (near `insightsSchema`):

```ts
export const memoryPatternsSchema = z.object({
  patterns: z.array(z.object({
    colorToken: z.enum(['money', 'move', 'rituals']).catch('money'),
    title: z.string(),
    detail: z.string(),
  })).default([]),
})
```

Add the import for `memoryPatternsPrompt` to the existing prompts import, and `MAX_PATTERNS` to the memory import. Add the method to `Pal`:

```ts
  async refreshPatterns(ctx: InsightsContext, digest: MemoryDigest): Promise<MemoryPattern[]> {
    const raw = await this.client.complete(
      [{ role: 'user', content: memoryPatternsPrompt(ctx, digest) }],
      { json: true, maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 },
    )
    return memoryPatternsSchema.parse(extractJson(raw)).patterns.slice(0, MAX_PATTERNS)
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/pal.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/pal.ts server/src/pal.test.ts
git commit -m "feat(server): add refreshPatterns extraction pass"
```

---

## Task 6: Remove fabricated agenda memory; agenda reads injected digest

**Files:**
- Modify: `server/src/pal.ts`
- Test: `server/src/pal.test.ts`

**Interfaces:**
- Consumes: `MemoryDigest` (Task 1), `agendaPrompt(c, memory?)` (Task 3).
- Produces:
  - `agendaModelSchema` loses its `memory` field.
  - `AgendaResult` loses its `memory` field.
  - `Pal.agenda(ctx: ChatContext, memory?: MemoryDigest): Promise<AgendaResult>` — injects memory into the prompt; no longer returns a `memory` array.

- [ ] **Step 1: Write the failing test**

```ts
// add to server/src/pal.test.ts
describe('agenda no longer fabricates memory', () => {
  it('omits a memory field from the result', async () => {
    const client: CompletionClient = {
      complete: async () => JSON.stringify({ proposals: [], autopilot: [] }),
      completeWithTools: async () => ({ content: '', toolCalls: [] }),
    }
    const res = await new Pal(client).agenda(chatCtxFixture, { facts: [], patterns: [] })
    expect('memory' in res).toBe(false)
    expect(res.proposals).toEqual([])
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/pal.test.ts`
Expected: FAIL — `memory` still present on `AgendaResult`.

- [ ] **Step 3: Write minimal implementation**

In `server/src/pal.ts`:
- Remove the `memory: z.array(...)` line from `agendaModelSchema`.
- Remove `memory: Array<{ text: string; meta: string }>` from the `AgendaResult` interface.
- In `Pal.agenda`, add the `memory?: MemoryDigest` param, pass it into `agendaPrompt(ctx, memory)`, and delete the `memory: parsed.memory` line from the returned object.

```ts
  async agenda(ctx: ChatContext, memory?: MemoryDigest): Promise<AgendaResult> {
    const raw = await this.client.complete(
      [{ role: 'user', content: agendaPrompt(ctx, memory) }],
      { json: true, maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 },
    )
    const parsed = agendaModelSchema.parse(extractJson(raw))
    return {
      proposals: parsed.proposals.map((p, i) => { /* unchanged */ }),
      autopilot: parsed.autopilot.map((a, i) => ({ /* unchanged */ })),
      streakDays: ctx.moveStreakDays,
    }
  }
```

Also update `agendaPrompt` in `prompts.ts` (Task 3 already added the `memory` param and injection): remove the `"memory"` clause from the instruction text and the `memory` key from the `shape` string, since the model no longer produces it.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/pal.test.ts` then `npm test`.
Expected: PASS. Fix any existing agenda test that asserted on `memory`.

- [ ] **Step 5: Commit**

```bash
git add server/src/pal.ts server/src/prompts.ts server/src/pal.test.ts
git commit -m "refactor(server): stop fabricating agenda memory; inject stored digest"
```

---

## Task 7: Token-aware guard + wire MemoryStore into the app

**Files:**
- Modify: `server/src/app.ts`, `server/src/schemas.ts`, `server/src/server.ts`
- Test: `server/src/app.test.ts`

**Interfaces:**
- Consumes: `MemoryStore` (Task 1), `Pal.refreshPatterns` (Task 5).
- Produces:
  - `AppDeps.memory: MemoryStore`.
  - `guardTok<T>(schema, handler: (body: T, token: string) => Promise<unknown>)` — like `guard`, but extracts the validated bearer token (via `extractBearer`) and passes it to the handler.
  - `memoryRefreshBody = z.object({ context: insightsContext })` in `schemas.ts`.

- [ ] **Step 1: Write the failing test**

```ts
// add to server/src/app.test.ts — assumes existing buildApp test harness with a fake Pal + stores.
// The harness must now also pass `memory: new MemoryStore(':memory:')` into buildApp.
describe('memory endpoints', () => {
  it('GET /v1/memory returns the stored digest for the token', async () => {
    const { app, memory, token } = buildTestApp()
    memory.addFact(token, 'rent due on the 1st')
    const res = await app.inject({ method: 'GET', url: '/v1/memory', headers: { authorization: `Bearer ${token}` } })
    expect(res.statusCode).toBe(200)
    expect(res.json().facts[0].text).toBe('rent due on the 1st')
  })

  it('DELETE /v1/memory/facts/:id forgets one fact', async () => {
    const { app, memory, token } = buildTestApp()
    const f = memory.addFact(token, 'vegetarian')
    const res = await app.inject({ method: 'DELETE', url: `/v1/memory/facts/${f.id}`, headers: { authorization: `Bearer ${token}` } })
    expect(res.statusCode).toBe(200)
    expect(memory.listFacts(token)).toEqual([])
  })

  it('DELETE /v1/memory wipes all memory', async () => {
    const { app, memory, token } = buildTestApp()
    memory.addFact(token, 'a'); memory.setPatterns(token, [{ colorToken: 'money', title: 't', detail: 'd' }])
    await app.inject({ method: 'DELETE', url: '/v1/memory', headers: { authorization: `Bearer ${token}` } })
    expect(memory.digest(token)).toEqual({ facts: [], patterns: [] })
  })

  it('POST /v1/memory/refresh rewrites patterns and returns the digest', async () => {
    const { app, memory, token } = buildTestApp() // fake Pal.refreshPatterns returns one pattern
    const res = await app.inject({
      method: 'POST', url: '/v1/memory/refresh',
      headers: { authorization: `Bearer ${token}` },
      payload: { context: insightsCtxFixture },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().patterns).toHaveLength(1)
    expect(memory.getPatterns(token)).toHaveLength(1)
  })
})
```

Update `buildTestApp` (or the existing helper) to construct and expose a `MemoryStore` and a valid `token` (issue one via the `TokenStore`), and make the fake `Pal` implement `refreshPatterns` returning a single pattern and `chat` returning `{ reply, actions: [], memoryOps: [] }`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/app.test.ts`
Expected: FAIL — routes 404 / `memory` not in deps.

- [ ] **Step 3: Write minimal implementation**

`schemas.ts`:

```ts
export const memoryRefreshBody = z.object({ context: insightsContext })
```

`app.ts` — extend deps and add the token-aware guard near the existing `guard`:

```ts
import { memoryRefreshBody } from './schemas.js'   // add to the existing import list
import type { MemoryStore } from './memory.js'
```

```ts
export interface AppDeps {
  // ...existing fields...
  memory: MemoryStore
}
```

```ts
  // like `guard`, but hands the validated bearer token to the handler (memory is
  // partitioned by token). preHandler has already proven the token is valid.
  const guardTok = <T>(schema: z.ZodType<T>, handler: (body: T, token: string) => Promise<unknown>) =>
    async (req: FastifyRequest, reply: FastifyReply) => {
      const parsed = schema.safeParse(req.body)
      if (!parsed.success) return reply.code(400).send({ error: { code: 'bad_request', message: 'invalid body' } })
      const token = extractBearer(req.headers.authorization)!
      try {
        return await handler(parsed.data, token)
      } catch (err) {
        const status = err instanceof OpenRouterError ? 502 : 500
        req.log?.error?.(err)
        return reply.code(status).send({ error: { code: 'upstream', message: 'pal request failed' } })
      }
    }
```

Add routes (inside the child plugin, alongside the other `/v1/*` routes):

```ts
  app.get('/v1/memory', async (req, reply) => {
    const token = extractBearer(req.headers.authorization)!
    return deps.memory.digest(token)
  })

  app.post('/v1/memory/refresh', guardTok(memoryRefreshBody, async (b, token) => {
    const patterns = await deps.pal.refreshPatterns(b.context, deps.memory.digest(token))
    deps.memory.setPatterns(token, patterns)
    return deps.memory.digest(token)
  }))

  app.delete('/v1/memory/facts/:id', async (req, reply) => {
    const token = extractBearer(req.headers.authorization)!
    deps.memory.forgetFact(token, (req.params as { id: string }).id)
    return deps.memory.digest(token)
  })

  app.delete('/v1/memory', async (req, reply) => {
    const token = extractBearer(req.headers.authorization)!
    deps.memory.wipe(token)
    return { ok: true }
  })
```

`server.ts` — construct and pass the store:

```ts
import { MemoryStore } from './memory.js'
// ...
const memory = new MemoryStore(config.sqlitePath)
// add `memory` to the buildApp({ ... }) call
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/app.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/app.ts server/src/schemas.ts server/src/server.ts server/src/app.test.ts
git commit -m "feat(server): add memory CRUD + refresh endpoints"
```

---

## Task 8: Wire the digest into chat/agenda/insights/review/routine handlers

**Files:**
- Modify: `server/src/app.ts`
- Test: `server/src/app.test.ts`

**Interfaces:**
- Consumes: `guardTok` (Task 7), `Pal.chat(...memory)` (Task 4), `Pal.agenda(...memory)` (Task 6), `MemoryStore.digest`/`applyOps`.
- Produces: handlers that load the digest, pass it to `Pal`, and (for chat) apply returned `memoryOps`. The `/v1/chat` response shape is unchanged (`{ reply, actions }`).

- [ ] **Step 1: Write the failing test**

```ts
// add to server/src/app.test.ts
it('chat applies memoryOps to the store and never returns them as actions', async () => {
  // fake Pal.chat returns memoryOps: [{op:'remember', text:'likes oat milk'}], actions: []
  const { app, memory, token } = buildTestApp()
  const res = await app.inject({
    method: 'POST', url: '/v1/chat',
    headers: { authorization: `Bearer ${token}` },
    payload: { history: [], message: 'i like oat milk', context: chatCtxFixture },
  })
  expect(res.statusCode).toBe(200)
  expect(res.json()).not.toHaveProperty('memoryOps')
  expect(memory.listFacts(token).map((f) => f.text)).toContain('likes oat milk')
})
```

Make the fake `Pal.chat` in the harness return `{ reply: 'ok', actions: [], memoryOps: [{ op: 'remember', text: 'likes oat milk' }] }`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/app.test.ts`
Expected: FAIL — ops not applied; or `memoryOps` leaks into the response.

- [ ] **Step 3: Write minimal implementation**

Replace the affected route registrations in `app.ts`:

```ts
  app.post('/v1/chat', guardTok(chatBody, async (b, token) => {
    const res = await deps.pal.chat(b.history, b.message, b.context, deps.memory.digest(token))
    deps.memory.applyOps(token, res.memoryOps) // server-side; not part of the wire response
    return { reply: res.reply, actions: res.actions }
  }))
  app.post('/v1/review', guardTok(reviewBody, async (b, token) => ({ text: await deps.pal.review(b.context, deps.memory.digest(token)) })))
  app.post('/v1/insights', guardTok(insightsBody, async (b, token) => deps.pal.insights(b.context, deps.memory.digest(token))))
  app.post('/v1/routine', guardTok(routineBody, async (b, token) => deps.pal.generateRoutine(b.goal, b.exercises, deps.memory.digest(token))))
  app.post('/v1/agenda', guardTok(agendaBody, async (b, token) => deps.pal.agenda(b.context, deps.memory.digest(token))))
```

This requires `Pal.review`, `Pal.insights`, `Pal.generateRoutine` to accept the optional `memory` param. Add it in `pal.ts` if not already present:
- `review(ctx, memory?)` → `reviewPrompt(ctx, memory)`
- `insights(ctx, memory?)` → `insightsPrompt(ctx, memory)`
- `generateRoutine(goal, exercises, memory?)` → `routinePrompt(goal, exercises, memory)` (thread through both `draw()` calls)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/app.test.ts` then `npm test`.
Expected: PASS (whole server suite green).

- [ ] **Step 5: Commit**

```bash
git add server/src/app.ts server/src/pal.ts server/src/app.test.ts
git commit -m "feat(server): inject memory digest into chat/agenda/insights/review/routine"
```

---

## Task 9: Dart memory models + PalService seam

**Files:**
- Modify: `lib/services/pal/pal_service.dart`
- Test: `test/services/pal_service_models_test.dart` (create, or add to an existing models test)

**Interfaces:**
- Produces:
  - `class PalFact { final String id; final String text; }` (with `==`/`hashCode`).
  - `class PalMemoryDigest { final List<PalFact> facts; final List<InsightPattern> patterns; const PalMemoryDigest({this.facts = const [], this.patterns = const []}); bool get isEmpty => facts.isEmpty && patterns.isEmpty; }`
  - `PalService` gains: `Future<PalMemoryDigest> memory()`, `Future<PalMemoryDigest> refreshMemory()`, `Future<PalMemoryDigest> deleteFact(String id)`, `Future<PalMemoryDigest> clearMemory()`.
  - Removes: `class PalMemory` and `PalAgenda.memory` (and `memory` from `PalAgenda.isEmpty`).

- [ ] **Step 1: Write the failing test**

```dart
// test/services/pal_service_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  test('PalMemoryDigest is empty when both lists are empty', () {
    expect(const PalMemoryDigest().isEmpty, isTrue);
    expect(
      const PalMemoryDigest(facts: [PalFact(id: 'f-1', text: 'x')]).isEmpty,
      isFalse,
    );
  });

  test('PalFact equality is by id and text', () {
    expect(const PalFact(id: 'f-1', text: 'x'), const PalFact(id: 'f-1', text: 'x'));
    expect(const PalFact(id: 'f-1', text: 'x') == const PalFact(id: 'f-2', text: 'x'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pal_service_models_test.dart`
Expected: FAIL — `PalFact` / `PalMemoryDigest` undefined.

- [ ] **Step 3: Write minimal implementation**

In `lib/services/pal/pal_service.dart`:
- Delete the `class PalMemory { ... }` block.
- Remove `memory` from `PalAgenda` (field, constructor param, and the `isEmpty` getter — becomes `proposals.isEmpty && autopilot.isEmpty`).
- Add the new models:

```dart
/// One durable fact the user told Pal (the `/v1/memory` facts list). Deletable
/// per item in "What Pal remembers".
class PalFact {
  const PalFact({required this.id, required this.text});
  final String id;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PalFact && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);
}

/// Pal's persistent memory: user-authored [facts] + derived [patterns]
/// (the `/v1/memory` payload). Patterns reuse [InsightPattern].
class PalMemoryDigest {
  const PalMemoryDigest({this.facts = const [], this.patterns = const []});
  final List<PalFact> facts;
  final List<InsightPattern> patterns;
  bool get isEmpty => facts.isEmpty && patterns.isEmpty;
}
```

- Add to the `PalService` interface:

```dart
  /// `/v1/memory`: Pal's current persistent memory for this device.
  Future<PalMemoryDigest> memory();

  /// `POST /v1/memory/refresh`: re-derive patterns from recent data; returns the
  /// updated digest.
  Future<PalMemoryDigest> refreshMemory();

  /// `DELETE /v1/memory/facts/:id`: forget one fact; returns the updated digest.
  Future<PalMemoryDigest> deleteFact(String id);

  /// `DELETE /v1/memory`: wipe all memory; returns the (empty) digest.
  Future<PalMemoryDigest> clearMemory();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/pal_service_models_test.dart`
Expected: PASS. (Compilation will now fail in `http_pal_service.dart`, `mock_pal_service.dart`, and `pal_home_screen.dart` — fixed in Tasks 10-12. Do not run the full suite yet.)

- [ ] **Step 5: Commit**

```bash
git add lib/services/pal/pal_service.dart test/services/pal_service_models_test.dart
git commit -m "feat(app): add Pal memory models, remove fabricated agenda memory"
```

---

## Task 10: HttpPalService memory methods

**Files:**
- Modify: `lib/services/pal/http_pal_service.dart`
- Test: `test/services/http_pal_service_memory_test.dart` (create)

**Interfaces:**
- Consumes: `PalMemoryDigest`, `PalFact`, `InsightPattern` (Task 9); `PalContextSource.insights` for the refresh payload.
- Produces: `_get(path)` and `_delete(path)` helpers (mirroring `_post`'s token/401/retry handling); impls of `memory()`, `refreshMemory()`, `deleteFact()`, `clearMemory()`; a `_digestFromWire(Map)` decoder. Removes the `memory` mapList from `agenda()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/http_pal_service_memory_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

HttpPalService _service(MockClient client) => HttpPalService(
      baseUrl: 'https://x.test',
      httpClient: client,
      tokens: TokenProvider(token: () async => 't', clear: () async {}),
      context: PalContextSource(
        chat: () async => {},
        review: (_, __) async => {},
        insights: (_) async => {'range': 'month', 'entries': <String>[], 'spendByWeekday': <num>[]},
        suggest: (_, __) async => {},
        postWorkout: (_) async => {},
        resolveRoutineTitle: (_) async => null,
      ),
    );

void main() {
  test('memory() decodes facts and patterns', () async {
    final client = MockClient((req) async {
      expect(req.method, 'GET');
      expect(req.url.path, '/v1/memory');
      return http.Response(
        jsonEncode({
          'facts': [{'id': 'f-1', 'text': 'marathon in October'}],
          'patterns': [{'colorToken': 'move', 'title': 'Mornings', 'detail': 'before noon'}],
        }),
        200,
      );
    });
    final d = await _service(client).memory();
    expect(d.facts.single, const PalFact(id: 'f-1', text: 'marathon in October'));
    expect(d.patterns.single.title, 'Mornings');
  });

  test('deleteFact() DELETEs the fact path and returns the updated digest', () async {
    final client = MockClient((req) async {
      expect(req.method, 'DELETE');
      expect(req.url.path, '/v1/memory/facts/f-1');
      return http.Response(jsonEncode({'facts': [], 'patterns': []}), 200);
    });
    final d = await _service(client).deleteFact('f-1');
    expect(d.isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/http_pal_service_memory_test.dart`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Write minimal implementation**

In `lib/services/pal/http_pal_service.dart`, add request helpers next to `_post`:

```dart
  Future<Map<String, dynamic>> _send(String method, String path, {Map<String, Object?>? body}) async {
    Future<http.Response> go() async {
      final token = await tokens.token();
      final uri = _base.replace(path: path);
      final headers = {'content-type': 'application/json', 'authorization': 'Bearer $token'};
      final encoded = body == null ? null : jsonEncode(body);
      return switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'DELETE' => _http.delete(uri, headers: headers),
        _ => _http.post(uri, headers: headers, body: encoded),
      }
          .timeout(timeout);
    }

    http.Response res;
    try {
      res = await go();
      if (res.statusCode == 401) { await tokens.clear(); res = await go(); }
    } on TimeoutException {
      throw const PalException('request timed out');
    } catch (e) {
      throw PalException('network error: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PalException('proxy returned ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
```

(Optionally refactor `_post` to delegate to `_send('POST', ...)`; only if it keeps existing `_post` tests green.) Then the memory methods:

```dart
  PalMemoryDigest _digestFromWire(Map<String, dynamic> json) => PalMemoryDigest(
        facts: ((json['facts'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((f) => PalFact(id: f['id'] as String? ?? '', text: f['text'] as String? ?? ''))
            .toList(),
        patterns: ((json['patterns'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((p) => InsightPattern(
                  colorToken: _colorToken(p['colorToken']),
                  title: p['title'] as String? ?? '',
                  detail: p['detail'] as String? ?? '',
                ))
            .toList(),
      );

  @override
  Future<PalMemoryDigest> memory() async => _digestFromWire(await _send('GET', '/v1/memory'));

  @override
  Future<PalMemoryDigest> refreshMemory() async => _digestFromWire(
      await _send('POST', '/v1/memory/refresh', body: {'context': await context.insights(InsightRange.month)}));

  @override
  Future<PalMemoryDigest> deleteFact(String id) async =>
      _digestFromWire(await _send('DELETE', '/v1/memory/facts/$id'));

  @override
  Future<PalMemoryDigest> clearMemory() async {
    await _send('DELETE', '/v1/memory');
    return const PalMemoryDigest();
  }
```

Remove the `memory: mapList('memory', ...)` block from `agenda()` (it no longer exists on `PalAgenda`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/http_pal_service_memory_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/pal/http_pal_service.dart test/services/http_pal_service_memory_test.dart
git commit -m "feat(app): HttpPalService memory get/refresh/delete/clear"
```

---

## Task 11: MockPalService memory

**Files:**
- Modify: `lib/services/pal/mock_pal_service.dart`
- Test: `test/services/mock_pal_service_test.dart` (existing — add cases)

**Interfaces:**
- Consumes: `PalMemoryDigest`, `PalFact`, `InsightPattern` (Task 9).
- Produces: in-memory facts (`final List<PalFact> _facts = []`) and canned patterns; impls of `memory()`/`refreshMemory()`/`deleteFact()`/`clearMemory()`. Removes the `memory:` argument from the canned `PalAgenda` in `agenda()`.

- [ ] **Step 1: Write the failing test**

```dart
// add to test/services/mock_pal_service_test.dart
test('mock memory: refresh seeds patterns, delete/clear mutate facts', () async {
  final pal = MockPalService(latency: Duration.zero);
  final seeded = await pal.refreshMemory();
  expect(seeded.patterns, isNotEmpty);

  final afterClear = await pal.clearMemory();
  expect(afterClear.isEmpty, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/mock_pal_service_test.dart`
Expected: FAIL — methods undefined / `memory:` arg removed breaks compile.

- [ ] **Step 3: Write minimal implementation**

In `mock_pal_service.dart`:
- Remove the `memory: [ PalMemory(...) ... ]` argument from the `PalAgenda(...)` returned by `agenda()`.
- Add fields + methods:

```dart
  final List<PalFact> _facts = [];
  int _factSeq = 0;

  static const _cannedPatterns = <InsightPattern>[
    InsightPattern(colorToken: 'money', title: 'Fridays cost the most', detail: 'Dining out drives the spike.'),
    InsightPattern(colorToken: 'move', title: 'Trains in the morning', detail: 'Most sessions land before noon.'),
    InsightPattern(colorToken: 'rituals', title: 'Evenings slip when working late', detail: 'Wind-down skipped past 8pm.'),
  ];
  List<InsightPattern> _patterns = const [];

  @override
  Future<PalMemoryDigest> memory() async {
    await Future<void>.delayed(latency);
    return PalMemoryDigest(facts: List.of(_facts), patterns: List.of(_patterns));
  }

  @override
  Future<PalMemoryDigest> refreshMemory() async {
    await Future<void>.delayed(latency);
    _patterns = _cannedPatterns;
    return PalMemoryDigest(facts: List.of(_facts), patterns: List.of(_patterns));
  }

  @override
  Future<PalMemoryDigest> deleteFact(String id) async {
    await Future<void>.delayed(latency);
    _facts.removeWhere((f) => f.id == id);
    return PalMemoryDigest(facts: List.of(_facts), patterns: List.of(_patterns));
  }

  @override
  Future<PalMemoryDigest> clearMemory() async {
    await Future<void>.delayed(latency);
    _facts.clear();
    _patterns = const [];
    return const PalMemoryDigest();
  }
```

(The mock has no chat-driven `remember`, which is acceptable for the preview — `_factSeq` is reserved for any future seeded fact; remove it if unused to satisfy the linter.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/mock_pal_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/pal/mock_pal_service.dart test/services/mock_pal_service_test.dart
git commit -m "feat(app): MockPalService memory support"
```

---

## Task 12: palMemoryProvider + Pal Home memory section

**Files:**
- Create: `lib/controllers/pal_memory_controller.dart`
- Modify: `lib/screens/pal/pal_home_screen.dart`
- Test: `test/screens/pal_home_memory_test.dart` (create)

**Interfaces:**
- Consumes: `palServiceProvider` (existing), `PalMemoryDigest`, `PalFact`, `InsightPattern`.
- Produces: `palMemoryProvider` (a `@riverpod Future<PalMemoryDigest>` that degrades to `const PalMemoryDigest()` on error, mirroring `palAgenda`). `PalHomeScreen` renders facts (deletable) + patterns (read-only) from the digest; the "Manage" row triggers wipe-all.

- [ ] **Step 1: Write the failing test**

```dart
// lib/controllers/pal_memory_controller.dart skeleton first so the provider exists,
// then test the screen renders a fact and a pattern from an overridden provider.
// test/screens/pal_home_memory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/pal_memory_controller.dart';
import 'package:opal/services/pal/pal_service.dart';
// ...pump PalHomeScreen wrapped in ProviderScope with:
//   palMemoryProvider.overrideWith((ref) async => const PalMemoryDigest(
//     facts: [PalFact(id: 'f-1', text: 'marathon in October')],
//     patterns: [InsightPattern(colorToken: 'move', title: 'Mornings', detail: 'before noon')]))
// expect(find.text('marathon in October'), findsOneWidget);
// expect(find.text('Mornings'), findsOneWidget);
```

Write the concrete widget test against the project's existing screen-test harness (see other tests under `test/screens/` for the `ProviderScope` + `MaterialApp`/router setup pattern).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/pal_home_memory_test.dart`
Expected: FAIL — `palMemoryProvider` undefined; screen still reads `agenda.memory`.

- [ ] **Step 3: Write minimal implementation**

Create the controller:

```dart
// lib/controllers/pal_memory_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'pal_memory_controller.g.dart';

/// Pal's persistent memory for the "What Pal remembers" section. One-shot like
/// [palAgenda]; an unreachable backend degrades to an empty digest rather than
/// an error.
@riverpod
Future<PalMemoryDigest> palMemory(Ref ref) async {
  final pal = ref.watch(palServiceProvider);
  try {
    return await pal.memory();
  } catch (_) {
    return const PalMemoryDigest();
  }
}
```

Run codegen: `dart run build_runner build --delete-conflicting-outputs`.

In `pal_home_screen.dart`:
- Replace the `if (agenda.memory.isNotEmpty)` section. Watch `palMemoryProvider`:
  `final memory = ref.watch(palMemoryProvider).asData?.value ?? const PalMemoryDigest();`
  and gate on `if (!memory.isEmpty)`.
- Update `_MemoryCard` to take `PalMemoryDigest` plus `onDeleteFact(String id)` and `onWipe()` callbacks. Render each `PalFact` as a row with a delete affordance (`xmark` AppIcon button calling `onDeleteFact(fact.id)`), and each `InsightPattern` as a read-only row (text = `title`, meta = `detail`). Make the existing "Manage what Pal remembers" row call `onWipe()`.
- Wire callbacks to the service and refresh the provider:

```dart
  Future<void> _deleteFact(String id) async {
    await ref.read(palServiceProvider).deleteFact(id);
    ref.invalidate(palMemoryProvider);
  }

  Future<void> _wipeMemory() async {
    await ref.read(palServiceProvider).clearMemory();
    ref.invalidate(palMemoryProvider);
  }
```

Keep the existing card styling; only the data source and the two callbacks change. Do not restyle unrelated sections.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/pal_home_memory_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/controllers/pal_memory_controller.dart lib/controllers/pal_memory_controller.g.dart lib/screens/pal/pal_home_screen.dart test/screens/pal_home_memory_test.dart
git commit -m "feat(app): Pal Home memory section backed by /v1/memory with delete + wipe"
```

---

## Task 13: Trigger pattern refresh from Recap

**Files:**
- Modify: `lib/controllers/recap_controller.dart`
- Test: `test/controllers/recap_refresh_memory_test.dart` (create)

**Interfaces:**
- Consumes: `palServiceProvider.refreshMemory()` (Task 9/10), `palMemoryProvider` (Task 12).
- Produces: a fire-and-forget call to `refreshMemory()` when the Recap is generated, followed by `ref.invalidate(palMemoryProvider)`. Failure is swallowed (memory never blocks Recap).

- [ ] **Step 1: Write the failing test**

Inspect `lib/controllers/recap_controller.dart` for its existing generation entry point. Write a test that overrides `palServiceProvider` with a fake recording `refreshMemory()` calls, drives the Recap generation, and asserts `refreshMemory()` was invoked exactly once and that a thrown `refreshMemory()` does not propagate out of Recap generation.

```dart
// shape (adapt to the real recap controller API):
test('generating the recap triggers a single memory refresh, errors swallowed', () async {
  final pal = _RecordingPal(); // refreshMemory increments a counter; can be set to throw
  final container = ProviderContainer(overrides: [palServiceProvider.overrideWithValue(pal)]);
  addTearDown(container.dispose);
  await container.read(/* recap generation future/provider */);
  expect(pal.refreshCount, 1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/recap_refresh_memory_test.dart`
Expected: FAIL — refresh not triggered.

- [ ] **Step 3: Write minimal implementation**

In `recap_controller.dart`, at the point the recap is generated (after the review/insights fetch completes), add:

```dart
  // refresh Pal's learned patterns from the data this recap already loaded;
  // fire-and-forget so a model hiccup never blocks the recap.
  unawaited(() async {
    try {
      await ref.read(palServiceProvider).refreshMemory();
      ref.invalidate(palMemoryProvider);
    } catch (_) {
      // memory refresh is best-effort
    }
  }());
```

Add `import 'dart:async';` (for `unawaited`) and the `pal_memory_controller.dart` import if not present. If the recap controller cannot hold a `ref` at that point, expose a small method the screen calls on open instead — match the controller's existing structure.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/recap_refresh_memory_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/controllers/recap_controller.dart test/controllers/recap_refresh_memory_test.dart
git commit -m "feat(app): refresh Pal patterns when the recap is generated"
```

---

## Task 14: Full-suite green + cleanup

**Files:** none new — verification.

- [ ] **Step 1: Run the server suite**

Run: `cd server && npm test`
Expected: all green. Fix any agenda/chat test still asserting the removed `memory` field or the old `chat` return shape.

- [ ] **Step 2: Run the app suite + analyzer**

Run: `flutter analyze && flutter test`
Expected: no analyzer errors (watch for unused `PalMemory` references, the removed `agenda.memory`, unused `_factSeq`); all tests pass.

- [ ] **Step 3: Confirm goldens unaffected**

The Pal Home memory card changed shape. If a golden covers Pal Home, re-baseline only that golden intentionally (`flutter test --update-goldens <path>`) and eyeball the diff. Do not blanket-update goldens.

- [ ] **Step 4: Commit any fixups**

```bash
git add -A
git commit -m "test(pal-memory): fix up suites after memory integration"
```

---

## Self-Review

**Spec coverage:**
- Data model (`pal_facts`, `pal_patterns`, caps, digest) → Task 1. ✓
- Facts via `remember`/`forget` tools, applied server-side, not client actions → Tasks 4, 8. ✓
- Patterns via dedicated `/v1/memory/refresh`, full rewrite, prior-context framing → Tasks 5, 7; prompt framing Task 3. ✓
- Digest injection into Chat/Agenda/Insights/Recap/Generate-routine; excluded from Parse/Post-workout/Receipts → Tasks 3, 8 (and Task 3 test asserts exclusion). ✓
- Agenda fabricated `memory` removed → Task 6 (server), Tasks 9-12 (client). ✓
- API: `GET /v1/memory`, `POST /v1/memory/refresh`, `DELETE /v1/memory/facts/:id`, `DELETE /v1/memory` → Task 7. ✓
- Pal Home memory section repointed, per-fact delete + wipe-all → Task 12. ✓
- Refresh cadence on Recap → Task 13. ✓
- Error handling: best-effort writes (Task 8 applies ops after a successful chat; refresh 502 via `guardTok`); digest read on chat degrades because the store returns an empty digest for an unknown token (never throws) → Tasks 7, 8. ✓ Token-revoke teardown is satisfied by `MemoryStore` keying on token (a revoked token simply never matches again); explicit cascade on revoke is **out of scope** per the spec's "dropped on token revoke" (rows orphan harmlessly; add a cascade later if retention requires hard deletion).
- Mock + tests → Tasks 9-13. ✓

**Placeholder scan:** No "TBD"/"handle errors appropriately" left; each code step shows code. Two tasks (12, 13) reference the project's existing screen/controller test harness rather than reproducing it — acceptable because the harness is project-specific and must be matched, not invented; the assertions to write are spelled out.

**Type consistency:** `MemoryDigest`/`MemoryFact`/`MemoryPattern`/`MemoryOp` used identically across Tasks 1-8. `memoryBlock(digest, {withIds})`, `Pal.chat(...memory)`, `Pal.agenda(...memory)`, `Pal.refreshPatterns(ctx, digest)` consistent. Dart `PalMemoryDigest`/`PalFact` + `memory()/refreshMemory()/deleteFact()/clearMemory()` consistent across Tasks 9-13. Patterns reuse `InsightPattern` on the client and `MemoryPattern` (same field names) on the server.

**One flagged risk:** Tasks 9-11 deliberately leave the build red between them (removing `PalMemory`/`agenda.memory` breaks `http`/`mock`/`screen` until each is fixed). They are ordered so the suite returns to green by Task 12; do not run the full app suite mid-sequence — run only the per-task file noted in each Step 4.
