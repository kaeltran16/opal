# Oura Conversion Defects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the seven defects the Oura conversion runs filed, each at its root, with a failing test first and a light and dark scenario step for every visible change.

**Architecture:** Routine completion and the routines target get one rule in `lib/models/goals.dart`. The day plan folds the evening routine and Pal's close-out proposal into one close-out row. `AppIcon` gains a line form, the routines providers stop retrying, Manage routines awaits its writes behind a shared `FailureNote`, failure copy loses its em-dash, and You moves onto `LargeTitleScrollView`.

**Tech Stack:** Flutter, Riverpod 3 with codegen (`riverpod_annotation`), drift, flutter_test scenario harness.

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Spec:** `docs/superpowers/specs/2026-10-14-oura-defects-design.md`
**Verify:** `flutter test --exclude-tags "golden || scenario"`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario/defects_scenario_test.dart test/scenario/you_scenario_test.dart test/scenario/pal_money_settings_scenario_test.dart test/scenario/today_scenario_test.dart test/scenario/routines_onboarding_scenario_test.dart test/scenario/area_page_scenario_test.dart`

## Global Constraints

- Baseline on main ac99734: `flutter analyze --fatal-infos` is clean, and all 1218 unit tests pass.
- Every fix starts with a failing test that shows the defect, then makes it pass. Fix the shared function once, not the path the defect names.
- Comments are lower case and only say why. No magic numbers: name them as consts, as the surrounding files do. No new dependencies. No emojis.
- Every tappable control is 44px or larger and has a semantics label.
- Riverpod codegen: run `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart` files it changes.
- Do not regenerate goldens, except `test/golden/goldens/profile_dark.png` and `profile_light.png` in Task 7. A parallel run retires the legacy tokens and regenerates every other golden.
- Do not edit `test/scenario/final_scenario_test.dart`. The parallel clean-up run owns it.
- Commit subjects use the repo's `type(scope): summary` style, with no attribution or co-author trailer.
- Save-failure copy is exactly `Couldn't save. Try again.`
- Widget tests that boot the full `LoopApp` under fake async can stall after a repository write: the write completes, but the next pop never runs. Wrap such writes in `tester.runAsync`, as the existing tests do.

## Review Focus

- **All routines empty.** Today's routines target is 0, not the legacy fallback of 5, and the routines area reads `No steps in your routines yet.` Pinned in Task 1.
- **No evening routine, or one with no time.** If the `evening` id is gone, there is no close-out row and Pal's close-out proposal is dropped. If the evening time is blank or unparseable, the row sits at 9:30 PM. Pinned in Task 2.
- **Save tapped twice while a write is in flight.** Exactly one write reaches the repository. Pinned in Task 5.
- **A `.fill` name whose stem has no line entry** (for example `flame.fill`). `lineIconForSf` falls back to the filled glyph, not the `circle` placeholder. Pinned in Task 4.
- **A long name at text scale 1.3 on a 390-wide You.** The subtitle ellipsises, with no overflow. Pinned in Task 7.

---

### Task 1: An empty routine does not count
**Depends on:** none
**Chunk:** A routine with no steps can never complete: RitualsState.isComplete in lib/controllers/rituals_controller.dart
**Files:** `lib/models/goals.dart`, `lib/controllers/rituals_controller.dart`, `lib/controllers/today_controller.dart`, `lib/controllers/area_detail_controller.dart`, `lib/controllers/areas_controller.dart`, `lib/controllers/spending_controller.dart`, `lib/controllers/providers.dart`, `lib/controllers/recap_controller.dart`, `lib/controllers/weekly_review_controller.dart`, `lib/services/pal/pal_context_builder.dart`, `lib/screens/today/today_screen.dart`, `lib/screens/today/day_plan.dart`, `test/completed_routines_test.dart`, `test/rituals_test.dart`, `test/screens/day_plan_test.dart`, `test/controllers/area_detail_controller_test.dart`, `test/controllers/areas_controller_test.dart`, `test/services/pal_context_builder_test.dart`, `test/today_screen_test.dart`

Implements spec section 1. A routine with no steps is set up but not tracked. It leaves every routines target and Today's plan, and it is never done.

