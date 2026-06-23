# Exercise Library & Workout-Screen Fixes — Design

Date: 2026-06-23

Three independent fixes surfaced while investigating an empty Exercise Library:

1. **Reference-data seeding** — the exercise catalog is never seeded in prod, so the library is empty.
2. **Exercise Library header** — hand-rolled `_Header` instead of the shared large-title nav bar.
3. **Generate-with-AI loading** — the loading indicator renders below the fold; a tap looks like a no-op.

Each is small and touches a single component. They are batched here for one session but are otherwise unrelated.

---

## Fix 1 — Seed the exercise catalog as reference data

### Problem

`Seeder.seedIfNeeded()` seeds everything — catalog **and** a fake user's demo history — in one transaction guarded by one marker (`initial_seed_v7`). `main.dart` only calls it when `SEED_DATA=true` (the dev launch config). In prod the whole seed is skipped, so the `exercises` table is empty → `watchExercises()` emits `[]` → the Exercise Library shows its empty state.

The catalog is **reference data**, not demo data. It is a compile-time `const` (`SeedData.exercises()` in `lib/data/seed/seed_data.dart`) with zero runtime dependencies — no asset load, no network. It must live in the DB because `watchExercises()` queries the `exercises` table and `routines` / `set_logs` hold foreign keys to `exercises.id`.

Two content decisions made during design (both affect what gets seeded):

- **Catalog breadth → expand to ~36.** The original 21 covered the major barbell compounds but were thin on machine/isolation work and core (only 2). Adding ~15 high-frequency exercises: Push +3 (Flat DB Press, Dips, Cable Fly), Pull +4 (Lat Pulldown, Seated Cable Row, Hammer Curl, Barbell Shrug), Legs +4 (Leg Curl, Leg Extension, Hip Thrust, Bulgarian Split Squat), Core +4 (Crunch, Cable Crunch, Russian Twist, Ab Wheel Rollout). Final: Push 8 / Pull 9 / Legs 9 / Core 6 / Cardio 4 = 36. New entries reuse SF Symbols already present in the catalog (no unmapped glyphs).
- **PRs are demo data, not reference data → strip them from the shipped catalog.** The PRs baked into the catalog (`92.5 kg` bench, etc.) are the demo user's records, used only as the PR-detection baseline (`workout_session.dart` `_seedPrHistory`, read from the live DB catalog — nothing writes PRs back). Shipping them to prod would show fabricated PRs on every fresh user's library and skew their PR detection. So `seedReferenceData()` seeds the catalog PR-less; `seedDemoData()` overlays mira's PRs (`SeedData.demoExercisePrs()`) onto the same rows via `insertOrReplace` (dev only). The mapper round-trips cleanly: `toCompanion()` writes `Value(pr?.weightKg)` (null → null columns), and `copyWith(pr:)` sets them.

### Design

Split the seed along the reference/demo line:

| Method | Seeds | Marker | Runs |
|---|---|---|---|
| `seedReferenceData()` | exercise catalog only | `catalog_seed_v1` | always (prod + dev) |
| `seedDemoData()` | goals, rituals, pal notes, routines, workouts, entries, weekly plan, budgets, nutrition | `demo_seed_v1` | only when `SEED_DATA=true` |
| `seedIfNeeded()` | convenience = reference then demo | — | kept so existing test callers need no change |

- **`main.dart`** seeds reference unconditionally, demo behind the flag:
  ```dart
  final seeder = Seeder(container.read(loopDatabaseProvider));
  await seeder.seedReferenceData();           // always — catalog is reference data
  if (_seedData) await seeder.seedDemoData();  // demo history stays dev-only
  ```
- **FK safety:** `seedDemoData()` calls `seedReferenceData()` first (cheap marker check, no-op if already seeded), so demo routines/workouts always have their catalog FK targets. Removes any caller-ordering footgun.
- **Two transactions** instead of one: the catalog commit no longer depends on the larger demo commit. A crash mid-demo (dev only) cannot leave the catalog half-written; prod never opens the demo transaction.
- **Markers:** fresh namespace replaces `initial_seed_v7`. On existing DBs both new markers are absent, so each section re-runs once via `insertOrReplace` on stable ids (idempotent — same as any past marker bump). The orphaned legacy `initial_seed_%` marker is deleted as one-time cleanup. Future catalog additions = bump `catalog_seed_v2`; prod picks them up.

### Implementation

1. `lib/data/seed/seed_data.dart`:
   - Rewrite `exercises()` PR-less and expanded to 36 (the additions above). Update the doc comment.
   - Add `demoExercisePrs()` → `Map<String, ExercisePR>` with the 17 original PRs keyed by exercise id.
