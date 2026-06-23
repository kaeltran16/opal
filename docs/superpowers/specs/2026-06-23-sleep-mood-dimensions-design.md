# Sleep & Mood — Two New Dimensions — Design

Date: 2026-06-23

Port the `Sleep & Mood.html` Claude-Design prototype into Opal as two new, fully-wired
dimensions — siblings to Money, Move, Nutrition & Rituals. Sleep is **display-only**,
read from Apple Health; Mood is **user-logged** via a few-second pleasant↔unpleasant
check-in. Both expose cross-dimension "connections" through the existing correlation
engine and a (now upgraded) shared trust sheet.

Decisions taken during brainstorming (all confirmed with the user):

- **Navigation** — a new **"Dimensions" hub** reached from Today, listing Sleep & Mood
  (and room for more later). Keeps the bottom bar at 4 tabs.
- **Scope** — fully wired end-to-end: Drift persistence, real Health sleep ingestion,
  Riverpod controllers, real correlation computation. No stub services, no fake data
  source, no placeholder layers.
- **Connections** — computed by the real engine (extended for the two new dims), with
  the demo seed engineered so Sleep×Spending and Mood×Routine genuinely clear the
  statistical bar. Trust-sheet numbers are **computed, not authored** — they will read
  close to, not identical to, the prototype's strings.
- **Shared widgets** — upgrade the shared `CorrelationCard` + trust sheet to match the
  prototype exactly (benefits every dimension; single source of truth).
- **Demo seed** — keep it (dev-only, behind `SEED_DATA`), consistent with how Move /
  Nutrition seed demo content today. The production path remains real Health + real logging.
- **Design system** — every screen is built from `lib/theme` tokens (`AppType`,
  `context.colors`, `Spacing`, `Radii`, `Elevation`) and existing shared widgets. New
  dimensions mirror **Nutrition** as the structural template (own table, model, mappers,
  repository, `@riverpod` controller, provider, seed). No `EntryType` additions.

The prototype source of truth: project `b14afff0-1260-4a1b-8de4-6a50fd32f9f5`, file
`Sleep & Mood.html` and its `src/*.jsx` (`tokens`, `sleep-mood-data`, `sleep-screens`,
`mood-screens`, `sleep-mood-trust`). It renders 7 review states that collapse into:
Sleep landing, Sleep needs-sync, Mood landing, Mood logger sheet, and the shared trust
sheet (opened from a connection on either surface).

---

## Area 1 — Theme tokens

### Problem

`AppColors` (`lib/theme/app_colors.dart`) defines per-dimension accents for `money`,
`move`, `rituals`, `nutrition` only. `forType(String)` maps those four; anything else
falls through to `accent`. The prototype introduces two more accents with exact hex
values (light/dark), and the correlation card looks up a dimension's color via
`c.forType('sleep' | 'mood')`.

### Design

Add `sleep`/`sleepTint` and `mood`/`moodTint` as first-class tokens, using the
prototype's exact values (`tokens.jsx`):

| Token | Light | Dark | Tint (light .14 / dark .18–.20) |
|---|---|---|---|
| `sleep` | `#5B6CDB` | `#8491F0` | `rgba(91,108,219,.14)` / `rgba(132,145,240,.20)` |
| `mood`  | `#2FA6BC` | `#56C2DA` | `rgba(47,166,188,.14)` / `rgba(86,194,218,.20)` |

These sit beside the existing palette without colliding (sleep = periwinkle indigo,
distinct from rituals purple `#AF52DE`; mood = muted teal — close to but intentionally
separate from nutrition `#0FB5C9`, as the prototype author intended).

### Implementation

`lib/theme/app_colors.dart`:
1. Add four fields (`sleep, sleepTint, mood, moodTint`) to the class + constructor.
2. Set them in `AppColors.light()` and `AppColors.dark()` per the table.
3. Extend `forType`: `'sleep' => sleep, 'mood' => mood`.
4. Carry them through `copyWith` and `lerp` (both enumerate every field).

### Tests

`test/theme/app_colors_test.dart` (new or extend): `forType('sleep')`/`forType('mood')`
return the right token in both brightnesses; `lerp` interpolates the new fields.

---

## Area 2 — Data layer (Drift v8 → v9)

### Problem

