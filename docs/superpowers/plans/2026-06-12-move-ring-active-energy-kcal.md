# Move Ring → Active-Energy kcal (Apple Watch) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-base opal's daily "move" ring from minutes to active-energy kilocalories, capture kcal on every move entry, and feed today's Apple-Watch active energy into the ring via the existing `/v1/health/ingest` server (read-back through a new `GET /v1/health/day`).

**Architecture:** The per-entry `Entry.calories` column already exists and is persisted/seeded; the move *total* is derived at runtime by summing entries. So the core change is (a) sum `calories` instead of `duration`, (b) rename the single `Goals.dailyMoveMinutes` column to `dailyMoveKcal` (Drift migration v5→v6), (c) make all logging paths capture kcal, (d) rename the minutes wire-fields/labels across the Pal LLM contract and the iOS rings widget, and (e) add a client `HealthService` that reads today's metrics from the server and upserts one health-sourced move `Entry`.

**Tech stack:** Flutter/Dart (Riverpod codegen, Drift ORM), iOS WidgetKit (Swift, App Group `group.com.opal.opal`), Node/Fastify + Zod + better-sqlite3 server, Vitest + flutter_test.

---

## Naming contract (use these EXACT names in every task)

| Concept | Old | New |
|---|---|---|
| Model field | `Goals.dailyMoveMinutes` (int, def 60) | `Goals.dailyMoveKcal` (int, def 500) |
| DB column | `daily_move_minutes` | `daily_move_kcal` |
| Drift getter | `dailyMoveMinutes` | `dailyMoveKcal` |
| Today/Move state | `moveMinutes` | `moveKcal` |
| GoalTarget enum | `GoalTarget.dailyMoveMinutes` | `GoalTarget.dailyMoveKcal` |
| Chat wire | `moveGoalMin` / `movedTodayMin` / `weekMovedMin` | `moveGoalKcal` / `movedTodayKcal` / `weekMovedKcal` |
| Insights wire | `moveMinutes` / `moveTarget` | `moveKcal` / `moveTargetKcal` |
| Review wire | `hoursMoved` | `kcalMoved` |
| Widget keys | `moveMinutes` / `dailyMoveMinutes` | `moveKcal` / `dailyMoveKcal` |
| Pal tool arg | `set_move_goal.dailyMoveMinutes` | `set_move_goal.dailyMoveKcal` |
| Pal tool (new) | — | `log_movement.calories` (optional int) |
| UI unit label | `min` / `MIN` / `m` | `kcal` |

**Defaults/ranges (product choices — confirm before Phase 2):** default goal `500` kcal; onboarding chips `300/500/700/900`; settings stepper step `±50`, clamp `0–5000`.

**UNCHANGED (do NOT rename):** `moveStreakDays`, `streakDays` (days), `movedDeltaPct` (percent), the `'move'` color/type token, `Entry.duration` (still shown as "30 min" on the timeline), `Workout.duration`/`weekMinutes`/`durationMinutes` (training-session minutes, a separate concept from the move ring).

## Deploy coordination (READ FIRST — contract break)

The server validates request bodies with Zod; renaming chat/insights/review wire-fields makes the **new server reject an old app** and vice-versa. This is a single-user app (Kael), so the release is coordinated:
1. Land all phases on `main` together.
2. The server auto-deploys on push (GitHub Action). The Flutter app must be rebuilt/reinstalled from the same commit.
3. Do **not** push Phase 6 (server contract) without the matching client phases in the same release.

---

## PHASE 1 — Server: `GET /v1/health/day` read endpoint

Net-new, additive, no contract break. Build first so the client has something to read.

### Task 1.1: `HealthStore.getDay`

**Files:**
- Modify: `server/src/health.ts`
- Test: `server/src/health.test.ts`

- [ ] **Step 1: Write failing test** — append to `server/src/health.test.ts`:

