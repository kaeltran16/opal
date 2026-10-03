# Oura-style redesign: Today and the area pages

**Spec:** `docs/superpowers/specs/2026-10-04-oura-redesign-today-area-pages-design.md` records what this run builds from the board, what it defers (the Areas tab, the Nutrition, Sleep and Mood area pages, the three-tab bar, the profile button), and the states the board does not draw.
**Verify:** `flutter test --exclude-tags golden --exclude-tags scenario`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\ai-first-home\project\Today.dc.html

**Goal:** Migrate `lib/theme` to the DESIGN.md tokens, rebuild Today to the approved
prototype, and replace the three area detail screens (Money, Move, Routines) with the
prototype's area page, all wired to real data.

**Sources of truth.** Read both before writing code.
- Rulebook: `DESIGN.md` at the repo root once Task 1 lands. Until then read it from
  `C:\Users\cktra\Projects\opal\DESIGN.md` (untracked in the main checkout).
- Prototype: `C:\Users\cktra\Projects\opal\.superpowers\design\ai-first-home\project\Today.dc.html`
  (gitignored; read it from that path). One interactive board, drawn in dark mode. Its
  inline styles are the measurements: sizes, gaps, radii, weights. Its weekly numbers and
  Pal sentences on the area page are sample data, not requirements.
- Spec: `docs/superpowers/specs/2026-10-04-oura-redesign-today-area-pages-design.md`. The
  board draws more than this run builds. The spec's "Deferred" list wins over the board:
  no Areas tab, no Nutrition, Sleep or Mood area page, four tabs not three, no profile
  button, and the area page's back label is always `Today`. The spec also fixes the light
  theme and the loading, error and empty states the board does not draw.

## Global constraints

- Flutter app, Riverpod 3 with codegen, go_router, drift. Follow the repo's conventions:
  screens are dumb, derivation lives in controllers or pure functions with unit tests.
- Principles: simple and direct, KISS, YAGNI, DRY, single source of truth, no abstraction
  for a single use, handle errors at boundaries and never swallow them silently, long-term
  fix over band-aid. Comments only for "why", lower case, only when necessary. No emojis.
- `test/theme/token_guard_test.dart` stays green: no raw `Color(0x...)` or numeric
  `BorderRadius.circular(` outside `lib/theme/` unless annotated `kept literal: <why>`.
  Scene palettes therefore live in `lib/theme/`.
- A task that changes a `@riverpod` provider or its signature runs
  `dart run build_runner build --delete-conflicting-outputs` and commits the `.g.dart`.
  CI fails on stale generated files.
- Every time-dependent value reads `clock.now()` (package `clock`), never `DateTime.now()`.
- Colour means state, never area. Today and the area pages use no area colour
  (`money`, `move`, `rituals`, ... and their tints and inks), no shadow on cards, and no
  glass except the composer and the tab bar.
- State words are fixed: Ahead, On track, Worth watching, Needs care. State colour is never
  shown without its word or an icon.
- Minimum text size 12. Touch targets 44 minimum. Primary buttons 48 tall. Numbers that can
  change use tabular figures. Large numbers are light (w300), never bold.
- The serif (`AppType.lead`) is used only for Pal's lead line on Today.
- Honour reduce motion (`MediaQuery.disableAnimationsOf`) for any new animation.
- Out of scope: the tab structure, any screen not named in a task, removing area colours
  from untouched screens. Do not reformat or refactor files a task does not own.
- Single-user app sideloaded with a free Apple account: add nothing that needs a paid
  entitlement. Nothing in this plan does.
- Commit messages are `type(scope): description`, no attribution trailers of any kind.
- A task names focused tests only. Run those plus Check; the engine runs the full suite.
- Scenario steps: every task that renders something adds its steps to its own file under
  `test/scenario/` using the Task 4 harness, with finder assertions before each shot so a
  missing view fails the run. Each step listed in a task is a PNG name written by `shot`.

## Review focus

Conditions no single task's happy path exercises, most likely first. Each has a test in
the task that owns the code.
1. Zero or unset goals (budget 0, move goal 0, no routines): rings, state, hero, week bars
   and the goal line must render without division by zero or NaN, and read as plain
   amounts in neutral ink. Tests in Tasks 2, 5, 6.
2. Over budget: money left never shows negative, the ring is empty, the state is Needs
   care, and the area page says how much over. Tests in Tasks 2, 5.
3. An empty day (no proposals, no routines, rest day, nothing logged): Today shows the
   all-done card and no timeline rail, not an empty gap or a crash. Tests in Tasks 3, 9.
4. Pal offline (brief and agenda both fail): Today still renders from local data with the
   current item's own sentence as the lead. Test in Task 9.
5. Long text and large text scale: a long routine or proposal title ellipsises in the
   timeline and wraps in the card without overflow at text scale 1.3 on a 390 wide
   screen. Tests in Tasks 9, 10.

---

### Task 1: Theme tokens, type ramp, serif, dark default
**Depends on:** none

Migrate `lib/theme` per DESIGN.md sections 3, 4, 5 and 10.

Design decisions
- Copy `C:\Users\cktra\Projects\opal\DESIGN.md` to the repo root unchanged, so it lands
  with this work.
- Neutrals: `AppColors.light()` and `AppColors.dark()` take the section 3 tables exactly
  (`bg`, `surface`, `surface2`, `hair`, `ink`, `ink2`, `ink3`, `ink4`), all opaque. Add
  `track`. `fill` becomes `surface2`.
- State colours: add `thriving`, `good`, `watch`, `care` (fills) and `thrivingInk`,
  `goodInk`, `watchInk`, `careInk` from the section 3 state table. In dark, fill and ink
  share the one listed value.
