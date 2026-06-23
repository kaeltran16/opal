# Pal ↔ LLM contract realignment

**Date:** 2026-06-23
**Status:** Design — pending implementation plan

## Problem

The app has grown a fourth tracked area (nutrition) and a currency setting, but
the LLM layer (`server/src/prompts.ts`, `schemas.ts`, `pal.ts`) still describes
and serializes the older three-pillar, dollar-only product. Pal's mental model
has drifted from the app's reality:

- **Framing is stale.** `chatSystemPrompt` / `agendaPrompt` / `suggestionsPrompt`
  call the app one that tracks "money, movement and daily rituals" — nutrition
  is invisible to Pal even though it has a tab, meals, and correlations.
- **Dimension tokens diverged.** The on-device correlation engine has
  `Dimension { money, move, rituals, nutrition }` (`lib/analysis/correlations.dart`)
  and surfaces nutrition correlations, but the server's `colorToken` enum
  (`pal.ts`) is still `money | move | rituals`. A nutrition-flavoured
  correlation narration can't carry a nutrition colour — and the client's
  `HttpPalService._colorToken` clamps any unknown token down to `rituals`.
- **Currency is hard-coded to `$` on both sides.** Prompts render `$${...}`
  throughout; the client bakes `\$` into entry strings in
  `formatEntryLine()` (`pal_context_builder.dart`) *before* they reach the
  server. `AppSettings.currency` (USD/VND, full `formatCurrency` support)
  never travels to Pal. A VND user can be told they spent "$12.00".
- **A client feature the backend never serves.** `HttpPalService.estimateMeal()`
  POSTs `/v1/nutrition/estimate`, which does not exist in `app.ts` → 404 →
  `PalException` → silent fallback to `MockPalService.localEstimate`. Every user
  today gets the local heuristic, never the model.
- **No single owner for product vocabulary.** Dimension tokens, the framing
  sentence, and currency rendering are scattered string literals across
  `prompts.ts`, `schemas.ts`, and `pal.ts`. Every new surface has to remember to
  update several unrelated places — which is exactly how this drift happened.

## Goals

1. One canonical, server-side source of truth for product vocabulary that
   prompts and schemas import, so a new dimension/currency is a one-place change.
2. Per-user currency travels in the context payload and is rendered correctly by
   both sides — Pal never speaks the wrong currency.
3. Nutrition is part of Pal's vocabulary: it is named in the framing and is a
   valid colour/correlation dimension end to end.
4. `/v1/nutrition/estimate` exists and is served by the model, closing the dead
   client feature; the local fallback stays for offline/error.
5. Pal can log a meal from chat ("had a burrito for lunch"), with a confirmation
   card + Undo/Edit, matching how logged entries behave.

## Non-goals (explicitly out of scope)

- **Nutrition reasoning in chat/insights.** No daily calorie/macro aggregates or
  meal lines are fed into `buildChatContext`/`buildInsightsContext`. Pal does not
  coach nutrition; the Nutrition tab keeps owning its on-device patterns. The
  single nutrition signal Pal already receives — `InsightsContext.correlation.summary`
  — is unchanged.
- **A daily calorie target.** `Goals` is not extended; the meal card shows a
  calorie range, not a progress ring (see §5).
- **A new `NutritionSource`.** Chat-logged meals reuse `NutritionSource.manual`.
- **Codegen / a shared Dart↔TS schema.** Enum parity across languages stays a
  documented manual contract (see Risks).

## Decisions

| Fork | Decision |
|---|---|
| Nutrition depth | Vocabulary alignment only (no reasoning data into context) |
| `/v1/nutrition/estimate` | Implement now |
| Vocabulary source of truth | Tiny canonical `server/src/product.ts` |
| Meal logging via chat | Yes — full parity (confirmation card + Undo/Edit) |
| Meal card calories | Calorie range + confidence chip, no ring (no calorie goal) |

## Architecture

Five workstreams. §1 is the foundation the rest import; §2–4 are
contract-alignment; §5 is the one new user-facing capability.

### 1. Canonical vocabulary module — `server/src/product.ts` (new)

The single owner of product vocabulary. `prompts.ts`, `schemas.ts`, and `pal.ts`
import from it; nothing else re-declares these tokens.