```ts
it('getDay returns all metrics for a date as a map', () => {
  store.upsert('2026-06-12', { steps: { value: 8423, unit: 'count' }, activeEnergy: { value: 412, unit: 'kcal' } }, '2026-06-12T20:00:00Z')
  expect(store.getDay('2026-06-12')).toEqual({
    steps: { value: 8423, unit: 'count' },
    activeEnergy: { value: 412, unit: 'kcal' },
  })
})

it('getDay returns an empty map for a day with no data', () => {
  expect(store.getDay('2026-01-01')).toEqual({})
})
```

- [ ] **Step 2: Run, verify fail** — `cd server && npx vitest run src/health.test.ts` → FAIL (`getDay is not a function`).

- [ ] **Step 3: Implement** — add to the `HealthStore` class in `server/src/health.ts`:

```ts
getDay(date: string): Record<string, Metric> {
  const rows = this.db
    .prepare('SELECT metric, value, unit FROM health_metrics WHERE date = ?')
    .all(date) as { metric: string; value: number; unit: string }[]
  const out: Record<string, Metric> = {}
  for (const r of rows) out[r.metric] = { value: r.value, unit: r.unit }
  return out
}
```

- [ ] **Step 4: Run, verify pass** — `npx vitest run src/health.test.ts` → PASS.
- [ ] **Step 5: Commit** — `git add server/src/health.ts server/src/health.test.ts && git commit -m "feat(server): HealthStore.getDay reads a day's metrics"`

### Task 1.2: route `GET /v1/health/day?date=`

**Files:**
- Modify: `server/src/schemas.ts`, `server/src/app.ts`
- Test: `server/src/app.test.ts`

- [ ] **Step 1: Failing test** — in `server/src/app.test.ts`, after the existing health ingest tests, add:

```ts
it('reads back an ingested day', async () => {
  const token = store.issue('d1')
  await app.inject({ method: 'POST', url: '/v1/health/ingest', headers: { authorization: `Bearer ${token}` }, payload: health })
  const res = await app.inject({ method: 'GET', url: '/v1/health/day?date=2026-06-12', headers: { authorization: `Bearer ${token}` } })
  expect(res.statusCode).toBe(200)
  expect(res.json().metrics.steps.value).toBe(8423)
})

it('rejects /v1/health/day with a bad date', async () => {
  const token = store.issue('d1')
  const res = await app.inject({ method: 'GET', url: '/v1/health/day?date=bad', headers: { authorization: `Bearer ${token}` } })
  expect(res.statusCode).toBe(400)
})
```

Note: the existing `build()` helper shares one `healthStore` per app instance, so the ingest+read in the first test hit the same store.

- [ ] **Step 2: Run, verify fail** — `npx vitest run src/app.test.ts` → FAIL (404/400).

- [ ] **Step 3: Schema** — add to `server/src/schemas.ts`:

```ts
export const healthDayQuery = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
})
```

- [ ] **Step 4: Route** — in `server/src/app.ts`, import `healthDayQuery`, then after the ingest route add:

```ts
app.get('/v1/health/day', async (req, reply) => {
  const parsed = healthDayQuery.safeParse(req.query)
  if (!parsed.success) return reply.code(400).send({ error: { code: 'bad_request', message: 'invalid query' } })
  return { date: parsed.data.date, metrics: deps.healthStore.getDay(parsed.data.date) }
})
```

(Bearer guard already covers all `/v1/*` via the existing `preHandler`.)

- [ ] **Step 5: Run, verify pass** — `npx vitest run` (server) → all PASS.
- [ ] **Step 6: Commit** — `git add server/src/schemas.ts server/src/app.ts server/src/app.test.ts && git commit -m "feat(server): GET /v1/health/day reads a day's metrics"`

---

## PHASE 2 — DB migration + `Goals` model (minutes → kcal)

