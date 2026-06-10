# Backend LLM Proxy (U22 + U23) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `MockPalService` with a real Anthropic-backed proxy on the DigitalOcean droplet, swapped in via a Riverpod provider override with zero screen/controller changes.

**Architecture:** A Node + TypeScript (Fastify) service in `server/` forwards to the Anthropic Messages API using the exact handoff prompts (server-owned). The Flutter `HttpPalService` reads repositories to build structured context JSON, POSTs it, and maps responses into the existing `PalService` DTOs. Per-device bearer tokens (provisioning-key-gated `/register`) stored in SQLite gate the endpoints. The `PalService` interface is unchanged.

**Tech Stack:** Node 20+, TypeScript, Fastify, `@anthropic-ai/sdk`, `better-sqlite3`, `zod`, `@fastify/rate-limit`, Vitest (server). Dart `http`, `flutter_secure_storage`, `uuid`, Riverpod codegen (client).

**Reference spec:** `docs/superpowers/specs/2026-06-10-backend-llm-proxy-design.md`

---

## The wire contract (single source of truth)

Both halves must agree on these shapes. The client builds them; the server consumes them.

```
POST /v1/chat        { history: [{role:"user"|"assistant", text}], message, context: ChatContext }   -> { reply }
POST /v1/parse       { text }                                                                          -> { type, amount, duration, category, title, note }
POST /v1/review      { context: ReviewContext }                                                        -> { text }
POST /v1/suggest-workout { another: boolean, context: SuggestContext }                                 -> { routineId, reason }
POST /v1/post-workout-note { context: PostWorkoutContext }                                             -> { note }
POST /v1/register    { provisioningKey, deviceId }                                                     -> { token }
GET  /healthz                                                                                          -> 200 "ok"

ChatContext        { userName, todayEntries:string[], dailyBudget, moveGoalMin, ritualGoal,
                     spentToday, movedTodayMin, ritualsDoneToday,
                     weekSpent, weekBudget, weekMovedMin, weekRitualsDone, weekRitualGoal, moveStreakDays }
ReviewContext      { spent, spentDeltaPct, hoursMoved, movedDeltaPct, activeDays,
                     ritualsKept, ritualsTarget, ritualsPct, streakDays, topCategory, topCategoryPct, discoveredPattern }
SuggestContext     { recentWorkouts:[{routineName, date, muscles}], dayOfWeek, availableRoutines:[{id, name}] }
PostWorkoutContext { routineName, setCount, volumeKg, prCount, prExercises:string[], lastSessionVolumeKg|null, daysAgoLastSession|null }

/parse response `type` is the wire token "money" | "move" | "rituals"; `amount`/`duration`/`category`/`note` are nullable.
```

All POST endpoints except `/v1/register` require `Authorization: Bearer <deviceToken>`.

---

# Part A — Server (`server/`, U22)

### Task 1: Scaffold the Node/TS project

**Files:**
- Create: `server/package.json`
- Create: `server/tsconfig.json`
- Create: `server/vitest.config.ts`
- Create: `server/.gitignore`
- Create: `server/.env.example`
- Create: `server/src/config.ts`

- [ ] **Step 1: Create `server/package.json`**

```json
{
  "name": "loop-pal-proxy",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": { "node": ">=20" },
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/server.js",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "@anthropic-ai/sdk": "^0.40.0",
    "@fastify/rate-limit": "^10.2.0",
    "better-sqlite3": "^11.8.0",
    "fastify": "^5.2.0",
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "@types/better-sqlite3": "^7.6.12",
    "@types/node": "^22.10.0",
    "tsx": "^4.19.0",
    "typescript": "^5.7.0",
    "vitest": "^2.1.0"
  }
}
```

- [ ] **Step 2: Create `server/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "resolveJsonModule": true
  },
  "include": ["src/**/*.ts"]
}
```

- [ ] **Step 3: Create `server/vitest.config.ts`**

```ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: { environment: 'node', include: ['src/**/*.test.ts'] },
})
```

- [ ] **Step 4: Create `server/.gitignore`**

```
node_modules/
dist/
.env
*.sqlite
*.sqlite-journal
```

- [ ] **Step 5: Create `server/.env.example`**

```
# Anthropic key — server-side only, never commit the real value
ANTHROPIC_API_KEY=sk-ant-...
# Gates POST /v1/register; ships in the app build via --dart-define
PAL_PROVISIONING_KEY=change-me-long-random
# Model id; handoff default is claude-haiku-4-5 (latency). Alternative: claude-opus-4-8
PAL_MODEL=claude-haiku-4-5
PORT=8080
SQLITE_PATH=./loop.sqlite
# Comma-separated origins allowed for the web preview (CORS). Empty = no browser origin allowed.
CORS_ORIGINS=http://localhost:8080
```

- [ ] **Step 6: Create `server/src/config.ts`**

```ts
function required(name: string): string {
  const v = process.env[name]
  if (!v) throw new Error(`Missing required env var: ${name}`)
  return v
}

export const config = {
  anthropicApiKey: required('ANTHROPIC_API_KEY'),
  provisioningKey: required('PAL_PROVISIONING_KEY'),
  model: process.env.PAL_MODEL ?? 'claude-haiku-4-5',
  port: Number(process.env.PORT ?? 8080),
  sqlitePath: process.env.SQLITE_PATH ?? './loop.sqlite',
  corsOrigins: (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
}
```

- [ ] **Step 7: Install deps and verify the toolchain builds**

Run: `cd server && npm install && npx tsc --noEmit`
Expected: install completes; `tsc --noEmit` exits 0 (no source files reference anything missing yet — `config.ts` compiles).

- [ ] **Step 8: Commit**

```bash
git add server/package.json server/package-lock.json server/tsconfig.json server/vitest.config.ts server/.gitignore server/.env.example server/src/config.ts
git commit -m "chore(server): scaffold Node/TS Pal proxy project"
```

---

### Task 2: SQLite token store

**Files:**
- Create: `server/src/store.ts`
- Test: `server/src/store.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
// server/src/store.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { TokenStore } from './store.js'

describe('TokenStore', () => {
  let store: TokenStore
  beforeEach(() => { store = new TokenStore(':memory:') })

  it('issues a token and validates it', () => {
    const token = store.issue('device-1')
    expect(token).toHaveLength(64)
    expect(store.isValid(token)).toBe(true)
  })

  it('rejects an unknown token', () => {
    expect(store.isValid('nope')).toBe(false)
  })

  it('revokes a token', () => {
    const token = store.issue('device-2')
    store.revoke(token)
    expect(store.isValid(token)).toBe(false)
  })

  it('reuses the token for a known device instead of duplicating', () => {
    const a = store.issue('device-3')
    const b = store.issue('device-3')
    expect(b).toBe(a)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/store.test.ts`
Expected: FAIL — cannot find module `./store.js`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/store.ts
import Database from 'better-sqlite3'
import { randomBytes } from 'node:crypto'

export class TokenStore {
  private db: Database.Database

