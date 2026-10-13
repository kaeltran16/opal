# Workout family in the Oura design language (run A of 3)

> **For agentic workers:** each task carries its design decisions, the files it owns, the interfaces other tasks rely on and the focused tests that prove it. You write the implementation. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Convert the Workout tab, its sub-screens, the session flow and the routine editor, plus three shared widgets (nav-bar title, ListRow/InsetSection, controls), to the Oura design language, following the approved Workout canvas.

**Architecture:** First the shared widgets and the session engine change land as independent tasks. The screens then restyle in parallel on top of them, one owner per file. Pieces that two screens show (day strip, session row, search pill, exercise row) are shared widgets from Task 3, and the Pal pick lead has one owner (Task 5). Last, one new scenario file shoots every canvas state and sub-screen in both themes. The behaviour stays where it lives today (the controllers). The screens only lay out, apart from the running-session rule, which lives in one launcher helper.

**Tech Stack:** Flutter, Riverpod 3 codegen (`riverpod_annotation`), go_router, flutter_test scenario harness (`test/scenario/scenario_harness.dart`).

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Verify:** `flutter test --exclude-tags "golden || scenario"`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario/workout_scenario_test.dart`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first-workout\project\Main.dc.html

## Design sources

- The canvas above is the reference: its `renderVals()` is the behaviour and its inline styles are the measurements. It is gitignored, so read it by absolute path. Its Ask Pal sheet (`ask.open`) belongs to run B. Do not build it.
- `DESIGN.md` sections 2 to 9 are the rules. The converted screens to match are Today (`lib/screens/today/today_screen.dart`: `_Lead`, `_ActionCard`, `_Pill`), You (`lib/screens/profile/profile_screen.dart`: `_LinkRow`), `lib/screens/you/sub_screen.dart`, `lib/widgets/pal_label.dart` and `lib/widgets/contributor_bar.dart`.
- Canvas measurements to reuse: title 22/27 w500; section heading `headline` 17/600; Pal's line `AppType.lead`; the action card is `surface`, radius `Radii.card`, padding 16, gap 14; the primary pill is 48 tall with `ink` fill and `bg` text in `headline`; the secondary pill uses `surface2` fill with `ink` text; text buttons are `headline` in `ink` or `ink2` with no fill; hairline rows are 1px `hair`, min height 48 (tool rows 52); icon buttons are 44 circles in `surface2`; stats are 28/32 w300 tabular with the unit in `subhead` `ink3` and the label in `label` `ink3`, with columns split by a 1px `hair` left border; bars are 4px `ink` on `track`; the state word for a beaten best is "Ahead" or "New best" in `thrivingInk`.

## Deviations from the canvas (decided by the user)

- **Freestyle:** the tab's + is labelled `Start a workout` and opens Start workout (the routine picker). Freestyle sessions do not exist in the app: the old row had no tap handler and the engine needs a routine id. The inert row is removed, and real freestyle is the initiative's follow-up chunk "Workout: real freestyle sessions".
- **Pick another replaces Not today** (run goal): the card's secondary calls `PalPickController.another()`. The canvas's "Rest today, then…" skipped state is therefore not built.
- **Pal's line is `WorkoutSuggestion.rationale`** (run goal), never the canvas's sample sentence.
- **Post-workout reading copy** (run goal): it keeps the app's `Pal is reading your session…`, not the canvas's `Reading your session…`.
- **Settled day** (user, 10-14): built. Once a workout is logged today, the lead settles as the canvas does (Task 5).

## Plan-owned designs (not on the canvas)

The canvas draws only the tab, the session, the finish sheet and the summary. These are this plan's designs, built from DESIGN.md and the canvas's patterns, and the final verifier should judge them against DESIGN.md rather than the canvas: the Pal pick error state; the in-progress line copy; the Recent section being hidden when there are no sessions (existing behaviour); and every sub-screen (Start workout, Generate with Pal, Weekly plan, History and trends, Workout detail, Exercise library, Routine editor and its sheets, Streak celebration).

## Global constraints

- Done means, per task: the task's files have zero matches for
  `AppType\.(caption2|footnote|title1|title2|title3|large|amountLg|amount)\b|\bc(olors)?\.(money|move|rituals|nutrition|sleep|mood)(Tint|Ink)?\b|Elevation\.(sm|card)\b|\.glass(Border|Highlight)?\b|\.accent(Ink|Tint)?\b|onAccent|\bsfr\(|AppText\.mono|Radii\.(md|lg)\b`
  (check with `grep -nE '<pattern>' <files>`).
- Colour means state only. No area colours, gradients, glass cards or shadows. Blur only on floating bars. Big numbers are light and tabular (`AppType.display` / `AppType.score`). Titles are `AppType.title`. One lead and one primary pill per screen. Space first, hairline second, card last. Line icons in `ink2`, never `.fill` glyphs in coloured tiles. Every state colour comes with its word. Uppercase only on a date line.
- Restyle; never drop behaviour. Every existing tap target, sheet, dialog result, snackbar and controller call on a screen still works.
- No magic numbers: name measurements as file-level `const`s, as `today_screen.dart` does. Comments are lower case and say only why.
- Touch targets are 44 or larger, and every tappable control has a semantics label.
- No new dependencies. No emojis. Riverpod codegen: `dart run build_runner build --delete-conflicting-outputs`, and commit the `.g.dart` files.
- Shared widgets keep their public constructors source-compatible: runs B and C call `ListRow`, `InsetSection`, `Segmented` and `ProgressBar` from their own files.
- Commit subjects use `type(scope): summary` with no attribution or co-author trailer.
- `test/scenario/final_scenario_test.dart` already fails on main. Do not edit it.
- Goldens: only `test/golden/goldens/move_light.png` and `move_dark.png` are regenerated (Task 5). Task 3's `Segmented` change also reaches the `new_entry` golden. That screen is run B's, so `new_entry_light.png` and `new_entry_dark.png` are left stale on purpose: goldens are outside Verify, and run B (or the final token-retirement run) regenerates them. Say so in the task report.
- Scenario steps: every task names, in its acceptance, the steps in `test/scenario/workout_scenario_test.dart` that show its views and perform its interactions. Task 11 writes that file (one owner), with exactly those step names.

## Review focus

1. **Text scale 1.3 on a 390-wide surface.** Rows, stat rows, steppers and pills must not overflow; they wrap or ellipsise. Tests for this are in Tasks 2, 3, 6 and 9.
2. **Leaving a running session.** Minimise, browse other tabs and come back: the tab card reads In progress, and Resume reopens the same sets. Finishing clears it, so the tab settles. Tests in Tasks 4 and 5, and scenario steps `workout_tab_in_progress` and `session_resumed`.
3. **Skip exercise on the last exercise.** It completes the session ("All sets logged") rather than throwing or looping. Test in Task 4.
4. **Pal's pick after Pick another.** While loading, the line reads `Thinking…` in ink3 with no card. On failure, the line and card change as described in Task 5. Test in Task 5.
5. **Steppers at their floors.** Weight never goes below 0 and reps never below 1. Test in Task 9.

---

### Task 1: Nav bar large title
**Depends on:** none
**Chunk:** Shared: large nav-bar title
**Files:** `lib/widgets/nav_bar.dart`, `lib/screens/shell/tab_header.dart`, `test/large_title_scroll_view_test.dart`, `test/screens/tab_header_test.dart`, `test/navigation/route_compat_test.dart`

Decisions:
- `LargeTitleNavBar` and `LargeTitleScrollView`'s expanded title use `AppType.title` (22/27 w500) in `ink`, not bold 34. The expanded block matches the canvas header: the title on one 44pt row with the `trailing` action at its right (`min-height: 44`, title `flex: 1`, the action a 44 control). `leading` (back), when present, sits on its own 44 row above. Eyebrow and subtitle keep their API; subtitle uses `subhead` `ink3`, eyebrow `label` `ink3`. Re-derive `_titleH`, `maxExtent` and friends from the new metrics, as named consts.
- Collapsed bar: the compact title is `headline`, centred, constrained to the space between `leading` and `trailing` (ellipsised), so it can never draw under or over either one. This fixes "the collapsed bar draws + over the title on Workout". The collapsed bar may keep `GlassSurface` (a bar floating over scrolling content is the one place blur is allowed). Its hairline is 1px `hair`.
- "The collapsed title sits flush left on You": check whether You renders through this widget. If it does, fix it here. If it doesn't (profile_screen.dart is run B's and has its own header), leave it and say so in the task report.
- `NavIconButton` becomes the canvas's 44 `surface2` circle with a 20 `ink` glyph, replacing the 32 circle in `c.accent`. `NavAction`'s default tint is `ink` (`color` still overrides it), and disabled stays `ink4`.
- Clear the legacy tokens in `nav_bar.dart` (`AppType.large`, `c.accent`).

Acceptance: the tests below pass, plus scenario steps `workout_tab` (expanded title with + on one row) and `workout_tab_collapsed` (the tab scrolled until the bar collapses, the compact title clear of the +).

- [ ] Write failing tests in `test/large_title_scroll_view_test.dart`: (a) the expanded title's style is `AppType.title` (font size 22, weight w500); (b) with a trailing 44 action and a long title on a 390-wide surface, fully collapsed, the compact title's rect does not intersect the trailing or leading rects; (c) the trailing action shares a row with the expanded title (equal vertical centres, within 1px).
- [ ] Update `test/screens/tab_header_test.dart` and `test/navigation/route_compat_test.dart` only where they assert the old metrics or tint.
- [ ] Implement. Run `flutter test test/large_title_scroll_view_test.dart test/screens/tab_header_test.dart test/navigation/route_compat_test.dart`, then `flutter analyze --fatal-infos`.
- [ ] Commit `feat(nav): oura large title and collapsed bar`.

### Task 2: ListRow and InsetSection without coloured tiles
**Depends on:** none
**Chunk:** Shared: coloured icon tiles in ListRow and settings rows
**Files:** `lib/widgets/inset_section.dart`, `test/widgets/inset_section_test.dart`

Decisions:
- `InsetSection` is open: no surface card, no clip, no fill. Its `header` renders as written (no `toUpperCase`) in `headline` `ink`, as the canvas's "Recent" heading does (margin bottom 4). `footer` is `subhead` `ink3`. The default `margin` keeps the 16 screen gutter and the bottom gap.
- `ListRow` takes the canvas tool-row shape: min height 52; the optional icon is a 22 `ink2` `AppIcon` with no tile; a 14 gap; the title in `body` `ink`; the subtitle in `subhead` `ink3`; the value in `subhead` `ink3` tabular (`valueColor` still overrides it); a 16 `ink3` chevron when tappable. Rows run on the screen gutter: no inner horizontal padding, so the row text lines up with the section header. The hairline is 1px `hair` between rows (not under `last`), inset to the text edge when there is an icon. The pressed highlight stays `fill`.
- `iconBg` and `iconColor` stay as constructor parameters, ignored. Their doc comment says they are kept only so existing call sites compile until the legacy tokens retire. Do not mark them `@Deprecated`: same-package deprecation is an info and fails `--fatal-infos` for the other runs.
- Overflow fix (inset_section.dart:121, 27px at text scale 1.3 on 390 wide): the value is capped at half the row width and wraps instead of overflowing, as profile_screen.dart's `_Value` does. The title may wrap to 2 lines.
- Semantics: a tappable row is a button labelled `title`, plus `, value` when there is a value.

Acceptance: the tests below pass, plus scenario step `workout_tab` (the tool rows with `ink2` icons and no tiles).

- [ ] Write failing tests in `test/widgets/inset_section_test.dart`: (a) a `ListRow(icon: 'calendar', iconBg: <any colour>, …)` paints no decorated tile, so no `Container`/`DecoratedBox` ancestor of the icon has a colour; (b) the icon's colour is `ink2`; (c) 390 wide at `TextScaler.linear(1.3)` with title `History and trends` and value `All sessions, all time` throws no overflow (`tester.takeException()` is null); (d) the header text is not uppercased; (e) the semantics label is `title, value`.
- [ ] Implement. Run `flutter test test/widgets/inset_section_test.dart` and `flutter analyze --fatal-infos`.
- [ ] Commit `feat(widgets): open inset sections and line-icon list rows`.

### Task 3: Controls and the shared Oura pieces
**Depends on:** none
**Chunk:** Shared: segmented controls, toggles and chips (controls.dart)
**Files:** `lib/widgets/controls.dart`, `lib/widgets/stat_row.dart`, `lib/widgets/app_sheet.dart`, `lib/widgets/pal_lead.dart`, `lib/widgets/day_strip.dart`, `lib/widgets/session_row.dart`, `lib/widgets/exercise_row.dart`, `lib/widgets/app_icon.dart`, `test/widgets/controls_test.dart`, `test/widgets/stat_row_test.dart`, `test/widgets/app_sheet_test.dart`, `test/widgets/pal_lead_test.dart`, `test/widgets/workout_rows_test.dart`

Interfaces (later tasks rely on these exact names; every widget here is presentational and reads no providers):
- `controls.dart`
  - `PillButton({required String label, required VoidCallback? onTap, bool primary = true, String? icon, String? semanticLabel})`: 48 tall, full pill, `headline`. Primary is `ink` fill with `bg` text. Secondary is `surface2` fill with `ink` text. An optional leading 18 glyph. A null `onTap` renders disabled (text `ink4`). The label ellipsises on one line.
  - `AppSwitch({required bool value, required ValueChanged<bool>? onChanged, required String semanticLabel})`: a `CupertinoSwitch` with track `ink` when on and `track` when off, thumb `bg` when on and `ink3` when off, as autopilot_screen.dart does.
  - `AppChip({required String label, required bool selected, required VoidCallback onTap})`: a pill at least 44 tall (tap target) with a 32 visible height. Unselected is `surface2` with `ink2` text. Selected is `ink` fill with `bg` text. Text in `label`. Semantics: a button that reports `selected`.
  - `SearchPill({required TextEditingController controller, String placeholder = 'Search', ValueChanged<String>? onChanged})`: 44 tall, a `surface2` pill, a `magnifyingglass` `ink3` 16 glyph, `body` text, an `ink3` placeholder, and a semantics text field labelled `placeholder`.
  - `Segmented<T>` keeps its constructor: the track is a `surface2` pill, the thumb is a `surface` pill (`bg` in light, if `surface` reads too close) with no shadow, labels in `label`, the selected one `ink` and the rest `ink2`, and each segment at least 44 tall.
  - `ProgressBar({required double value, Color? color, double height = 4})`: `ink` on `track`. The `gradient` parameter is removed, since it has no callers.
  - `CheckButton` is deleted (no callers in lib or test; grep again before deleting).
- `stat_row.dart`: `StatRow({required List<Stat> stats})` and `Stat({required String value, String? unit, required String label})`. Equal columns, value 28/32 w300 tabular `ink` (a named `TextStyle` built from `AppType.score` with copyWith), unit `subhead` `ink3`, label `label` `ink3`, a 1px `hair` left border with 16 padding on every column after the first. A value scales down (`FittedBox`) rather than overflowing.
- `app_sheet.dart`: `Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scrollable = false})`. A bottom sheet with a `surface` fill, top radius `Radii.card`, padding `8 16 34` plus the safe area, a 36x5 `track` grabber, a `scrim` barrier and no shadow. `scrollable` uses `isScrollControlled` for tall content (the exercise picker).
- `pal_lead.dart`: `PalLead({String label = 'Pal', required String text, bool muted = false})`. `PalLabel(text: label)` over the line in `AppType.lead`, max 3 lines, max width 330, gap 8, `ink` (or `ink3` when `muted`), wrapped in a live region. Also `ActionCard({required String meta, required String title, required Widget primary, Widget? secondary})`: the canvas lead card (`surface`, `Radii.card`, padding 16, gap 14, meta `label` `ink3` tabular, title `AppType.title`, a row with `primary` expanded and `secondary` capped at half the width).
- `day_strip.dart`: `DayStrip({required List<DayMark> days, required String semanticLabel, ValueChanged<int>? onTap, int? selected})` and `DayMark({required String letter, required bool done, required bool today})`. The canvas strip: 7 equal columns, 30 discs; done is `ink` fill with a 14 `bg` check; today is a 1.5 `ink` ring; other days are `track`; the letter is `caption`, with today `ink` w600 and the rest `ink3`. `selected` draws an `ink` ring. With `onTap`, each column is a 44 target labelled with its day; without it, the strip is one image labelled `semanticLabel`.
- `session_row.dart`: `SessionRow({required String when, required String title, required String detail, bool newBest = false, VoidCallback? onTap, bool first = false})`. A hairline row (no top border when `first`), min height 48: `when` in `caption` `ink3` at width 44 (text-scaled), the title in `callout` `ink`, the detail in `subhead` `ink3` tabular, then `New best` in `thrivingInk` when `newBest`. The semantics label is `title, when, detail[, new best]`.
- `exercise_row.dart`: `ExerciseRow({required String name, required String detail, String icon = 'dumbbell', String? value, VoidCallback? onTap, Widget? trailing, bool first = false})`. A hairline row, min height 52: a 22 `ink2` line icon, the name in `body`, the detail in `subhead` `ink3` (one line, ellipsised), then `value` in `subhead` `ink3` tabular, or `trailing` (for the editor's controls).
- `app_icon.dart`: add the line glyphs the screens need, mapped to Cupertino/Material outline icons: `list.bullet`, `wand.and.stars`, `book`, `chart.line.uptrend.xyaxis`, `minus`, `dumbbell`, `star`, `trash`, `square.and.arrow.up` if missing. Existing names stay.

Callers in runs B and C (`Segmented` in new_entry_sheet, recap, rituals_builder, appearance and budgets_goals; `ProgressBar` in email_dashboard) must still compile unchanged.

Acceptance: the tests below pass, plus scenario steps that show each piece in use: `workout_tab` (DayStrip, SessionRow, StatRow, ActionCard, PalLead), `history` (Segmented), `exercise_library` (SearchPill, AppChip, ExerciseRow), `session_finish_sheet` (showAppSheet, PillButton primary and secondary), and `routine_editor_toggles` (AppSwitch).

- [ ] Write failing tests: `controls_test.dart` (PillButton primary and secondary colours; null `onTap` is disabled and not tappable; `AppChip` semantics reports selected; `Segmented` calls `onChanged` and each segment is at least 44 tall; `SearchPill` forwards typed text to `onChanged`); `stat_row_test.dart` (three stats at 390 wide and text scale 1.3 with no overflow; each column after the first has a left hair border); `app_sheet_test.dart` (the sheet shows its grabber and content, a barrier tap dismisses it with null, and `pop(true)` returns true); `pal_lead_test.dart` (`muted` paints the line in `ink3`; the line uses the `Newsreader` family; `ActionCard` at 390 and text scale 1.3 does not overflow); `workout_rows_test.dart` (DayStrip: a done day paints an `ink` disc with a check, and `onTap` reports the index; SessionRow: `newBest` shows `New best` in `thrivingInk`; ExerciseRow: no coloured tile ancestor on the icon and no overflow at 1.3).
- [ ] Implement. Run `flutter test test/widgets/controls_test.dart test/widgets/stat_row_test.dart test/widgets/app_sheet_test.dart test/widgets/pal_lead_test.dart test/widgets/workout_rows_test.dart` and `flutter analyze --fatal-infos`.
- [ ] Commit `feat(widgets): oura controls, stat row, sheet, lead and workout rows`.

### Task 4: Running session and Skip exercise
**Depends on:** none
**Files:** `lib/controllers/workout_session.dart`, `lib/controllers/workout_session_controller.dart`, `lib/controllers/workout_session_controller.g.dart`, `lib/screens/workout/session_launcher.dart`, `test/workout_session_test.dart`, `test/controllers/running_session_test.dart`

Decisions and interfaces:
- `WorkoutSession.skipExercise()` (in `workout_session.dart`): drops the current exercise's not-done sets from the workout, stops any rest, and moves the cursor to the first open set of the next exercise. On the last exercise the session becomes complete (`isComplete` true). It is a no-op when complete. `WorkoutSessionController.skipExercise()` delegates, re-snapshots and syncs the Live Activity like the other commands.
- `WorkoutSessionController` becomes `@Riverpod(keepAlive: true)`, so minimising (popping the screen) does not end the session, its timer or its Live Activity. `finish()` still returns the `Workout`. It then clears the running session and invalidates itself, so the next start is fresh and `onDispose` ends the Live Activity.
- `RunningSession` lives in `lib/controllers/workout_session_controller.dart`, beside the controller: `@Riverpod(keepAlive: true) class RunningSession` → `runningSessionProvider`, state `String?` (the running routine id). Methods: `void start(String routineId)` and `void clear()`.
- `lib/screens/workout/session_launcher.dart`: `void openWorkoutSession(BuildContext context, WidgetRef ref, String routineId)`. If a session is running, it pushes `AppRoute.activeSession` for the running routine id (resume). Otherwise it calls `start(routineId)` and pushes that one. This is the single source of the one-session-at-a-time rule: every Start, Resume and Start workout in Tasks 5, 6, 7 and 9 calls it.
- A session opened by deep link (`/session/:routineId`, Live Activity) must also read as running. Mark it running from the controller once its build has resolved, or from the screen in Task 9. Riverpod 3 forbids modifying another provider synchronously during build. Whichever you pick, the test below must pass and the choice goes in the report.

Acceptance: the tests below pass, plus scenario steps `session_skip_exercise` (Skip exercise performed, the next exercise shown), `workout_tab_in_progress` (minimised, still running) and `session_resumed` (Resume reopens the session with the set logged before minimising still done).

- [ ] Write failing tests. In `test/workout_session_test.dart`: skip on the first exercise moves to exercise 2, set 1, and removes exercise 1's open sets; skip mid-rest stops the rest; skip on the last exercise completes the session. In `test/controllers/running_session_test.dart`, with a `ProviderContainer`: the session state survives the listener going away (keepAlive), with logged sets intact; `finish()` clears `runningSessionProvider` and a re-read starts fresh; building the controller for routine X leaves `runningSessionProvider` == X.
- [ ] Implement, then run `dart run build_runner build --delete-conflicting-outputs`. Run `flutter test test/workout_session_test.dart test/controllers/running_session_test.dart test/active_session_test.dart` and `flutter analyze --fatal-infos`.
- [ ] Commit `feat(workout): keep a running session alive and add skip exercise`.

### Task 5: Workout tab and the Pal pick lead
**Depends on:** Task 1, Task 2, Task 3, Task 4
**Chunk:** Workout tab
**Files:** `lib/screens/move/move_screen.dart`, `lib/screens/workout/pal_pick_lead.dart`, `test/move_screen_test.dart`, `test/screens/workout/pal_pick_lead_test.dart`, `test/golden/goldens/move_light.png`, `test/golden/goldens/move_dark.png`

`lib/screens/workout/pal_pick_lead.dart` (Task 6 reuses it): `class PalPickLead extends ConsumerWidget` with `const PalPickLead({super.key, bool onPicker = false})`. It renders `PalLead` plus an optional `ActionCard` (Task 3). Its states, the first that matches wins:
1. **In progress** (`runningSessionProvider` non-null): label `In progress`; the line `{done} sets in, {left} to go.` from that session's `ActiveSessionState`; the card's meta `{m:ss elapsed} · {current exercise name}`, ticking each second while visible; title the routine name; primary `Resume` (`openWorkoutSession`); no secondary.
2. **Settled** (not on the picker, and a workout was logged today: the newest `RecentSession` with `relativeDate == 'Today'` from `moveStateProvider`): label `Pal`; the line `{workout name} is done. {next routine} is next, on {Weekday}.`, where the next routine is the first day after today in `weeklyPlanControllerProvider` with a routine (rest days skipped). With no planned routine left this week, the line is `{workout name} is done.`. No card. This is a fixed sentence in code, not a model call.
3. **Pick loading** (`palPickControllerProvider` loading): label `Pal's pick for today`; the line `Thinking…`, `muted`; no card.
4. **Pick error**: the line `Pal couldn't pick one just now.`, muted. On the tab, the card is titled `Pick a routine`, with primary `Start workout` (opens `AppRoute.startWorkout`) and secondary text button `Try again` (`another()`). On the picker (`onPicker: true`), the card is titled `Pick a routine below` with primary `Try again`.
5. **Pick**: label `Pal's pick for today`; the line `WorkoutSuggestion.rationale`; the card's meta `{estimatedMinutes} min · {focus}` (missing parts skipped); title `suggestion.title`; primary `Start` (`openWorkoutSession` with `routineId`, falling back to `startWorkoutProvider`'s `firstStrength`; with neither, open Start workout); secondary text button `Pick another` (`PalPickController.another()`).