This is the schema/data change. After this phase the app stores a kcal goal; UI/derivation still reference minutes until later phases, so **expect the app not to compile until Phase 4 completes** — Phases 2–7 land as one release (see Deploy coordination). Each task still commits independently.

### Task 2.1: `Goals` model

**Files:** Modify `lib/models/goals.dart`; Test `test/models_test.dart`

- [ ] **Step 1: Failing test** — in `test/models_test.dart` add:

```dart
test('Goals defaults to 500 kcal move goal', () {
  expect(const Goals().dailyMoveKcal, 500);
});
```

- [ ] **Step 2: Run, fail** — `flutter test test/models_test.dart` → FAIL (no `dailyMoveKcal`).
- [ ] **Step 3: Implement** — in `lib/models/goals.dart` rename every `dailyMoveMinutes` → `dailyMoveKcal`, change default `60` → `500`, and update `toString` line 43 from `move: ${dailyMoveMinutes}min` → `move: ${dailyMoveKcal}kcal`. (Constructor, field, `copyWith`, `==`, `hashCode`, `toString`.)
- [ ] **Step 4: Run, pass** — `flutter test test/models_test.dart` → PASS.
- [ ] **Step 5: Commit** — `git add lib/models/goals.dart test/models_test.dart && git commit -m "refactor(goals): dailyMoveMinutes -> dailyMoveKcal (default 500)"`

### Task 2.2: Drift table + migration v5→v6

**Files:** Modify `lib/data/db/tables.dart`, `lib/data/db/database.dart`; regenerate `database.g.dart`

- [ ] **Step 1: Table** — in `lib/data/db/tables.dart` (GoalsTable, ~line 223) replace:

```dart
IntColumn get dailyMoveMinutes => integer().withDefault(const Constant(60))();
```
with
```dart
IntColumn get dailyMoveKcal => integer().withDefault(const Constant(500))();
```
The generated SQL column name auto-derives to `daily_move_kcal`.

- [ ] **Step 2: Bump schemaVersion** — in `lib/data/db/database.dart` line 37, `schemaVersion => 5` → `=> 6`.

- [ ] **Step 3: Migration** — in the `onUpgrade` chain (after the `from < 5` block) add:

```dart
if (from < 6) {
  // rename move goal column minutes -> kcal, converting old minute goals to a
  // reasonable kcal default (minutes are not convertible to kcal, so seed 500).
  await customStatement(
    'ALTER TABLE goals ADD COLUMN daily_move_kcal INTEGER NOT NULL DEFAULT 500');
  await customStatement('UPDATE goals SET daily_move_kcal = 500');
}
```
(We keep the legacy `daily_move_minutes` column in the DB rather than dropping it — SQLite drop-column is fragile across drift flows, and the mapper simply stops reading it. Document this.)

- [ ] **Step 4: Regenerate** — `dart run build_runner build --delete-conflicting-outputs`. Confirm `database.g.dart` now exposes `dailyMoveKcal` / `daily_move_kcal`.

- [ ] **Step 5: Migration test** — add `test/db_migration_test.dart`:

```dart
// opens a v5 DB, runs migration, asserts goals.dailyMoveKcal == 500.
// (use drift's NativeDatabase.memory + the schema-test harness if present;
//  otherwise assert get/save round-trips the new column.)
```
Run `flutter test test/db_migration_test.dart` → PASS.

- [ ] **Step 6: Commit** — `git add lib/data/db/ test/db_migration_test.dart && git commit -m "feat(db): migrate goals move column to kcal (schema v6)"`

### Task 2.3: mappers + seed

**Files:** Modify `lib/data/db/mappers.dart` (lines 303, 312), `lib/data/seed/seed_data.dart` (line 35)