2. `lib/data/seed/seeder.dart`:
   - Replace the single `_markerKey` with `_catalogMarker = 'catalog_seed_v1'` and `_demoMarker = 'demo_seed_v1'`.
   - Add `seedReferenceData()`: marker-guarded transaction that inserts `SeedData.exercises()` only, deletes any legacy `initial_seed_%` markers, writes `_catalogMarker`.
   - Add `seedDemoData()`: calls `seedReferenceData()` first; then a marker-guarded transaction that (a) overlays `demoExercisePrs()` onto the catalog rows via `copyWith(pr:)` + `insertOrReplace`, then inserts goals → ritual routines/steps → pal notes → routines/slots → workouts/sets → entries → weekly plan → budgets → nutrition, then writes `_demoMarker`. (Exercises themselves move out of this method.)
   - `seedIfNeeded()` becomes `await seedReferenceData(); await seedDemoData();`.
3. `lib/main.dart`: move catalog seeding out from behind `_seedData` per the snippet above.

### Tests (`test/...`)

- New: after `seedReferenceData()` alone, `getAllExercises()` is non-empty, **all** have `pr == null`, and `watchRoutines()`/workouts/entries are empty (the failing-test reproduction of the empty-library + prod-PR bugs).
- New: `seedReferenceData()` is idempotent (second call inserts no duplicates).
- New: after `seedIfNeeded()`, a known lift (bench) has its demo PR set (overlay applied).
- Existing full-seed + idempotency tests + `exercise_library_test` (asserts `92.5 kg`/`115 kg` from the full seed) stay green via `seedIfNeeded()`.

---

## Fix 2 — Exercise Library uses the shared large-title nav bar

### Problem

`exercise_library_screen.dart` hand-rolls `_Header` (a `Row` with a small `AppType.title2` ≈22pt title). Every other focus screen (`routine_editor`, `workout_detail`, `start_workout`, `routine_generator`) uses the shared `LargeTitleNavBar`/`LargeTitleScrollView` (34pt `AppType.large` title, 56px status inset, `NavAction` back button). Hence the visual mismatch.

### Design

Replace `_Header` with the static `LargeTitleNavBar`, matching `routine_editor`'s pattern (static nav bar + fixed body) — the library keeps its search pill + filter chips **pinned** above a scrolling list, so the static (non-collapsing) variant fits.

```dart
LargeTitleNavBar(
  title: 'Exercises',
  subtitle: count != null ? '$count in library' : null,
  leading: NavAction(
    icon: 'chevron.left',
    onTap: () => context.pop(),
    semanticLabel: 'Back',
  ),
)
```

Deliberate choices:
- **Back button icon-only**, matching sibling convention (current labels it "Workout"; stale audit wants "Move" — neither matches siblings).
- **No trailing `+`** — there is no add-exercise flow (catalog is seeded, not user-authored), so a `+` would be dead.

### Implementation

1. `lib/screens/library/exercise_library_screen.dart`:
   - Replace `_Header(count: async.asData?.value.length)` with `LargeTitleNavBar(...)` as above (subtitle from the same async count).
   - Remove the top inset duplication: the nav bar supplies the 56px status pad, so drop `SafeArea(top:...)` for the header region (verify against `routine_editor`'s exact wrapping during implementation).
   - Delete the `_Header` widget and any now-unused imports.
   - Search pill, filter chips, and `Expanded(ListView)` unchanged.

### Tests

- Existing `exercise_library_test.dart` asserts on rows/sections/filtering — must stay green. Add an assertion that the screen now renders `LargeTitleNavBar` with title `Exercises` (and the back `NavAction`).

---

## Fix 3 — Generate-with-AI loading indicator below the fold

### Problem

`routine_generator_screen.dart` has three logical modes — idle form, loading, result — but loading is not its own mode. During loading `isResult` is `false`, so the form block (`if (!isResult)`, lines 114-135) still renders the hero + prompt + 6-goal grid, which fill the viewport. The `_LoadingPill` is then appended after it (line 137), landing below the fold. The form greys out (disabled) but the spinner is off-screen, so a tap reads as a no-op.

### Design

Make loading a real mode, the way result already is. Change the form guard:

```dart
if (!isResult && !isLoading) ...[ hero, prompt, quickPicks ]
```

With the form hidden during loading, `_LoadingPill` (already padded `Spacing.xxl` on top) renders directly under the "Generate with AI" large title — immediately visible. The error branch keeps the form (so the user can retry), unchanged.

### Implementation

1. `lib/screens/workout/routine_generator_screen.dart`: change the single guard on line 114 from `if (!isResult)` to `if (!isResult && !isLoading)`. No other changes.

### Tests

- New widget test: while `RoutineGeneratorLoading`, the hero/prompt/quick-picks are absent and the loading pill ("Pal is building your routine…") is present. (Drive via a provider override that holds the loading state.)

---

## Out of scope

- An add-exercise UI (the chosen model is seed-the-catalog, not user-authored exercises).
- Any change to demo content, goals seeding, or the `SEED_DATA` flag's other effects.
- The collapsing-on-scroll large title for the library (static nav bar is the deliberate choice).