The Workout tab (`move_screen.dart`), following the canvas's `onTab` board top to bottom:
- Header via `TabHeaderScrollView` (Task 1): title `Workout`, no subtitle. The contextual action is a 44 `surface2` + with the semantics label `Start a workout`, opening `AppRoute.startWorkout`.
- `PalPickLead()`.
- This week: heading `This week`, with `{weekWorkouts} of {weekGoal} workouts` on the right in `subhead` `ink3`, or `No weekly plan yet` when `weekGoal == 0`. Then `DayStrip` from `MoveState.weekDays`, with semantics `This week: trained {days}. {n} of {goal} workouts`. Then a `StatRow`: Volume `{t}` unit `t`, Time `{min}` unit `min`, Records `{weekPrCount}`.
- Recent (only when `recentSessions` is non-empty, which is existing behaviour): heading `Recent` with a `See all` text button at the right (opens `AppRoute.workoutHistory`). `SessionRow`s with `relativeDate`, the name, `{min} min · {t} t`, and `newBest` when the session set a PR (as the old `_PrBadge` decided). A row opens `AppRoute.workoutDetail`.
- Tools (`InsetSection` with no header and `ListRow`s): Weekly plan (`calendar`), My routines (`list.bullet`, value `MoveState.routineCount`, opens Start workout), Generate with Pal (`wand.and.stars`, opens the generator), New routine (`plus`, opens the routine editor), Exercise library (`book`, value: the length of `exercisesProvider`'s data, omitted while loading), History and trends (`chart.line.uptrend.xyaxis`).
- Other activity (only when non-empty): `InsetSection(header: 'Other activity')`, with `ListRow` icon `figure.run`, title and subtitle, no chevron.
- The loading and error states of `moveStateProvider` keep their text, restyled (`…` in `ink3`; `Couldn't load Workout.` in `subhead` `ink3`).
- Delete `_WeekHero`, `_MiniRing`, `_RingPainter`, `_HatchPainter`, `_StartCta`, `_SessionCard`, `_VolumeSparkline`, `_StatChip` and `_PrBadge` once nothing uses them.

Acceptance: the tests below pass, plus scenario steps `workout_tab`, `workout_tab_collapsed`, `workout_tab_thinking`, `workout_tab_error`, `workout_tab_pick_another` (after Pick another resolves, the new rationale and title show), `workout_tab_no_plan`, `workout_tab_in_progress` and `workout_tab_settled` (after a session is saved: the settled line, no card, today ticked, a Today row in Recent).

- [ ] Write failing tests in `test/screens/workout/pal_pick_lead_test.dart`, overriding the providers for each state: the rationale shows and the canvas sample does not; `Pick another` calls `another()`; while loading, `Thinking…` shows with no `Start`; on error, `Pal couldn't pick one just now.` and `Try again` show (and the picker variant has no `Start workout`); a running session shows `In progress` and `Resume` and no `Pick another`; with a workout logged today and a routine planned for a later day, the settled line names both; with nothing planned, it ends after `is done.`; in-progress takes precedence over settled.
- [ ] Update `test/move_screen_test.dart` (the existing `Generate with AI` assertions become `Generate with Pal`): `weekGoal == 0` shows `No weekly plan yet`; the + has the semantics label `Start a workout` and opens Start workout; `New routine` is a row that opens the editor; `See all` opens history; the exercise library row shows the `exercisesProvider` count.
- [ ] Implement. Run `flutter test test/move_screen_test.dart test/screens/workout/pal_pick_lead_test.dart test/move_controller_test.dart` and `flutter analyze --fatal-infos`. Run the legacy-token grep on both lib files.
- [ ] Regenerate the Workout goldens: `flutter test --update-goldens --tags golden test/golden/design_system_golden_test.dart --plain-name move`, and check that only `move_light.png` and `move_dark.png` changed.
- [ ] Commit `feat(workout): workout tab and pal pick lead in the oura design`.

### Task 6: Start workout and Generate with Pal
**Depends on:** Task 5
**Files:** `lib/screens/workout/start_workout_screen.dart`, `lib/screens/workout/routine_generator_screen.dart`, `test/start_workout_test.dart`, `test/screens/workout/routine_generator_goals_test.dart`

Start workout:
- Header `Start workout` with a back control. The subtitle becomes `Pick a routine`.
- Lead: `PalPickLead(onPicker: true)` (Task 5). Delete `_PalPickCard`, `_StartButton` and `_AnotherButton`. The pick card is the screen's one primary pill, so the routine rows carry no pills.
- Strength and Cardio become `InsetSection(header: 'Strength')` / `'Cardio'` with `ExerciseRow`s (Task 3) in place of the 2-column grid and the cardio cards. Use the `dumbbell` or `figure.run` icon, the routine name, the detail `{n} exercises · {min} min · {3 days ago | Never done}`, and a second detail line replacing the chips: the first exercise names (`Bench press, Incline press, +3`). If `ExerciseRow` has one detail line, join the two with ` · ` and let it ellipsise. Tap opens via `openWorkoutSession`; long-press still deletes through the existing Cupertino confirm. This removes the "BOTTOM OVERFLOWED BY 4.9 PIXELS".
- Tool rows: Generate with Pal, New routine, Exercise library (`ListRow`s, `ink2` icons). The inert `Freestyle session` row is removed.

Generate with Pal:
- The title is `Generate with Pal`. The hero card and radial tint become `PalLead(text: 'Describe the workout you want.')`.
- The prompt field is a `surface2` box (radius `Radii.card`, padding 16, `body`), and its placeholder is `ink3`.
- Quick goals become `AppChip`s. Generate is the primary `PillButton`, and loading shows the pill label `Generating…`, disabled.
- The error card becomes a `subhead` line in `careInk` with the word `Couldn't generate` first, plus a `Try again` text button.
- The result header shows the routine name in `title` and meta in `label` `ink3`. Exercises are `ExerciseRow`s with detail `sets × reps`. The result actions keep their existing labels and callbacks; the save action becomes the primary `PillButton` and the other becomes a secondary `PillButton`.

Acceptance: the tests below pass, plus scenario steps `start_workout` (the routine list at 390 wide, no overflow banner), `start_workout_delete_confirm` (long-press on a routine shows the confirm), `generate`, `generate_loading` (Generating… while the controller is pending) and `generate_result`.

- [ ] Write failing tests. In `test/start_workout_test.dart`: at a 390 by 844 surface (`tester.view.physicalSize`) and at text scale 1.0 and 1.3, the screen with 4 strength and 1 cardio routine throws no overflow; `Freestyle session` is absent; tapping a routine with `runningSessionProvider` set to another routine opens the running one; long-press still shows the delete confirm. In `routine_generator_goals_test.dart`: the title reads `Generate with Pal`; a quick-goal chip fills the prompt (existing behaviour); Generate while loading is disabled and reads `Generating…`.
- [ ] Implement. Run `flutter test test/start_workout_test.dart test/screens/workout/routine_generator_goals_test.dart test/controllers/routine_generator_controller_test.dart` and `flutter analyze --fatal-infos`. Run the legacy-token grep on both screens.
- [ ] Commit `feat(workout): start workout and generate with pal in the oura design`.

### Task 7: Weekly plan and History
**Depends on:** Task 1, Task 2, Task 3, Task 4
**Files:** `lib/screens/move/weekly_plan_screen.dart`, `lib/screens/move/workout_history_screen.dart`, `test/weekly_plan_editor_test.dart`, `test/workout_history_screen_test.dart`

Weekly plan:
- The week chips become `DayStrip` (Task 3) with `onTap` and `selected`. Tap behaviour stays.
- The purple today spotlight becomes `ActionCard`: meta `Today`, the routine name as title, primary `PillButton('Start workout')` calling `openWorkoutSession`. A rest day today shows only the line `Rest day` in `title` with no card.
- Schedule rows are `SessionRow`s: `when` is the weekday, the title is the routine name (or `Rest`), the detail is the existing estimate. Tapping opens the assign sheet. The dashed circle painter goes.
- The assign-routine sheet uses `showAppSheet`, with `ListRow`s (Start workout, New routine, Rest day, the routines, Create a routine with its subtitle). Every action stays.
- The progress note is a `subhead` `ink2` line.

History and trends:
- The header reads `History and trends`. The range `Segmented` (Task 3) stays at the top.
- Summary tiles become `StatRow`s of at most 3 stats each (keep the existing metrics), with no overflow at text scale 1.3.
- Volume trend bars are `ink` for the current period and `track` for the rest, with no colour. The trend pill becomes a `subhead` `ink3` sentence (`Up 12% on last month`), with no colour.
- Balance becomes `ContributorBar` rows (`off: false`). PR rows are `ExerciseRow`s (detail `{kg} kg × {reps} · {date}`), with `New best` in `thrivingInk` as `trailing` only for PRs inside the selected range. Sessions are `SessionRow`s that open detail.
- Empty range: one `subhead` `ink3` line, keeping the existing copy if there is one, else `No sessions in this range.`.

Acceptance: the tests below pass, plus scenario steps `weekly_plan`, `weekly_plan_assign_sheet`, `weekly_plan_rest_day` (Rest day chosen in the sheet, the row reads Rest), `history` and `history_empty_range`.

- [ ] Write failing tests. In `test/weekly_plan_editor_test.dart`: the assign sheet opens from a schedule row and still assigns a routine and sets a rest day; Start workout on today opens a session via the launcher. In `test/workout_history_screen_test.dart`: switching the range updates the stats; the trend sentence has no state colour (its colour is `ink3`); a session row opens detail; the empty range shows the empty line.
- [ ] Implement. Run `flutter test test/weekly_plan_editor_test.dart test/weekly_plan_test.dart test/workout_history_screen_test.dart test/workout_history_test.dart` and `flutter analyze --fatal-infos`. Run the legacy-token grep on both screens.
- [ ] Commit `feat(workout): weekly plan and history in the oura design`.

### Task 8: Workout detail and Exercise library
**Depends on:** Task 1, Task 2, Task 3
**Files:** `lib/screens/workout/workout_detail_screen.dart`, `lib/screens/library/exercise_library_screen.dart`, `test/workout_detail_test.dart`, `test/exercise_library_test.dart`

Workout detail:
- The header is the workout name, with a back control and a 44 `ellipsis` button as the trailing action (semantics `More options`).
- Lead: the session volume in `AppType.display` with `kg lifted` in `subhead` `ink2` (the canvas post-workout pattern), then `New best · {exercise}, {kg} kg` in `thrivingInk` with a check when the workout has a PR, then a `StatRow` (Time, Sets, Records).
- The volume chart is bars in `ink` on `track`. The trend pill becomes a `subhead` `ink3` sentence.
- Exercise blocks: the exercise name in `headline` and a hairline set table (set number `caption` `ink3`, `{kg} kg × {reps}` in `subhead`, `New best` in `thrivingInk` on a PR set). The sparkline goes.
- The Pal note is `PalLabel` over a `body` line (not the serif; the screen's lead is the number). Loading reads `Pal is reading your session…` in `ink3`, and the error copy stays.
- The More options sheet uses `showAppSheet`. `Delete workout` is a row in `careInk` with a `trash` icon, keeping the existing confirm and delete flow.

Exercise library:
- Keep the existing `LargeTitleNavBar` (Task 1 restyles it) with the title `Exercises`.
- `SearchPill` and `AppChip` filters (Task 3).
- `ExerciseRow`s with no green tile: the detail `{muscle} · {equipment}` and the PR as `value` when present.
- The empty state is one `subhead` `ink3` line, keeping the existing copy.

Acceptance: the tests below pass, plus scenario steps `workout_detail`, `workout_detail_more_sheet`, `exercise_library` and `exercise_library_empty`.

- [ ] Write failing tests. In `test/workout_detail_test.dart`: the volume renders with `AppType.display` metrics (font size 64, w300); More options opens the sheet and Delete workout still deletes after confirm; a PR set shows `New best`. In `test/exercise_library_test.dart`: a chip filters the list and reports `selected` in semantics; search filters; the empty search shows the empty line; no row icon has a coloured tile ancestor.
- [ ] Implement. Run `flutter test test/workout_detail_test.dart test/exercise_library_test.dart` and `flutter analyze --fatal-infos`. Run the legacy-token grep on both screens.
- [ ] Commit `feat(workout): workout detail and exercise library in the oura design`.

### Task 9: Active session, finish sheet, post-workout, streak
**Depends on:** Task 1, Task 2, Task 3, Task 4
**Chunk:** Workout session: active session, finish dialog, post-workout, streak
**Files:** `lib/screens/workout/active_session_screen.dart`, `lib/screens/workout/post_workout_screen.dart`, `lib/screens/reflect/streak_celebration_screen.dart`, `test/active_session_test.dart`, `test/post_workout_test.dart`, `test/screens/workout/streak_celebration_test.dart`

Active session (canvas `onSession`):
- Header: a 44 `chevron.down` labelled `Minimise, the session keeps running` (pops the route; the session lives on via Task 4); centred, the routine name in `label` `ink3` over the elapsed clock in `headline` w400 tabular (semantics `Elapsed m:ss`); `Finish` as a text button at the right.
- Progress: `Exercise {n} of {N}` and `{logged} of {total} sets` in `caption` `ink3` tabular, over a 4px `ProgressBar`.
- The exercise is `{muscle} · {equipment}` in `label` `ink3` over the name in `title`.
- The set card (an `ActionCard`-shaped `surface` card) has three states, one at a time:
  - Entering: `Set {i} of {n}` with `Best {kg} kg × {reps}` at the right (from the catalog PR, when known). Weight and reps columns: `label` `ink3`, then `AppType.score` (weight with a `kg` unit), then −/+ 44 `surface2` circles labelled `Less weight`, `More weight`, `Fewer reps` and `More reps`. The step is 2.5 kg and 1 rep; weight floors at 0 and reps at 1. The values are screen-local, seeded from the current set's target, and re-seed when the cursor moves. When the weight beats the best, `Ahead of your best by {kg} kg` shows in `thrivingInk` (this is the PR line). Then primary `PillButton('Complete set', icon: 'checkmark')`, which calls `logCurrentSet(weightKg, reps)` with the stepped values.
  - Resting: `Rest` label, the clock in `AppType.display`, `Next: set {i} · {kg} kg × {reps}` in `subhead` `ink2`, a secondary `+30 s` (semantics `Add 30 seconds rest`, `addRestTime`) and a primary `Skip rest` (`skipRest`).
  - Finished: `{logged} of {total} sets` over `All sets logged` in `title`, with primary `See your summary`, which finishes directly (no sheet) and goes to post-workout.
- The set list is hairline rows: a 28 disc (done is `surface2` with a check, current is `ink` fill with a `bg` number, open is a hair ring with an `ink3` number), `Set {i}` with ` · now` in `label` `ink3` on the current one, and the value in `subhead` (done rows `ink3`).
- Under the list are `Add set` (text button with +, `addSet`) and, when there is a next exercise and the session isn't finished, `Skip exercise` (`ink2`, `skipExercise`). Then `Up next`: the name in `callout` and `{n} sets` in `subhead` `ink3`.
- Finish (header) opens `showAppSheet` with `Finish workout?` in `title`, `{logged} of {total} sets logged. This ends the session and shows your summary.` in `subhead` `ink2`, a primary `Finish` and a secondary `Keep going`. Finish calls `finish()` and `pushReplacementNamed(postWorkout, extra: workout)`, as today. The Material `AlertDialog` goes.
- Swipe between exercises is not present today, so none is added. The Live Activity hooks stay in the controller, untouched.
- Loading and error states keep their copy, restyled.

Post-workout (canvas `onPost`):
- Header: `Done · {workout name}` in `label` `ink3`, and a 44 close (`xmark`, semantics `Back to Workout`) to `/move`.
- Lead: `PalLead` from `postWorkoutNoteProvider`. While loading, `Pal is reading your session…` (muted; the run goal keeps this copy over the canvas's). On error, `Pal couldn't write a note just now.` (muted).
- `AppType.display` volume with `kg lifted` in `subhead` `ink2`; `New best · {exercise}, {kg} kg` in `thrivingInk` with a check when there is a PR; `StatRow` Time (`min`), Sets (`of {total}`), Records.
- `Muscles worked`: `ContributorBar` rows (name, share %). `By exercise`: the same rows with `{sets} × {top kg} kg`, plus `Ahead` in `thrivingInk` on a PR (beside the row's value).
- The action row is `Share` (a text button with `square.and.arrow.up`, keeping the existing snackbar) and a primary `Save to timeline` / `Saving…` (disabled while saving). The save failure snackbar stays.
- No active session: `No active session` in `title`, `Your last summary is no longer available.` in `subhead` `ink3`, and a primary `Back to Workout`.

Streak celebration:
- Drop the rays, the dot grid's colour and the giant green number. Show `label` `ink3` `Workout streak`, the streak count in `AppType.display` with `days` in `subhead` `ink2`, and `sinceLine` (the existing copy) in `AppType.lead`.
- The stat pills become a `StatRow` (Total, Best day, Next milestone; keep the existing values).
- One primary `Keep going` with the existing close behaviour (pop or go to `/today`), plus the 44 close control.
- The share card, if it stays, is neutral `surface` with no gradient, rays or colour.

Acceptance: the tests below pass, plus scenario steps `session_entering`, `session_resting`, `session_rest_added` (+30 s performed, the clock 30 s longer), `session_rest_skipped` (Skip rest performed, back to entering), `session_skip_exercise`, `session_all_logged`, `session_finish_sheet`, `session_resumed`, `post_workout_reading`, `post_workout`, `post_workout_saving` (Save to timeline tapped, `Saving…` shown), `post_workout_no_session` and `streak`.

- [ ] Write failing tests. In `test/active_session_test.dart`: More weight then Complete set logs target + 2.5; Less weight floors at 0 and Fewer reps at 1; `Ahead of your best by` shows only when the weight is above the PR; resting shows `+30 s` and `Skip rest`, and each calls its controller method; Skip exercise moves to the next exercise; Finish opens a sheet (no `AlertDialog`), `Keep going` closes it, and `Finish` pushes post-workout; the minimise control pops and the session is still running (`runningSessionProvider` non-null); 390 wide at text scale 1.3 has no overflow. In `test/post_workout_test.dart`: the note loading text is muted; Save shows `Saving…` and returns to `/move`; the no-session state shows `Back to Workout`. In `test/screens/workout/streak_celebration_test.dart`: the streak number uses display metrics (64, w300); there is exactly one `PillButton` with `primary: true`; Keep going closes.
- [ ] Implement. Run `flutter test test/active_session_test.dart test/post_workout_test.dart test/screens/workout/streak_celebration_test.dart test/workout_session_test.dart` and `flutter analyze --fatal-infos`. Run the legacy-token grep on all three screens.
- [ ] Commit `feat(workout): session, finish sheet, summary and streak in the oura design`.

### Task 10: Routine editor and Add exercise sheet
**Depends on:** Task 1, Task 2, Task 3
**Chunk:** Routine editor and Add exercise sheet
**Files:** `lib/screens/workout/routine_editor_screen.dart`, `test/routine_editor_test.dart`

- The header is `New routine` or `Edit routine` (existing copy) with a back control. Save is the screen's one primary `PillButton` (existing enable rule and callback).
- The name field is borderless `AppType.title` text on `bg`, with an `ink3` placeholder and a 1px `hair` underline.
- Tag and rest presets use `Segmented` (Task 3) under `headline` section headings (no uppercase).
- Toggles: hairline rows with no tiles (title in `body`, `AppSwitch` at the right, semantics labels `Warmup reminder` and `Auto-progress weights`), replacing `_SwitchRow`'s coloured tiles and `Switch.adaptive`.
- The exercise list is `ExerciseRow`s with detail `{sets} × {reps} · {kg} kg` and the existing reorder, remove and targets affordances as `trailing`, at 44 targets. `Add exercise` is a `ListRow` with a `plus` icon and the subtitle `Pick from the library`.
- The Add exercise sheet uses `showAppSheet(scrollable: true)`: a `title` heading `Add exercise`, a `SearchPill`, `AppChip` muscle filters if present, and `ExerciseRow`s (detail `{muscle} · {equipment}`). Selection behaviour is unchanged.
- The targets sheet uses `showAppSheet`, with stepper rows of 44 `surface2` −/+ circles, the value in `AppType.score`, and labels in `label` `ink3`.

Acceptance: the tests below pass, plus scenario steps `routine_editor`, `routine_editor_add_exercise` (the sheet open, after a search), `routine_editor_targets_sheet` (the targets sheet after one + on sets) and `routine_editor_toggles` (both switches flipped on).

- [ ] Write failing tests in `test/routine_editor_test.dart`: the Add exercise sheet opens, filters by search and adds the tapped exercise; the targets sheet's steppers change sets and reps; the toggles are `AppSwitch`es that flip the draft; Save is disabled until a name and an exercise exist (existing rule); no row icon has a coloured tile ancestor.
- [ ] Implement. Run `flutter test test/routine_editor_test.dart` and `flutter analyze --fatal-infos`. Run the legacy-token grep on the screen.
- [ ] Commit `feat(workout): routine editor and add exercise sheet in the oura design`.

### Task 11: Workout scenario
**Depends on:** Task 5, Task 6, Task 7, Task 8, Task 9, Task 10
**Chunk:** Workout sub-screens: start, generate, weekly plan, history, detail, library
**Files:** `test/scenario/workout_scenario_test.dart`

The sub-screens chunk ticks here because it spans Tasks 6 to 8. It is done once all three have landed and are shot.

Create `test/scenario/workout_scenario_test.dart` (`@Tags(['scenario'])`), using `scenarioTest` and `shot` from `scenario_harness.dart` and booting the seeded app as `you_scenario_test.dart` does. Every step is shot in light and dark (the harness registers both). Override `palPickControllerProvider` (a fake whose `another()` returns a second, different suggestion, and variants that stay loading or throw) and `postWorkoutNoteProvider` (fixed text, or a never-completing future for the reading step) so the shots are deterministic. Each step asserts the state it shows before shooting (named below) and that `tester.takeException()` is null. Steps, each shot named as listed:

- `workout_tab`: the canvas `onTab` board. Assert the fake rationale, `Start` and `Pick another`.
- `workout_tab_collapsed`: scrolled until the bar collapses. Assert the compact `Workout` title's rect does not intersect the `Start a workout` button's rect.
- `workout_tab_thinking`: `Thinking…`, no `Start`.
- `workout_tab_error`: `Pal couldn't pick one just now.` and `Try again`.
- `workout_tab_pick_another`: tap `Pick another` and settle. The second suggestion's rationale and title show.
- `workout_tab_no_plan`: `weekGoal` 0. `No weekly plan yet`.
- `workout_tab_in_progress`: start Pal's pick, log a set, minimise. `In progress` and `Resume`.
- `session_resumed`: tap Resume. Set 1 shows as done (the set logged before minimising).
- `session_entering`: tap More weight until past the best. `Ahead of your best by`.
- `session_resting`: tap Complete set. `Rest`, `+30 s` and `Skip rest`.
- `session_rest_added`: tap `+30 s`. The rest clock reads 30 s more than before the tap.
- `session_rest_skipped`: tap `Skip rest`. `Complete set` is back.
- `session_skip_exercise`: tap `Skip exercise`. The next exercise's name is the title.
- `session_all_logged`: log every remaining set. `All sets logged` and `See your summary`.
- `session_finish_sheet`: from a part-done session, tap `Finish`. `Finish workout?`, `Finish` and `Keep going`.
- `post_workout_reading`: the summary with the note pending. `Pal is reading your session…`.
- `post_workout`: the canvas `onPost` with the note. The fixed note and `kg lifted` (`New best` when the seeded session has a PR).
- `post_workout_saving`: tap `Save to timeline`. `Saving…`, shot before the save completes.
- `workout_tab_settled`: after the save completes, back on the tab. The settled line ending `is done.` or naming the next routine, no `Start`, and a `Today` session row.
- `post_workout_no_session`: open post-workout with no workout. `No active session` and `Back to Workout`.
- `streak`: the streak celebration. `Workout streak` and `Keep going`.
- `start_workout`: the picker at 390 wide. No overflow and no `Freestyle session`.
- `start_workout_delete_confirm`: long-press a routine. The delete confirm is shown.
- `generate`: Generate with Pal, empty.
- `generate_loading`: tap a quick goal, then Generate, with the controller held pending. `Generating…`.
- `generate_result`: after a result. The routine name and the save action.
- `weekly_plan` and `weekly_plan_assign_sheet` (a schedule row tapped, the sheet open).
- `weekly_plan_rest_day`: `Rest day` chosen in the sheet. The row reads `Rest`.
- `history` and `history_empty_range` (a range with no sessions).
- `workout_detail` and `workout_detail_more_sheet` (`Delete workout` visible).
- `exercise_library` and `exercise_library_empty` (a search with no match).
- `routine_editor`, `routine_editor_add_exercise` (the sheet after a search), `routine_editor_targets_sheet` (after one + on sets) and `routine_editor_toggles` (both switches on).

- [ ] Write the file. Run `flutter test --tags scenario test/scenario/workout_scenario_test.dart` and check that every PNG lands in `build/scenario` (or `ARC_FINAL_OUT`). Run `flutter analyze --fatal-infos`.
- [ ] Commit `test(workout): scenario for the workout family`.