- Accent is removed as a choice. Delete `enum AppAccent`, its extension, the
  `settings.accent` getter and setter in `SettingsRepository`, `AppSettings.accent` and
  `setAccent` in `lib/controllers/providers.dart`, and the Accent section of
  `lib/screens/settings/appearance_screen.dart`. The factories become no-argument. The
  fields `accent`, `accentInk`, `accentTint`, `onAccent` stay as aliases so untouched
  screens keep compiling: `accent = ink`, `accentInk = ink`, `accentTint = surface2`,
  `onAccent = bg`. `red` becomes the `care` fill and `dangerInk` the `care` ink.
  `copyWith` keeps only `brightness`. Update every test that passes an `AppAccent`
  (about 45 files, a mechanical edit to `AppColors.light()` / `AppColors.dark()`) and
  delete tests of the accent picker and accent tables.
- Area colours, their tints and inks, and `forType` / `inkForType` stay unchanged.
- Glass tokens are re-valued for floating bars only: `glass` is `surface` at 0.78 alpha,
  `glassBorder` is `hair`, `glassHighlight` is fully transparent. `shadow` stays.
- Scene palettes: add `lib/theme/scene_palette.dart` with
  `enum DayPhase { morning, afternoon, evening }` and
  `class ScenePalette { final List<Color> sky; final List<double> skyStops; final Color sun; final Alignment sunCenter; final Color far, mid, near; }`
  plus `ScenePalette scenePalette(DayPhase phase, Brightness brightness)`. Dark values come
  from the prototype's `SCENES` (sky gradient stops, sun rgba at its 0.34 / 0.30 / 0.32
  peak, hill fills, sun position as an `Alignment` equivalent to `sunLeft` / `sunTop` on
  the 390 by 380 scene). Light values are new: the same three moods in pale warm tones
  that fade into `bg #F7F1E8`, chosen so `ink #1E2427` holds 4.5:1 against every sky stop
  and hill fill. Export it from `theme.dart`.
- Type (`lib/theme/app_type.dart`): add the section 4 roles with exact size, line height,
  weight and tracking: `display` 64/68 w300 -1.6 tabular, `score` 40/44 w300 -0.8 tabular,
  `lead` 30/36 w300 -0.6 in family `Newsreader`, `title` 22/27 w500 -0.4,
  `label` 13/18 w500 +0.3. Existing roles keep their metrics (other screens depend on
  them). Remove `eyebrow`; its one caller, `lib/widgets/nav_bar.dart`, uses `label`.
  Leave `brief` in place (Task 9 removes it with its caller).
- Serif: bundle Newsreader Light under the OFL as `assets/fonts/Newsreader-Light.ttf` with
  `assets/fonts/OFL.txt`, declared in `pubspec.yaml` as family `Newsreader`, weight 300.
  Use a static Light instance from the official Newsreader release
  (github.com/productiontype/Newsreader); if only the variable font is obtainable, bundle
  that and set `fontVariations` for `wght` 300 on `lead`. No runtime network fetch and no
  `google_fonts` dependency.
- Radius: `Radii.card` becomes 20.
- Default theme: `SettingsRepository.brightness` returns dark when nothing is saved; a
  saved `light` is kept. `test/support/golden_harness.dart` `bootApp` writes the
  brightness explicitly for both values of `dark`.

Files owned: `DESIGN.md`, `lib/theme/*`, `pubspec.yaml`, `assets/fonts/*`,
`lib/data/repositories/settings_repository.dart`, `lib/controllers/providers.dart` (and
its `.g.dart`), `lib/app.dart` (theme build only), `lib/screens/settings/appearance_screen.dart`,
`lib/widgets/nav_bar.dart` (the eyebrow line only), `test/theme/*`,
`test/support/golden_harness.dart`, and the `AppAccent` call sites in tests.

Interfaces other tasks rely on
- `AppColors.light()`, `AppColors.dark()`; fields `track`, `thriving`, `good`, `watch`,
  `care`, `thrivingInk`, `goodInk`, `watchInk`, `careInk`.
- `AppType.display`, `score`, `lead`, `title`, `label`.
- `DayPhase`, `ScenePalette`, `scenePalette(DayPhase, Brightness)`.

Acceptance and tests
- `test/theme/contrast_test.dart`: for light and dark, each of the four state inks reaches
  4.5:1 on `bg`, `surface` and `surface2`; each state fill reaches 3:1 on the same three
  grounds; `ink`, `ink2`, `ink3` reach 4.5:1 on all three; `ink` reaches 4.5:1 on every
  sky stop and hill fill of every `scenePalette` in both themes; `onAccent` on `accent`
  reaches 4.5:1. If a DESIGN.md value fails, fail the task and report the measured ratio
  instead of changing the colour.
- `test/theme/app_colors_test.dart`: neutrals equal the section 3 hex values; the accent
  aliases equal the tokens named above; `lerp` at 0 and 1 keeps the state tokens;
  `copyWith(brightness:)` returns the other palette.
- `test/theme/app_type_test.dart`: the five new roles have the exact size, height, weight,
  tracking; `lead.fontFamily == 'Newsreader'`; `display` and `score` carry tabular figures;
  no role carries a colour; no role is below 12 except the untouched legacy `caption2`.
- `test/theme/radii_test.dart`: `Radii.card == 20`.
- `test/settings_repository_test.dart`: unset brightness is dark, a saved `light` reads
  light, a saved `dark` reads dark.
- A test in `test/theme/app_type_test.dart` loads `assets/fonts/Newsreader-Light.ttf`
  through `rootBundle` and finds it non-empty.
- Focused run: `flutter test test/theme test/settings_repository_test.dart test/profile_test.dart`
- Scenario steps for this task's visible changes (the dark default and the Appearance
  screen without its Accent section) are `theme_default_dark`, `theme_appearance_dark` and
  `theme_appearance_switched_light`. Task 8 adds them, since the harness lands separately.

### Task 2: State rule and the three glances
**Depends on:** none

One pure source for "how is this area going" and for what a ring says.

Design decisions (the approved rule for DESIGN.md open decision 4)
- New file `lib/analysis/area_state.dart`.
- `enum AreaState { thriving, good, watch, care }` with `String get word`: Ahead, On track,
  Worth watching, Needs care.
- `double dayShare(DateTime now)`: the fraction of the waking day elapsed, 0 at or before
  07:00, 1 at or after 22:00, linear between.