- [ ] **Step 1** — in `mappers.dart` rename both `dailyMoveMinutes:` references → `dailyMoveKcal:` (in `toModel()` and `toCompanion()`).
- [ ] **Step 2** — in `seed_data.dart` line 35, `dailyMoveMinutes: 60` → `dailyMoveKcal: 500`.
- [ ] **Step 3: Run** — `flutter analyze lib/data` (expect remaining errors only in not-yet-touched controllers).
- [ ] **Step 4: Commit** — `git add lib/data && git commit -m "refactor(data): map/seed goals move kcal"`

---

## PHASE 3 — Capture kcal on every move entry

So manual + Pal-logged workouts contribute to the kcal ring.

### Task 3.1: manual entry sheet — calories field

**Files:** Modify `lib/screens/entry/new_entry_sheet.dart` (move branch, ~line 314), its controller/draft; Test `test/` entry sheet test if present.

- [ ] **Step 1** — read `new_entry_sheet.dart` move branch. It currently captures `durationMinutes`. Add a numeric "Calories (kcal)" input bound to a new draft field `calories` (int?), shown only for `EntryType.move`. Persist it onto the created `Entry.calories`.
- [ ] **Step 2** — wherever the sheet builds the `Entry` for a move log, set `calories: <input>` alongside the existing `duration:`.
- [ ] **Step 3: Test** — add/extend a widget or controller test asserting a logged move entry carries the entered `calories`.
- [ ] **Step 4: Commit** — `git commit -m "feat(entry): capture calories on manual move entries"`

### Task 3.2: Pal `log_movement` gains `calories` (server)

**Files:** Modify `server/src/pal.ts`; Test `server/src/pal.test.ts`

- [ ] **Step 1: Failing test** — in `pal.test.ts`, change the `log_movement` tool call (line ~161) to include calories and assert it surfaces:

```ts
toolCall('log_movement', { durationMinutes: 30, calories: 240, title: 'Run' })
// assert the decoded action carries calories: 240
```

- [ ] **Step 2** — in `pal.ts`: add `calories: number` (optional) to the `log_movement` action union (~line 212) and tool JSON schema (~line 270-271, add property `calories` desc `'kcal burned, if known'`), parse it in the handler (~line 242-244), and include it in the confirmation string (~line 310): `` `logged ${a.durationMinutes} min / ${a.calories ?? 0} kcal of ${a.title}` ``.
- [ ] **Step 3: Run** — `npx vitest run src/pal.test.ts` → PASS.
- [ ] **Step 4: Commit** — `git commit -m "feat(server): log_movement carries optional calories"`

### Task 3.3: client decodes `calories` from `log_movement`

**Files:** Modify `lib/services/pal/pal_service.dart` (`LogEntryAction`), `lib/services/pal/http_pal_service.dart` (tool-call parse ~line 118/135), `lib/controllers/pal_action_executor.dart` (`_entryFor` ~line 88), `lib/services/pal/mock_pal_service.dart` (line 127 copy); Tests `test/services/http_pal_service_test.dart`.

- [ ] **Step 1** — add `final int? calories;` to `LogEntryAction` (constructor, `==`, `hashCode`).
- [ ] **Step 2** — in `http_pal_service.dart` parse `calories` from the `log_movement` args into `LogEntryAction(calories: ...)`.
- [ ] **Step 3** — in `pal_action_executor.dart` `_entryFor`, set `calories: a.type == EntryType.move ? a.calories : null`.
- [ ] **Step 4** — update `mock_pal_service.dart:127` copy to include kcal.
- [ ] **Step 5: Test** — extend `http_pal_service_test.dart` to assert a `log_movement` response with calories decodes to `LogEntryAction.calories`.
- [ ] **Step 6: Commit** — `git commit -m "feat(pal): client carries calories from log_movement to Entry"`

---

## PHASE 4 — Move total derivation: sum calories, not duration

After this phase the app compiles again and the ring reflects kcal.

### Task 4.1: `today_controller`

**Files:** Modify `lib/controllers/today_controller.dart` (lines 54-57 + 72-73); Test `test/today_screen_test.dart` / a today controller test.