**Produces** (in `lib/models/goals.dart`; Tasks 2 and 8 rely on these):
- `bool isRoutineComplete(RitualRoutine r, Set<String> doneStepIds)`: true when `r.steps` is non-empty and every step id is in `doneStepIds`.
- `List<RitualRoutine> trackedRoutines(List<RitualRoutine> routines)`: the routines with at least one step, in their given order.
- `int effectiveDailyRitualTarget(List<RitualRoutine> routines, Goals goals)`: this replaces the `int routineCount` signature. With no routines at all it returns `goals.dailyRitualTarget`, as today. Otherwise it returns `trackedRoutines(routines).length`, which may be 0.

**Decisions:**
- `completedRoutines`, `RitualsState.isComplete` and `TodayState._routineComplete` all call `isRoutineComplete`. Drop the duplicated checks, and update the `completedRoutines` doc, which says the other two "do not yet route through it".
- Every total or target that counts `routines.length` moves to `trackedRoutines` or the new `effectiveDailyRitualTarget`. These are: today_controller.dart (`ritualsTarget`, `glance.routinesTotal`), today_screen.dart:182, areas_controller.dart:397, area_detail_controller.dart:389, spending_controller.dart:242, providers.dart:294, recap_controller.dart:199, weekly_review_controller.dart:154 and pal_context_builder.dart:46 and :210. Grep `routines.length` and `effectiveDailyRitualTarget(` to confirm none are left. The Budgets and goals Routines target row (budgets_goals_screen.dart:67 and :150) is the one exception: Task 6 owns that file and moves it onto `trackedRoutines`.
- `routineCount` in profile_controller and move_controller counts routines that are set up. It is not a target, so it stays raw.
- `buildDayPlan` builds no routine item for a routine without steps.
- On the routines area page, the "next" contributor and the next row skip routines without steps (`RitualsState.upNext` already does). When routines exist but none has a step, the Pal line reads `No steps in your routines yet.` The rows still list the empty routine.
- The player's `No steps yet` state and the close-out's `Nothing to close` card stay as they are.

**Acceptance:**
- [ ] Write failing tests first.
  - `test/completed_routines_test.dart`:
    - `isRoutineComplete` is false for an empty routine and true when every step id is done.
    - `trackedRoutines` drops empty routines and keeps the order.
    - `effectiveDailyRitualTarget([], goals)` returns `goals.dailyRitualTarget`.
    - `effectiveDailyRitualTarget([full, empty], goals)` returns 1.
    - `effectiveDailyRitualTarget([empty], goals)` returns 0.
  - `test/rituals_test.dart`: `RitualsState.isComplete(empty)` is false. With one full routine complete and one empty routine, `TodayState.ritualsDone == ritualsTarget == 1`.
  - `test/screens/day_plan_test.dart`: an empty routine produces no `routine:` item.
  - `test/controllers/area_detail_controller_test.dart`:
    - With one complete routine and one empty routine, the hero reads `1` of `1`, and the next contributor is absent.
    - With only empty routines, the Pal line is `No steps in your routines yet.`
  - `test/services/pal_context_builder_test.dart`: an empty routine is not in `ritualsTarget`.
- [ ] Run `flutter test test/completed_routines_test.dart test/rituals_test.dart test/screens/day_plan_test.dart test/controllers/area_detail_controller_test.dart test/services/pal_context_builder_test.dart` and see the new cases fail. Implement, then run it again and see them pass.
- [ ] Visible changes for Task 8: steps `empty_routine_today`, `routines_area_no_steps` and `routines_area_mixed` (the routines area with one complete routine and one empty routine, and the Areas summary for the same day).

### Task 2: One close-out row on Today
**Depends on:** Task 1
**Chunk:** Today's close-out item never completes: the closeOut PlanItem in lib/screens/today/day_plan.dart never sets done
**Files:** `lib/screens/today/day_plan.dart`, `lib/controllers/rituals_controller.dart`, `lib/screens/reflect/evening_close_out_screen.dart`, `lib/screens/today/today_screen.dart`, `test/screens/day_plan_test.dart`, `test/rituals_test.dart`, `test/screens/evening_close_out_screen_test.dart`, `test/today_screen_test.dart`, `test/scenario/today_scenario_test.dart`

Implements spec section 2, with the fold the Spec review asked for. This also clears the follow-ups initiative's "dedupe the close-out proposal and the local item", which has the same root cause: the plan has no notion of what the close-out is.