  constructor(path: string) {
    this.db = new Database(path)
    this.db.pragma('journal_mode = WAL')
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS device_tokens (
        token      TEXT PRIMARY KEY,
        device_id  TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    `)
  }

  // returns existing token for a known device, else issues a new one
  issue(deviceId: string): string {
    const existing = this.db
      .prepare('SELECT token FROM device_tokens WHERE device_id = ?')
      .get(deviceId) as { token: string } | undefined
    if (existing) return existing.token

    const token = randomBytes(32).toString('hex') // 64 hex chars
    this.db
      .prepare('INSERT INTO device_tokens (token, device_id, created_at) VALUES (?, ?, ?)')
      .run(token, deviceId, Date.now())
    return token
  }

  isValid(token: string): boolean {
    const row = this.db
      .prepare('SELECT 1 FROM device_tokens WHERE token = ?')
      .get(token)
    return row !== undefined
  }

  revoke(token: string): void {
    this.db.prepare('DELETE FROM device_tokens WHERE token = ?').run(token)
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/store.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add server/src/store.ts server/src/store.test.ts
git commit -m "feat(server): SQLite per-device token store"
```

---

### Task 3: Prompt templates

**Files:**
- Create: `server/src/prompts.ts`
- Test: `server/src/prompts.test.ts`

These reproduce the handoff "AI Prompts" verbatim with context substituted. Keep the strings exact.

- [ ] **Step 1: Write the failing test**

```ts
// server/src/prompts.test.ts
import { describe, it, expect } from 'vitest'
import { chatSystemPrompt, reviewPrompt, parsePrompt, suggestPrompt, postWorkoutPrompt } from './prompts.js'

describe('prompts', () => {
  it('chat system prompt substitutes user data', () => {
    const p = chatSystemPrompt({
      userName: 'Kael', todayEntries: ['08:00 Coffee (money, -$5)'],
      dailyBudget: 60, moveGoalMin: 30, ritualGoal: 5,
      spentToday: 12, movedTodayMin: 20, ritualsDoneToday: 3,
      weekSpent: 200, weekBudget: 420, weekMovedMin: 140, weekRitualsDone: 18,
      weekRitualGoal: 35, moveStreakDays: 11,
    })
    expect(p).toContain('You are Pal')
    expect(p).toContain('Kael')
    expect(p).toContain('08:00 Coffee (money, -$5)')
    expect(p).toContain('Daily budget $60')
    expect(p).toContain('11-day move streak')
    expect(p).toContain('Never say "amazing" or "great job"')
  })

  it('parse prompt embeds the raw input', () => {
    expect(parsePrompt('coffee 5')).toContain('"coffee 5"')
    expect(parsePrompt('coffee 5')).toContain('money|move|rituals')
  })

  it('review prompt embeds the numbers', () => {
    const p = reviewPrompt({
      spent: 1840, spentDeltaPct: 12, hoursMoved: 18, movedDeltaPct: 8,
      activeDays: 22, ritualsKept: 120, ritualsTarget: 150, ritualsPct: 80,
      streakDays: 12, topCategory: 'Food', topCategoryPct: 34, discoveredPattern: 'mornings set the tone',
    })
    expect(p).toContain('$1840')
    expect(p).toContain('12-day move streak')
    expect(p).toContain('Food 34%')
  })

  it('suggest prompt lists routines and day', () => {
    const p = suggestPrompt({
      recentWorkouts: [{ routineName: 'Push A', date: 'Mon', muscles: 'chest' }],
      dayOfWeek: 'Wednesday',
      availableRoutines: [{ id: 'r1', name: 'Push A' }, { id: 'r2', name: 'Legs' }],
    })
    expect(p).toContain('Wednesday')
    expect(p).toContain('Push A')
    expect(p).toContain('routineId')
  })

  it('post-workout prompt includes PRs and trend', () => {
    const p = postWorkoutPrompt({
      routineName: 'Push A', setCount: 18, volumeKg: 5400, prCount: 2,
      prExercises: ['Bench'], lastSessionVolumeKg: 5100, daysAgoLastSession: 4,
    })
    expect(p).toContain('Push A')
    expect(p).toContain('2 PRs')
    expect(p).toContain('Bench')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/prompts.test.ts`
Expected: FAIL — cannot find module `./prompts.js`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/prompts.ts

export interface ChatContext {
  userName: string
  todayEntries: string[]
  dailyBudget: number
  moveGoalMin: number
  ritualGoal: number
  spentToday: number
  movedTodayMin: number
  ritualsDoneToday: number
  weekSpent: number
  weekBudget: number
  weekMovedMin: number
  weekRitualsDone: number
  weekRitualGoal: number
  moveStreakDays: number
}

export interface ReviewContext {
  spent: number
  spentDeltaPct: number
  hoursMoved: number
  movedDeltaPct: number
  activeDays: number
  ritualsKept: number
  ritualsTarget: number
  ritualsPct: number
  streakDays: number
  topCategory: string
  topCategoryPct: number
  discoveredPattern: string
}

export interface SuggestContext {
  recentWorkouts: Array<{ routineName: string; date: string; muscles: string }>
  dayOfWeek: string
  availableRoutines: Array<{ id: string; name: string }>
}

export interface PostWorkoutContext {
  routineName: string
  setCount: number
  volumeKg: number
  prCount: number
  prExercises: string[]
  lastSessionVolumeKg: number | null
  daysAgoLastSession: number | null
}

export function chatSystemPrompt(c: ChatContext): string {
  const entries = c.todayEntries.length ? c.todayEntries.join('\n') : '(none yet)'
  return `You are Pal, a gentle, concise coach in an iOS app that tracks money, movement and daily rituals.

Today's entries for ${c.userName}:
${entries}

Daily budget $${c.dailyBudget}, move goal ${c.moveGoalMin}min, ritual goal ${c.ritualGoal}.
Spent $${c.spentToday} so far, moved ${c.movedTodayMin}min, ${c.ritualsDoneToday}/${c.ritualGoal} rituals done.

Week: $${c.weekSpent} of $${c.weekBudget} spent, ${c.weekMovedMin}min moved, ${c.weekRitualsDone}/${c.weekRitualGoal} rituals. ${c.moveStreakDays}-day move streak.

Reply in 1-3 short sentences. Friendly, specific, no filler. Never say "amazing" or "great job" — be observational and warm instead.`
}

export function reviewPrompt(c: ReviewContext): string {
  return `Write a 2-3 sentence warm, specific, editorial reflection on this month's tracking data. Avoid hype words like "amazing" or "crushed it". Be specific and observational.

Data: $${c.spent} spent (down ${c.spentDeltaPct}% vs last month), ${c.hoursMoved}h moved (up ${c.movedDeltaPct}%), ${c.activeDays} active days, ${c.ritualsKept}/${c.ritualsTarget} rituals kept (${c.ritualsPct}%). Current ${c.streakDays}-day move streak. Top category: ${c.topCategory} ${c.topCategoryPct}%. Pattern: ${c.discoveredPattern}.`
}

export function parsePrompt(input: string): string {
  return `Parse this free-form log into JSON. User said: "${input}"
Return strictly: {"type": "money|move|rituals", "amount": number|null, "duration": number|null, "category": string|null, "title": string, "note": string|null}
No prose. If ambiguous, guess from context.`
}

export function suggestPrompt(c: SuggestContext): string {
  const recent = c.recentWorkouts.length
    ? c.recentWorkouts.map((w) => `${w.routineName} — ${w.date} — ${w.muscles}`).join('\n')
    : '(none this week)'
  const available = c.availableRoutines.map((r) => `${r.id}: ${r.name}`).join(', ')
  return `The user logged these workouts this week:
${recent}

Today is ${c.dayOfWeek}. Pick ONE routine from ${available} that balances their recent volume. Return strictly:
{"routineId": string, "reason": "one sentence, specific, observational"}`
}

export function postWorkoutPrompt(c: PostWorkoutContext): string {
  const last =
    c.lastSessionVolumeKg !== null && c.daysAgoLastSession !== null
      ? `Their last session of the same routine was ${c.lastSessionVolumeKg}kg, ${c.daysAgoLastSession} days ago.`
      : 'This is their first recorded session of this routine.'
  return `User just finished ${c.routineName}: ${c.setCount} sets, ${c.volumeKg}kg total, ${c.prCount} PRs on ${c.prExercises.join(', ') || 'none'}. ${last}

Write 1-2 sentences observing the trend and recommending one concrete change next session (e.g. add 2.5kg, add a set, drop weight and focus on form). Warm, specific, no hype.`
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/prompts.test.ts`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add server/src/prompts.ts server/src/prompts.test.ts
git commit -m "feat(server): handoff prompt templates + context types"
```

---

### Task 4: Anthropic client wrapper (mockable)

**Files:**
- Create: `server/src/pal.ts`
- Test: `server/src/pal.test.ts`

`Pal` wraps the Anthropic SDK. It takes an injectable `AnthropicLike` so tests never hit the network. Free-text calls use `messages.create`; JSON calls (`parse`, `suggest`) use `messages.parse` with a zod schema.

- [ ] **Step 1: Write the failing test**

```ts
// server/src/pal.test.ts
import { describe, it, expect, vi } from 'vitest'
import { Pal } from './pal.js'

function fakeAnthropic(textOrParsed: { text?: string; parsed?: unknown }) {
  return {
    messages: {
      create: vi.fn(async () => ({ content: [{ type: 'text', text: textOrParsed.text ?? '' }] })),
      parse: vi.fn(async () => ({ parsed_output: textOrParsed.parsed })),
    },
  }
}

describe('Pal', () => {
  it('chat returns the model text', async () => {
    const anthropic = fakeAnthropic({ text: 'Nice — logged it.' })
    const pal = new Pal(anthropic as never, 'claude-haiku-4-5')
    const reply = await pal.chat([], 'hi', baseChatCtx())
    expect(reply).toBe('Nice — logged it.')
    expect(anthropic.messages.create).toHaveBeenCalledOnce()
  })

  it('parse returns the structured object', async () => {
    const parsed = { type: 'money', amount: 5, duration: null, category: 'Coffee', title: 'Coffee', note: null }
    const anthropic = fakeAnthropic({ parsed })
    const pal = new Pal(anthropic as never, 'claude-haiku-4-5')
    const result = await pal.parse('coffee 5')
    expect(result).toEqual(parsed)
  })

  it('suggestWorkout returns routineId + reason', async () => {
    const parsed = { routineId: 'r2', reason: 'Legs are rested.' }
    const anthropic = fakeAnthropic({ parsed })
    const pal = new Pal(anthropic as never, 'claude-haiku-4-5')
    const result = await pal.suggestWorkout(false, {
      recentWorkouts: [], dayOfWeek: 'Wed', availableRoutines: [{ id: 'r2', name: 'Legs' }],
    })
    expect(result).toEqual(parsed)
  })
})

function baseChatCtx() {
  return {
    userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalMin: 30, ritualGoal: 5,
    spentToday: 0, movedTodayMin: 0, ritualsDoneToday: 0,
    weekSpent: 0, weekBudget: 420, weekMovedMin: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/pal.test.ts`
Expected: FAIL — cannot find module `./pal.js`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/pal.ts
import { z } from 'zod'
import {
  chatSystemPrompt, reviewPrompt, parsePrompt, suggestPrompt, postWorkoutPrompt,
  type ChatContext, type ReviewContext, type SuggestContext, type PostWorkoutContext,
} from './prompts.js'

// Minimal surface of the Anthropic SDK we use — keeps the wrapper testable.
export interface AnthropicLike {
  messages: {
    create(args: unknown): Promise<{ content: Array<{ type: string; text?: string }> }>
    parse(args: unknown): Promise<{ parsed_output: unknown }>
  }
}

const MAX_TOKENS = 1024

export const parseSchema = z.object({
  type: z.enum(['money', 'move', 'rituals']),
  amount: z.number().nullable(),
  duration: z.number().nullable(),
  category: z.string().nullable(),
  title: z.string(),
  note: z.string().nullable(),
})
export type ParsedEntry = z.infer<typeof parseSchema>

export const suggestSchema = z.object({ routineId: z.string(), reason: z.string() })
export type Suggestion = z.infer<typeof suggestSchema>

// zodOutputFormat lives in the SDK helper; import lazily so tests can inject a fake client.
async function jsonFormat<T extends z.ZodTypeAny>(schema: T) {
  const { zodOutputFormat } = await import('@anthropic-ai/sdk/helpers/zod')
  return zodOutputFormat(schema)
}

export class Pal {
  constructor(private readonly client: AnthropicLike, private readonly model: string) {}

  private firstText(content: Array<{ type: string; text?: string }>): string {
    const block = content.find((b) => b.type === 'text')
    return block?.text?.trim() ?? ''
  }

  async chat(history: Array<{ role: 'user' | 'assistant'; text: string }>, message: string, ctx: ChatContext): Promise<string> {
    const res = await this.client.messages.create({
      model: this.model,
      max_tokens: MAX_TOKENS,
      system: chatSystemPrompt(ctx),
      messages: [
        ...history.map((m) => ({ role: m.role, content: m.text })),
        { role: 'user', content: message },
      ],
    })
    return this.firstText(res.content)
  }

  async review(ctx: ReviewContext): Promise<string> {
    const res = await this.client.messages.create({
      model: this.model,
      max_tokens: MAX_TOKENS,
      messages: [{ role: 'user', content: reviewPrompt(ctx) }],
    })
    return this.firstText(res.content)
  }

  async postWorkoutNote(ctx: PostWorkoutContext): Promise<string> {
    const res = await this.client.messages.create({
      model: this.model,
      max_tokens: MAX_TOKENS,
      messages: [{ role: 'user', content: postWorkoutPrompt(ctx) }],
    })
    return this.firstText(res.content)
  }

  async parse(text: string): Promise<ParsedEntry> {
    const res = await this.client.messages.parse({
      model: this.model,
      max_tokens: MAX_TOKENS,
      messages: [{ role: 'user', content: parsePrompt(text) }],
      output_config: { format: await jsonFormat(parseSchema) },
    })
    return parseSchema.parse(res.parsed_output)
  }

  async suggestWorkout(another: boolean, ctx: SuggestContext): Promise<Suggestion> {
    const nudge = another ? '\n\nPick a DIFFERENT routine than you would normally default to.' : ''
    const res = await this.client.messages.parse({
      model: this.model,
      max_tokens: MAX_TOKENS,
      messages: [{ role: 'user', content: suggestPrompt(ctx) + nudge }],
      output_config: { format: await jsonFormat(suggestSchema) },
    })
    return suggestSchema.parse(res.parsed_output)
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/pal.test.ts`
Expected: PASS (3 tests). The fake client's `parse` returns `{ parsed_output }`, and `parseSchema.parse` validates it.

- [ ] **Step 5: Commit**

```bash
git add server/src/pal.ts server/src/pal.test.ts
git commit -m "feat(server): Anthropic Pal wrapper (chat/parse/review/suggest/note)"
```

---

### Task 5: Auth middleware + zod request schemas

**Files:**
- Create: `server/src/schemas.ts`
- Create: `server/src/auth.ts`
- Test: `server/src/auth.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
// server/src/auth.test.ts
import { describe, it, expect } from 'vitest'
import { extractBearer } from './auth.js'

describe('extractBearer', () => {
  it('pulls the token from a Bearer header', () => {
    expect(extractBearer('Bearer abc123')).toBe('abc123')
  })
  it('returns null for a missing or malformed header', () => {
    expect(extractBearer(undefined)).toBeNull()
    expect(extractBearer('Basic abc')).toBeNull()
    expect(extractBearer('Bearer')).toBeNull()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/auth.test.ts`
Expected: FAIL — cannot find module `./auth.js`.

- [ ] **Step 3: Write minimal implementations**

```ts
// server/src/auth.ts
export function extractBearer(header: string | undefined): string | null {
  if (!header) return null
  const [scheme, token] = header.split(' ')
  if (scheme !== 'Bearer' || !token) return null
  return token
}
```

```ts
// server/src/schemas.ts
import { z } from 'zod'

export const registerBody = z.object({
  provisioningKey: z.string().min(1),
  deviceId: z.string().min(1),
})

export const chatContext = z.object({
  userName: z.string(),
  todayEntries: z.array(z.string()),
  dailyBudget: z.number(),
  moveGoalMin: z.number(),
  ritualGoal: z.number(),
  spentToday: z.number(),
  movedTodayMin: z.number(),
  ritualsDoneToday: z.number(),
  weekSpent: z.number(),
  weekBudget: z.number(),
  weekMovedMin: z.number(),
  weekRitualsDone: z.number(),
  weekRitualGoal: z.number(),
  moveStreakDays: z.number(),
})

export const chatBody = z.object({
  history: z.array(z.object({ role: z.enum(['user', 'assistant']), text: z.string() })),
  message: z.string(),
  context: chatContext,
})

export const parseBody = z.object({ text: z.string() })

export const reviewContext = z.object({
  spent: z.number(), spentDeltaPct: z.number(), hoursMoved: z.number(), movedDeltaPct: z.number(),
  activeDays: z.number(), ritualsKept: z.number(), ritualsTarget: z.number(), ritualsPct: z.number(),
  streakDays: z.number(), topCategory: z.string(), topCategoryPct: z.number(), discoveredPattern: z.string(),
})
export const reviewBody = z.object({ context: reviewContext })

export const suggestContext = z.object({
  recentWorkouts: z.array(z.object({ routineName: z.string(), date: z.string(), muscles: z.string() })),
  dayOfWeek: z.string(),
  availableRoutines: z.array(z.object({ id: z.string(), name: z.string() })),
})
export const suggestBody = z.object({ another: z.boolean(), context: suggestContext })

export const postWorkoutContext = z.object({
  routineName: z.string(), setCount: z.number(), volumeKg: z.number(), prCount: z.number(),
  prExercises: z.array(z.string()), lastSessionVolumeKg: z.number().nullable(), daysAgoLastSession: z.number().nullable(),
})
export const postWorkoutBody = z.object({ context: postWorkoutContext })
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/auth.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add server/src/auth.ts server/src/schemas.ts server/src/auth.test.ts
git commit -m "feat(server): bearer extraction + zod request schemas"
```

---

### Task 6: Build the Fastify app with all routes

**Files:**
- Create: `server/src/app.ts`
- Create: `server/src/server.ts`
- Test: `server/src/app.test.ts`

`buildApp({ pal, store, provisioningKey, corsOrigins })` wires routes against injected deps so the test passes a fake `Pal` and an in-memory `TokenStore` — no network, no real key.

- [ ] **Step 1: Write the failing test**

```ts
// server/src/app.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { buildApp } from './app.js'
import { TokenStore } from './store.js'

function fakePal() {
  return {
    chat: async () => 'reply text',
    parse: async () => ({ type: 'money', amount: 5, duration: null, category: 'Coffee', title: 'Coffee', note: null }),
    review: async () => 'review text',
    suggestWorkout: async () => ({ routineId: 'r2', reason: 'Legs rested.' }),
    postWorkoutNote: async () => 'note text',
  }
}

describe('app', () => {
  let app: ReturnType<typeof buildApp>
  let store: TokenStore

  beforeEach(async () => {
    store = new TokenStore(':memory:')
    app = buildApp({ pal: fakePal() as never, store, provisioningKey: 'secret', corsOrigins: [] })
    await app.ready()
  })

  it('GET /healthz returns 200', async () => {
    const res = await app.inject({ method: 'GET', url: '/healthz' })
    expect(res.statusCode).toBe(200)
  })

  it('register issues a token only with the right provisioning key', async () => {
    const bad = await app.inject({ method: 'POST', url: '/v1/register', payload: { provisioningKey: 'wrong', deviceId: 'd1' } })
    expect(bad.statusCode).toBe(401)

    const ok = await app.inject({ method: 'POST', url: '/v1/register', payload: { provisioningKey: 'secret', deviceId: 'd1' } })
    expect(ok.statusCode).toBe(200)
    expect(ok.json().token).toHaveLength(64)
  })

  it('rejects a protected route without a valid token', async () => {
    const res = await app.inject({ method: 'POST', url: '/v1/parse', payload: { text: 'coffee 5' } })
    expect(res.statusCode).toBe(401)
  })

  it('serves /v1/parse with a valid token', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/parse',
      headers: { authorization: `Bearer ${token}` },
      payload: { text: 'coffee 5' },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().title).toBe('Coffee')
  })

  it('returns 400 on a malformed body', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/chat',
      headers: { authorization: `Bearer ${token}` },
      payload: { message: 'hi' }, // missing history + context
    })
    expect(res.statusCode).toBe(400)
  })

  it('serves /v1/chat and returns the reply', async () => {
    const token = store.issue('d1')
    const res = await app.inject({
      method: 'POST', url: '/v1/chat',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        history: [], message: 'hi',
        context: {
          userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalMin: 30, ritualGoal: 5,
          spentToday: 0, movedTodayMin: 0, ritualsDoneToday: 0,
          weekSpent: 0, weekBudget: 420, weekMovedMin: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
        },
      },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json().reply).toBe('reply text')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/app.test.ts`
Expected: FAIL — cannot find module `./app.js`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/app.ts
import Fastify, { type FastifyInstance, type FastifyRequest, type FastifyReply } from 'fastify'
import rateLimit from '@fastify/rate-limit'
import { z } from 'zod'
import Anthropic from '@anthropic-ai/sdk'
import { extractBearer } from './auth.js'
import type { Pal } from './pal.js'
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
        const status = err instanceof Anthropic.APIError ? 502 : 500
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
```

```ts
// server/src/server.ts
import Anthropic from '@anthropic-ai/sdk'
import { config } from './config.js'
import { buildApp } from './app.js'
import { Pal } from './pal.js'
import { TokenStore } from './store.js'

const anthropic = new Anthropic({ apiKey: config.anthropicApiKey })
const pal = new Pal(anthropic as never, config.model)
const store = new TokenStore(config.sqlitePath)

const app = buildApp({ pal, store, provisioningKey: config.provisioningKey, corsOrigins: config.corsOrigins })

app.listen({ port: config.port, host: '0.0.0.0' }).then((addr) => {
  console.log(`pal proxy listening on ${addr}`)
})
```

> Note: `new Anthropic(...)` is cast to `never` only at the `Pal` boundary because `Pal` accepts the narrow `AnthropicLike` interface; the real client is a structural superset.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/app.test.ts`
Expected: PASS (7 tests).

- [ ] **Step 5: Verify the whole server compiles**

Run: `cd server && npx tsc --noEmit`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add server/src/app.ts server/src/server.ts server/src/app.test.ts
git commit -m "feat(server): Fastify routes, auth guard, rate limit, error mapping"
```

---

### Task 7: Deploy artifacts

**Files:**
- Create: `server/Caddyfile.example`
- Create: `server/loop-pal.service.example`
- Create: `server/README.md`

- [ ] **Step 1: Create `server/Caddyfile.example`**

```
# Replace pal.example.com with your droplet's domain. Caddy auto-provisions TLS.
pal.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

- [ ] **Step 2: Create `server/loop-pal.service.example`**

```ini
[Unit]
Description=Loop Pal LLM proxy
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/loop-pal
EnvironmentFile=/opt/loop-pal/.env
ExecStart=/usr/bin/node dist/server.js
Restart=on-failure
User=loop

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 3: Create `server/README.md`**

````markdown
# Loop Pal proxy (U22)

Stateless LLM proxy for the Loop app's `PalService`. Forwards to the Anthropic
Messages API with the handoff prompts. Per-device bearer tokens (SQLite) gate
the endpoints. See `docs/superpowers/specs/2026-06-10-backend-llm-proxy-design.md`.

## Local dev

```bash
cp .env.example .env   # fill ANTHROPIC_API_KEY + PAL_PROVISIONING_KEY
npm install
npm run dev            # tsx watch on PORT (default 8080)
npm test               # Vitest, no network
```

## Deploy (DigitalOcean droplet)

1. Install Node 20+, Caddy. Create user `loop`, dir `/opt/loop-pal`.
2. Copy the repo's `server/` to `/opt/loop-pal`, `npm ci`, `npm run build`.
3. `cp .env.example .env`, fill secrets. `SQLITE_PATH=/opt/loop-pal/loop.sqlite`.
4. `cp loop-pal.service.example /etc/systemd/system/loop-pal.service`; `systemctl enable --now loop-pal`.
5. `cp Caddyfile.example /etc/caddy/Caddyfile` (set your domain); `systemctl reload caddy`.
6. Verify: `curl https://pal.example.com/healthz` → `ok`.

## Client wiring

Build the Flutter app with:

```
--dart-define=PAL_BASE_URL=https://pal.example.com
--dart-define=PAL_PROVISIONING_KEY=<same as server PAL_PROVISIONING_KEY>
```

Without `PAL_BASE_URL` the app stays on `MockPalService`.

## Endpoints

`POST /v1/{chat,parse,review,suggest-workout,post-workout-note}` (Bearer token),
`POST /v1/register` (provisioning key → token), `GET /healthz`.
````

- [ ] **Step 4: Run the full server suite once**

Run: `cd server && npm test`
Expected: all suites green (store, prompts, pal, auth, app).

- [ ] **Step 5: Commit**

```bash
git add server/Caddyfile.example server/loop-pal.service.example server/README.md
git commit -m "docs(server): deploy artifacts (Caddy, systemd, README)"
```

---

# Part B — Client (`lib/`, U23)

### Task 8: Add client dependencies

**Files:**
- Modify: `pubspec.yaml` (dependencies block)

- [ ] **Step 1: Add `http` and `flutter_secure_storage` under `dependencies:`**

Add after the `shared_preferences` entry (around `pubspec.yaml:33`):

```yaml
  # Backend Pal proxy (U23): HTTP client + per-device token storage.
  http: ^1.2.0
  flutter_secure_storage: ^9.2.0
```

- [ ] **Step 2: Resolve dependencies**

Run: `flutter pub get`
Expected: resolves without conflict; `http` and `flutter_secure_storage` appear in `pubspec.lock`.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add http + flutter_secure_storage for U23"
```

---

### Task 9: Device token client (registration + secure storage)

**Files:**
- Create: `lib/services/pal/device_token_store.dart`
- Test: `test/services/device_token_store_test.dart`

A thin wrapper that holds the token in `flutter_secure_storage` and registers on first use. Storage is injected so tests use an in-memory fake.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/device_token_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loop/services/pal/device_token_store.dart';

class _FakeSecureStore implements TokenSecureStore {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

void main() {
  test('registers once, then reuses the cached token', () async {
    var registerCalls = 0;
    final store = DeviceTokenStore(
      secure: _FakeSecureStore(),
      deviceId: 'device-fixed',
      register: (deviceId) async {
        registerCalls++;
        return 'token-$deviceId';
      },
    );

    final first = await store.token();
    final second = await store.token();

    expect(first, 'token-device-fixed');
    expect(second, 'token-device-fixed');
    expect(registerCalls, 1);
  });

  test('clear forces a re-register on next token()', () async {
    var registerCalls = 0;
    final store = DeviceTokenStore(
      secure: _FakeSecureStore(),
      deviceId: 'd',
      register: (_) async {
        registerCalls++;
        return 'tok$registerCalls';
      },
    );

    await store.token();
    await store.clear();
    final after = await store.token();

    expect(after, 'tok2');
    expect(registerCalls, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/device_token_store_test.dart`
Expected: FAIL — `device_token_store.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/pal/device_token_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Narrow secure-storage seam so the token store is unit-testable without a
/// platform channel.
abstract interface class TokenSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Default [TokenSecureStore] backed by the platform keychain (in-memory on web).
class FlutterTokenSecureStore implements TokenSecureStore {
  const FlutterTokenSecureStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Obtains a server device token, registering once and caching it in secure
/// storage. [register] performs the `POST /v1/register` round-trip.
class DeviceTokenStore {
  DeviceTokenStore({
    required TokenSecureStore secure,
    required String deviceId,
    required Future<String> Function(String deviceId) register,
  })  : _secure = secure,
        _deviceId = deviceId,
        _register = register;

  static const _key = 'pal_device_token';

  final TokenSecureStore _secure;
  final String _deviceId;
  final Future<String> Function(String deviceId) _register;

  Future<String> token() async {
    final cached = await _secure.read(_key);
    if (cached != null && cached.isNotEmpty) return cached;
    final fresh = await _register(_deviceId);
    await _secure.write(_key, fresh);
    return fresh;
  }

  /// Drops the cached token so the next [token] call re-registers (used after a 401).
  Future<void> clear() => _secure.delete(_key);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/device_token_store_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/pal/device_token_store.dart test/services/device_token_store_test.dart
git commit -m "feat(client): device token store (register once, secure cache)"
```

---

### Task 10: PalContextBuilder (assemble context from repos)

**Files:**
- Create: `lib/services/pal/pal_context_builder.dart`
- Test: `test/services/pal_context_builder_test.dart`

Builds the wire-context maps from repositories. Reuses `buildMonthlyStats` (from `monthly_review_controller.dart`) for the review numbers rather than re-deriving them. Pure aggregation given fetched lists, so it is directly testable with fixtures.

> Scope note: the `discoveredPattern`, `spentDeltaPct`, `movedDeltaPct`, and `topCategory` figures reuse what U18 already computes where available; for v1 the builder fills them from the same monthly aggregates and a simple top-category fold. Improving pattern discovery is out of scope (see spec §3).

- [ ] **Step 1: Write the failing test**

```dart
// test/services/pal_context_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loop/models/models.dart';
import 'package:loop/services/pal/pal_context_builder.dart';

void main() {
  final goals = const Goals(dailyBudget: 60, dailyMoveMinutes: 30, dailyRitualTarget: 5);

  Entry money(double amount, {String? category, DateTime? at}) => Entry(
        id: '', timestamp: at ?? DateTime(2026, 6, 10, 8), type: EntryType.money,
        title: category ?? 'Spend', amount: amount, category: category, source: EntrySource.manual,
      );
  Entry move(int min, {DateTime? at}) => Entry(
        id: '', timestamp: at ?? DateTime(2026, 6, 10, 9), type: EntryType.move,
        title: 'Walk', duration: min, source: EntrySource.manual,
      );
  Entry ritual({DateTime? at}) => Entry(
        id: '', timestamp: at ?? DateTime(2026, 6, 10, 7), type: EntryType.rituals,
        title: 'Meditate', source: EntrySource.manual,
      );

  test('buildChatContext folds today + week numbers', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: goals,
      todayEntries: [money(-12, category: 'Coffee'), move(20), ritual(), ritual(), ritual()],
      weekEntries: [money(-200, category: 'Coffee'), move(140), ritual()],
      moveStreakDays: 11,
    );

    expect(ctx['userName'], 'Kael');
    expect(ctx['dailyBudget'], 60);
    expect(ctx['spentToday'], 12); // absolute value of the expense
    expect(ctx['movedTodayMin'], 20);
    expect(ctx['ritualsDoneToday'], 3);
    expect(ctx['weekBudget'], 420); // 60 * 7
    expect(ctx['weekRitualGoal'], 35); // 5 * 7
    expect(ctx['moveStreakDays'], 11);
    expect((ctx['todayEntries'] as List).length, 5);
  });

  test('buildPostWorkoutContext reads volume + PRs from the workout', () {
    final workout = Workout(
      id: 'w1', routineId: 'r1', name: 'Push A',
      startedAt: DateTime(2026, 6, 10, 17), endedAt: DateTime(2026, 6, 10, 18),
      sets: const [
        SetLog(id: 's1', exerciseId: 'bench', weightKg: 60, reps: 5, completed: true, isPR: true),
        SetLog(id: 's2', exerciseId: 'bench', weightKg: 60, reps: 5, completed: true, isPR: false),
      ],
    );

    final ctx = buildPostWorkoutContext(workout: workout, lastSessionVolumeKg: 540, daysAgoLastSession: 4);

    expect(ctx['routineName'], 'Push A');
    expect(ctx['prCount'], 1);
    expect((ctx['prExercises'] as List), contains('bench'));
    expect(ctx['lastSessionVolumeKg'], 540);
    expect(ctx['daysAgoLastSession'], 4);
  });
}
```

> Before running, confirm the exact `Workout`/`SetLog` constructor field names against `lib/models/workout.dart` and `lib/models/set_log.dart`; adjust the fixture to match (e.g. `weightKg` vs `weight`). The assertions on the returned map keys do not change.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pal_context_builder_test.dart`
Expected: FAIL — `pal_context_builder.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/pal/pal_context_builder.dart
import '../../models/models.dart';

/// Formats one timeline entry as the handoff's `HH:MM Title (type, detail)`.
String formatEntryLine(Entry e) {
  final hh = e.timestamp.hour.toString().padLeft(2, '0');
  final mm = e.timestamp.minute.toString().padLeft(2, '0');
  final detail = switch (e.type) {
    EntryType.money => e.amount == null ? '' : '\$${e.amount!.toStringAsFixed(0)}',
    EntryType.move => e.duration == null ? '' : '${e.duration}min',
    EntryType.rituals => '',
  };
  final typeToken = e.type.name;
  return '$hh:$mm ${e.title} ($typeToken${detail.isEmpty ? '' : ', $detail'})';
}

double _spent(Iterable<Entry> entries) {
  var total = 0.0;
  for (final e in entries) {
    if (e.type == EntryType.money && (e.amount ?? 0) < 0) total += e.amount!.abs();
  }
  return total;
}

int _movedMin(Iterable<Entry> entries) =>
    entries.where((e) => e.type == EntryType.move).fold(0, (a, e) => a + (e.duration ?? 0));

int _rituals(Iterable<Entry> entries) =>
    entries.where((e) => e.type == EntryType.rituals).length;

Map<String, Object?> buildChatContext({
  required String userName,
  required Goals goals,
  required List<Entry> todayEntries,
  required List<Entry> weekEntries,
  required int moveStreakDays,
}) {
  return {
    'userName': userName,
    'todayEntries': todayEntries.map(formatEntryLine).toList(),
    'dailyBudget': goals.dailyBudget,
    'moveGoalMin': goals.dailyMoveMinutes,
    'ritualGoal': goals.dailyRitualTarget,
    'spentToday': _spent(todayEntries),
    'movedTodayMin': _movedMin(todayEntries),
    'ritualsDoneToday': _rituals(todayEntries),
    'weekSpent': _spent(weekEntries),
    'weekBudget': goals.dailyBudget * 7,
    'weekMovedMin': _movedMin(weekEntries),
    'weekRitualsDone': _rituals(weekEntries),
    'weekRitualGoal': goals.dailyRitualTarget * 7,
    'moveStreakDays': moveStreakDays,
  };
}

Map<String, Object?> buildReviewContext({
  required double spent,
  required int spentDeltaPct,
  required int hoursMoved,
  required int movedDeltaPct,
  required int activeDays,
  required int ritualsKept,
  required int ritualsTarget,
  required int streakDays,
  required String topCategory,
  required int topCategoryPct,
  required String discoveredPattern,
}) {
  final pct = ritualsTarget == 0 ? 0 : ((ritualsKept / ritualsTarget) * 100).round();
  return {
    'spent': spent,
    'spentDeltaPct': spentDeltaPct,
    'hoursMoved': hoursMoved,
    'movedDeltaPct': movedDeltaPct,
    'activeDays': activeDays,
    'ritualsKept': ritualsKept,
    'ritualsTarget': ritualsTarget,
    'ritualsPct': pct,
    'streakDays': streakDays,
    'topCategory': topCategory,
    'topCategoryPct': topCategoryPct,
    'discoveredPattern': discoveredPattern,
  };
}

Map<String, Object?> buildSuggestContext({
  required List<Workout> recentWorkouts,
  required String dayOfWeek,
  required List<Routine> availableRoutines,
}) {
  return {
    'recentWorkouts': recentWorkouts
        .map((w) => {
              'routineName': w.name,
              'date': '${w.startedAt.month}/${w.startedAt.day}',
              'muscles': w.sets.map((s) => s.exerciseId).toSet().join(', '),
            })
        .toList(),
    'dayOfWeek': dayOfWeek,
    'availableRoutines':
        availableRoutines.map((r) => {'id': r.id, 'name': r.name}).toList(),
  };
}

Map<String, Object?> buildPostWorkoutContext({
  required Workout workout,
  required double? lastSessionVolumeKg,
  required int? daysAgoLastSession,
}) {
  final done = workout.sets.where((s) => s.completed);
  final prExercises = done.where((s) => s.isPR).map((s) => s.exerciseId).toSet().toList();
  return {
    'routineName': workout.name,
    'setCount': done.length,
    'volumeKg': workout.totalVolumeKg,
    'prCount': workout.prCount,
    'prExercises': prExercises,
    'lastSessionVolumeKg': lastSessionVolumeKg,
    'daysAgoLastSession': daysAgoLastSession,
  };
}
```

> Field-name check: this uses `workout.name`, `workout.sets`, `workout.startedAt`, `workout.totalVolumeKg`, `workout.prCount`, `set.exerciseId`, `set.completed`, `set.isPR`, `routine.id`, `routine.name`, `goals.dailyBudget/dailyMoveMinutes/dailyRitualTarget`, `entry.timestamp/type/title/amount/duration`. Verify each against the model files and fix any mismatch before implementing — do not guess.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/pal_context_builder_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/pal/pal_context_builder.dart test/services/pal_context_builder_test.dart
git commit -m "feat(client): PalContextBuilder — repo data to wire context"
```

---

### Task 11: HttpPalService (implements PalService)

**Files:**
- Create: `lib/services/pal/http_pal_service.dart`
- Test: `test/services/http_pal_service_test.dart`

Implements the existing `PalService` interface. Injects an `http.Client` (tested via `MockClient`), a `DeviceTokenStore`, the repositories, and the base URL. Re-registers once on 401.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/http_pal_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loop/models/models.dart';
import 'package:loop/services/pal/http_pal_service.dart';
import 'package:loop/services/pal/pal_service.dart';

void main() {
  // A token store stub that hands back a fixed token and counts clears.
  late int clears;
  TokenProvider tokenProvider() {
    clears = 0;
    return TokenProvider(
      token: () async => 'tok',
      clear: () async => clears++,
    );
  }

  // Minimal context fetcher stub: the service calls this to assemble context.
  PalContextSource contextStub() => PalContextSource(
        chat: () async => {'userName': 'Kael', 'todayEntries': <String>[], 'dailyBudget': 60,
          'moveGoalMin': 30, 'ritualGoal': 5, 'spentToday': 0, 'movedTodayMin': 0,
          'ritualsDoneToday': 0, 'weekSpent': 0, 'weekBudget': 420, 'weekMovedMin': 0,
          'weekRitualsDone': 0, 'weekRitualGoal': 35, 'moveStreakDays': 0},
        review: (_) async => {'spent': 100, 'spentDeltaPct': 0, 'hoursMoved': 1, 'movedDeltaPct': 0,
          'activeDays': 1, 'ritualsKept': 1, 'ritualsTarget': 5, 'ritualsPct': 20, 'streakDays': 1,
          'topCategory': 'Food', 'topCategoryPct': 30, 'discoveredPattern': 'steady'},
        suggest: (_) async => {'recentWorkouts': <Object>[], 'dayOfWeek': 'Wed',
          'availableRoutines': [{'id': 'r2', 'name': 'Legs'}]},
        postWorkout: (_) async => {'routineName': 'Push', 'setCount': 1, 'volumeKg': 60,
          'prCount': 0, 'prExercises': <String>[], 'lastSessionVolumeKg': null, 'daysAgoLastSession': null},
        resolveRoutineTitle: (id) async => 'Legs',
      );

  HttpPalService build(MockClient client) => HttpPalService(
        baseUrl: 'https://pal.test',
        httpClient: client,
        tokens: tokenProvider(),
        context: contextStub(),
      );

  test('chat posts to /v1/chat and returns the reply', () async {
    late http.Request seen;
    final service = build(MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode({'reply': 'Nice — logged it.'}), 200);
    }));

    final reply = await service.chat([], 'hi');

    expect(reply, 'Nice — logged it.');
    expect(seen.url.path, '/v1/chat');
    expect(seen.headers['authorization'], 'Bearer tok');
    expect(jsonDecode(seen.body)['message'], 'hi');
  });

  test('parse maps the response into a ParsedEntryDraft (expense negated)', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({'type': 'money', 'amount': 5, 'duration': null, 'category': 'Coffee', 'title': 'Coffee', 'note': null}),
          200,
        )));

    final draft = await service.parse('coffee 5');

    expect(draft.type, EntryType.money);
    expect(draft.title, 'Coffee');
    expect(draft.amount, -5); // positive money amount becomes an expense
    expect(draft.category, 'Coffee');
  });

  test('suggestWorkout fills title from resolveRoutineTitle', () async {
    final service = build(MockClient((req) async =>
        http.Response(jsonEncode({'routineId': 'r2', 'reason': 'Legs rested.'}), 200)));

    final s = await service.suggestWorkout();

    expect(s.routineId, 'r2');
    expect(s.rationale, 'Legs rested.');
    expect(s.title, 'Legs');
  });

  test('re-registers once on 401 then retries', () async {
    var calls = 0;
    final service = build(MockClient((req) async {
      calls++;
      if (calls == 1) return http.Response('unauthorized', 401);
      return http.Response(jsonEncode({'reply': 'ok'}), 200);
    }));

    final reply = await service.chat([], 'hi');

    expect(reply, 'ok');
    expect(calls, 2);
    expect(clears, 1); // token was cleared before the retry
  });

  test('throws PalException on a non-2xx after retry', () async {
    final service = build(MockClient((req) async => http.Response('boom', 502)));
    expect(() => service.review(DateTime(2026, 6)), throwsA(isA<PalException>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/http_pal_service_test.dart`
Expected: FAIL — `http_pal_service.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/pal/http_pal_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'pal_service.dart';

/// Raised when the proxy is unreachable or returns a non-2xx (after one retry).
class PalException implements Exception {
  const PalException(this.message);
  final String message;
  @override
  String toString() => 'PalException: $message';
}

/// Token seam: yields the current device token and can clear it (after a 401).
class TokenProvider {
  const TokenProvider({required this.token, required this.clear});
  final Future<String> Function() token;
  final Future<void> Function() clear;
}

/// Context seam: yields the wire-context maps and resolves a routine title.
/// The real impl reads repositories; tests pass fixed maps.
class PalContextSource {
  const PalContextSource({
    required this.chat,
    required this.review,
    required this.suggest,
    required this.postWorkout,
    required this.resolveRoutineTitle,
  });
  final Future<Map<String, Object?>> Function() chat;
  final Future<Map<String, Object?>> Function(DateTime month) review;
  final Future<Map<String, Object?>> Function(bool another) suggest;
  final Future<Map<String, Object?>> Function(Workout workout) postWorkout;
  final Future<String?> Function(String routineId) resolveRoutineTitle;
}

/// Real [PalService]: posts structured context to the droplet proxy and maps
/// responses into the existing DTOs. Interface-compatible with [MockPalService].
class HttpPalService implements PalService {
  HttpPalService({
    required String baseUrl,
    required http.Client httpClient,
    required TokenProvider tokens,
    required PalContextSource context,
    Duration timeout = const Duration(seconds: 30),
  })  : _base = Uri.parse(baseUrl),
        _http = httpClient,
        _tokens = tokens,
        _context = context,
        _timeout = timeout;

  final Uri _base;
  final http.Client _http;
  final TokenProvider _tokens;
  final PalContextSource _context;
  final Duration _timeout;

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    Future<http.Response> send() async {
      final token = await _tokens.token();
      return _http
          .post(
            _base.replace(path: path),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    }

    http.Response res;
    try {
      res = await send();
      if (res.statusCode == 401) {
        await _tokens.clear();
        res = await send();
      }
    } on TimeoutException {
      throw const PalException('request timed out');
    } catch (e) {
      throw PalException('network error: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PalException('proxy returned ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<String> chat(List<PalMessage> history, String message) async {
    final body = {
      'history': history
          .map((m) => {'role': m.role == PalRole.user ? 'user' : 'assistant', 'text': m.text})
          .toList(),
      'message': message,
      'context': await _context.chat(),
    };
    final json = await _post('/v1/chat', body);
    return json['reply'] as String;
  }

  @override
  Future<ParsedEntryDraft> parse(String text) async {
    final json = await _post('/v1/parse', {'text': text});
    final type = _entryTypeFromWire(json['type'] as String);
    final rawAmount = (json['amount'] as num?)?.toDouble();
    // ParsedEntryDraft convention: negative = expense. Server returns a magnitude.
    final amount = (type == EntryType.money && rawAmount != null && rawAmount > 0)
        ? -rawAmount
        : rawAmount;
    return ParsedEntryDraft(
      type: type,
      title: json['title'] as String?,
      amount: amount,
      category: json['category'] as String?,
      durationMinutes: (json['duration'] as num?)?.round(),
      note: json['note'] as String?,
    );
  }

  @override
  Future<String> review(DateTime month) async {
    final json = await _post('/v1/review', {'context': await _context.review(month)});
    return json['text'] as String;
  }

  @override
  Future<WorkoutSuggestion> suggestWorkout({bool another = false}) async {
    final json = await _post('/v1/suggest-workout', {
      'another': another,
      'context': await _context.suggest(another),
    });
    final routineId = json['routineId'] as String?;
    final title = (routineId == null ? null : await _context.resolveRoutineTitle(routineId)) ?? 'Workout';
    return WorkoutSuggestion(
      title: title,
      rationale: json['reason'] as String,
      routineId: routineId,
    );
  }

  @override
  Future<String> postWorkoutNote(Workout workout) async {
    final json = await _post('/v1/post-workout-note', {
      'context': await _context.postWorkout(workout),
    });
    return json['note'] as String;
  }

  EntryType _entryTypeFromWire(String token) => switch (token) {
        'money' => EntryType.money,
        'move' => EntryType.move,
        'rituals' => EntryType.rituals,
        _ => EntryType.money,
      };
}
```

> Verify `PalRole`, `PalMessage.role/text`, `ParsedEntryDraft` named params (`durationMinutes`, not `duration`), and `WorkoutSuggestion` named params against `pal_service.dart` (read in this plan's research; `durationMinutes` and `WorkoutSuggestion(title, rationale, routineId, estimatedMinutes?, focus?)` are confirmed). Drop the `await tester.pumpWidget` teardown note — these are plain `test()` cases with no widget tree or drift timers.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/http_pal_service_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/pal/http_pal_service.dart test/services/http_pal_service_test.dart
git commit -m "feat(client): HttpPalService implementing PalService over the proxy"
```

---

### Task 12: Wire the real service behind a dart-define gate

**Files:**
- Modify: `lib/services/services.dart` (export the new files)
- Modify: `lib/controllers/providers.dart:78-79` (`palService` provider)
- Test: `test/controllers/pal_service_provider_test.dart`

The `palService` provider returns `MockPalService` unless `PAL_BASE_URL` is set; when set it builds `HttpPalService` with a `PalContextSource` backed by the repositories.

- [ ] **Step 1: Export the new pal files from the services barrel**

In `lib/services/services.dart`, add under the existing pal exports:

```dart
export 'pal/device_token_store.dart';
export 'pal/http_pal_service.dart';
export 'pal/pal_context_builder.dart';
```

- [ ] **Step 2: Write the failing test (mock stays by default)**

```dart
// test/controllers/pal_service_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop/controllers/providers.dart';
import 'package:loop/services/services.dart';

void main() {
  test('palServiceProvider defaults to MockPalService when PAL_BASE_URL is unset', () {
    // Tests run without --dart-define, so the gate must fall back to the mock.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(palServiceProvider);

    expect(service, isA<MockPalService>());
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/controllers/pal_service_provider_test.dart`
Expected: FAIL — the provider currently always returns `MockPalService`, so this actually PASSES today. To make it a real guard test, first change the provider (Step 4), then this test pins the default-path behavior. Run it after Step 4.

- [ ] **Step 4: Rewrite the `palService` provider**

Replace `lib/controllers/providers.dart:78-79`:

```dart
@Riverpod(keepAlive: true)
PalService palService(Ref ref) => MockPalService();
```

with:

```dart
/// Compile-time backend config. `--dart-define=PAL_BASE_URL=...` swaps in the
/// real proxy; unset (tests, backend-less preview) keeps the mock.
const _palBaseUrl = String.fromEnvironment('PAL_BASE_URL');
const _palProvisioningKey = String.fromEnvironment('PAL_PROVISIONING_KEY');

@Riverpod(keepAlive: true)
PalService palService(Ref ref) {
  if (_palBaseUrl.isEmpty) return MockPalService();

  final http = HttpClientHolder.instance;
  final entries = ref.watch(entryRepositoryProvider);
  final goals = ref.watch(goalsRepositoryProvider);
  final workouts = ref.watch(workoutRepositoryProvider);
  final routines = ref.watch(routineRepositoryProvider);

  final tokens = TokenProvider(
    token: () => _deviceTokens(http).token(),
    clear: () => _deviceTokens(http).clear(),
  );

  final context = PalContextSource(
    chat: () async {
      final now = DateTime.now();
      final today = await entries.watchToday(now).first;
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final week = await entries.watchEntriesInRange(
        DateTime(weekStart.year, weekStart.month, weekStart.day),
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
      ).first;
      return buildChatContext(
        userName: 'there',
        goals: await goals.get(),
        todayEntries: today,
        weekEntries: week,
        moveStreakDays: 0, // streak source wired in U18 reuse; 0 until then
      );
    },
    review: (month) async {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      final monthEntries = await entries.watchEntriesInRange(start, end).first;
      var spent = 0.0;
      var movedMin = 0;
      var kept = 0;
      String topCat = '—';
      final byCat = <String, double>{};
      for (final e in monthEntries) {
        switch (e.type) {
          case EntryType.money:
            if ((e.amount ?? 0) < 0) {
              spent += e.amount!.abs();
              final c = e.category ?? 'Other';
              byCat[c] = (byCat[c] ?? 0) + e.amount!.abs();
            }
          case EntryType.move:
            movedMin += e.duration ?? 0;
          case EntryType.rituals:
            kept += 1;
        }
      }
      var topVal = 0.0;
      byCat.forEach((k, v) { if (v > topVal) { topVal = v; topCat = k; } });
      final topPct = spent == 0 ? 0 : ((topVal / spent) * 100).round();
      final g = await goals.get();
      return buildReviewContext(
        spent: spent,
        spentDeltaPct: 0,
        hoursMoved: (movedMin / 60).round(),
        movedDeltaPct: 0,
        activeDays: monthEntries.map((e) => e.timestamp.day).toSet().length,
        ritualsKept: kept,
        ritualsTarget: g.dailyRitualTarget * 30,
        streakDays: 0,
        topCategory: topCat,
        topCategoryPct: topPct,
        discoveredPattern: 'steady tracking this month',
      );
    },
    suggest: (another) async {
      final recent = await workouts.watchWorkouts().first;
      final all = await routines.getAll();
      const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
      return buildSuggestContext(
        recentWorkouts: recent.take(5).toList(),
        dayOfWeek: days[DateTime.now().weekday - 1],
        availableRoutines: all,
      );
    },
    postWorkout: (workout) async {
      final priors = (await workouts.watchWorkouts().first)
          .where((w) => w.routineId == workout.routineId && w.id != workout.id)
          .toList();
      double? lastVol;
      int? daysAgo;
      if (priors.isNotEmpty) {
        priors.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        lastVol = priors.first.totalVolumeKg;
        daysAgo = DateTime.now().difference(priors.first.startedAt).inDays;
      }
      return buildPostWorkoutContext(
        workout: workout,
        lastSessionVolumeKg: lastVol,
        daysAgoLastSession: daysAgo,
      );
    },
    resolveRoutineTitle: (id) async => (await routines.getById(id))?.name,
  );

  return HttpPalService(
    baseUrl: _palBaseUrl,
    httpClient: http,
    tokens: tokens,
    context: context,
  );
}
```

Add a tiny module-level holder + register helper near the top of `providers.dart` (after the imports), so the `http.Client` and `DeviceTokenStore` are created once:

```dart
// Single shared http client + device-token store for the real Pal proxy.
// Kept module-level (not a provider) since they hold no Riverpod state and the
// gate above is the only consumer.
class HttpClientHolder {
  static final http.Client instance = http.Client();
}

DeviceTokenStore? _deviceTokensCache;
DeviceTokenStore _deviceTokens(http.Client client) {
  return _deviceTokensCache ??= DeviceTokenStore(
    secure: const FlutterTokenSecureStore(),
    deviceId: const Uuid().v4(),
    register: (deviceId) async {
      final res = await client.post(
        Uri.parse('$_palBaseUrl/v1/register'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'provisioningKey': _palProvisioningKey, 'deviceId': deviceId}),
      );
      if (res.statusCode != 200) {
        throw PalException('register failed (${res.statusCode})');
      }
      return (jsonDecode(res.body) as Map<String, dynamic>)['token'] as String;
    },
  );
}
```

Add the required imports at the top of `providers.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
```

> The `deviceId` is generated fresh per process here; because `DeviceTokenStore` reads the cached token from secure storage first, a returning device reuses its stored token and the new `deviceId` is only used if no token exists yet. (A persisted deviceId is a later refinement; not needed for correctness.)

- [ ] **Step 5: Regenerate Riverpod codegen (orchestrator-owned step)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `providers.g.dart` regenerates; the `palServiceProvider` signature is unchanged (still `PalService`), so no downstream `.g.dart` churn.

- [ ] **Step 6: Run the provider test + full client suite**

Run: `flutter test test/controllers/pal_service_provider_test.dart`
Expected: PASS (mock is returned because no `--dart-define`).

Run: `flutter test`
Expected: all existing tests + the 3 new client suites pass (84 → ~89 tests).

- [ ] **Step 7: Analyze + web build**

Run: `flutter analyze`
Expected: no issues.

Run: `flutter build web`
Expected: build succeeds.

- [ ] **Step 8: Commit**

```bash
git add lib/services/services.dart lib/controllers/providers.dart lib/controllers/providers.g.dart test/controllers/pal_service_provider_test.dart
git commit -m "feat(client): gate HttpPalService behind PAL_BASE_URL dart-define"
```

---

### Task 13: Manual end-to-end verification (documented, not automated)

**Files:** none (verification only)

- [ ] **Step 1: Run the server locally**

```bash
cd server && cp .env.example .env   # set a real ANTHROPIC_API_KEY + any PAL_PROVISIONING_KEY
npm run dev
curl localhost:8080/healthz   # → ok
```

- [ ] **Step 2: Smoke-test register + one endpoint with curl**

```bash
TOKEN=$(curl -s localhost:8080/v1/register -H 'content-type: application/json' \
  -d '{"provisioningKey":"<key>","deviceId":"dev-1"}' | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
curl -s localhost:8080/v1/parse -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"text":"coffee 5"}'
# → {"type":"money","amount":5,...,"title":"Coffee",...}
```

- [ ] **Step 3: Run the app against the local proxy**

```bash
flutter run -d chrome \
  --dart-define=PAL_BASE_URL=http://localhost:8080 \
  --dart-define=PAL_PROVISIONING_KEY=<key>
```

Open Ask Pal → send a message → confirm a real reply arrives (not a canned mock string). In New Entry → "Type it" → "coffee 5" → confirm the form pre-fills an expense. Confirm CORS: the browser console shows no CORS error (the local origin is in `CORS_ORIGINS`).

- [ ] **Step 4: Record the result**

Note in the PR description whether each of chat / parse / review / suggest / post-note returned live output, and any endpoint that needs follow-up.

---

## Self-review checklist (completed)

**Spec coverage:**
- Topology / single Node service + Caddy + systemd + SQLite → Tasks 1, 2, 7. ✓
- 5 endpoints + register + health, server-owned prompts, JSON mode for parse/suggest → Tasks 3, 4, 6. ✓
- Context assembly client-side, interface unchanged, suggest title resolved from RoutineRepository → Tasks 10, 11, 12. ✓
- Per-device token via provisioning-gated register, secure storage, 401 re-register → Tasks 2, 6, 9, 11, 12. ✓
- `PAL_BASE_URL` gate keeps mock by default → Task 12. ✓
- Error handling: 30s timeout, typed exceptions, 502 mapping, real Pal error state via `AsyncValue.error` (controllers already render it) → Tasks 6, 11. ✓
- Tests with mocked Anthropic / `MockClient`, no real network in CI → all test tasks. ✓
- Deploy artifacts + README → Task 7. ✓
- U24 sketch → spec only; not in this plan (correct — separate cycle). ✓

**Type consistency:** `ChatContext`/`ReviewContext`/`SuggestContext`/`PostWorkoutContext` field names are identical across `prompts.ts`, `schemas.ts`, and the Dart `buildXContext` maps. `parseSchema`/`suggestSchema` match the `/parse` and `/suggest-workout` response shapes. `TokenProvider`, `PalContextSource`, `PalException` are defined in Task 11 and reused in Task 12. `WorkoutSuggestion(title, rationale, routineId)` and `ParsedEntryDraft(type, title, amount, category, durationMinutes, note)` match `pal_service.dart`.

**Open verification flagged inline (do before coding the marked task):** exact `Workout`/`SetLog`/`Routine`/`Goals`/`Entry` field names (Task 10/12), and the `@anthropic-ai/sdk` minor version's `messages.parse` + `zodOutputFormat` helper path (Task 4) — confirm against the installed SDK; if `messages.parse` differs in the pinned version, fall back to `messages.create` with `output_config.format` and `JSON.parse` the first text block.
```