```ts
// Timeline entry types — what /chat log-tools and /parse may emit. NOT nutrition:
// meals live in the Nutrition tab / the log_meal tool, never on the entry timeline.
export const ENTRY_TYPES = ['money', 'move', 'rituals'] as const
export type EntryTypeToken = (typeof ENTRY_TYPES)[number]

// Trackable dimensions for colour + correlation. Adds nutrition.
export const DIMENSIONS = ['money', 'move', 'rituals', 'nutrition'] as const
export type DimensionToken = (typeof DIMENSIONS)[number]

// One framing sentence every prompt reuses.
export const PRODUCT_FRAMING =
  'an iOS app that tracks money, movement, daily rituals, and nutrition'

// Per-user currency, shipped in the context payload (the server has no currency
// table — the client is the source of truth). Mirrors the fields the client's
// Currency enum already carries.
export interface CurrencyDescriptor {
  symbol: string
  symbolBefore: boolean
  decimals: number
  group: string   // thousands separator
  decimal: string // decimal mark
}
export const USD: CurrencyDescriptor = {
  symbol: '$', symbolBefore: true, decimals: 2, group: ',', decimal: '.',
}

// Renders an amount in the user's currency. Mirrors the client's formatCurrency:
// trims a .00 tail on whole amounts, places the symbol per symbolBefore, groups
// thousands. Defaults to USD so an older client (no currency field) is safe.
export function money(amount: number, c: CurrencyDescriptor = USD): string { /* … */ }
```

**The two token sets are distinct on purpose.** `ENTRY_TYPES` is the set a chat
log-tool or `/parse` may produce; nutrition is *not* one, because the client's
`_entryTypeFromWire` coerces unknown types to `money` and would silently corrupt
data. `DIMENSIONS` is the colour/correlation set and gains nutrition. Conflating
them is the bug to avoid.

### 2. Currency propagation

**Client**
- Add `CurrencyDescriptor toWire()` (or a `Map` getter) to the `Currency` enum in
  `lib/util/format.dart` — keeps `format.dart` the single owner of currency.
  Emits `{symbol, symbolBefore, decimals, group, decimal}` (no `budgetScale` —
  UI-only).
- `buildChatContext` / `buildReviewContext` / `buildInsightsContext`
  (`pal_context_builder.dart`) take a `Currency currency` param and add a
  `'currency'` key to the wire map.
- `formatEntryLine(Entry e, Currency currency)` replaces the hard-coded
  `\$${amount}` with `formatCurrency(e.amount!.abs(), currency, withSign: true)`.
- `providers.dart` passes `settings.currency` into each builder.

**Server**
- The `chatContext`, `reviewContext`, and `insightsContext` Zod schemas gain an
  optional `currency` object. Optional + the `USD` default in `money()` means an
  older client never breaks.
- Every `$${...}` in `chatSystemPrompt`, `reviewPrompt`, `insightsPrompt`,
  `agendaPrompt`, and `memoryPatternsPrompt` becomes `money(value, c.currency)`.
- `parsePrompt` already states "do not assume a currency" / "no currency symbol"
  — unchanged.

Money stays a `number` on the wire (the model still needs raw magnitudes); only
the *rendering* moves behind `money()`.

### 3. Nutrition vocabulary alignment

- `pal.ts`: `const colorToken = z.enum(DIMENSIONS)` (now four values). The
  `parseSchema.type` and `suggestionEntry.type` enums stay `z.enum(ENTRY_TYPES)`
  (three values) — see §1.
- Prompts advertise the tokens matching their *grounded data*: `insightsPrompt`
  lists all four (its `correlation.summary` can be about calories), while
  `agenda`/`suggestions` keep the three entry pillars (they carry no nutrition
  data). The enum stays permissive for decode safety; prompt text stays specific
  for grounding.
- The framing sentence (§1) now names nutrition. The chat prompt's tool guidance
  gains a meal example (see §5) — note this *replaces* any "meals aren't logged
  from chat" wording, since §5 makes them loggable.
- **Client:** `HttpPalService._colorToken` accepts `'nutrition'` (theme already
  has `nutrition`/`nutritionTint`; `AppColors.forType` already maps it).

### 4. Nutrition estimate route — `POST /v1/nutrition/estimate`

Mirrors the existing `/v1/parse` shape exactly.

- `prompts.ts`: `nutritionEstimatePrompt(description: string)` — asks for a
  calorie range + confidence for a free-text meal, JSON only.
- `pal.ts`: `nutritionEstimateSchema = z.object({ name: z.string(), calLo:
  z.number(), calHi: z.number(), confidence: z.enum(['high','med','low']) })`
  and `Pal.estimateMeal(description)` (JSON mode, `temperature: 0`).
- `schemas.ts`: `nutritionEstimateBody = z.object({ text: z.string() })`.
- `app.ts`: `app.post('/v1/nutrition/estimate', guard(nutritionEstimateBody, b =>
  deps.pal.estimateMeal(b.text)))`.

Wire response `{ name, calLo, calHi, confidence }` already matches the client's
existing decode in `HttpPalService.estimateMeal`; its `PalException` →
`MockPalService.localEstimate` fallback is unchanged. No client change needed
for this workstream.

### 5. Meal logging via chat — full parity

The model emits the intent and its own calorie estimate in one tool call; the
client persists a meal and shows a confirmation card with Undo/Edit, reusing the
existing chat action/undo spine.

**Server**
- New chat tool `log_meal` in `CHAT_TOOLS` (`pal.ts`), args:
  `name` (string, required), `slot` (string, optional —
  `breakfast|lunch|dinner|snack`), `calLo` (number), `calHi` (number),
  `confidence` (`high|med|low`). The model self-estimates calories (same model
  that backs §4); this keeps the card self-contained and avoids a second
  round-trip mid-chat.