**Consumes:** `RitualsState.isComplete` from Task 1.
**Produces:** `RitualRoutine? get evening` on `RitualsState`: the routine with id `evening`, or null. The id constant moves from evening_close_out_screen.dart (`_eveningRoutineId`) into rituals_controller.dart, and the close-out screen reads `state.evening`.

**Decisions:**
- **One row.** `buildDayPlan` builds no `routine:` item for the evening routine. It builds one `closeOut` item, only when `evening` exists and has steps:
  - `id: 'closeOut'` and `kind: PlanKind.closeOut`.
  - The title `Close-out` and the icon `moon.stars.fill`.
  - `minuteOfDay: routineMinute(evening.time) ?? closeOutMinute`.
  - `said: evening.blurb`, unless a Pal proposal replaces it.
  - `actionLabel: 'Start'`.
  - `done: rituals.isComplete(evening)`, `ref: evening.id` and `area: DetailTracker.rituals`.
- Other routines keep their own rows. Tapping the close-out row still opens the close-out screen (today_screen.dart:138).
- Remove the `toCloseOut` branch in today_screen.dart's `_act` (lines 121-126 at ac99734). Close-out proposals never become items, so it can no longer run. A `proposal` item then always settles as done.
- **Needs care.** `_careLead` for `DetailTracker.rituals` picks from the `routine` and `closeOut` items, in the same time order as today.
- **Pal's proposal.** A proposal with `navigatesToCloseOut` never becomes its own item. When the close-out row exists, the proposal's `body` becomes the row's `said`. Without the row, the proposal is dropped.
- Move the `routine:evening` expectations in `test/screens/day_plan_test.dart` to `closeOut`. The care-lead case at :270 expects `closeOut`. Update `test/scenario/today_scenario_test.dart` only where it asserts an evening routine row or a separate close-out proposal.

**Acceptance:**
- [ ] Write failing tests first in `test/screens/day_plan_test.dart`:
  1. With every evening step done, the `closeOut` item is `done` and not in `open(...)`.
  2. With the evening routine present, there is no `routine:evening` item, and the `closeOut` minute is the evening routine's time.
  3. Evening time `''` puts the item at `closeOutMinute`.
  4. With no `evening` routine, or one with no steps, there is no `closeOut` item.
  5. A `close_out` proposal with a close-out row present gives exactly one item, whose `said` is the proposal body, and no `proposal:` item.
  6. A `close_out` proposal with no close-out row gives no item.
  7. With rituals in Needs care and the morning routine done, the care lead is `closeOut`.
- [ ] In `test/rituals_test.dart`, `evening` returns the `evening` routine, or null when it is absent.
- [ ] Run `flutter test test/screens/day_plan_test.dart test/rituals_test.dart test/screens/evening_close_out_screen_test.dart test/today_screen_test.dart`: the new cases fail, then pass.
- [ ] Visible changes for Task 8: steps `closeout_done_today` and `closeout_one_row`.

### Task 3: Routines providers fail at once
**Depends on:** Task 2
**Model:** claude-sonnet-5-5
**Chunk:** Routines load failure shows the loading copy for riverpod's whole retry window: ritualsProvider and related providers lack retry: noRetry (lib/controllers/providers.dart, rituals_controller.dart)
**Files:** `lib/controllers/providers.dart`, `lib/controllers/providers.g.dart`, `lib/controllers/rituals_controller.dart`, `lib/controllers/rituals_controller.g.dart`, `lib/controllers/rituals_builder_controller.dart`, `lib/controllers/rituals_builder_controller.g.dart`, `test/controllers/rituals_retry_test.dart`

Implements spec section 4.

**Decisions:**
- Add `@Riverpod(retry: noRetry)` to `ritualRoutinesStream` (providers.dart:113), `RitualsController` and `RitualsBuilderController`.
- Give each the one-line "why" comment the other providers carry, for example `/// No retry: a failing local query would fail again, and retrying holds the screen on loading.`
- Regenerate with build_runner.
- No screen changes. The close-out, the player and Manage already render their error copy:
  - close-out: `Couldn't load your routines. Try again in a moment.`
  - Manage: `Couldn't load routines. Try again in a moment.`
  - the player's existing error branch.