- [ ] **Step 1: Failing test** — assert `TodayState.moveKcal` sums `calories` of today's move entries and `moveRing == moveKcal / goals.dailyMoveKcal`.
- [ ] **Step 2** — rename getter `moveMinutes` → `moveKcal`; body sums `e.calories ?? 0`. Update `moveRing` to divide by `goals.dailyMoveKcal`.
- [ ] **Step 3: Run/pass; Step 4: Commit** — `git commit -m "feat(today): move ring sums active-energy kcal"`

### Task 4.2: `move_controller`, `weekly_review_controller`, `monthly_review_controller`, `profile_controller`, `providers.dart`

**Files:** Modify each; update matching tests (`test/weekly_review_test.dart`, `test/monthly_review_test.dart`, `test/profile_test.dart`).

- [ ] For each controller, change the `fold(e.duration ?? 0)` move-total to `fold(e.calories ?? 0)` and rename the exposed field to `moveKcal` (and `moveTarget` → kcal-based: `goals.dailyMoveKcal * periodDays`). Keep workout `durationMinutes`/`weekMinutes` untouched.
- [ ] Update each controller's test fixtures to set `calories` on move entries and assert kcal totals.
- [ ] Commit per controller: `git commit -m "feat(<controller>): move totals in kcal"`

---

## PHASE 5 — UI labels min → kcal

Pure presentation. One task per screen; each: change label/unit string, run the screen's test, commit.

- [ ] **5.1 `lib/screens/today/today_screen.dart`** — RingStat (145-149) `goal: '/ ${goals.dailyMoveKcal} KCAL'`, `value: '${today.moveKcal}'`; SummaryTile (223-233) `big: '${today.moveKcal}'`, `unit: 'KCAL'`, `sub: 'of ${goals.dailyMoveKcal} kcal goal'`; timeline move row (556-562) — keep `'${entry.duration} min'` for duration display (duration unchanged) but if `calories != null` prefer `'${entry.calories} kcal'`. Run `flutter test test/today_screen_test.dart`. Commit.
- [ ] **5.2 `budgets_goals_screen.dart`** — `_move` loaded from `g.dailyMoveKcal`, saved to `Goals(dailyMoveKcal: _move...)`; stepper (110-118) `value: '$_move kcal'`, `onMinus/onPlus` step `±50`, clamp `0..5000`. Commit.
- [ ] **5.3 `onboarding_screen.dart`** — `_moveOptions = [300,500,700,900]`, `_moveMinutes`→`_moveKcal=500`, big value `'$_moveKcal KCAL'`, chips `'$m kcal'`, save `dailyMoveKcal`, body copy (279) → "Any session counts — we track the calories you burn." Update `test/onboarding_test.dart`. Commit.
- [ ] **5.4 `profile_screen.dart`** (199-205) — `value: '${goals.dailyMoveKcal} kcal'`. Commit.
- [ ] **5.5 `weekly_review_controller`/screen** tile (113-118) — `sub: 'of $moveTargetKcal kcal'`, value `$moveKcal`. Commit.
- [ ] **5.6 `monthly_review_controller`/screen** row (174-181) — `unit: 'kcal'`, value `$moveKcal`. Commit.
- [ ] **5.7 `streak_celebration_screen.dart`** (36-52) — pills `'${stats.moveKcal} kcal'` and best-day `'$wd · ${stats.bestMoveDayKcal} kcal'`. Commit.
- [ ] **5.8 `move_screen.dart`** (710-711) — leave per-session `durationMinutes`/`'min'` (training duration, not the ring) UNLESS it shows the daily move total; verify and only change the daily-total surface. Commit.

---

## PHASE 6 — Server LLM contract rename (lockstep with client context builder)

### Task 6.1: server schemas + prompts + interfaces