- `AreaState moneyState({required double spent, required double budget, required DateTime now})`:
  budget <= 0 gives `good`; spent > budget gives `care`;
  `spent / budget - dayShare(now) >= 0.25` gives `watch`; else `good`. Money is never
  `thriving` during the day.
- `AreaState progressState({required num done, required num goal, required DateTime now})`
  for Move and Routines: goal <= 0 gives `good`; done >= goal gives `thriving`; at or after
  21:00 with `done / goal < 0.5` gives `care`; `dayShare(now) - done / goal >= 0.25` gives
  `watch`; else `good`.
- `class AreaGlance { final DetailTracker tracker; final String value; final double fraction; final AreaState state; final String semantics; }`
  and `List<AreaGlance> areaGlances(GlanceNumbers n, Currency currency, DateTime now)`
  returning money, move, routines in that order. `DetailTracker` is the existing enum in
  `lib/controllers/spending_controller.dart`; `GlanceNumbers` is the existing class in
  `lib/screens/today/today_logic.dart` (import it, do not modify that file).
  - Money: value `"$22 left"` (formatted with `formatCurrency`), fraction
    `moneyLeft / budget`; with no budget, value is the amount spent and fraction 0.
  - Move: value `"310 kcal"`, fraction `moveKcal / moveGoal` clamped to 0..1.
  - Routines: value `"2 of 4"`, fraction `done / total` clamped; with no routines, value
    `"0"` and fraction 0.
  - `semantics` reads like the prototype: `"Money: $22 of $60 left to spend. Worth watching"`.
  - The fraction is always the fraction the value states, so ring and number never disagree.

Files owned: `lib/analysis/area_state.dart`, `test/analysis/area_state_test.dart`.

Acceptance and tests (`flutter test test/analysis/area_state_test.dart`)
- `dayShare` at 06:00, 07:00, 14:30, 22:00, 23:30.
- Money: on pace is `good`; 63% spent at 09:00 is `watch`; 63% spent at 20:00 is `good`;
  one cent over budget is `care`; exactly at budget late in the day is `good`; zero budget
  is `good` with fraction 0 and no NaN.
- Progress: goal met is `thriving` at any hour; 0 done at 09:00 is `good`; 0 done at 14:00
  is `watch`; 40% done at 21:00 is `care`; 60% done at 21:30 is `watch`; zero goal is `good`.
- `areaGlances`: order, exact value strings, fractions, over-budget money shows
  `"$0 left"` with fraction 0, semantics strings.

### Task 3: The day plan
**Depends on:** none

One local model behind Today's action card and timeline.

Design decisions
- New file `lib/screens/today/day_plan.dart`, pure, no Flutter widgets.
- `enum PlanKind { proposal, routine, workout, mood, meal, closeOut, sleep, receipt }`.
- `class PlanItem { final String id; final PlanKind kind; final String title; final String icon; final int? minuteOfDay; final String? detail; final String? said; final String actionLabel; final String skipLabel; final bool done; final String? ref; }`
  where `ref` is the proposal id, routine id or entry id the screen needs to act, and
  `icon` is an `AppIcon` name already used in the app.
- `DayPlan buildDayPlan({required PalAgenda agenda, required RitualsState? rituals, required WeekPlanDay? workout, required SleepNight? lastNight, required MoodCheckin? lastCheckin, required List<NutritionMeal> meals, required List<Entry> entries, required DateTime now})`.
  Items, in this rule set:
  - each pending Pal proposal: actionable, untimed, `said` is the proposal body, action
    label is its `approveLabel`, skip label `Not now`;
  - each ritual routine: actionable, timed by `routineMinute(routine.time)` (existing
    helper in `today_logic.dart`), done when `RitualsState.isComplete`, `said` is its
    blurb, action `Start`;
  - today's planned workout when the day is not a rest day: actionable, untimed, detail
    `"45 min"` from `est`, done when `WeekPlanDay.done`, action `Start`;
  - mood check-in: actionable, untimed, done when `lastCheckin` is today, action `Check in`;
  - a meal: one actionable untimed `Log a meal` item when no meal is logged today; each
    logged meal is a done, informational row;
  - evening close-out: actionable, at 21:30, present only when there is at least one
    routine, action `Start`;
  - last night's sleep, when `lastNight` is dated today: done, informational, detail is the
    time asleep;
  - each entry Pal logged today (`isDoneByPal`): done, informational, kind `receipt`,
    `ref` is the entry id.
  - Skip label is `Not today` unless stated.
- `PlanItem` also has `bool get actionable`: true for kinds proposal, routine, workout,
  mood, closeOut, and for the single `Log a meal` item; false for sleep, receipt and
  logged-meal rows.
- `PlanSession`, immutable in-memory session state, matching the current Needs-you
  behaviour. Exact API:
  - `const PlanSession({Map<String, bool> settled = const {}, List<String> history = const [], String? selected})`
    with those three as final fields; in `settled`, true is done and false is skipped.
  - `PlanSession settle(String id, {required bool done})` records the item, appends it to
    `history` and clears `selected`.
  - `PlanSession undo()` removes the last `history` id from `settled` and selects it; with
    an empty history it returns itself.
  - `PlanSession select(String id)`.
  - `bool get canUndo`.
- `DayPlan`. Exact API:
  - `const DayPlan(this.items)`; `final List<PlanItem> items`.
  - `List<PlanItem> open(PlanSession session, DateTime now)`: actionable, not done, not in
    `session.settled`; ordered: timed items whose minute has passed, ascending; then
    untimed; then future timed, ascending.
  - `PlanItem? current(PlanSession session, DateTime now)`: the selected open item, else
    the first open, else null.
  - `List<PlanItem> later(PlanSession session, DateTime now)`: `open` minus `current`, same
    order.
  - `List<PlanItem> get doneRows`: items that are done or not actionable, newest first.
  - `int doneCount(PlanSession session)`: actionable items that are done, or settled as
    done in the session; a skip does not count.
  - `int get total`: the number of actionable items.
  - `String whenLabel(PlanItem item, PlanSession session, DateTime now)`: `Now` for the
    first open item, `At 9:00 PM` for a timed one, `Any time` otherwise, joined to the
    detail with ` · ` as in the prototype.