**Acceptance:**
- [ ] Write a failing test first, in a new `test/controllers/rituals_retry_test.dart`. In a `ProviderContainer`, override `ritualRepositoryProvider` with a repository whose `watchRoutines()` emits an error. After one microtask turn, with no fake-clock advance past riverpod's retry delay, each of these reads `AsyncError`, not `AsyncLoading`:
  - `ritualRoutinesStreamProvider`
  - `ritualsControllerProvider`
  - `ritualsBuilderControllerProvider`
- [ ] Run `flutter test test/controllers/rituals_retry_test.dart`: it fails, then passes.
- [ ] Visible changes for Task 8: steps `closeout_load_error`, `manage_load_error` and `player_load_error`. Each pumps once after boot, with no long settle, and shows the screen's error copy.

### Task 4: Routine glyphs draw as lines
**Depends on:** none
**Chunk:** Routine step glyphs come from seed data as .fill SF names, so AppIcon draws filled glyphs where DESIGN.md asks for line glyphs (player, close-out, Manage)
**Files:** `lib/widgets/app_icon.dart`, `lib/screens/rituals/routine_player_screen.dart`, `lib/screens/rituals/rituals_builder_screen.dart`, `test/widgets/app_icon_test.dart`, `test/screens/routine_player_screen_test.dart`, `test/screens/rituals_builder_screen_test.dart`

Implements spec section 3. Stored names and the picker's keys stay unchanged, so seed data and existing user data both draw line glyphs.

**Produces:**
- `IconData lineIconForSf(String name)`: if `name` ends in `.fill` and its stem is in `_sfMap`, it returns the stem's glyph. Otherwise it returns `iconForSf(name)`.
- The named constructor `AppIcon.line(String name, {double size = 17, Color? color})`, which draws `lineIconForSf(name)`.

**Decisions:**
- Add outline entries to `_sfMap` for `sunrise`, `sun.max`, `moon.stars`, `drop`, `bolt`, `leaf`, `book.closed`, `books.vertical`, `character.book.closed`, `tray`, `cup.and.saucer` and `heart`.
  - Use the Cupertino outline glyph where one exists (for example `CupertinoIcons.sunrise`, `CupertinoIcons.drop`, `CupertinoIcons.heart`).
  - Otherwise use the Material `_outlined` glyph (for example `Icons.eco_outlined` for `leaf`, `Icons.menu_book_outlined` for `books.vertical`).
  - Keep the comment style of the existing "workout line glyphs (oura)" block.
- Use `AppIcon.line` in Manage routines for the routine row glyph (line 234), the step row glyph (line 694) and the icon picker cells (line 948). Use it in the routine player for the step glyph (line 371).
- Leave the player's streak `flame.fill`, Today's rows and the tab bar unchanged. The close-out draws no routine glyph, so it needs no change.

**Acceptance:**
- [ ] Write failing tests first in `test/widgets/app_icon_test.dart`:
  - For each `.fill` key in the Manage icon picker, `lineIconForSf(key)` is not `iconForSf(key)` and not `CupertinoIcons.circle`. The test lists the keys itself (`sunrise.fill`, `sun.max.fill`, `moon.stars.fill`, `drop.fill`, `bolt.fill`, `leaf.fill`, `book.closed.fill`, `books.vertical.fill`, `character.book.closed.fill`, `tray.fill`, `cup.and.saucer.fill`, `heart.fill`). `_iconChoices` stays private.
  - `lineIconForSf('sparkles') == iconForSf('sparkles')`.
  - `lineIconForSf('flame.fill') == iconForSf('flame.fill')`, because no `flame` entry exists.
- [ ] In `test/screens/routine_player_screen_test.dart`, a step whose icon is `drop.fill` renders `Icon(CupertinoIcons.drop)`.
- [ ] In `test/screens/rituals_builder_screen_test.dart`, the morning routine row renders `lineIconForSf('sunrise.fill')`.
- [ ] Run `flutter test test/widgets/app_icon_test.dart test/screens/routine_player_screen_test.dart test/screens/rituals_builder_screen_test.dart`: the new cases fail, then pass.
- [ ] Visible changes for Task 8: steps `manage_line_glyphs` (the list and the open editor with its icon picker) and `player_line_glyph`.