**Files:** Modify `server/src/schemas.ts`, `server/src/prompts.ts`; Tests `server/src/prompts.test.ts`, `server/src/pal.test.ts`.

- [ ] **Step 1: Update tests first** — in `prompts.test.ts` and `pal.test.ts`, rename context fields per the Naming contract (`moveGoalMin`→`moveGoalKcal`, `movedTodayMin`→`movedTodayKcal`, `weekMovedMin`→`weekMovedKcal`, `moveMinutes`→`moveKcal`, `moveTarget`→`moveTargetKcal`, `hoursMoved`→`kcalMoved`) and update the asserted prompt substrings to the kcal wording (see Step 3).
- [ ] **Step 2: schemas.ts** — rename the fields in `chatContext` (L12/15/19), `insightsContext` (L44), `reviewContext` (L35) accordingly (all stay `z.number()`).
- [ ] **Step 3: prompts.ts** — update the TS interfaces (`ChatContext`/`ReviewContext`/`InsightsContext`) to the new names AND the rendered strings:
  - L73 `move goal ${c.moveGoalKcal}kcal`
  - L74 `moved ${c.movedTodayKcal}kcal`
  - L76 `${c.weekMovedKcal}kcal moved`
  - L90 (review) `${c.kcalMoved}kcal moved${deltaPhrase(c.movedDeltaPct)}`
  - L107 (insights) `${c.moveKcal} of ${c.moveTargetKcal} move kcal`
  - Leave parse-section duration wording (L125/128/131) — that's per-entry minutes, unchanged.
- [ ] **Step 4: set_move_goal tool** — in `pal.ts` rename arg `dailyMoveMinutes`→`dailyMoveKcal` (action union L215, handler L251, tool desc L276-277 → "in kcal", confirmation L313 → "kcal").
- [ ] **Step 5: Run** — `npx vitest run` (server) → all PASS.
- [ ] **Step 6: Commit** — `git commit -m "feat(server): move LLM contract switches minutes->kcal"`

### Task 6.2: client context builder + http service (lockstep)

**Files:** Modify `lib/services/pal/pal_context_builder.dart`, `lib/services/pal/http_pal_service.dart`, `lib/services/pal/pal_service.dart` (`GoalTarget`); Tests `test/services/pal_context_builder_test.dart`, `test/services/http_pal_service_test.dart`.

- [ ] **Step 1: Tests first** — rename keys in both test files; change `_movedMin` helper fixtures to set `calories` and assert kcal totals; `movedTodayMin`→`movedTodayKcal` etc.
- [ ] **Step 2** — in `pal_context_builder.dart`: rename helper `_movedMin`→`_movedKcal` summing `e.calories`; emit `moveGoalKcal: goals.dailyMoveKcal` (L41), `movedTodayKcal` (L44), `weekMovedKcal` (L48), `moveKcal`/`moveTargetKcal` (L170-171 with `goals.dailyMoveKcal * periodDays`), review `kcalMoved` (L76). Update per-entry line (L10): keep `'${e.duration}min'` (duration still displayed) — unchanged.
- [ ] **Step 3** — in `pal_service.dart` rename `GoalTarget.dailyMoveMinutes`→`dailyMoveKcal`; in `http_pal_service.dart` (L148-149) parse `dailyMoveKcal` into `SetGoalAction(target: GoalTarget.dailyMoveKcal, ...)`.
- [ ] **Step 4** — in `pal_action_executor.dart` `_applyGoal` (L96): `GoalTarget.dailyMoveKcal => g.copyWith(dailyMoveKcal: a.value.round())`.
- [ ] **Step 5: Run** — `flutter test test/services/` → PASS.
- [ ] **Step 6: Commit** — `git commit -m "feat(pal): client move context switches to kcal"`

---

## PHASE 7 — iOS rings widget (Swift) kcal

Keys are matched by string across Dart↔Swift — change BOTH sides together.

### Task 7.1: Dart widget sync