Sleep nights and Mood check-ins are new, dimension-specific data. Following the
**Nutrition** convention, each is its own table — not an `EntryType` on the shared
`entries` table (which holds *actions*: money/move/rituals). Mood is a continuous
0–1 pleasantness scale (the prototype's draggable orb), **not** a small enum of levels;
the word ("Slightly pleasant") is derived, never stored.

### Design

Two new Drift tables, schema bumped `8 → 9` with an additive migration.

`sleep_nights` — one row per night, written only by the sleep sync (read-only to the user):

| Column | Type | Notes |
|---|---|---|
| `id` | text PK | uuid or Health source ref |
| `night` | dateTime | the calendar date the night belongs to (the morning's date) |
| `asleepMinutes` | int | total time asleep |
| `inBedMinutes` | int | time in bed |
| `bedtime` | text | `HH:mm` display |
| `wake` | text | `HH:mm` display |
| `deepMinutes` / `remMinutes` / `coreMinutes` / `awakeMinutes` | int | stage split |
| `wakes` | int | brief wakes |
| `source` | text | `HealthSource.wire` (`health`) |
| `sourceRef` | text? | Health sample UUID (dedup) |

`mood_checkins` — one row per check-in:

| Column | Type | Notes |
|---|---|---|
| `id` | text PK | uuid |
| `timestamp` | dateTime | when logged |
| `pleasantness` | real | 0..1 |
| `tag` | text? | one-word tag, nullable |
| `source` | text | `EntrySource.wire` (`manual`) |

"Usual" sleep (trailing median) and per-day mood means are **derived in the controller**,
not stored.

### Implementation

1. `lib/models/sleep_night.dart`, `lib/models/mood_checkin.dart` — immutable models with
   `copyWith`/`==`/`hashCode`, mirroring `nutrition_meal.dart`. Export via `models.dart`.
2. `lib/data/db/tables.dart` — add `SleepNights` and `MoodCheckins` table classes
   (`@DataClassName('SleepNightRow' | 'MoodCheckinRow')`).
3. `lib/data/db/database.dart` — register both in `@DriftDatabase(tables: […])`; bump
   `schemaVersion` to `9`; add `if (from < 9) { await m.createTable(sleepNights);
   await m.createTable(moodCheckins); }` to `onUpgrade`.
4. `lib/data/db/mappers.dart` — `toModel()` / `toCompanion()` extensions for both, matching
   the Nutrition mapper pattern (enum `.wire` round-trip, nullable handling).
5. `lib/data/repositories/sleep_repository.dart`, `mood_repository.dart` — constructor
   `(LoopDatabase db, {Uuid?})`; `watch*InRange` / `get*InRange` streams + reads; `insert`
   (assigns uuid when id empty, returns id), `upsert`, `deleteById`. Export via the
   repositories barrel.
6. `lib/controllers/providers.dart` — `@Riverpod(keepAlive: true)` `sleepRepository` and
   `moodRepository`, each `(ref) => …(ref.watch(loopDatabaseProvider))`.

### Tests

`test/repository_test.dart` — new groups mirroring `EntryRepository`/Nutrition tests on an
in-memory DB (`LoopDatabase.forTesting(NativeDatabase.memory())`): insert assigns uuid;
`watch*InRange` respects bounds and emits on change; round-trip preserves all fields
(including stage split and nullable tag).

---

## Area 3 — Sleep ingestion from Health (real path)

### Problem

`HealthService` (`lib/services/health/health_service.dart`) only exposes
`fetchDay(day) → HealthDay { activeEnergyKcal, steps }`. There is no sleep data. Move
already syncs Health via `health_sync_controller`; Sleep must do the same for real (the
prototype's "needs more nights" screen is a genuine empty state, not a placeholder).

### Design

Extend the service interface with a sleep fetch and add a sync controller that persists
nights into `sleep_nights`, mirroring the Move health-sync flow. The **HTTP** service is
the production source (the server endpoint the iOS Health shortcut populates).
`MockHealthService` implements the new method returning "no data" — it is only the
test/dev double, never the feature's source.

```dart
class HealthSleep {              // one synced night
  const HealthSleep({ required this.night, required this.asleepMinutes,
    required this.inBedMinutes, required this.bedtime, required this.wake,
    required this.deep, required this.rem, required this.core, required this.awake,
    required this.wakes, this.sourceRef });
  // …fields…
}

abstract interface class HealthService {
  Future<HealthDay> fetchDay(DateTime day);
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to); // NEW
}
```

### Implementation

1. `health_service.dart` — add `HealthSleep` + `fetchSleep` to the interface.
2. `http_health_service.dart` — implement `fetchSleep` against the real endpoint
   (`GET /v1/health/sleep?from=…&to=…`); map JSON → `HealthSleep`.
3. `mock_health_service.dart` — implement `fetchSleep` returning `[]` (no data).
4. `lib/controllers/sleep_sync_controller.dart` (new, `@riverpod`) — on demand / app
   resume, fetch the recent window and `upsert` nights via `sleepRepository`, deduping by
   `sourceRef`. Mirror `health_sync_controller`'s structure and triggers.

### Tests

`test/controllers/sleep_sync_controller_test.dart` — with a fake `HealthService` returning
known nights, the controller upserts them and dedups by `sourceRef`; with `[]`, nothing
is written (drives the needs-sync state).

---

## Area 4 — Correlation engine extension

### Problem

`lib/analysis/correlations.dart` has the generic engine but `Dimension` is
`{money, move, rituals, nutrition}`; `buildDailyVectors(List<Entry>, List<NutritionMeal>,
{required now, windowDays})` builds series for those four only; and the two-group
`GroupBreakdown` is driven solely by `_binaryDims = {move, rituals}` using `value > 0`
("active"). The prototype's two connections don't fall out of this as-is:

- **Sleep × Spending** is a **next-day, threshold-split** relationship ("on nights under
  6h 30m, you spend ~1.6× more *the next day*"). The engine pairs *same-day* values and
  splits binaries at `>0`.
- **Mood × Routine** ("days you finish morning rituals → more pleasant mood") fits the
  existing binary×continuous breakdown directly (rituals binary, mood continuous).

### Design

Minimal, generic extensions — no per-pair hardcoding:

1. `Dimension` → add `sleep, mood`.
2. `buildDailyVectors` gains two params: `List<SleepNight> nights`, `List<MoodCheckin>
   moods`. Series:
   - **sleep** — `asleepMinutes`, attributed to the **following** calendar day
     (`night + 1d`), so the engine's same-day pairing yields the *next-day* relationship
     the prototype describes. Sparse (only nights present), like nutrition.
   - **mood** — daily **mean** `pleasantness`. Sparse (only days with a check-in).
3. **Threshold split for sleep breakdowns.** Generalize `_toCorrelation` so a dimension
   can declare how it produces its binary signal for the breakdown:
   - `move`/`rituals` keep `>0` = active (unchanged).
   - `sleep` uses a threshold split at `kShortNightMinutes = 390` (6h 30m): below =
     "short night" (the *active*/highlighted group), at/above = "other night". This keeps
     the existing `GroupBreakdown` shape (`meanWhenActive` = avg of the continuous side on
     short nights).
   - When both sides are continuous and neither is a breakdown-driver (e.g. sleep×mood),
     no breakdown — same as the current continuous×continuous path.
4. Extend the label/format switches for the two new dims:
   - `dimensionNoun`: `sleep => 'sleep'`, `mood => 'mood'`.
   - `activeDayLabel`/`inactiveDayLabel`: `sleep => 'short nights' / 'other nights'`.
   - `formatValue`: `sleep => hm(v)` (e.g. "6h 54m"), `mood => '${moodWord(v)}
     (${v.toStringAsFixed(2)})'` (e.g. "Pleasant (0.64)") — matching the prototype's
     trust-sheet strings.
5. `surfacedCorrelationsProvider` (`lib/controllers/correlations_controller.dart`) already
   watches `entryRepository` + `nutritionRepository`; add `sleepRepository` +
   `moodRepository`, fetch their ranges, and pass to `buildDailyVectors`. Thresholds
   (`kMinPairedDays=21`, `kMinAbsR=0.4`, `kAlpha=0.05`) and Holm-Bonferroni correction are
   unchanged — the new pairs compete on equal footing.

The exact computed numbers depend on the seed (Area 7); they will read close to the
prototype's ("≈1.6×", "$64 vs $39", "Pleasant 0.64 vs Slightly unpl. 0.46") but are honest
outputs of the engine, per the agreed approach.

### Implementation

Edit `correlations.dart` per the five points; thread the two new repos through
`correlations_controller.dart`. All other call sites are unaffected (the `Dimension` enum
gains values; existing `switch`es over it must add arms — caught by the analyzer).

### Tests

`test/analysis/correlations_test.dart` — extend with: next-day attribution (a night maps
to the next day's pair); the short-night threshold split produces the expected
active/inactive means and counts; mood daily-mean; and an **engineered fixture** (the seed
shape from Area 7) asserting Sleep×Spending and Mood×Routine both survive the
Holm-corrected bar with `|r| ≥ 0.4`.

---

## Area 5 — Shared connection card & trust sheet (upgrade)

### Problem

The current `CorrelationCard` (`lib/widgets/correlation_card.dart`) and
`showCorrelationTrustSheet` are thinner than the prototype: the card is two dots + a
`MONEY X MONEY` eyebrow + body + "Based on N days"; the sheet is a title + two rows + a
footnote. The prototype's connection card and `TrustSheet` (`sleep-mood-trust.jsx`) are
richer, and `_label`/`_token` only know the four existing dimensions.

### Design

Upgrade both shared widgets to the prototype, rendering **generically from a
`Correlation`** (+ its `breakdown`) so every dimension benefits and nothing is authored
per-pair. A small presentation helper derives the display pieces:

- **pairLabel** — `"Sleep × Spending"` from the two dims' labels.
- **line / claim** — built from `summary` / breakdown (bold the figures, accent the key
  delta in the a-dimension color).
- **compare** (side-by-side bars) — from `breakdown.meanWhenActive/Inactive`: low/hi
  labels + values + normalized fractions.
- **numbers** (underlying list) — derived rows (group counts, the two means, the ratio).
- **source** — templated from the pair + the correlation's own paired-day count `n` (e.g.
  "Apple Health + your spending · last N days"), so it never overstates the window.
- **why** — a generic honest note referencing the significance bar ("held across enough
  days to be more than noise … an observation, not a verdict").
- **Ask Pal** — `context.go('/pal-composer?seed=…')` seeded with the claim (the existing
  pal-noticed pattern).

Connection **card**: gradient a→b dot, `PAL NOTICED` eyebrow, the templated line, and
"Tap to see the nights and the numbers." Trust **sheet**: grabber + two-dot `PairTag`,
restated claim, "Side by side" comparison bars, underlying-numbers list, source row, "Why
you're seeing this" box, "Ask Pal about this" button — all from `context.colors` /
`AppType` / `Spacing` / `Radii`.

Extend `CorrelationCard._label`/`_token` with `sleep => 'Sleep'`, `mood => 'Mood'`.

### Blast radius

Recap (`recap_screen.dart`) and Nutrition Patterns (`nutrition_patterns_screen.dart`) use
these shared widgets — they get the richer, design-accurate sheet automatically. **Visual
change only; same data, same provider, same tap target.** No API change to
`CorrelationCard(correlation:, narration:)` or `showCorrelationTrustSheet(context,
correlation)`.

### Implementation

Rewrite the two widgets in `lib/widgets/correlation_card.dart` to the prototype layout,
plus the derivation helper (kept in the same file or a small sibling). Reuse `AppIcon`,
`PressScale`. The narration override (`narration`) still wins over the templated line when
present.

### Tests

`test/widgets/correlation_card_test.dart` — golden/structure tests: card shows the
eyebrow + line; tapping opens the sheet; the sheet renders the comparison bars and numbers
from a `Correlation` with a `breakdown`, and falls back to the summary when there's no
breakdown; "Ask Pal" navigates to `/pal-composer?seed=…`.

---

## Area 6 — Controllers & state

### Problem

The screens need derived state the prototype computes inline (last night vs usual, week /
month series, today's mood lean, check-in list). Follow the `NutritionController` pattern:
a `@riverpod` controller exposing a `Stream<…State>` derived from the repository, with pure
helpers and action methods on the notifier.

### Design

`lib/controllers/sleep_controller.dart` → `SleepController extends _$SleepController`,
`build()` → `Stream<SleepState>`:

```
SleepState { lastNight: SleepNight?, usualMinutes: int (trailing-2-week median),
  week: List<SleepBar> (7), month: List<int> (30), syncedNights: int }
```

Watches `sleepRepository.watchNightsInRange(window)`; derives usual (median), the week /
month series, and the synced count (drives needs-sync when `< 3`). No write actions
(read-only dimension).

`lib/controllers/mood_controller.dart` → `MoodController`, `build()` → `Stream<MoodState>`:

```
MoodState { todayCheckins: List<MoodCheckin>, todayLean: double (avg), mostTag: String?,
  lastCheckin: MoodCheckin?, week: List<MoodBar> (7 daily means) }
Future<void> logCheckin(double pleasantness, String? tag)  // persists via moodRepository
```

Both expose helpers as pure top-level/private functions for unit testing.

### Implementation

Two controller files + generated `.g.dart` (build_runner). No provider wiring beyond the
repositories (Area 2).

### Tests

`test/controllers/sleep_controller_test.dart`, `mood_controller_test.dart` — feed an
in-memory repo, assert derived state (median usual, week buckets, synced count → needs-sync
boundary at 3; mood lean average, most-frequent tag, `logCheckin` persists and re-emits).

---

## Area 7 — Demo seed

### Problem

Like every dimension, the demo build needs content so the screens and connections render.
`Seeder.seedDemoData()` (`lib/data/seed/seeder.dart`, dev-only behind `SEED_DATA`) seeds
each table from `SeedData` (`lib/data/seed/seed_data.dart`) idempotently via markers +
`InsertMode.insertOrReplace`.

### Design

Add seed sleep nights + mood check-ins, **engineered** so the engine surfaces the two
connections (per the agreed approach):

- **Sleep nights** — ~30 nights ending "last night" (Wed 7h12 asleep, 7h30 in bed,
  stages 64/98/270/18, bedtime 11:32 → wake 7:02, usual ≈6h54), with ~8 nights under
  6h 30m (the "short nights") clustered against higher next-day spend so Sleep×Spending
  clears the bar (~1.5–1.6×).
- **Mood check-ins** — daily check-ins across the window with higher pleasantness on
  morning-routine-kept days (pairs against the existing rituals seed) so Mood×Routine
  clears the bar; today = three check-ins (0.46 Tired 8:05, 0.62 Calm 1:40, 0.70 Calm 9:12),
  matching the prototype's hero.

Production path stays real Health + real logging; this is demo content only.

### Implementation

`seed_data.dart` — `static List<SleepNight> sleepNights()` and `static List<MoodCheckin>
moodCheckins()` with stable ids. `seeder.dart` — insert both in `seedDemoData()` with
`insertOrReplace`; bump the demo marker if needed. Align dates to the existing demo
window/anchor so cross-dimension days line up with the seeded entries/rituals.

### Tests

`test/seed/...` (or extend existing seed test) — after `seedDemoData()`, sleep nights and
mood check-ins are present, idempotent on re-run, and `surfacedCorrelations` over the
seeded DB includes Sleep×Spending and Mood×Routine.

---

## Area 8 — Screens

All screens use `TabHeaderScrollView` / `LargeTitleScrollView`, `InsetSection`/`ListRow`,
`Segmented`, `AppIcon`, `PressScale`, and `context.colors`/`AppType`/`Spacing`/`Radii`/
`Elevation`. Custom painters only where no shared widget fits (stage-split bar, sleep
trend with "usual" band, mood midline week chart, the logger orb + gradient scale).
`moodColor(t, dark)` and `moodWord(t)` are ported from `sleep-mood-data.jsx` as pure Dart
helpers (`lib/util/mood_scale.dart`), plus `hm`/`hmShort` duration formatters (reuse
`lib/util/dates.dart` if equivalents exist, else add).

### 8a — Sleep landing (`lib/screens/sleep/sleep_screen.dart`)

NavBar "Sleep · synced from Health" + a `Health` pill (heart). "Last night" indigo
gradient hero: big `7h 12m` with "x less/more than your usual", a `moon.stars.fill`
"restful" chip, the **StageSplit** bar (Deep/REM/Core/Awake), and "in bed 11:32–7:02 ·
7h 30m in bed · 2 brief wakes". A **Recent nights** card: `Segmented` Week/Month, bars with
a dashed "usual" band, footer sentence. A **Connections** section with the shared
`CorrelationCard` (Sleep×Spending). Loading/empty → 8b.

### 8b — Sleep needs-sync (variant of 8a)

Centered `moon.stars.fill` in a `sleepTint` disc, "A few more nights", explanatory copy,
a 2-of-3 progress dots row, "Open Health settings" button, reassurance line. Shown when
`syncedNights < 3`.

### 8c — Mood landing (`lib/screens/mood/mood_screen.dart`)

NavBar "Mood · how you've been feeling" + a teal "+" button (opens 8d). "Today leans"
teal gradient hero: `moodWord(avg)`, "averaged from N check-ins", a tag chip, a mini
pleasant↔unpleasant scale with marker, "most often {tag} · last logged {time}". A
"Check in again" row. **Check-ins** list (`InsetSection`): time · mood-color orb dot ·
word · optional tag. **This week** midline chart (above = more pleasant). **Connections**
with `CorrelationCard` (Mood×Routine).

### 8d — Mood logger (`lib/screens/mood/mood_logger_sheet.dart`)

Modal bottom sheet (route via `_sheetPage`, or `showModalBottomSheet`): "How you feel right
now", the live `moodWord` readout, the **orb** (radial gradient that morphs border-radius
+ scale with `t`), the **track** (cool→warm gradient rail, tap or drag to set `t`,
Unpleasant↔Pleasant ends), optional one-word **tag chips** (`MOOD_TAGS`), a gentle helper
line, and a "Log mood" primary button tinted by the current `moodColor` →
`moodController.logCheckin(t, tag)`. Drag handled with a `GestureDetector`/`Listener`
(pointer math equivalent to the prototype's `setFromX`).

### Implementation

New files under `lib/screens/sleep/` and `lib/screens/mood/`, plus the small painters and
`lib/util/mood_scale.dart`. Each screen is a `ConsumerWidget` consuming its controller via
`ref.watch(...).when(loading/error/data)`.

### Tests

Widget tests per screen: Sleep renders hero + stage split + trend and switches Week/Month;
needs-sync shows under the synced-night threshold; Mood renders hero + check-ins + week;
the logger updates the word/orb on drag and `logCheckin` persists + closes.

---

## Area 9 — Navigation (Dimensions hub)

### Problem

Sleep & Mood are secondary dimensions; the bottom bar already has 4 tabs + the Pal FAB.
Per the chosen approach they live behind a **Dimensions hub** reached from Today (the same
spirit as Money living at `/today/spending`).

### Design

- New routes in `AppRoute` (`router.dart`): `dimensionsHub` (`/today/dimensions`), `sleep`
  (`/today/dimensions/sleep`), `mood` (`/today/dimensions/mood`), nested under the Today
  branch so back returns to Today. The Mood logger is a modal (`_sheetPage` or
  `showModalBottomSheet`).
- **Hub** (`lib/screens/dimensions/dimensions_hub_screen.dart`): `LargeTitleScrollView`
  "Dimensions" + an `InsetSection` of `ListRow`s — Sleep (`moon.stars.fill`, `sleepTint`
  tile) and Mood (`heart.fill`, `moodTint` tile) — each pushing its screen. Built to extend
  (future dims drop in as rows).
- **Today entry point**: add a single `ListRow`/section on the Today screen ("Dimensions"
  → hub). Exact placement confirmed against `today_screen.dart` during planning; minimal,
  matches existing Today rows.

### Implementation

Add the enum values + `GoRoute`s under the Today branch; create the hub screen; add the
Today entry row. `AppIcon` mappings for any new SF Symbols (`moon.stars.fill`, `sparkles`,
`heart.fill`, `arrow.up`/`arrow.down`, `xmark`) — add to `app_icon.dart` if missing.

### Tests

Router/widget test: Today → Dimensions → hub lists Sleep & Mood; tapping each pushes the
right screen; deep links to the three new paths resolve.

---

## Out of scope

- Apple Health *write*; Sleep is read-only.
- LLM narration changes — the existing `correlationNarration` path is reused as-is (the
  upgraded card still prefers `narration` over the templated line).
- Editing/deleting mood check-ins from the UI (repository supports it; no screen yet).
- Any new bottom tab or change to the existing 4-tab shell.

## Risks & notes

- **Engine `switch` exhaustiveness** — adding `Dimension.sleep`/`mood` forces new arms in
  every `switch` over `Dimension`; the analyzer enumerates them. This is the intended
  safety net.
- **Computed ≠ authored numbers** — accepted. The seed is tuned to land close to the
  prototype, but the trust sheet shows the engine's real output.
- **Migration** — additive only (two `createTable`s at v9); no existing data touched.
- **Shared-widget upgrade** — verify Recap & Nutrition-patterns still render correctly
  after the card/sheet rewrite (visual regression check).