### Task 5: Manage routines handles failed writes
**Depends on:** Task 4
**Chunk:** RitualsBuilderController addOrUpdate/delete/reorder are fire-and-forget from Manage routines; a repository failure is an unhandled async error with no calm copy
**Files:** `lib/widgets/failure_note.dart`, `lib/screens/rituals/rituals_builder_screen.dart`, `lib/screens/onboarding/onboarding_screen.dart`, `test/widgets/failure_note_test.dart`, `test/screens/rituals_builder_screen_test.dart`, `test/onboarding_test.dart`

Implements spec section 5.

**Produces** (in the new `lib/widgets/failure_note.dart`; Task 6 relies on `saveFailedCopy`):
- `const String saveFailedCopy = "Couldn't save. Try again.";`
- `class FailureNote extends StatelessWidget` with `const FailureNote([this.text = saveFailedCopy])`. This is onboarding's `_SaveFailed`, moved as-is:
  - `Semantics(liveRegion: true)` around a `surface2` box with `Radii.inset`.
  - `AppType.subhead` text in `ink`.
  - Padding of 16 horizontal and 12 vertical, as named consts.
- Onboarding uses `FailureNote()`. Delete its `_saveFailed` and `_SaveFailed`.

**Decisions:**
- **Save and delete.** The editor sheet's `onSave` and `onDelete` become async and await `addOrUpdate` and `delete`.
  - On success the sheet pops, as it does today.
  - On failure it logs (`debugPrint('manage routines: saving <name> failed: $e\n$st')`, or `deleting`). The sheet stays open with the user's edits intact and shows `FailureNote()` above its footer buttons. For delete, it shows `FailureNote("Couldn't delete. Try again.")`.
  - Save is disabled, and a second tap is ignored, while a write is in flight.
  - The note clears on the next edit or the next attempt.
- **Reorder.** `onReorderItem` awaits `reorder`. On failure it logs and shows `FailureNote()` under the nav bar on the Manage list. The note clears on the next successful write. The list keeps showing the repository's order.
- `RitualsBuilderController` keeps its signatures and still throws. Only the screen boundary catches.

**Acceptance:**
- [ ] Write failing tests first.
  - `test/screens/rituals_builder_screen_test.dart`, with a repository whose `upsertRoutine`, `deleteRoutine` and `reorderRoutines` throw:
    1. Saving an edit shows `Couldn't save. Try again.`, the sheet stays open, the edited name is still in the field, and `tester.takeException()` is null.
    2. A confirmed delete shows `Couldn't delete. Try again.` and the sheet stays open.
    3. A failed reorder shows `Couldn't save. Try again.` on the list.
    4. Two quick Save taps on a slow repository make exactly one `upsertRoutine` call.
    5. After a failure, editing the name clears the note.
  - `test/widgets/failure_note_test.dart`: the default text is `saveFailedCopy`, and the note is a live region.
  - `test/onboarding_test.dart`: its existing save-failure case still passes, using `FailureNote`.
- [ ] Run `flutter test test/screens/rituals_builder_screen_test.dart test/widgets/failure_note_test.dart test/onboarding_test.dart`: the new cases fail, then pass.
- [ ] Visible changes for Task 8: steps `manage_save_failed`, `manage_delete_failed` and `manage_reorder_failed`.

### Task 6: Failure copy without the em-dash
**Depends on:** Task 1, Task 5
**Model:** claude-sonnet-5-5
**Chunk:** Old snackbar copy 'Couldn't save — try again.' remains in budgets_goals_screen.dart:74, post_workout_screen.dart:80, routine_generator_screen.dart:78 (onboarding now says 'Couldn't save. Try again.')
**Files:** `lib/screens/settings/budgets_goals_screen.dart`, `lib/screens/workout/post_workout_screen.dart`, `lib/screens/workout/routine_generator_screen.dart`, `lib/screens/email/email_dashboard_screen.dart`, `lib/screens/email/email_setup_screen.dart`, `lib/screens/entry/new_entry_sheet.dart`, `lib/screens/settings/export_data_screen.dart`, `test/util/failure_copy_test.dart`, `test/screens/settings/budgets_goals_screen_test.dart`, `test/screens/settings/settings_screens_test.dart`, `test/screens/email/email_screens_test.dart`, `test/new_entry_test.dart`, `test/post_workout_test.dart`, `test/screens/workout/routine_generator_goals_test.dart`, `test/scenario/pal_money_settings_scenario_test.dart`

Implements spec section 6.