Files owned: `lib/screens/today/day_plan.dart`, `test/screens/day_plan_test.dart`.

Acceptance and tests (`flutter test test/screens/day_plan_test.dart`)
- Ordering: an overdue routine precedes an untimed proposal, which precedes a future routine.
- `current` follows `select`, and falls back to the first open item when the selected one
  is settled.
- `settle` then `undo` restores the item, selects it, and restores `doneCount`.
- A skipped item leaves `open` and does not raise `doneCount`.
- A rest day has no workout item; no routines means no close-out item.
- Empty inputs (empty agenda, null rituals, null workout, nothing logged) give a plan
  whose only open items are mood and `Log a meal`; settling both gives `current == null`.
- A sleep night dated yesterday is not listed; an email entry from yesterday is not a receipt.
- `whenLabel` for the first open item, a timed item, an untimed item, with and without detail.

### Task 4: Screenshot scenario harness
**Depends on:** none

The Final check: widget-test scenarios that render the real app with real fonts and write
PNGs.

Design decisions
- `test/scenario/scenario_harness.dart`:
  - `Future<void> loadScenarioFonts()`: loads every family declared in the app's
    `FontManifest.json` through `rootBundle` (so the bundled serif is picked up without
    naming it), and registers Roboto from
    `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts` as the sans under every family name
    the app's text resolves to in tests, so no text renders as Ahem blocks.
  - `void scenarioTest(String name, Future<void> Function(WidgetTester tester, bool dark) body, {Clock? at})`:
    registers a light and a dark test tagged `scenario`, pins a 390 by 844 surface at
    device pixel ratio 2, runs under `at` (default `goldenClock` from
    `test/support/golden_harness.dart`), and reuses `bootApp` from that harness.
  - `Future<void> shot(WidgetTester tester, String name)`: captures the app's root repaint
    boundary to `<out>/<name>.png`, where `<out>` is the `ARC_FINAL_OUT` environment
    variable, or `build/scenario` when unset. Creates the directory.
- `dart_test.yaml`: declare the `scenario` tag. `.github/workflows/app.yml`: the test step
  also excludes `scenario`.
- `test/scenario/boot_scenario_test.dart`: boots the seeded app and shoots it.

Files owned: `test/scenario/scenario_harness.dart`, `test/scenario/boot_scenario_test.dart`,
`dart_test.yaml`, `.github/workflows/app.yml`.

Interfaces other tasks rely on: `loadScenarioFonts`, `scenarioTest`, `shot` as above.

Acceptance
- `flutter test --tags scenario test/scenario/boot_scenario_test.dart` exits 0 and writes
  `boot_light.png` and `boot_dark.png` at 780 by 1688, to `ARC_FINAL_OUT` when set.
- The test decodes one PNG and asserts its size, and asserts the tab label `Today` is found
  before shooting.
- Text in the PNGs is real glyphs. The test asserts this by checking that a `Text`
  widget's resolved render paragraph is narrower than the same string would be in Ahem
  (Ahem glyphs are one em wide).
- Scenario steps: `boot_light`, `boot_dark`.

### Task 5: Area detail data
**Depends on:** Task 2

The view model for the area page, from real data.

Design decisions
- New file `lib/controllers/area_detail_controller.dart` (with its `.g.dart`).
- `class Contributor { final String label; final String value; final double fraction; final bool off; }`
- `class WeekBar { final String day; final double? value; final bool today; final bool off; }`
  where `value` is null for days after today.
- `class AreaDetail { final DetailTracker tracker; final String hero; final String unit; final AreaState state; final String palLine; final List<Contributor> contributors; final List<WeekBar> week; final double goal; final String goalLabel; final String weekNote; final List<DayGroup> days; }`
  `days` is the existing recent-entries grouping from `buildDetailData`.
- `AreaDetail buildAreaDetail({required DetailTracker tracker, required List<Entry> entries, required Goals goals, required List<RitualRoutine> routines, required RitualsState? rituals, required WeekPlanDay? workout, required Currency currency, required DateTime now})`,
  pure, reusing `buildDetailData` for totals, target, categories and day groups rather
  than recomputing them, and `moneyState` / `progressState` from Task 2 for the state.
  - Hero and unit. Money: `"$22"` and `"left of $60 today"`; over budget `"$5"` and
    `"over $60 today"`; no budget, the amount spent and `"spent today"`. Move: `"310"` and
    `"of 500 kcal burned"`; no goal `"kcal burned"`. Routines: `"2"` and
    `"of 4 routines done"`; none set up `"0"` and `"routines set up"`.
  - Contributors. Money: `Spent today` (`"$38 of $60"`, spent / budget, off when over),
    then up to three top categories by amount (label, formatted amount, share of spend).
    Move: `Burned` (`"310 of 500 kcal"`), then today's planned workout when there is one
    (routine name, `"45 min planned"` or `"Done"`, fraction 0 or 1). Routines: one per
    routine (name, `"2 of 5 steps"`, steps done / steps).
  - Week: seven bars Monday to Sunday (`startOfWeek`). Money is the day's spend, off when
    over the daily budget. Move is the day's kcal, off when under the goal. Routines is
    routines completed that day (every step logged that day), off when under the target
    (`effectiveDailyRitualTarget`). Today is never off. `goal` is the daily budget, move
    goal or routine target; `goalLabel` is `"$60 daily budget"`, `"500 kcal goal"` or
    `"all 4 routines"`; `weekNote` is `"Every day on track"`, or `"1 day over budget"`,
    `"2 days under goal"`, `"1 day missed"`, counting past days only.
  - Pal line, composed locally in DESIGN.md section 8 voice (short declaratives, no
    exclamation marks, numbers with units), no backend call. Money: `"$22 left for today."`;
    watch `"$22 left, and the day is not over."`; over `"$5 over budget. Hold spending for today."`;
    no budget `"$38 spent today."`. Move: `"190 kcal to go."` plus
    `" Push Day A is planned today."` when a workout is planned and not done; met
    `"Goal met."`. Routines: `"2 left. Evening is at 9:00 PM."` using `RitualsState.upNext`;
    all done `"All 4 done."`; none `"No routines set up yet."`