**Files:** Modify `lib/services/widget_sync/widget_sync_service.dart` (params+keys L19/22/23, L78/82/83), `lib/controllers/widget_sync_controller.dart` (L24/28/29); Tests `test/services/widget_sync_service_test.dart`, `test/controllers/widget_sync_controller_test.dart`.

- [ ] **Step 1: Tests first** — rename `moveMinutes`→`moveKcal`, `dailyMoveMinutes`→`dailyMoveKcal` in `syncSample`/`_sampleState` and assertions; sample state move entry sets `calories` (e.g. 240) and `Goals(dailyMoveKcal: 500)`.
- [ ] **Step 2** — rename the `sync(...)` params and the payload map keys to `moveKcal`/`dailyMoveKcal`; source them from `s.moveKcal` / `s.goals.dailyMoveKcal`.
- [ ] **Step 3: Run** — `flutter test test/services/widget_sync_service_test.dart test/controllers/widget_sync_controller_test.dart` → PASS.
- [ ] **Step 4: Commit** — `git commit -m "feat(widget): dart sync sends move kcal"`

### Task 7.2: Swift widget

**Files:** Modify `ios/Runner/Widgets/OpalWidgetSyncBridge.swift` (L34-35), `ios/OpalWidgets/OpalRingsSnapshot.swift` (fields L24-25, Key L42-43, save L60-61, load L76-77, `.empty` L33-34), `ios/OpalWidgets/OpalRingsWidget.swift` (L89).

- [ ] **Step 1** — in `OpalRingsSnapshot.swift` rename struct fields `moveMinutes`→`moveKcal`, `dailyMoveMinutes`→`dailyMoveKcal`; Key constants `"moveKcal"`/`"dailyMoveKcal"`; update save/load/`.empty` (keep `Int` — kcal are whole numbers).
- [ ] **Step 2** — in `OpalWidgetSyncBridge.swift` (L34-35) read `a["moveKcal"]`/`a["dailyMoveKcal"]`.
- [ ] **Step 3** — in `OpalRingsWidget.swift` L89: `StatRow(color: moveColor, value: "\(s.moveKcal)", suffix: "/ \(s.dailyMoveKcal) kcal")`.
- [ ] **Step 4: Build** — `flutter build ios --no-codesign` (or open Xcode) to confirm Swift compiles. (Manual verify on a device/simulator: widget shows "X / 500 kcal".)
- [ ] **Step 5: Commit** — `git commit -m "feat(widget): iOS rings widget renders move kcal"`

---

## PHASE 8 — Client health sync (the Apple-Watch feature)

Reads today's active energy from `GET /v1/health/day` and upserts one health-sourced move `Entry`, which Phase 4's derivation already sums into the ring.

### Task 8.1: `HealthService` (interface + http + mock)

**Files:** Create `lib/services/health/health_service.dart`, `lib/services/health/http_health_service.dart`, `lib/services/health/mock_health_service.dart`; Test `test/services/http_health_service_test.dart`.

- [ ] **Step 1: Interface** — `health_service.dart`:

```dart
/// Reads a day's health metrics from the server (populated by the iOS Shortcut).
class HealthDay {
  const HealthDay({required this.activeEnergyKcal, required this.steps});
  final int activeEnergyKcal; // 0 when absent
  final int steps;            // 0 when absent
}

abstract interface class HealthService {
  /// GET /v1/health/day?date=YYYY-MM-DD
  Future<HealthDay> fetchDay(DateTime day);
}
```