**Consumes:** `saveFailedCopy` from `lib/widgets/failure_note.dart` (Task 5), and `trackedRoutines` from `lib/models/goals.dart` (Task 1).

**Decisions:**
- The three save snackbars use `Text(saveFailedCopy)`:
  - budgets_goals_screen.dart:86
  - post_workout_screen.dart:100
  - routine_generator_screen.dart:80
- The other strings become, exactly:
  - email_dashboard_screen.dart:50: `Sync failed. Try again.`
  - email_dashboard_screen.dart:72: `Couldn't disconnect. Try again.`
  - email_setup_screen.dart:24: `Connection failed. Check the password.`
  - new_entry_sheet.dart:112: `Pal's unreachable. Log it here.`
  - new_entry_sheet.dart:296: `Couldn't parse that. Try again or enter it by hand.`
  - export_data_screen.dart:66: `Couldn't copy. Try again.`
- On Budgets and goals, the Routines target row counts `trackedRoutines(routines).length` instead of `routines.length` (lines 67 and 150), using Task 1's `trackedRoutines`. A test in `test/screens/settings/budgets_goals_screen_test.dart` shows that one full routine and one empty routine read `1 routine`.
- Move every test that asserts an old string to the new one, including the five assertions in `test/scenario/pal_money_settings_scenario_test.dart` (lines 541, 805, 933, 976 and 1062 at ac99734).

**Acceptance:**
- [ ] Write a failing guard test first, in a new `test/util/failure_copy_test.dart`. It reads every `lib/**/*.dart` file, skipping `.g.dart`, and fails on any line that is not a comment and has a string literal holding an em-dash next to failure wording: `Couldn't`, `failed`, `unreachable`, `try again` or `Try again`. It lists each offending `file:line`. It fails on ac99734's nine strings.
- [ ] Run `flutter test test/util/failure_copy_test.dart test/screens/settings/budgets_goals_screen_test.dart test/screens/settings/settings_screens_test.dart test/screens/email/email_screens_test.dart test/new_entry_test.dart test/post_workout_test.dart test/screens/workout/routine_generator_goals_test.dart`: the guard fails, then everything passes.
- [ ] Visible changes for Task 8: step `budgets_goals_routines_target` (one full routine and one empty routine read `1 routine`), and steps `budgets_goals_save_failed`, `post_workout_save_failed` and `routine_generator_save_failed`. The email, export and new-entry strings are already shown by `pal_money_settings_scenario_test.dart`, which now asserts the new copy.

### Task 7: You on the shared large-title header
**Depends on:** none
**Chunk:** You: the collapsed title sits flush left. profile_screen.dart draws its own header, not LargeTitleScrollView, so run A's nav-bar fix does not reach it
**Files:** `lib/screens/profile/profile_screen.dart`, `test/profile_test.dart`, `test/scenario/you_scenario_test.dart`, `test/golden/goldens/profile_dark.png`, `test/golden/goldens/profile_light.png`

Implements spec section 7. Moving onto the shared header works, so no layout is copied.

**Decisions:**
- `ProfileScreen` returns `LargeTitleScrollView(title: 'You', subtitle: youLine(name, streakDays, memberSince, clock.now()), padding: ..., children: [...])`.
  - The former `ListView` children become `children`, with the `_Gutter` wrappers kept.
  - The bottom inset (`kSubScreenShellOverlay + Spacing.xxl + safe.bottom`) moves into `padding`.
  - The top inset now comes from the shared header.
- Delete `_Header` and `_contentTop`. `youLine` stays as it is.
- The subtitle is one ellipsised line. The long-name test at `test/profile_test.dart:324` becomes "ellipsises with no overflow at text scale 1.3 on a 390-wide surface".
- Regenerate only the two profile goldens, with `flutter test --update-goldens test/golden/design_system_golden_test.dart --plain-name profile` or the narrowest filter that hits only them. Revert any other golden file the command touches. Name both goldens in the task report.
- Update `test/scenario/you_scenario_test.dart` only where it asserts the old header layout.

**Acceptance:**
- [ ] Write failing tests first in `test/profile_test.dart`:
  1. You renders a `LargeTitleScrollView` titled `You`, with the header line as its subtitle.
  2. Scrolled until the bar collapses on a 390-wide surface, the compact `You` text's centre x is 195 (within 1px), and its left edge is at least `Spacing.lg`.
  3. A 1000-day streak with a long name at text scale 1.3 throws no overflow.
  4. `You` is still announced as a header.