- `@riverpod Stream<AreaDetail> areaDetail(Ref ref, DetailTracker tracker)` re-emitting on
  entries, goals, routines and weekly plan changes, following the existing detail provider
  in `spending_controller.dart`. Errors propagate to the screen's error state.

Files owned: `lib/controllers/area_detail_controller.dart`, its `.g.dart`,
`test/controllers/area_detail_controller_test.dart`.

Acceptance and tests (`flutter test test/controllers/area_detail_controller_test.dart`)
- Money, move and routines each produce the exact hero, unit, state, contributors, Pal line
  and goal label for a fixed set of entries under a fixed clock.
- Over budget: hero is the overage, never negative; state `care`; first contributor `off`.
- Zero budget, zero move goal, no routines: no NaN or infinity in any fraction or value;
  `goal` 0; `weekNote` `"Every day on track"`; state `good`.
- Week: seven bars, Monday first; days after today have null values; a past day over
  budget is `off` and counted in `weekNote`; today over budget is not `off`.
- Routines per day counts a routine only when all its steps were logged that day.
- The provider re-emits after an entry is inserted (in-memory drift database, as in
  `test/spending_detail_test.dart`).

### Task 6: Ring, contributor bar, week bars
**Depends on:** Task 1, Task 2, Task 4

The three glance and focus components from DESIGN.md section 7, at the prototype's
measurements.

Design decisions
- `lib/widgets/state_colors.dart`: `extension AreaStateColors on AppColors` with
  `Color arcFor(AreaState)` (`ink` for `good` and `thriving`, the `watch` / `care` fill
  otherwise) and `Color wordInkFor(AreaState)` (`ink3` for `good`, the state ink otherwise).
- `lib/widgets/pal_label.dart`: `PalLabel`, the 16 px sparkles icon and the word `Pal` in
  `label`, `ink2`.
- `lib/widgets/shortcut_ring.dart`:
  `ShortcutRing({required String icon, required String value, required AreaState state, required double fraction, required String semanticLabel, required VoidCallback onTap})`.
  56 circle filled `surface`, 3 px `track` ring, 3 px round-capped arc from 12 o'clock for
  `fraction`, 20 px icon in `ink`, value in `headline` tabular, state word in `caption`.
  A `thriving` ring shows a small filled check in the `thriving` fill at the arc's end. One
  button with the given semantics label; the tap target is at least 44 by 44.
- `lib/widgets/contributor_bar.dart`:
  `ContributorBar({required String label, required String value, required double fraction, bool off = false})`.
  Label in `subhead` `ink2` left, value in `subhead` w600 tabular right, a 4 px pill bar
  beneath, `ink` on `track`; value and bar take the `watch` colours when `off`.
- `lib/widgets/week_bars.dart`:
  `WeekBars({required List<double?> values, required List<bool> off, required int todayIndex, required double goal, required String semanticLabel})`.
  Seven equal columns in a 64 tall chart with 8 gaps, top corners radius 4, minimum bar
  height 2, a dashed 1 px `ink3` goal line at `goal / max(goal, values)`, day letters
  M T W T F S S beneath in `caption`. Fills: today `ink`, an off day the `watch` fill,
  other past days `ink3`, days with no value `track`. Today's letter is w600 `ink`. With
  `goal` 0 there is no goal line. The chart is one image-role semantics node with the label.
- These replace nothing yet; Tasks 9 and 10 use them. `lib/widgets/activity_rings.dart`
  and `spend_ring.dart` are untouched (other screens use them).

Files owned: the four widget files above, `lib/widgets/pal_label.dart`,
`test/widgets/shortcut_ring_test.dart`, `test/widgets/contributor_bar_test.dart`,
`test/widgets/week_bars_test.dart`, `test/scenario/components_scenario_test.dart`.

Acceptance and tests
(`flutter test test/widgets/shortcut_ring_test.dart test/widgets/contributor_bar_test.dart test/widgets/week_bars_test.dart`)
- Ring: exposes one button with the exact semantics label; tap fires; target is at least
  44 by 44; the state word text equals `state.word`; the word's colour is `ink3` for
  `good` and the `watch` ink for `watch`; fraction 0, 1 and 1.4 paint without error.
- Contributor bar: `off` colours the value and bar; fraction above 1 is clamped.
- Week bars: seven columns; all values null renders seven track stubs; `goal` 0 draws no
  goal line and does not throw; a value above the goal scales the chart to that value.
- Scenario steps, in `components_scenario_test.dart`, rendering the components on `bg`:
  `components_rings_light`, `components_rings_dark` (one ring per state, plus a thriving
  ring), `components_bars_light`, `components_bars_dark` (contributor bars on and off, a
  week with an off day and future days, and a zero-goal week).

### Task 7: Time-of-day scene
**Depends on:** Task 1, Task 4

The drawn landscape behind the top of Today.

Design decisions
- `lib/widgets/day_scene.dart`: `DayPhase phaseFor(DateTime now)` (morning before 12:00,
  afternoon before 18:00, else evening) and `DayScene({required DayPhase phase})`, a
  `CustomPaint` that is excluded from semantics.
- Geometry from the prototype, scaled to the widget's width from a 390 wide design: a 380
  tall sky gradient, a 150 px radial sun glow at the palette's position, three hill layers
  from the prototype's three SVG paths in a 190 tall band starting at y 190, and a 62 px
  fade into `bg` ending at y 382. Colours come only from `scenePalette(phase, brightness)`.
- A phase change cross-fades over 700 ms; with reduce motion it swaps in one frame.
- No tap-to-preview: the phase follows the clock.

Files owned: `lib/widgets/day_scene.dart`, `test/widgets/day_scene_test.dart`,
`test/scenario/scene_scenario_test.dart`.

Acceptance and tests (`flutter test test/widgets/day_scene_test.dart`)
- `phaseFor` at 00:00, 11:59, 12:00, 17:59, 18:00, 23:59.
- The scene paints at widths 320, 390 and 430 without error and contributes no semantics
  nodes.