- New `PalAction` union member `{ kind: 'log_meal', name, slot, calLo, calHi,
  confidence }` and a `TOOL_PARSERS.log_meal` that validates/drops malformed
  calls like the others.
- The chat prompt's tool guidance adds: `"had a burrito for lunch" calls
  log_meal`.

**Client**
- `pal_service.dart`: new `LogMealAction extends PalAction { name, slot, cal
  (IntRange), confidence }`; decoded in `HttpPalService._actionFromWire`
  (`case 'log_meal'`, dropping the action if `calLo`/`calHi` are absent).
- `pal_action_executor.dart`: a `case LogMealAction()` builds a `MealEstimate`
  from the action and inserts a `NutritionMeal` (source `manual`, slot from the
  action or inferred from the hour when null) via `nutritionRepositoryProvider`,
  mirroring `NutritionController.addMeal`. Record the new id.
- `AppliedActions` gains `mealIds: List<String>`; the rollback in
  `applyPalActions` and `_reverse` in `pal_composer_controller.dart` delete meals
  by id (alongside the existing `entryIds`/`routineIds`). `isEmpty` includes it.
- `pal_composer_screen.dart`: `_Bubble` renders a meal variant of `_LogCard` for
  a `LogMealAction` — meal name, `"≈ {mid} cal"` + a confidence chip (reusing the
  nutrition calorie/meal-row styling), with the same Undo/Edit affordances.
  **No progress ring** — nutrition has no daily target (§Non-goals).

## Error handling

- `/v1/nutrition/estimate`: malformed model JSON → schema parse throws →
  `guard` maps to 502 → client `estimateMeal` catches `PalException` → local
  fallback. Unchanged behaviour.
- `log_meal` with missing/garbled args: dropped by the tool parser (server) or
  `_actionFromWire` (client), exactly like the other actions — no card, no write.
- Mixed-action chat turns (e.g. an expense + a meal) roll back atomically:
  `applyPalActions` already deletes everything it created on a mid-batch failure;
  `mealIds` joins that path.
- Missing `currency` on the wire → `money()` falls back to `USD`.

## Testing

**Server**
- `money()`: USD trims `.00` on whole amounts, keeps cents; VND trails the symbol,
  0 decimals, `.` grouping; absent descriptor → USD.
- `product.ts`: `ENTRY_TYPES` (3) vs `DIMENSIONS` (4) are the expected sets.
- `/v1/nutrition/estimate`: route returns `{name,calLo,calHi,confidence}` from a
  stubbed completion; bad JSON → 502.
- `colorToken` accepts `nutrition`; `parseSchema.type` rejects it.
- `log_meal` tool call → `PalAction`; malformed args dropped.
- Context schemas accept and round-trip the optional `currency`.

**Client**
- `formatEntryLine` renders a money entry under VND correctly.
- Context builders include the currency descriptor.
- `_colorToken` passes `nutrition` through (not clamped to `rituals`).
- `_actionFromWire` decodes `log_meal`; drops it when calories are missing.
- `applyPalActions` inserts a `NutritionMeal` for a `LogMealAction` and undo
  deletes it; mixed-action rollback removes the meal too.
- Composer renders the meal confirmation card with Undo/Edit.

**Update existing**
- `pal_context_builder_test.dart`, `pal/pal_context_builder_test.dart`
  (new `currency` param + key).
- `mock_estimate_meal_test.dart` (unchanged behaviour, but verify the real path).
- `pal_action_executor_test.dart` (new `mealIds`/meal case).

## Files touched

**Server (`server/src/`)**: **+`product.ts`**, `prompts.ts`, `pal.ts`,
`schemas.ts`, `app.ts`.

**Client (`lib/`)**: `util/format.dart` (`Currency.toWire`),
`services/pal/pal_context_builder.dart`, `services/pal/http_pal_service.dart`,
`services/pal/pal_service.dart` (`LogMealAction`), `controllers/providers.dart`,
`controllers/pal_action_executor.dart`, `controllers/pal_composer_controller.dart`,
`screens/pal/pal_composer_screen.dart`.

## Risks / notes

- **Cross-language enum sync is manual.** A server `product.ts` makes the *server*
  single-source, but the Dart `Currency` / `Dimension` / `EntryType` enums still
  have to agree on wire strings by hand. Documented; codegen is overkill for two
  enums and one currency table.
- **Chat-logged calories vs the route's estimate.** Meal logging uses the model's
  inline self-estimate (§5); the Nutrition tab's manual add uses `/v1/nutrition/estimate`
  (§4). Both are the same model, so values are close but not guaranteed identical.
  Accepted.
- **`log_meal` is the only behaviour change** in this effort; it is additive (a
  new tool + action + executor case) and does not alter the existing
  entry/goal/routine paths.