- [ ] Run `flutter test test/profile_test.dart test/large_title_scroll_view_test.dart`: the new cases fail, then pass.
- [ ] Visible changes for Task 8: steps `you_header` and `you_header_collapsed`.

### Task 8: Defects scenario
**Depends on:** Task 3, Task 6, Task 7
**Files:** `test/scenario/defects_scenario_test.dart`, `test/scenario/routines_onboarding_scenario_test.dart`, `test/scenario/area_page_scenario_test.dart`

A new scenario file. It has one `scenarioTest` step per visible change, so each is shot in light and dark as `<step>_<light|dark>`. Use `scenario_harness.dart`'s `bootToday`, `shot` and `scenarioTest`, and the `test/support/today_fixture.dart` fixtures, as `routines_onboarding_scenario_test.dart` does. Every step asserts what it shows before it shoots.

Task 8 also owns any fix-ups in `routines_onboarding_scenario_test.dart` and `area_page_scenario_test.dart`. Tasks 1 to 5 change screens they drive: the Today close-out row (routines_onboarding :542), Manage, the player and the routines area. Change an assertion only where an approved fix changed what it shows, and say which in the task report.

**Steps:**
- **`empty_routine_today`.** Today with one complete routine and one routine with no steps.
  - The routines count reads all done.
  - No plan row names the empty routine.
- **`routines_area_no_steps`.** The routines area page with only routines that have no steps.
  - `No steps in your routines yet.` shows.
- **`routines_area_mixed`.** The routines area with one complete routine and one routine with no steps.
  - The hero reads `1` of `1` routines done, and no next contributor shows.
  - The Areas summary for the same day reads the Routines area as done.
- **`rituals_detail_empty_routine`.** The rituals detail with one full routine and one routine with no steps.
  - The target is `1`.
- **`recap_empty_routine`.** Recap Day and Week with the same routines.
  - The routines totals count only the full routine.
- **`closeout_done_today`.** Every evening step done.
  - The close-out row shows as done.
  - No `Evening wind-down` routine row shows.
- **`closeout_one_row`.** Pal online, with the `close-out-tonight` proposal.
  - Exactly one close-out row, carrying the proposal's body.
- **`closeout_care_lead`.** Routines needs care in the evening.
  - The close-out row leads Today.
- **`closeout_load_error`.** `ritualRoutinesStreamProvider` errors.
  - After one pump past boot, the close-out shows `Couldn't load your routines. Try again in a moment.`
- **`manage_load_error`.** The same error, on Manage.
  - `Couldn't load routines. Try again in a moment.` shows.
- **`player_load_error`.** The same error, on the routine player.
  - The player's existing error copy shows.
- **`manage_line_glyphs`.** The Manage list, then the open editor with the icon picker.
  - The routine and picker glyphs are `lineIconForSf` glyphs.
- **`player_line_glyph`.** The player on a step with a `.fill` icon.
  - It draws the line glyph.
- **`manage_save_failed`, `manage_delete_failed` and `manage_reorder_failed`.** A throwing ritual repository.
  - Each shows its `FailureNote` copy.
  - The sheet stays open where the spec says it does.
- **`manage_save_in_flight`.** A save that has not finished.
  - Save is disabled.
- **`manage_failure_cleared`.** An edit after a failed save.
  - The failure note is gone.
- **`budgets_goals_routines_target`.** Budgets and goals with one full routine and one empty routine.
  - The Routines row reads `1 routine`.
- **`budgets_goals_save_failed`, `post_workout_save_failed` and `routine_generator_save_failed`.** A throwing write.
  - Each snackbar shows `Couldn't save. Try again.`
- **`you_header`.** The You tab at rest.
  - The `You` title with the header line under it.
- **`you_header_collapsed`.** You scrolled until the bar collapses.
  - The compact `You` is centred.

**Acceptance:**
- [ ] `flutter test --tags scenario test/scenario/defects_scenario_test.dart test/scenario/routines_onboarding_scenario_test.dart test/scenario/area_page_scenario_test.dart` passes. The defects file writes all 48 shots (24 steps in light and dark) to `ARC_FINAL_OUT` or `build/scenario`.
- [ ] `flutter analyze --fatal-infos` is clean.