- Reduce motion: changing the phase settles in one frame.
- Scenario steps: `scene_morning_light`, `scene_morning_dark`, `scene_afternoon_light`,
  `scene_afternoon_dark`, `scene_evening_light`, `scene_evening_dark`, each the scene over
  `bg` at 390 by 844.

### Task 8: Tab bar and composer restyle
**Depends on:** Task 1, Task 4

The two floating bars, to DESIGN.md section 7 and the prototype. Behaviour is unchanged.

Design decisions
- `lib/widgets/glass_tab_bar.dart`: a 62 tall pill with 4 px padding; each tab is a 22 px
  icon over a `caption` label; the active tab sits on a `surface2` pill in `ink` at w600,
  inactive tabs are `ink3` at w400. The four tabs, their ids, the minimise-on-scroll morph
  to a 52 circle, restore on tap, and reduce-motion handling stay as they are.
- `lib/widgets/pal_ask_bar.dart`: a 52 tall pill, left padding 20, placeholder
  `Tell Pal anything` in `callout` `ink3`, no avatar, and one 44 round button at the right
  filled `ink` with a 20 px mic in `bg`, labelled `Dictate`. Both still open the composer.
- `lib/widgets/glass_surface.dart`: the surface is the Task 1 glass tokens plus a 1 px
  `hair` border, blur 30, and `Elevation.fab`. Reduce-transparency and high-contrast
  fallbacks stay. Other callers of `GlassSurface` are not edited.
- `lib/screens/shell/loop_shell.dart`: only the constants needed so the composer sits 10
  above the tab bar, as today.

Files owned: `lib/widgets/glass_tab_bar.dart`, `lib/widgets/pal_ask_bar.dart`,
`lib/widgets/glass_surface.dart`, `lib/screens/shell/loop_shell.dart`,
`test/widgets/glass_tab_bar_test.dart`, `test/widgets/pal_ask_bar_test.dart`,
`test/widgets/glass_surface_test.dart`, `test/screens/shell_test.dart`,
`test/scenario/shell_scenario_test.dart`, `test/scenario/theme_scenario_test.dart`.

Acceptance and tests
(`flutter test test/widgets/glass_tab_bar_test.dart test/widgets/pal_ask_bar_test.dart test/widgets/glass_surface_test.dart test/screens/shell_test.dart`)
- Existing behaviour tests stay green: taps report ids, only the active tab is selected,
  targets are at least 44 by 44, minimised circle is 52, reduce motion swaps in one frame,
  scrolling minimises and restores, bar and mic open the composer.
- New: the active tab label is w600 in `ink` and inactive labels are `ink3`; the
  placeholder reads `Tell Pal anything`; the mic button is filled `ink`; the bar and the
  mic are two separate buttons.
- Scenario steps: `shell_bars_light`, `shell_bars_dark` (Workout tab active, both bars
  visible), `shell_minimized_dark` (after scrolling the Workout tab down), and
  `shell_composer_dark` (after tapping the composer bar, the composer sheet is open).
- Theme scenario steps for Task 1's visible changes, in `theme_scenario_test.dart`:
  `theme_default_dark` (the app booted with no saved brightness, asserting the theme's
  brightness is dark), `theme_appearance_dark` (the Appearance screen at
  `/you/appearance`, asserting the Light/Dark control is present and no `Accent` header
  is), and `theme_appearance_switched_light` (after tapping `Light`, asserting the theme's
  brightness is light).

### Task 9: Today
**Depends on:** Task 1, Task 2, Task 3, Task 4, Task 6, Task 7

Rebuild Today to the prototype: scene, date line, three rings, Pal's lead, one action
card, timeline.

Design decisions
- `lib/screens/today/today_screen.dart` is rewritten. Top to bottom on `bg`, 16 gutter, 12
  between blocks, content starting 52 below the top as in the prototype, scrollable with
  pull to refresh, bottom padding clearing the floating bars:
  1. `DayScene(phase: phaseFor(now))` behind the top of the screen, scrolling with content.
  2. Header row, 44 tall: the date line `MON 28 SEP · 9:30 AM` in `label` with tracking 1.2,
     `ink2` (the only uppercase on the screen); `Undo` as a text button when the session
     can undo; `N of M done` in `label` tabular `ink2`. The large title, greeting and
     `TabHeaderScrollView` are not used here. A visually hidden `Today` heading keeps the
     screen's semantics header.
  3. Three `ShortcutRing`s in equal columns from `areaGlances` (Task 2), with icons
     `dollarsign.circle.fill`, `figure.run`, `sparkles` or their line equivalents in
     `AppIcon`. Tapping a ring pushes that area's existing route
     (`AppRoute.spendingDetail`, `moveDetail`, `ritualsDetail`). Nothing expands in place.
  4. `PalLabel` and the lead in `AppType.lead`, at most three lines, max width 300, in a
     live region. The lead is the day headline from `todayBriefProvider`; when there is
     none, the current plan item's `said`; when there is neither, the item's title. When
     nothing is open: `Nothing is left. Rest up.`
  5. The action card, the only card: `surface` with a 1 px `hair` border, radius 20,
     padding 16. A 48 disc in `surface2` with the item's 24 px icon; the when line
     (`DayPlan.whenLabel`) in `label` `ink3`; the title in `title`. Below, a primary pill
     (48 tall, `ink` fill, `bg` text, `headline`) and one secondary pill (`surface2`,
     `ink` text). With nothing open the card reads `All done` / `That's the day` with the
     moon icon and no buttons.
  6. The timeline: a 1 px `hair` rail, rows 44 tall with the time (or `Any`) in `caption`
     tabular `ink3`, a 28 disc in `surface2` with an 18 px icon, the title in `callout`
     ellipsised, the detail right-aligned in `subhead` `ink3`. First the `later` items,
     then `doneRows` in `ink3`. With no rows the rail is not drawn.