- [ ] **Step 2: Failing test** — `http_health_service_test.dart`: fake an HTTP client returning `{"date":"...","metrics":{"activeEnergy":{"value":412,"unit":"kcal"},"steps":{"value":8423,"unit":"count"}}}`; assert `fetchDay` → `activeEnergyKcal == 412`, `steps == 8423`, and missing metrics → `0`.
- [ ] **Step 3: Implement** `http_health_service.dart` reusing the base URL + bearer token from `device_token_store` (mirror `http_pal_service.dart`'s client setup); parse `metrics.activeEnergy.value`/`metrics.steps.value` (round to int), default 0. `mock_health_service.dart` returns a canned `HealthDay(activeEnergyKcal: 320, steps: 6000)`.
- [ ] **Step 4: Run/pass; Step 5: Commit** — `git commit -m "feat(health): client HealthService reads daily metrics"`

### Task 8.2: `health_sync_controller`

**Files:** Create `lib/controllers/health_sync_controller.dart`; provider wiring in `lib/controllers/providers.dart`; Test `test/controllers/health_sync_controller_test.dart`.

- [ ] **Step 1: Failing test** — given a `MockHealthService` returning 412 kcal, after sync the entry repo contains exactly one move `Entry` with deterministic id `health:move:2026-06-12`, `source: EntrySource.health`, `calories: 412`, `sourceRef: 'health:active-energy:2026-06-12'`, `duration: null`; a second sync (430 kcal) **upserts** (still one entry, calories 430).
- [ ] **Step 2: Implement** — controller fetches `fetchDay(today)`, builds the `Entry` (id = `health:move:<yyyy-MM-dd>`, `type: move`, `title: 'Apple Watch'`, `detail: '<steps> steps'`, `calories: activeEnergyKcal`, `source: health`, `sourceRef: 'health:active-energy:<date>'`, `timestamp: today 12:00`), and calls `entryRepo.upsert(entry)` (insert-or-replace by id — already exists). Trigger on app launch / Today refresh (mirror `widget_sync_controller`'s `ref.listen`/`fireImmediately`). Skip the write when `activeEnergyKcal == 0` (no data yet).
- [ ] **Step 3: Run/pass; Step 4: Commit** — `git commit -m "feat(health): sync daily active energy into a move entry"`

### Task 8.3: provider override (real vs mock)

**Files:** Modify `lib/controllers/providers.dart` (and wherever `PAL_BASE_URL` toggles real/mock, mirror Pal/email).

- [ ] Wire `healthServiceProvider` to `HttpHealthService` when `PAL_BASE_URL` is set, else `MockHealthService` (mirror the existing Pal seam). Activate `healthSyncControllerProvider` at app start (where `widgetSyncController` is activated). Commit.

---

## PHASE 9 — Verification & deploy

- [ ] **9.1** — `cd server && npx vitest run && npx tsc --noEmit` → all green.
- [ ] **9.2** — `flutter test` → all green; `flutter analyze` → no errors.
- [ ] **9.3** — `flutter build ios --no-codesign` → Swift widget compiles.
- [ ] **9.4 Manual** — run app against the live server; trigger the Shortcut (which already sends `activeEnergy`); confirm the Today move ring fills toward `/ 500 kcal`, the home-screen widget shows kcal, and a manually-logged workout with calories also moves the ring.
- [ ] **9.5 Deploy** — confirm the working tree is the release commit, then **(approval-gated)** `git push origin main`; the GitHub Action redeploys the server. Rebuild/reinstall the app from the same commit (contract is now kcal).

---

## Self-review notes

- **Spec coverage:** ring re-base (P2,P4,P5), every-entry kcal capture (P3), health sync (P1,P8), server contract (P6), widget (P7) — all covered.
- **Type consistency:** `dailyMoveKcal` (int), `moveKcal` (int), wire fields per the Naming contract used identically across P2/P4/P6/P7.
- **Known risk:** legacy `daily_move_minutes` column is left in the DB (not dropped) by design; note for future cleanup. The minutes→kcal migration cannot preserve the old goal's meaning, so it resets to 500 kcal — acceptable for a single-user app; flag to the user.
- **Open product defaults to confirm:** kcal goal default 500, onboarding chips 300/500/700/900, stepper ±50 / 0–5000.
