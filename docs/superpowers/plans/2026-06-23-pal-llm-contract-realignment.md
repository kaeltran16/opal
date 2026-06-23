# Pal ↔ LLM Contract Realignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Realign the LLM layer with the app — a canonical server vocabulary module, currency-aware rendering, nutrition as a colour/correlation dimension, the missing `/v1/nutrition/estimate` route, and chat meal logging with a confirmation card.

**Architecture:** A new `server/src/product.ts` owns product vocabulary (entry-type vs dimension tokens, framing sentence, a `money()` renderer + `CurrencyDescriptor`). Prompts/schemas import it. The client ships a currency descriptor in the context payload and stops hard-coding `$`. A `log_meal` chat tool lets the model log a meal (with its own calorie estimate); the client persists a `NutritionMeal` and renders a confirmation card with Undo/Edit, reusing the existing chat action/undo spine.

**Tech Stack:** Server — TypeScript, Fastify, Zod, Vitest. Client — Dart, Flutter, Riverpod, Drift, `flutter_test`.

> **Commit policy (overrides the skill's per-task commits):** Per the repo owner's git workflow, do **NOT** commit after each task. Implement through all tasks, then use the final **Task 15** to present the diff + message and await explicit approval before a single commit. Run the test/verify steps in every task regardless.

> **Spec:** `docs/superpowers/specs/2026-06-23-pal-llm-contract-realignment-design.md`

---

## File Structure

**Server (`server/src/`)**
- `product.ts` *(new)* — canonical tokens (`ENTRY_TYPES`, `DIMENSIONS`), `PRODUCT_FRAMING`, `CurrencyDescriptor`, `USD`, `money()`.
- `product.test.ts` *(new)* — unit tests for the above.
- `schemas.ts` — `currencyDescriptor` schema; optional `currency` on chat/review/insights contexts; `nutritionEstimateBody`.
- `prompts.ts` — import `product`; currency-aware rendering via `money()`; framing names nutrition; nutrition colour token in insights; `nutritionEstimatePrompt`; `log_meal` example.
- `pal.ts` — `colorToken = z.enum(DIMENSIONS)`; `nutritionEstimateSchema` + `Pal.estimateMeal`; `log_meal` tool + `PalAction` member + parser; `synthReply` excludes `log_meal`.
- `app.ts` — `POST /v1/nutrition/estimate`.
- `prompts.test.ts`, `pal.test.ts`, `app.test.ts` — extended.

**Client (`lib/`)**
- `util/format.dart` — `Currency.toWire()`.
- `services/pal/pal_context_builder.dart` — builders take a `Currency`; `formatEntryLine` uses `formatCurrency`.
- `services/pal/pal_service.dart` — `LogMealAction`.
- `services/pal/http_pal_service.dart` — `_colorToken` accepts `nutrition`; decode `log_meal`.
- `controllers/providers.dart` — pass `settings.currency` into the three builders.
- `controllers/pal_action_executor.dart` — `AppliedActions.mealIds`; `LogMealAction` case + rollback.
- `controllers/pal_composer_controller.dart` — `_reverse` deletes meals.
- `screens/pal/pal_composer_screen.dart` — `_MealCard`.

**Client tests (`test/`)**
- `util/format_test.dart`, `services/pal/pal_context_builder_test.dart`, `controllers/pal_action_executor_test.dart`, `controllers/pal_composer_controller_test.dart` — extended.
- `services/pal/http_pal_service_test.dart` *(new)* — decode behaviour.

---

## Task 1: Canonical vocabulary module (`product.ts`)

**Files:**
- Create: `server/src/product.ts`
- Test: `server/src/product.test.ts`

- [ ] **Step 1: Write the failing test**

Create `server/src/product.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { ENTRY_TYPES, DIMENSIONS, PRODUCT_FRAMING, USD, money, type CurrencyDescriptor } from './product.js'

const VND: CurrencyDescriptor = { symbol: '₫', symbolBefore: false, decimals: 0, group: '.', decimal: ',' }

describe('product vocabulary', () => {
  it('entry types are the three timeline trackers (no nutrition)', () => {
    expect(ENTRY_TYPES).toEqual(['money', 'move', 'rituals'])
  })
  it('dimensions add nutrition for colour/correlation', () => {
    expect(DIMENSIONS).toEqual(['money', 'move', 'rituals', 'nutrition'])
  })
  it('framing names nutrition', () => {
    expect(PRODUCT_FRAMING).toContain('nutrition')
  })
})

describe('money', () => {
  it('USD trims .00 on whole amounts and groups thousands', () => {
    expect(money(60, USD)).toBe('$60')
    expect(money(1840, USD)).toBe('$1,840')
  })
  it('USD keeps cents when present', () => {
    expect(money(12.5, USD)).toBe('$12.50')
  })
  it('VND trails the symbol, no decimals, dot grouping', () => {
    expect(money(2500000, VND)).toBe('2.500.000 ₫')
  })
  it('defaults to USD when no descriptor is given', () => {
    expect(money(5)).toBe('$5')
  })
  it('renders a minus for negative amounts', () => {
    expect(money(-5, USD)).toBe('-$5')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/product.test.ts`
Expected: FAIL — cannot resolve `./product.js`.

- [ ] **Step 3: Write the module**

Create `server/src/product.ts`:

```ts
// The single source of truth for product vocabulary the prompts/schemas import.

// Timeline entry types — the set a /chat log-tool or /parse may emit. NOT
// nutrition: meals live in the Nutrition tab / the log_meal tool, never on the
// entry timeline (the client coerces unknown entry types to money).
export const ENTRY_TYPES = ['money', 'move', 'rituals'] as const
export type EntryTypeToken = (typeof ENTRY_TYPES)[number]

// Trackable dimensions for colour + correlation. Adds nutrition.
export const DIMENSIONS = ['money', 'move', 'rituals', 'nutrition'] as const
export type DimensionToken = (typeof DIMENSIONS)[number]

// One framing sentence every prompt reuses.
export const PRODUCT_FRAMING =
  'an iOS app that tracks money, movement, daily rituals, and nutrition'

// Per-user currency rendering, shipped in the context payload (the server has
// no currency table; the client is the source of truth). Mirrors the fields the
// client's Currency enum carries.
export interface CurrencyDescriptor {
  symbol: string
  symbolBefore: boolean
  decimals: number
  group: string // thousands separator
  decimal: string // decimal mark
}

export const USD: CurrencyDescriptor = {
  symbol: '$', symbolBefore: true, decimals: 2, group: ',', decimal: '.',
}

// Renders an amount in the user's currency. Mirrors the client's formatCurrency:
// groups thousands, places the symbol per symbolBefore, trims a .00 tail on whole
// amounts. Defaults to USD so an older client (no currency field) stays correct.
export function money(amount: number, c: CurrencyDescriptor = USD): string {
  const negative = amount < 0
  const abs = Math.abs(amount)
  const isWhole = Number.isInteger(abs)
  const decimals = c.decimals > 0 && !isWhole ? c.decimals : 0
  const [whole, frac] = abs.toFixed(decimals).split('.')
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, c.group)
  const body = frac ? `${grouped}${c.decimal}${frac}` : grouped
  const withSymbol = c.symbolBefore ? `${c.symbol}${body}` : `${body} ${c.symbol}`
  return negative ? `-${withSymbol}` : withSymbol
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/product.test.ts`
Expected: PASS (11 assertions).

---

## Task 2: Schemas — optional currency + estimate body (`schemas.ts`)

**Files:**
- Modify: `server/src/schemas.ts`

- [ ] **Step 1: Add the descriptor schema and the estimate body**

In `server/src/schemas.ts`, after the `import { z } ...` line add:

```ts
export const currencyDescriptor = z.object({
  symbol: z.string(),
  symbolBefore: z.boolean(),
  decimals: z.number().int(),
  group: z.string(),
  decimal: z.string(),
})

export const nutritionEstimateBody = z.object({ text: z.string() })
```

- [ ] **Step 2: Add the optional `currency` field to the three money-bearing contexts**

In `chatContext`, add a final field (after `weekday: z.number(),`):

```ts
  currency: currencyDescriptor.optional(),
```

In `reviewContext`, add (after `streakDays: ..., topCategory: z.string(), topCategoryPct: z.number(),`):

```ts
  currency: currencyDescriptor.optional(),
```

In `insightsContext`, add (after `correlation: z.object({ summary: z.string() }).optional(),`):

```ts
  currency: currencyDescriptor.optional(),
```

- [ ] **Step 3: Typecheck**

Run: `cd server && npm run build`
Expected: PASS (no type errors). The optional field is additive; all existing callers still validate.

> Note: behavioural coverage for the optional `currency` field is added via an `app.inject` test in Task 6 (it travels through the `guard` validation path).

---

## Task 3: Currency-aware prompts (`prompts.ts`)

**Files:**
- Modify: `server/src/prompts.ts`
- Test: `server/src/prompts.test.ts`

- [ ] **Step 1: Update the failing assertions and add currency tests**

In `server/src/prompts.test.ts`:

1. In the test `'review prompt embeds the numbers and is month-worded for a month range'`, change `expect(p).toContain('$1840')` to:

```ts
    expect(p).toContain('$1,840')
```

2. In the test `'review prompt omits delta phrases when a delta is null'`, change `expect(p).toContain('$1840 spent,')` to:

```ts
    expect(p).toContain('$1,840 spent,')
```

3. Add these tests inside the `describe('prompts', ...)` block:

```ts
  it('renders money in the provided currency (VND: trailing symbol, dot grouping)', () => {
    const p = reviewPrompt({
      range: 'month', spent: 1840000, spentDeltaPct: null, kcalMoved: 0, movedDeltaPct: null,
      activeDays: 0, ritualsKept: 0, ritualsTarget: 0, ritualsPct: 0,
      streakDays: 0, topCategory: 'Food', topCategoryPct: 0,
      currency: { symbol: '₫', symbolBefore: false, decimals: 0, group: '.', decimal: ',' },
    })
    expect(p).toContain('1.840.000 ₫')
    expect(p).not.toContain('$')
  })

  it('chat framing names nutrition and mentions logging a meal', () => {
    const p = chatSystemPrompt({
      userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalKcal: 400, ritualGoal: 5,
      spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 420,
      weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0, hourOfDay: 8, weekday: 6,
    })
    expect(p).toContain('nutrition')
    expect(p).toContain('log_meal')
  })
```

- [ ] **Step 2: Run tests to verify the new/updated ones fail**

Run: `cd server && npx vitest run src/prompts.test.ts`
Expected: FAIL — `$1,840` not found (still `$1840`), VND test fails, framing test fails.

- [ ] **Step 3: Wire `product.ts` into `prompts.ts`**

In `server/src/prompts.ts`, add to the imports at the top:

```ts
import { PRODUCT_FRAMING, money, type CurrencyDescriptor } from './product.js'
```

Add `currency?: CurrencyDescriptor` as the last field of each of `ChatContext`, `ReviewContext`, and `InsightsContext` interfaces.

In `chatSystemPrompt`, replace the returned template's framing line and money lines so it reads:

```ts
  return `You are Pal, a gentle, concise coach in ${PRODUCT_FRAMING}.

${memSection}${heading}
${entries}

Daily budget ${money(c.dailyBudget, c.currency)}, move goal ${c.moveGoalKcal}kcal, ritual goal ${c.ritualGoal}.
Spent ${money(c.spentToday, c.currency)} so far, moved ${c.movedTodayKcal}kcal, ${c.ritualsDoneToday}/${c.ritualGoal} rituals done.

Week: ${money(c.weekSpent, c.currency)} of ${money(c.weekBudget, c.currency)} spent, ${c.weekMovedKcal}kcal moved, ${c.weekRitualsDone}/${c.weekRitualGoal} rituals. ${c.moveStreakDays}-day move streak.

You can act, not just talk. When the user tells you they did, spent, or ate something, asks to change a goal, or asks for a workout routine, call the matching tool — for example "add $5 for coffee" calls log_expense, "ran 30 min" calls log_movement, "had a burrito for lunch" calls log_meal, "set my budget to $60" calls set_daily_budget, "build me a push day" calls create_routine. Only call a tool when the user clearly wants that change; for questions, just answer.

When you log an entry (expense, income, movement or ritual), the app already shows the user a confirmation card with the entry and an updated progress ring — so do NOT restate what was logged or say "logged it". Instead reply with at most one short, specific insight tied to their day or week (a pace, a streak, a budget heads-up), or reply with nothing at all if you have nothing genuinely useful to add. For a goal or routine change, a one-line confirmation is still helpful.

Reply in 1-3 short sentences. Friendly, specific, no filler. Never say "amazing" or "great job" — be observational and warm instead.`
```

In `reviewPrompt`, replace the `Data:` line so the spend renders via `money`:

```ts
Data: ${money(c.spent, c.currency)} spent${deltaPhrase(c.spentDeltaPct)}, ${c.kcalMoved}kcal moved${deltaPhrase(c.movedDeltaPct)}, ${c.activeDays} active days, ${c.ritualsKept}/${c.ritualsTarget} rituals kept (${c.ritualsPct}%). Current ${c.streakDays}-day move streak. Top category: ${c.topCategory} ${c.topCategoryPct}%.`
```

In `insightsPrompt`, change the `byDay` line:

```ts
  const byDay = weekdays.map((d, i) => `${d} ${money(c.spendByWeekday[i] ?? 0, c.currency)}`).join(', ')
```

and the `Data:` line (the `$${c.spent} of $${c.budget} budget` portion):

```ts
Data: ${money(c.spent, c.currency)} of ${money(c.budget, c.currency)} budget, ${c.moveKcal} of ${c.moveTargetKcal} move kcal, ${c.ritualsKept}/${c.ritualsTarget} rituals kept, ${c.activeDays} active days, ${c.streakDays}-day move streak. Top category: ${c.topCategory} ${c.topCategoryPct}%.
```

In `agendaPrompt`, replace the framing and the money sentence:

```ts
  return `You are Pal, a calm, specific coach in ${PRODUCT_FRAMING}. Build today's agenda for ${name}.
```

```ts
Daily budget ${money(c.dailyBudget, c.currency)}, move goal ${c.moveGoalKcal}kcal, ritual goal ${c.ritualGoal}. So far: ${money(c.spentToday, c.currency)} spent, ${c.movedTodayKcal}kcal moved, ${c.ritualsDoneToday}/${c.ritualGoal} rituals done. Week: ${money(c.weekSpent, c.currency)} of ${money(c.weekBudget, c.currency)}, ${c.weekMovedKcal}kcal, ${c.weekRitualsDone}/${c.weekRitualGoal} rituals. ${c.moveStreakDays}-day move streak.
```

In `memoryPatternsPrompt`, change the `byDay` line and the `Data:` line the same way as `insightsPrompt`:

```ts
  const byDay = weekdays.map((d, i) => `${d} ${money(c.spendByWeekday[i] ?? 0, c.currency)}`).join(', ')
```

```ts
Data: ${money(c.spent, c.currency)} of ${money(c.budget, c.currency)} budget, ${c.moveKcal} of ${c.moveTargetKcal} move kcal, ${c.ritualsKept}/${c.ritualsTarget} rituals kept, ${c.activeDays} active days, ${c.streakDays}-day move streak. Top category: ${c.topCategory} ${c.topCategoryPct}%.
```

> `parsePrompt` and `suggestionsPrompt` are intentionally unchanged: parse is already currency-agnostic, and the suggestion chips produce timeline entries (3 pillars), so their "money/movement/rituals app" framing is accurate, not drift.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && npx vitest run src/prompts.test.ts`
Expected: PASS (existing tests still green — whole amounts like `$60`/`$200` are unaffected; `$1,840` now matches).

---

## Task 4: Nutrition as a colour dimension (`pal.ts` + `prompts.ts`)

**Files:**
- Modify: `server/src/pal.ts`, `server/src/prompts.ts`
- Test: `server/src/pal.test.ts`

- [ ] **Step 1: Write the failing test**

In `server/src/pal.test.ts`, add `insightsSchema` to the import from `./pal.js`, then add:

```ts
describe('insights colour tokens', () => {
  it('accepts a nutrition colour token on a pattern', () => {
    const parsed = insightsSchema.parse({
      headline: null, lede: null, suggestion: null,
      wins: [], patterns: [{ colorToken: 'nutrition', title: 't', detail: 'd' }],
    })
    expect(parsed.patterns[0].colorToken).toBe('nutrition')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/pal.test.ts -t "nutrition colour"`
Expected: FAIL — Zod rejects `'nutrition'` (enum is `money|move|rituals`).

- [ ] **Step 3: Point the colour-token enums at `DIMENSIONS`**

In `server/src/pal.ts`, add to the top imports:

```ts
import { ENTRY_TYPES, DIMENSIONS } from './product.js'
```

Wire the entry-type enums to the canonical set (same three values — pure SSoT, no behaviour change). Change `parseSchema`'s `type` field:

```ts
  type: z.enum(ENTRY_TYPES),
```

and `suggestionEntry`'s `type` field:

```ts
  type: z.enum(ENTRY_TYPES),
```

Change the shared colour-token enum:

```ts
const colorToken = z.enum(DIMENSIONS)
```

Change `memoryPatternsSchema`'s inline enum to also use `DIMENSIONS`:

```ts
export const memoryPatternsSchema = z.object({
  patterns: z.array(z.object({
    colorToken: z.enum(DIMENSIONS).catch('money'),
    title: z.string(),
    detail: z.string(),
  })).default([]),
})
```

In `server/src/prompts.ts`, in `insightsPrompt`, update the `shape` string's two `colorToken` unions to include nutrition, and the grounding instruction:

```ts
  const shape = `{"headline": string|null, "lede": string|null, "suggestion": string|null, "correlationNarration": string|null, "wins": [{"colorToken": "money"|"move"|"rituals"|"nutrition", "title": string, "sub": string}], "patterns": [{"colorToken": "money"|"move"|"rituals"|"nutrition", "title": string, "detail": string}]}`
```

In the same function, change the instruction:

```ts
Set "colorToken" to the metric each item is about (money, move, rituals or nutrition).
```

> `agendaModelSchema.proposals` reuse the shared `colorToken` and now accept nutrition at the schema level (decode-safe), but the agenda prompt still advertises the three pillars — it carries no nutrition data. `suggestionsModelSchema` and the autopilot enum keep their `…|'accent'` sets unchanged.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && npx vitest run src/pal.test.ts src/prompts.test.ts`
Expected: PASS.

---

## Task 5: Nutrition estimate — prompt, schema, Pal method

**Files:**
- Modify: `server/src/prompts.ts`, `server/src/pal.ts`
- Test: `server/src/prompts.test.ts`, `server/src/pal.test.ts`

- [ ] **Step 1: Write the failing tests**

In `server/src/prompts.test.ts`, add `nutritionEstimatePrompt` to the import from `./prompts.js`, then add inside `describe('prompts', ...)`:

```ts
  it('nutrition estimate prompt embeds the description and asks for a calorie range', () => {
    const p = nutritionEstimatePrompt('a chicken burrito')
    expect(p).toContain('a chicken burrito')
    expect(p).toContain('calLo')
    expect(p).toContain('confidence')
  })
```

In `server/src/pal.test.ts`, add `nutritionEstimateSchema` to the import from `./pal.js`, then add:

```ts
describe('nutritionEstimateSchema', () => {
  it('parses a calorie estimate', () => {
    expect(nutritionEstimateSchema.parse({ name: 'Burrito', calLo: 520, calHi: 820, confidence: 'med' }))
      .toEqual({ name: 'Burrito', calLo: 520, calHi: 820, confidence: 'med' })
  })
  it('coerces an off-list confidence to low', () => {
    expect(nutritionEstimateSchema.parse({ name: 'x', calLo: 1, calHi: 2, confidence: 'maybe' }).confidence).toBe('low')
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && npx vitest run src/prompts.test.ts src/pal.test.ts`
Expected: FAIL — `nutritionEstimatePrompt` / `nutritionEstimateSchema` not exported.

- [ ] **Step 3: Add the prompt**

In `server/src/prompts.ts`, add (e.g. after `parsePrompt`):

```ts
export function nutritionEstimatePrompt(description: string): string {
  return `Estimate the calories for this meal or drink: "${description}".
Return strictly: {"name": string, "calLo": number, "calHi": number, "confidence": "high"|"med"|"low"}
- name: a short, clean, title-cased label for the meal, e.g. "Chicken Burrito".
- calLo/calHi: an honest calorie range (calLo <= calHi) — no fake precision.
- confidence: "high" if the description is specific, "med" if rough, "low" if vague or very short.
No prose, no code fence. Output only the JSON object.`
}
```

- [ ] **Step 4: Add the schema and the Pal method**

In `server/src/pal.ts`, add the import for the prompt (extend the existing `import { ... } from './prompts.js'` list with `nutritionEstimatePrompt`).

Add the schema near the other exported schemas:

```ts
export const nutritionEstimateSchema = z.object({
  name: z.string(),
  calLo: z.number(),
  calHi: z.number(),
  confidence: z.enum(['high', 'med', 'low']).catch('low'),
})
export type NutritionEstimate = z.infer<typeof nutritionEstimateSchema>
```

Add the method to the `Pal` class (next to `parse`):

```ts
  async estimateMeal(description: string): Promise<NutritionEstimate> {
    const raw = await this.client.complete(
      [{ role: 'user', content: nutritionEstimatePrompt(description) }],
      { json: true, temperature: 0 },
    )
    return nutritionEstimateSchema.parse(extractJson(raw))
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd server && npx vitest run src/prompts.test.ts src/pal.test.ts`
Expected: PASS.

---

## Task 6: Serve the estimate route (`app.ts`)

**Files:**
- Modify: `server/src/app.ts`
- Test: `server/src/app.test.ts`

- [ ] **Step 1: Write the failing tests**

In `server/src/app.test.ts`:

1. Add `estimateMeal` to `fakePal()`'s returned object:

```ts
    estimateMeal: async () => ({ name: 'Burrito', calLo: 520, calHi: 820, confidence: 'med' }),
```

2. Add a chat-context fixture near `insightsCtxFixture`:

```ts
const chatCtxFixture = {
  userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalKcal: 400, ritualGoal: 5,
  spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 420,
  weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0, hourOfDay: 8, weekday: 6,
}
```

3. Add a `describe` block:

```ts
describe('nutrition + currency contract', () => {
  it('POST /v1/nutrition/estimate returns a calorie range', async () => {
    const { app, token } = buildTestApp()
    const res = await app.inject({
      method: 'POST', url: '/v1/nutrition/estimate',
      headers: { authorization: `Bearer ${token}` }, payload: { text: 'a burrito' },
    })
    expect(res.statusCode).toBe(200)
    expect(res.json()).toMatchObject({ name: 'Burrito', calLo: 520, calHi: 820, confidence: 'med' })
  })

  it('rejects an estimate request with no text', async () => {
    const { app, token } = buildTestApp()
    const res = await app.inject({
      method: 'POST', url: '/v1/nutrition/estimate',
      headers: { authorization: `Bearer ${token}` }, payload: {},
    })
    expect(res.statusCode).toBe(400)
  })

  it('accepts an optional currency descriptor in the chat context', async () => {
    const { app, token } = buildTestApp()
    const context = { ...chatCtxFixture, currency: { symbol: '₫', symbolBefore: false, decimals: 0, group: '.', decimal: ',' } }
    const res = await app.inject({
      method: 'POST', url: '/v1/chat',
      headers: { authorization: `Bearer ${token}` },
      payload: { history: [], message: 'hi', context },
    })
    expect(res.statusCode).toBe(200)
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && npx vitest run src/app.test.ts -t "nutrition + currency"`
Expected: FAIL — `/v1/nutrition/estimate` 404s (route missing).

- [ ] **Step 3: Register the route**

In `server/src/app.ts`, extend the schema import (add `nutritionEstimateBody`):

```ts
import { registerBody, chatBody, parseBody, reviewBody, insightsBody, suggestBody, postWorkoutBody, routineBody, agendaBody, suggestionsBody, emailTestBody, emailSyncBody, healthIngestBody, healthDayQuery, widgetSnapshotBody, memoryRefreshBody, nutritionEstimateBody } from './schemas.js'
```

Add the route next to `/v1/parse` (it needs no token-partitioned memory, so plain `guard`):

```ts
  app.post('/v1/nutrition/estimate', guard(nutritionEstimateBody, async (b) => deps.pal.estimateMeal(b.text)))
```

Add `estimateMeal` to the `Pal` type so the dep typechecks. In `server/src/pal.ts` the `Pal` class already has the method (Task 5); no separate interface to update — `deps.pal` is typed as `Pal`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && npm test`
Expected: PASS (full server suite green).

- [ ] **Step 5: Typecheck the server**

Run: `cd server && npm run build`
Expected: PASS.

---

## Task 7: `log_meal` chat tool (`pal.ts`)

**Files:**
- Modify: `server/src/pal.ts`
- Test: `server/src/pal.test.ts`

- [ ] **Step 1: Write the failing tests**

In `server/src/pal.test.ts`, inside `describe('toolCallsToActions', ...)` add:

```ts
  it('maps a log_meal tool call carrying the model calorie estimate', () => {
    const actions = toolCallsToActions([toolCall('log_meal', { name: 'Burrito', slot: 'Lunch', calLo: 520, calHi: 820, confidence: 'med' })])
    expect(actions).toEqual([{ kind: 'log_meal', name: 'Burrito', slot: 'Lunch', calLo: 520, calHi: 820, confidence: 'med' }])
  })
  it('drops a log_meal with no calorie range', () => {
    expect(toolCallsToActions([toolCall('log_meal', { name: 'Burrito' })])).toEqual([])
  })
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && npx vitest run src/pal.test.ts -t "log_meal"`
Expected: FAIL — `log_meal` is an unknown tool (dropped).

- [ ] **Step 3: Add the action type, parser, tool spec, and synthReply exclusion**

In `server/src/pal.ts`:

Extend the `PalAction` union with a new member:

```ts
  | { kind: 'log_meal'; name: string; slot: string | null; calLo: number; calHi: number; confidence: 'high' | 'med' | 'low' }
```

Add a parser to `TOOL_PARSERS`:

```ts
  log_meal: (a) => {
    const p = z.object({
      name: z.string().trim().min(1), slot: optStr,
      calLo: posInt, calHi: posInt,
      confidence: z.enum(['high', 'med', 'low']).catch('low'),
    }).parse(a)
    return { kind: 'log_meal', name: p.name, slot: p.slot ?? null, calLo: p.calLo, calHi: Math.max(p.calLo, p.calHi), confidence: p.confidence }
  },
```

Add a tool spec to `CHAT_TOOLS` (after `log_ritual`):

```ts
  tool('log_meal', 'Record a meal or drink the user ate, with your own calorie estimate. Use when the user says they ate or drank something (not when they only spent money on it).',
    obj({ name: strProp('short meal name, e.g. "burrito"'), slot: strProp('Breakfast, Lunch, Dinner, Snack, or Drink'), calLo: numProp('low end of the calorie estimate'), calHi: numProp('high end of the calorie estimate'), confidence: strProp('your confidence: high, med, or low') }, ['name', 'calLo', 'calHi'])),
```

In `synthReply`, exclude `log_meal` from the `ackable` set (it gets a card, like the other logs):

```ts
  const ackable = actions.filter(
    (a) =>
      a.kind !== 'log_expense' &&
      a.kind !== 'log_income' &&
      a.kind !== 'log_movement' &&
      a.kind !== 'log_ritual' &&
      a.kind !== 'log_meal',
  )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && npm test`
Expected: PASS.

- [ ] **Step 5: Typecheck**

Run: `cd server && npm run build`
Expected: PASS.

---

## Task 8: `Currency.toWire()` (client)

**Files:**
- Modify: `lib/util/format.dart`
- Test: `test/util/format_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/util/format_test.dart`, add inside `void main()`:

```dart
  test('Currency.toWire emits the server money descriptor', () {
    expect(Currency.usd.toWire(), {
      'symbol': '\$', 'symbolBefore': true, 'decimals': 2, 'group': ',', 'decimal': '.',
    });
    expect(Currency.vnd.toWire(), {
      'symbol': '₫', 'symbolBefore': false, 'decimals': 0, 'group': '.', 'decimal': ',',
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/util/format_test.dart`
Expected: FAIL — `toWire` is not defined on `Currency`.

- [ ] **Step 3: Add the method**

In `lib/util/format.dart`, inside the `Currency` enum (after `fromCode`), add:

```dart
  /// Wire descriptor sent to the Pal proxy so the server renders money in this
  /// currency. Mirrors [formatCurrency]'s inputs; omits the UI-only budgetScale.
  Map<String, Object?> toWire() => {
        'symbol': symbol,
        'symbolBefore': symbolBefore,
        'decimals': decimals,
        'group': groupSeparator,
        'decimal': decimalSeparator,
      };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/util/format_test.dart`
Expected: PASS.

---

## Task 9: Context builders carry currency (client)

**Files:**
- Modify: `lib/services/pal/pal_context_builder.dart`, `lib/controllers/providers.dart`
- Test: `test/services/pal/pal_context_builder_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/services/pal/pal_context_builder_test.dart`, add:

```dart
  test('buildChatContext carries the currency descriptor and formats entries with it', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: const Goals(dailyBudget: 50, dailyMoveKcal: 400, dailyRitualTarget: 3),
      todayEntries: [
        Entry(id: '1', timestamp: DateTime(2026, 6, 20, 8), type: EntryType.money,
            title: 'Coffee', amount: -5, source: EntrySource.manual),
      ],
      weekEntries: const [],
      moveStreakDays: 0,
      currency: Currency.vnd,
      now: DateTime(2026, 6, 20, 8),
    );
    expect(ctx['currency'], Currency.vnd.toWire());
    expect((ctx['todayEntries'] as List).single, contains('₫'));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pal/pal_context_builder_test.dart`
Expected: FAIL — `buildChatContext` has no `currency` parameter.

- [ ] **Step 3: Thread currency through the builders**

In `lib/services/pal/pal_context_builder.dart`:

Add the import for `Currency`/`formatCurrency` (top of file):

```dart
import '../../util/format.dart';
```

Replace `formatEntryLine` to take a currency and use `formatCurrency`:

```dart
/// Formats one timeline entry as the handoff's `HH:MM Title (type, detail)`.
String formatEntryLine(Entry e, Currency currency) {
  final hh = e.timestamp.hour.toString().padLeft(2, '0');
  final mm = e.timestamp.minute.toString().padLeft(2, '0');
  final detail = switch (e.type) {
    EntryType.money =>
      e.amount == null ? '' : formatCurrency(e.amount!, currency, withSign: true),
    EntryType.move => e.duration == null ? '' : '${e.duration}min',
    EntryType.rituals => '',
  };
  return '$hh:$mm ${e.title} (${e.type.wire}${detail.isEmpty ? '' : ', $detail'})';
}
```

In `buildChatContext`, add `Currency currency = Currency.usd,` to the parameter list, format `todayEntries` with it, and add a `currency` key:

```dart
    'todayEntries': todayEntries.map((e) => formatEntryLine(e, currency)).toList(),
```

and add as the last map entry:

```dart
    'currency': currency.toWire(),
```

In `buildReviewContext`, add `Currency currency = Currency.usd,` to the parameters and add as the last map entry:

```dart
    'currency': currency.toWire(),
```

In `buildInsightsContext`, add `Currency currency = Currency.usd,` to the parameters, format the entries list with it, and add a `currency` key:

```dart
    'entries': entries.take(_maxInsightEntries).map((e) => formatEntryLine(e, currency)).toList(),
```

and immediately after the `if (correlationSummary != null) ...` line, add:

```dart
    'currency': currency.toWire(),
```

- [ ] **Step 4: Pass the selected currency from `providers.dart`**

In `lib/controllers/providers.dart`, `settings` (the settings repository, already used for `settings.displayName`) exposes `.currency`. Add `currency: settings.currency,` to all three builder calls:

- In the `chat:` closure, the `buildChatContext(...)` call — add after `routines: await ritualRoutines.getAll(),`:

```dart
        currency: settings.currency,
```

- In the `review:` closure, the `buildReviewContext(...)` call — add after `topCategoryPct: topPct,`:

```dart
        currency: settings.currency,
```

- In the `insights:` closure, the `buildInsightsContext(...)` call — add after `correlationSummary: surfaced.isEmpty ? null : surfaced.first.summary,`:

```dart
        currency: settings.currency,
```

- [ ] **Step 5: Run the test + fix any other flagged call sites**

Run: `flutter test test/services/pal/pal_context_builder_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: no errors. If the analyzer flags another `formatEntryLine(e)` call site (it is only used inside the builders) or a builder call missing arguments, fix it — `currency` is optional (defaults to `Currency.usd`), so existing callers compile unchanged.

- [ ] **Step 6: Run the full context-builder + format suites**

Run: `flutter test test/services/pal/pal_context_builder_test.dart test/services/pal_context_builder_test.dart test/util/format_test.dart`
Expected: PASS.

---

## Task 10: `LogMealAction` model (client)

**Files:**
- Modify: `lib/services/pal/pal_service.dart`
- Test: `test/services/pal/pal_service_action_test.dart` *(new)*

- [ ] **Step 1: Write the failing test**

Create `test/services/pal/pal_service_action_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  test('LogMealAction values define equality', () {
    const a = LogMealAction(
      name: 'Burrito', cal: IntRange(520, 820),
      confidence: NutritionConfidence.med, slot: 'Lunch');
    const b = LogMealAction(
      name: 'Burrito', cal: IntRange(520, 820),
      confidence: NutritionConfidence.med, slot: 'Lunch');
    expect(a, b);
    expect(a, isA<PalAction>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pal/pal_service_action_test.dart`
Expected: FAIL — `LogMealAction` is undefined.

- [ ] **Step 3: Add the action class**

In `lib/services/pal/pal_service.dart`, after `CreateRoutineAction`, add:

```dart
/// Log a meal from chat: the model supplies the meal [name], a calorie range
/// [cal], a [confidence], and an optional [slot]. Fulfilled client-side by
/// inserting a NutritionMeal (source manual) — meals never join the entry
/// timeline. Slot falls back to the time of day when null.
class LogMealAction extends PalAction {
  const LogMealAction({
    required this.name,
    required this.cal,
    required this.confidence,
    this.slot,
  });

  final String name;
  final IntRange cal;
  final NutritionConfidence confidence;
  final String? slot;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogMealAction &&
          other.name == name &&
          other.cal == cal &&
          other.confidence == confidence &&
          other.slot == slot;

  @override
  int get hashCode => Object.hash(name, cal, confidence, slot);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/pal/pal_service_action_test.dart`
Expected: PASS.

---

## Task 11: Decode nutrition colour + `log_meal` (client)

**Files:**
- Modify: `lib/services/pal/http_pal_service.dart`
- Test: `test/services/pal/http_pal_service_test.dart` *(new)*

- [ ] **Step 1: Write the failing test**

Create `test/services/pal/http_pal_service_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

HttpPalService _service(Map<String, dynamic> body) {
  final client = MockClient((req) async => http.Response(
        jsonEncode(body), 200, headers: {'content-type': 'application/json'}));
  return HttpPalService(
    baseUrl: 'https://x.test',
    httpClient: client,
    tokens: TokenProvider(token: () async => 't', clear: () async {}),
    context: PalContextSource(
      chat: () async => {},
      review: (_, __) async => {},
      insights: (_) async => {},
      suggest: (_, __) async => {},
      postWorkout: (_) async => {},
      resolveRoutineTitle: (_) async => null,
    ),
  );
}

void main() {
  test('insights keeps a nutrition colour token (not clamped to rituals)', () async {
    final svc = _service({
      'headline': null, 'lede': null, 'suggestion': null, 'correlationNarration': null,
      'wins': const [],
      'patterns': [
        {'colorToken': 'nutrition', 'title': 'Lighter lunches', 'detail': 'fewer cals midday'}
      ],
    });
    final res = await svc.insights(InsightRange.week);
    expect(res.patterns.single.colorToken, 'nutrition');
  });

  test('chat decodes a log_meal action', () async {
    final svc = _service({
      'reply': 'In the bank.',
      'actions': [
        {'kind': 'log_meal', 'name': 'Burrito', 'slot': 'Lunch', 'calLo': 520, 'calHi': 820, 'confidence': 'med'}
      ],
    });
    final res = await svc.chat(const [], 'had a burrito for lunch');
    final meal = res.actions.single as LogMealAction;
    expect(meal.name, 'Burrito');
    expect(meal.cal, const IntRange(520, 820));
    expect(meal.confidence, NutritionConfidence.med);
    expect(meal.slot, 'Lunch');
  });

  test('chat drops a log_meal missing its calorie range', () async {
    final svc = _service({
      'reply': 'ok',
      'actions': [
        {'kind': 'log_meal', 'name': 'Burrito'}
      ],
    });
    final res = await svc.chat(const [], 'burrito');
    expect(res.actions, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pal/http_pal_service_test.dart`
Expected: FAIL — nutrition token is clamped to `rituals`; `log_meal` decodes to null.

- [ ] **Step 3: Accept nutrition + decode `log_meal`**

In `lib/services/pal/http_pal_service.dart`:

Update `_colorToken` to accept `nutrition`:

```dart
  String _colorToken(Object? raw) => switch (raw) {
        'money' || 'move' || 'rituals' || 'nutrition' => raw! as String,
        _ => 'rituals',
      };
```

Add a `log_meal` case to `_actionFromWire` (before `default:`):

```dart
      case 'log_meal':
        final lo = (a['calLo'] as num?)?.round();
        final hi = (a['calHi'] as num?)?.round();
        final mealName = a['name'] as String?;
        if (lo == null || hi == null || mealName == null || mealName.isEmpty) return null;
        return LogMealAction(
          name: mealName,
          slot: a['slot'] as String?,
          cal: IntRange(lo, hi < lo ? lo : hi),
          confidence: _confidenceFromWire(a['confidence'] as String?),
        );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/pal/http_pal_service_test.dart`
Expected: PASS.

---

## Task 12: Apply + undo a chat-logged meal (client)

**Files:**
- Modify: `lib/controllers/pal_action_executor.dart`
- Test: `test/controllers/pal_action_executor_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/controllers/pal_action_executor_test.dart`, add this test inside `void main()` (after the existing happy-path group). It uses the file's existing `refWith`/`_FakePal` helpers and an in-memory DB:

```dart
  group('applyPalActions — meal', () {
    test('logs a meal and rolls it back on reverse', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ref = refWith(db, _FakePal());

      final applied = await applyPalActions(ref, [
        const LogMealAction(
          name: 'Burrito', cal: IntRange(520, 820),
          confidence: NutritionConfidence.med, slot: 'Lunch'),
      ]);

      expect(applied.mealIds, hasLength(1));
      final repo = NutritionRepository(db);
      final after = await repo.getMealsInRange(
          DateTime(2000), DateTime(2100));
      expect(after.single.name, 'Burrito');
      expect(after.single.cal, const IntRange(520, 820));
      expect(after.single.source, NutritionSource.manual);

      // reverse (mirrors the controller's undo) clears it
      await repo.deleteById(applied.mealIds.single);
      expect(await repo.getMealsInRange(DateTime(2000), DateTime(2100)), isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/pal_action_executor_test.dart -p vm --plain-name "logs a meal"`
Expected: FAIL — `AppliedActions` has no `mealIds`; the executor has no `LogMealAction` case.

- [ ] **Step 3: Add `mealIds`, the executor case, and rollback**

In `lib/controllers/pal_action_executor.dart`:

Add the import for the slot helper (top of file):

```dart
import 'nutrition_controller.dart';
```

Extend `AppliedActions`:

```dart
class AppliedActions {
  const AppliedActions({
    this.entryIds = const [],
    this.routineIds = const [],
    this.mealIds = const [],
    this.priorGoals,
  });

  final List<String> entryIds;
  final List<String> routineIds;
  final List<String> mealIds;
  final Goals? priorGoals;

  bool get isEmpty =>
      entryIds.isEmpty && routineIds.isEmpty && mealIds.isEmpty && priorGoals == null;
}
```

In `applyPalActions`, declare the accumulator next to the others:

```dart
  final mealIds = <String>[];
```

Add a `case` to the `switch (action)` (after `CreateRoutineAction()`):

```dart
        case LogMealAction():
          final est = MealEstimate(
              name: action.name, cal: action.cal, confidence: action.confidence);
          final slot = (action.slot != null && action.slot!.trim().isNotEmpty)
              ? action.slot!.trim()
              : NutritionController.slotForHour(DateTime.now().hour);
          mealIds.add(await ref.read(nutritionRepositoryProvider).insert(
                NutritionMeal(
                  id: '',
                  timestamp: DateTime.now(),
                  slot: slot,
                  name: action.name,
                  source: NutritionSource.manual,
                  icon: NutritionSource.manual.icon,
                  confidence: est.confidence,
                  cal: est.cal,
                  macros: est.macros,
                ),
              ));
```

In the `catch (_)` rollback block, delete created meals (after the routine-id loop):

```dart
    final meals = ref.read(nutritionRepositoryProvider);
    for (final id in mealIds) {
      await meals.deleteById(id);
    }
```

Include `mealIds` in the returned record:

```dart
  return AppliedActions(
    entryIds: entryIds,
    routineIds: routineIds,
    mealIds: mealIds,
    priorGoals: priorGoals,
  );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/pal_action_executor_test.dart`
Expected: PASS (existing tests still green).

---

## Task 13: Undo deletes the meal in the composer (client)

**Files:**
- Modify: `lib/controllers/pal_composer_controller.dart`
- Test: `test/controllers/pal_composer_controller_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/controllers/pal_composer_controller_test.dart`, add inside `void main()`:

```dart
  group('meal undo', () {
    test('undo deletes a chat-logged meal', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final pal = _FakePal(reply: 'In the bank.', actions: const [
        LogMealAction(
          name: 'Burrito', cal: IntRange(520, 820),
          confidence: NutritionConfidence.med, slot: 'Lunch'),
      ]);
      final container = containerWith(db, pal);
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('had a burrito for lunch');
      final repo = NutritionRepository(db);
      expect(await repo.getMealsInRange(DateTime(2000), DateTime(2100)), hasLength(1));

      // the assistant turn is the last message; undo it
      final assistantIndex =
          container.read(palComposerControllerProvider()).messages.length - 1;
      await notifier.undo(assistantIndex);
      expect(await repo.getMealsInRange(DateTime(2000), DateTime(2100)), isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/pal_composer_controller_test.dart --plain-name "undo deletes a chat-logged meal"`
Expected: FAIL — `_reverse` never deletes meals, so the meal survives undo.

- [ ] **Step 3: Delete meals in `_reverse`**

In `lib/controllers/pal_composer_controller.dart`, in `_reverse`, after the routine-deletion loop add:

```dart
    final meals = ref.read(nutritionRepositoryProvider);
    for (final id in rec.mealIds) {
      await meals.deleteById(id);
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/pal_composer_controller_test.dart`
Expected: PASS.

---

## Task 14: Meal confirmation card in chat (client)

**Files:**
- Modify: `lib/screens/pal/pal_composer_screen.dart`
- Test: `test/screens/pal/pal_meal_card_test.dart` *(new)*

- [ ] **Step 1: Write the failing widget test**

Create `test/screens/pal/pal_meal_card_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/pal_composer_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/app_colors.dart';

class _MealPal implements PalService {
  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async =>
      const PalChatResult(reply: 'In the bank.', actions: [
        LogMealAction(
          name: 'Chicken Burrito', cal: IntRange(520, 820),
          confidence: NutritionConfidence.med, slot: 'Lunch'),
      ]);
  @override
  Future<PalAgenda> agenda() async => const PalAgenda();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a chat-logged meal renders a card with its calorie range', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(_MealPal()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light(AppAccent.blue)]),
        home: const Scaffold(body: PalComposerScreen(seed: 'had a burrito for lunch')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chicken Burrito'), findsOneWidget);
    expect(find.textContaining('cal'), findsWidgets);
  });
}
```

> The `ThemeData(useMaterial3: true, extensions: [AppColors.light(...)])` pattern + the `{loopDatabase, palService, sharedPreferences}` overrides match the proven harness in `test/controllers/pal_composer_controller_test.dart` and the app's other widget tests (`test/pal_home_test.dart`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/pal/pal_meal_card_test.dart`
Expected: FAIL — no card renders for a `LogMealAction` (the bubble only handles `LogEntryAction`).

- [ ] **Step 3: Render meal actions in `_Bubble` and add `_MealCard`**

In `lib/screens/pal/pal_composer_screen.dart`, in `_Bubble.build`, replace the log-actions block so it renders a card for both action types:

```dart
    final logActions =
        m.actions.where((a) => a is LogEntryAction || a is LogMealAction).toList();
    if (logActions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final action in logActions)
            if (action is LogEntryAction)
              _LogCard(action: action, undone: m.undone, onUndo: onUndo, onEdit: onEdit)
            else if (action is LogMealAction)
              _MealCard(action: action, undone: m.undone, onUndo: onUndo, onEdit: onEdit),
          if (m.text.trim().isNotEmpty)
            _assistantRow(context, _textBubble(context, m.text, isUser: false)),
        ],
      );
    }
```

Add the `_MealCard` widget (place it right after the `_LogCard` class, before `_CardAction`). It reuses the shared `_CardAction` footer and the nutrition palette; no progress ring (nutrition has no daily target):

```dart
/// The confirmation card shown when a Pal turn logged a meal: a nutrition-tinted
/// LOGGED header, the meal on a leaf tile with its calorie range + confidence,
/// and Undo / Edit. No progress ring — nutrition has no daily calorie target.
class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.action,
    required this.undone,
    this.onUndo,
    this.onEdit,
  });

  final LogMealAction action;
  final bool undone;
  final VoidCallback? onUndo;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.nutrition;
    final slot = action.slot ?? 'Meal';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const PalAvatar(size: 24, glyphSize: 11),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.84),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(Radii.lg),
                  topRight: Radius.circular(Radii.lg),
                  bottomRight: Radius.circular(Radii.lg),
                  bottomLeft: Radius.circular(Radii.xs),
                ),
                border: Border.all(color: c.hair, width: 0.5),
                boxShadow: [
                  BoxShadow(color: c.shadow, blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LOGGED header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.md, Spacing.md, Spacing.md, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 15,
                          height: 15,
                          decoration:
                              BoxDecoration(color: color, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: AppIcon('checkmark', size: 9, color: c.onAccent),
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'LOGGED',
                          style: AppType.caption2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Meal row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: c.nutritionTint,
                              borderRadius: BorderRadius.circular(Radii.md)),
                          alignment: Alignment.center,
                          child: AppIcon('leaf.fill', size: 18, color: color),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.subhead.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.ink,
                                  letterSpacing: -0.24,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '$slot · ${action.confidence.label}',
                                style: AppType.caption.copyWith(
                                    color: c.ink3, letterSpacing: -0.08),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          '${action.cal.lo}–${action.cal.hi} cal',
                          style: AppType.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Undo / Edit (or the undone marker)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.hair, width: 0.5)),
                    ),
                    child: undone
                        ? Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: Spacing.md),
                            child: Center(
                              child: Text(
                                'Undone',
                                style: AppType.footnote.copyWith(
                                    color: c.ink3, letterSpacing: -0.08),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _CardAction(
                                    label: 'Undo', color: c.red, onTap: onUndo),
                              ),
                              Container(width: 0.5, height: 38, color: c.hair),
                              Expanded(
                                child: _CardAction(
                                    label: 'Edit', color: c.accent, onTap: onEdit),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/pal/pal_meal_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Full client suite + analyzer**

Run: `flutter test`
Run: `flutter analyze`
Expected: PASS / no errors.

---

## Task 15: Final verification + single commit (approval-gated)

**Files:** none (verification + commit).

- [ ] **Step 1: Run both full suites**

Run: `cd server && npm test && npm run build`
Run (repo root): `flutter test && flutter analyze`
Expected: all green.

- [ ] **Step 2: Present the commit for approval**

Per the repo owner's git workflow, do not commit unprompted. Show `git status` (files M/A) with a one-line summary each, and propose this message, then ask "Awaiting approval. Proceed? (yes/no)":

```
feat(pal): realign LLM contract with the app

Canonical product.ts vocabulary (entry-type vs dimension tokens,
framing, money() + currency descriptor). Currency now travels in the
context payload and renders on both sides; nutrition is a colour/
correlation dimension; /v1/nutrition/estimate is served; and Pal can
log a meal from chat with a confirmation card + undo.
```

- [ ] **Step 3: On approval, stage and commit**

```bash
git add server/src lib test docs/superpowers
git commit
```

(Use the message from Step 2.)

---

## Verification matrix (spec → task)

- §1 `product.ts` (tokens, framing, `money`, `CurrencyDescriptor`) → Task 1.
- §2 Currency: client `toWire` → Task 8; builders + providers → Task 9; server schema → Task 2; prompts `money()` → Task 3.
- §3 Nutrition vocab: server enum + insights token → Task 4; client `_colorToken` → Task 11.
- §4 `/v1/nutrition/estimate`: prompt/schema/method → Task 5; route → Task 6.
- §5 Meal logging: tool/action/parser → Task 7; `LogMealAction` → Task 10; decode → Task 11; executor + undo → Tasks 12–13; card → Task 14.
- Error handling (currency-optional, dropped malformed actions, route 502 fallback) → Tasks 2/6/7/11 assertions.