- Behaviour
  - State comes from `buildDayPlan` (Task 3) fed by the existing providers
    (`palAgendaProvider`, `ritualsControllerProvider`, the weekly plan provider,
    `sleepControllerProvider`, `moodControllerProvider`, `nutritionControllerProvider`,
    `todayStateProvider`), and a `PlanSession` held in the screen's state.
  - Primary pill by kind: proposal approves it (the close-out proposal pushes
    `AppRoute.eveningCloseOut`, as today), routine pushes `AppRoute.routinePlayer`,
    workout goes to `AppRoute.startWorkout`, mood opens `showMoodLogger`, meal pushes the
    Pal composer, close-out pushes `AppRoute.eveningCloseOut`. Approving a proposal
    settles it as done in the session; the others become done from real data when the
    flow completes.
  - Secondary pill settles the item as skipped for this session. `Undo` reopens the last
    settled item.
  - Tapping a `later` row makes it the current card (label `"<title>, at <time>. Do this next"`).
  - Tapping a done row opens its screen: sleep `AppRoute.todaySleep`, mood
    `AppRoute.todayMood`, meal `AppRoute.nutrition`, routine `AppRoute.ritualsDetail`.
    A receipt row shows `Logged <title>, <amount>` and a 44 tall `Undo` that deletes the
    entry; a failed delete shows the existing floating snackbar above the bars and logs
    the error.
  - Loading and error states stay, restyled: `…` in `body` `ink3`, and
    `Couldn't load today. Try again in a moment.` in `subhead` `ink3`.
  - Pull to refresh and app resume still refetch the brief and agenda.
- Proposals move from the Needs-you cards to the action card. In
  `lib/screens/pal/pal_agenda_widgets.dart` delete `NeedsYouSection`, `AgentCard`,
  `CardStatus` and any private helper only they use; `MemoryCard`, `AutopilotCard` and
  `AutopilotRow` stay (the You tab uses them).
- Tests that follow the deletions:
  - `test/controllers/today_brief_controller_test.dart` asserts on the provider's value
    (a non-empty headline, or null) instead of `briefMode` / `BriefMode`, and drops the
    `today_logic.dart` import. Its coverage of the controller is unchanged.
  - `test/pal_home_test.dart`: the group `Needs you on Today` is rewritten against the
    action card, keeping the three behaviours: the primary pill on a proposal settles it
    and `Undo` in the header brings it back; `Not now` removes it; a close-out proposal's
    primary pill navigates to the close-out screen instead of settling. The other groups
    stay; the `pal_agenda_widgets.dart` import stays or goes as the analyzer requires.
- Delete what Today no longer uses: `lib/screens/today/today_area_cards.dart`,
  `lib/widgets/brief_text.dart`, `lib/widgets/whats_left_row.dart`, their tests,
  `AppType.brief` and its test, and from `today_logic.dart` the area ordering
  (`TodayArea`, `AreaStatus`, `orderAreas`), `BriefMode`, `briefMode` and `greetingFor`
  with their tests. Keep `GlanceNumbers`, `isDoneByPal`, `routineMinute`, `eveningMinute`.
  Do not delete anything another screen still imports; grep first.

Files owned: `lib/screens/today/today_screen.dart`, `lib/screens/today/today_logic.dart`,
`lib/screens/today/today_area_cards.dart`, `lib/widgets/brief_text.dart`,
`lib/widgets/whats_left_row.dart`, `lib/theme/app_type.dart` (the `brief` removal only),
`lib/screens/pal/pal_agenda_widgets.dart` (the three deletions only),
`test/controllers/today_brief_controller_test.dart`, `test/pal_home_test.dart`,
`test/today_screen_test.dart`, `test/screens/today_logic_test.dart`,
`test/widgets/brief_text_test.dart`, `test/widgets/whats_left_row_test.dart`,
`test/theme/app_type_test.dart` (the `brief` test only), `test/scenario/today_scenario_test.dart`.

Acceptance and tests
(`flutter test test/today_screen_test.dart test/screens/today_logic_test.dart test/controllers/today_brief_controller_test.dart test/pal_home_test.dart`)
- Three rings with the exact semantics labels from `areaGlances`; tapping each lands on its
  `DetailScreen` with the matching tracker, and no ring changes Today's own content.
- The lead shows the headline when Pal returns one, and the current item's sentence when
  insights fail.
- Pal fully offline (insights and agenda both throw): rings, card and timeline still render
  from local data, and no error view appears.
- The card shows the first open item; the primary pill opens the right route per kind;
  the secondary pill removes it and shows the next; `Undo` brings it back;
  `N of M done` follows.
- Tapping a later row makes it the card.
- A receipt row's `Undo` deletes the entry, and tolerates an entry already gone.
- Sleep, mood and meal done rows open their screens.
- An empty day shows the all-done card, no buttons and no rail.
- Zero goals: rings render with fraction 0, word `On track`, no exception.
- A 60 character routine title at text scale 1.3 on a 390 wide surface raises no overflow.
- Pull to refresh and resume refetch the brief (existing tests, kept).
- The date line is the only uppercase text; no widget on the screen reads an area colour
  token (assert the ring arc and icon colours are `ink`, `track` or a state colour).
- Scenario steps, in `today_scenario_test.dart`: `today_morning_light`,
  `today_morning_dark`, `today_afternoon_light`, `today_afternoon_dark`,
  `today_evening_light`, `today_evening_dark` (clock pinned to 07:10, 14:14, 18:40);
  `today_after_action_dark` (primary pill on a proposal tapped); `today_after_skip_dark`
  (secondary pill tapped, Undo visible); `today_after_undo_dark`; `today_row_selected_dark`
  (a later row tapped); `today_all_done_dark` (empty day); `today_offline_dark` (Pal
  throwing); `today_watch_dark` (money Worth watching); `today_scrolled_dark` (scrolled to
  the done rows); `today_error_dark` (today state provider failing); `today_loading_dark`
  (today state provider still pending, the `…` shown); `today_receipt_undo_dark` (a
  receipt row's `Undo` tapped, the row gone); `today_receipt_undo_failed_dark` (the entry
  repository's delete throwing, the snackbar shown above the bars);
  `today_done_row_sleep_dark` (the sleep row tapped, the Sleep screen shown);
  `today_done_row_mood_dark` (the mood row tapped, the Mood screen shown);
  `today_done_row_meal_dark` (a meal row tapped, the Nutrition tab shown).
- Today's header has no profile button (deferred in the spec).

### Task 10: Area page
**Depends on:** Task 1, Task 4, Task 5, Task 6, Task 9

Replace the detail screen behind the three ring routes with the prototype's area page.

Design decisions
- `lib/screens/detail/detail_screen.dart` is rewritten in place; `DetailScreen(tracker:)`
  and the three routes keep their names and paths, so `lib/router.dart` is not edited.
- Scrollable on `bg`, 16 gutter, top to bottom, at the prototype's spacings:
  1. Header, 44 tall: a back button (chevron and `Today`, `headline`), a spacer, and the
     date line (`MON 28 SEP · 9:30 AM`, `label` with tracking 1.2, `ink2`), as drawn. The
     current `+` button is removed; logging goes through the floating composer. The back
     label is always `Today` (the board's `Areas` label is deferred).
  2. Hero, 20 below: an area label row (16 px icon and `Money` / `Move` / `Routines` in
     `label` `ink2`, the screen's semantics header), the hero number in `display`, then
     the unit in `subhead` `ink2` with the state word in `label` using `wordInkFor`.
  3. `PalLabel` and the Pal line in `body`, max width 320, 28 below the hero.
  4. `What is shaping it` in `headline`, then one `ContributorBar` per contributor, 32
     below.
  5. `This week` in `headline` with `weekNote` right-aligned in `caption` `ink3`, the
     `WeekBars`, and `Dashed line: <goalLabel>` in `caption` `ink3`; the caption line is
     omitted when the goal is 0.
  6. The recent entries grouped by day, from `AreaDetail.days`, restyled flat: a day header
     in `label` `ink3`, rows separated by 1 px `hair` inset to the text edge, title in
     `callout`, amount or detail right-aligned in `subhead` tabular, no card, no area
     colour, no shadow. Row taps and any existing row actions keep working. With no
     entries, one line in `subhead` `ink3`: `Nothing logged yet.`
- Data from `areaDetailProvider(tracker)` (Task 5). Loading and error states keep the
  current copy, restyled to `ink3`.
- Removed from this screen: the hero percent ring, the category card, the glass nav bar,
  the Ask Pal pill. The floating composer in the shell already covers asking Pal.
- No scene behind the hero.
- Delete `DetailTracker` presentation fields that become unused (`colorToken`, `heroSub`,
  `heroIcon`, `askPalPrompt`, `unbudgetedLabel`) only if nothing else reads them; grep first.

Files owned: `lib/screens/detail/detail_screen.dart`, `lib/controllers/spending_controller.dart`
(unused `DetailTracker` fields only), `test/spending_detail_test.dart`,
`test/screens/area_page_test.dart`, `test/scenario/area_page_scenario_test.dart`.

Acceptance and tests (`flutter test test/screens/area_page_test.dart test/spending_detail_test.dart`)
- For each tracker under a fixed clock and seeded data: the hero, unit, state word, Pal
  line, every contributor label and value, the week note and the goal caption are on
  screen with the values `buildAreaDetail` gives.
- The state word is never shown in a state colour without its word; an on-track area shows
  `On track` in `ink3`.
- Back returns to Today; the header shows the date line and no `+` button.
- Recent entries render grouped by day; with none, `Nothing logged yet.` shows.
- Over budget: the hero is the overage, the word is `Needs care`, the first bar is off.
- Zero goal: no goal caption, no exception.
- A long entry title at text scale 1.3 on a 390 wide surface raises no overflow.
- The existing pure `buildDetailData` tests stay green.
- Scenario steps, in `area_page_scenario_test.dart`, each reached by tapping its ring on
  Today: `area_money_light`, `area_money_dark`, `area_move_light`, `area_move_dark`,
  `area_routines_light`, `area_routines_dark`; then `area_money_over_budget_dark`,
  `area_money_scrolled_dark` (recent entries in view), `area_move_empty_dark` (no entries,
  zero goal), `area_error_dark` (provider failing), `area_loading_dark` (provider still
  pending), and `area_back_dark` (after tapping back, Today is shown again).
- Only Money, Move and Routines get this page; Nutrition, Sleep and Mood pages are
  deferred in the spec.

### Task 11: Goldens and rulebook status
**Depends on:** Task 8, Task 9, Task 10

Close out: local baselines and the rulebook match what shipped.

- `test/golden/design_system_golden_test.dart`: the `today` golden asserts the new date
  line (`MON 28 SEP`) instead of the removed large title; the `new_entry` golden builds its
  theme with the no-argument `AppColors` factories. Regenerate every golden with
  `flutter test --update-goldens --tags golden` and commit the PNGs.
- `DESIGN.md`: section 10's lead sentence says the tokens are applied in `lib/theme/` and
  each row names what was done (accent aliases kept, area colours kept for untouched
  screens, legacy type roles kept for untouched screens). Section 11: decision 1 resolved
  (Newsreader Light, bundled), decision 3 resolved (dark is the default), decision 4
  resolved with the Task 2 rule written out in full. Decisions 2 and 5 stay open. Change
  nothing else in the document.
- `test/scenario/final_scenario_test.dart`: the end-to-end pass over the merged result.

Files owned: `test/golden/**`, `DESIGN.md`, `test/scenario/final_scenario_test.dart`.
This task edits nothing under `lib/`; Tasks 9 and 10 delete what they orphan.

Acceptance
- `flutter test --tags golden` passes against the regenerated baselines.
- `flutter analyze --fatal-infos` is clean.
- `git diff --ignore-cr-at-eol --exit-code` is clean after
  `dart run build_runner build --delete-conflicting-outputs`.
- Scenario step: `final_today_dark` and `final_area_money_dark` in
  `test/scenario/final_scenario_test.dart`, the seeded app at the golden clock on Today
  and, after tapping the Money ring, on its area page.
