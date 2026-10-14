# Oura conversion defects: design

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17

The Oura conversion runs filed seven defects. This spec fixes each one at its root and
names the rule each fix sets. The code was read at `ac99734`.

## Decisions

1. **A routine with no steps does not count.** It is set up but not tracked. It is left out
   of every "of N routines" target and out of Today's plan, and it is never "done". The
   human chose this over "an empty routine counts as done", which would add a done row to
   Today and count the routine as kept every day in Recap.
2. **One completion rule, in `lib/models/goals.dart`.** This file already holds
   `completedRoutines`, documented as "the single source of truth for routines done". Today
   (`TodayState._routineComplete`) and the routines state (`RitualsState.isComplete`) each
   re-implement the same check, and every target counts `routines.length` raw. The fix adds
   the rule there once, and the three checks and every target read it.
3. **The close-out is the evening routine.** The close-out screen already works through the
   `evening` routine's steps. Today shows that routine as one close-out row. The row opens
   the close-out, is done when the routine is complete, and appears only when the routine
   has steps. The evening routine gets no routine row of its own. Pal's close-out proposal
   does not get an item of its own either: it merges into that row. (Spec review asked for
   the fold.)
4. **Line glyphs come from `AppIcon`, not from the data.** Stored names stay as they are
   (`sunrise.fill` and so on), so no data migration is needed. A new `AppIcon.line` draws a
   name's outline form. Manage routines and the routine player use it for routine and step
   glyphs. Today's rows and the tab bar are out of scope, by the human's choice.
5. **The routines providers fail at once.** `ritualRoutinesStreamProvider`,
   `RitualsController` and `RitualsBuilderController` get `retry: noRetry`, as the other
   converted screens' providers already do. Each screen's existing error copy then shows on
   the first failed load.
6. **Manage routines awaits every write.** On a failure it shows calm inline copy, as
   onboarding does, and nothing escapes as an unhandled async error. The onboarding alert
   box becomes one shared widget, and the save-failure copy becomes one shared constant.
7. **Failure copy drops the em-dash.** It uses two sentences, as onboarding does: "Couldn't
   save. Try again." This applies to all three old snackbars and every other em-dash
   failure string in `lib/`.
8. **You moves onto `LargeTitleScrollView`.** That gives it the shared inset, the large
   title and the centred collapsed title. The header line becomes the shared header's
   subtitle, under the title. The human chose this over adding a slot beside the title.
   The profile goldens are regenerated.

## 1. Empty routines

**Defect.** `RitualsState.isComplete` (rituals_controller.dart:41) returns false for a
routine with no steps. Today's routines target is `routines.length` (today_controller.dart:95).
So one empty routine keeps the routines ring, the Areas summary, Recap and Pal's context
below the goal for good. Its Today plan item also never settles.

**Rule** (in `lib/models/goals.dart`):

- `bool isRoutineComplete(RitualRoutine r, Set<String> doneStepIds)`: true when `r` has
  steps and every step id is in `doneStepIds`. `completedRoutines`,
  `RitualsState.isComplete` and `TodayState._routineComplete` all call it.
- `List<RitualRoutine> trackedRoutines(List<RitualRoutine> routines)`: the routines that
  have at least one step, in their given order. Every routines total and target counts
  these.
- `effectiveDailyRitualTarget` takes the routine list instead of a count:
  `effectiveDailyRitualTarget(List<RitualRoutine> routines, Goals goals)`. With no routines
  at all, it keeps today's legacy fallback to `goals.dailyRitualTarget`. Otherwise it
  returns `trackedRoutines(routines).length`, which may be 0.

**Callers that move onto the rule.** Grep for `routines.length` used as a total or a
target: today_controller.dart (`ritualsTarget`, `glance.routinesTotal`), today_screen.dart:182,
areas_controller.dart:397, area_detail_controller.dart:389, spending_controller.dart:242,
providers.dart:294, recap_controller.dart:199, weekly_review_controller.dart:154,
pal_context_builder.dart:46 and :210, and the Routines target row on Budgets and goals
(budgets_goals_screen.dart:67 and :150), which then reads `trackedRoutines(routines).length`.
A count of routines that are set up (`routineCount` in
profile_controller and move_controller) is not a target and stays raw.

**Today's plan.** `buildDayPlan` builds no routine item for a routine without steps.

**Routines area page.** The "next" contributor and the next row skip routines without
steps (use `RitualsState.upNext`, which already does). When routines exist but none has a
step, the Pal line reads `No steps in your routines yet.` instead of `No routines set up
yet.` The routine rows still list the empty routine, so the user can find it and add a step.

**Kept as they are.** The player's `No steps yet` state and the close-out's `Nothing to
close` card already describe an empty routine as "nothing to do", which matches the rule.

## 2. Today's close-out item

**Defect.** The `closeOut` `PlanItem` (day_plan.dart:287) never sets `done`, so it stays in
the open list after the evening steps are all checked. The same steps also show up twice
more: the evening routine has its own `routine:evening` row, and Pal's `close-out-tonight`
proposal (`navigatesToCloseOut`) becomes its own plan item.

**Root cause.** The plan has no notion of what "the close-out" is. The screen knows it is
the `evening` routine (`_eveningRoutineId` in evening_close_out_screen.dart), but the plan
does not.

**Fix.**

- `RitualsState` gains `RitualRoutine? get evening`: the routine the close-out works
  through, by id `evening`. The id constant moves here from the close-out screen, and the
  screen reads `state.evening`.
- **One close-out row.** `buildDayPlan` builds no `routine:` item for the evening routine.
  It builds the `closeOut` item instead, but only when `evening` exists and has steps. This
  replaces the `routines.isNotEmpty` check. The item has:
  - `id: 'closeOut'` and `kind: PlanKind.closeOut`.
  - The title `Close-out` and the `moon.stars.fill` icon, as today. Tapping it still opens
    the close-out screen.
  - `minuteOfDay: routineMinute(evening.time) ?? closeOutMinute`, so it carries the evening
    routine's time when it has one.
  - `said: evening.blurb`, unless a Pal proposal replaces it (see the next point).
  - `done: rituals.isComplete(evening)`, `ref: evening.id` and
    `area: DetailTracker.rituals`.
- Every other routine keeps its own row.
- **Needs care.** The rituals rule in `_careLead` picks from the routine items and the
  close-out item, in time order. Otherwise a rituals Needs care state could never lead
  with the evening routine.
- **Pal's proposal.** A proposal with `navigatesToCloseOut` never becomes its own plan
  item. When the close-out row exists, the proposal's `body` becomes the row's `said`, so
  Pal's sentence survives the merge. Without a close-out row, the proposal is dropped,
  because it would only lead to `Nothing to close`. The `toCloseOut` branch in Today's
  proposal handler (today_screen.dart:121-126) can no longer run, so it is removed.
- **Tests that move.** `test/screens/day_plan_test.dart` expects `routine:evening` in
  several places. Those expectations move to `closeOut`, and the care-lead case at :270
  expects `closeOut`.

## 3. Routine step glyphs

**Defect.** Seed data and the Manage icon picker store `.fill` SF names. `AppIcon` maps
them to filled Cupertino glyphs, but the Oura rule is bare line glyphs in `ink2`
(docs/superpowers/plans/2026-10-13-oura-routines-onboarding.md).

**Fix** (in `lib/widgets/app_icon.dart`):

- `IconData lineIconForSf(String name)`: if `name` ends in `.fill` and its stem has an
  entry, it returns the stem's glyph. Otherwise it returns `iconForSf(name)`.
- Add outline entries for every stem the icon picker and the seed use: `sunrise`, `sun.max`,
  `moon.stars`, `drop`, `bolt`, `leaf`, `book.closed`, `books.vertical`,
  `character.book.closed`, `tray`, `cup.and.saucer`, `heart`. Use the Cupertino outline
  glyph where one exists, else the Material `_outlined` glyph. `book` already exists.
- `AppIcon.line(name, {size, color})`: a named constructor that draws `lineIconForSf`.
- Use it in Manage routines for the routine row glyph, the step row glyph and the icon
  picker cells, and in the routine player for the step glyph. Stored names and the
  picker's keys stay unchanged, so existing user data draws line glyphs too.

## 4. Routines load failure

**Defect.** `ritualRoutinesStreamProvider` (providers.dart:113), `RitualsController` and
`RitualsBuilderController` use riverpod's default retry. A failed load is held as loading
for the whole retry window, so the close-out, the player and Manage show `…` instead of
their error copy.

**Fix.** Add `@Riverpod(retry: noRetry)` to all three, with the same one-line "why" comment
the other providers carry. Regenerate the `.g.dart` files. The screens keep their existing
error copy:

- close-out: `Couldn't load your routines. Try again in a moment.`
- Manage: `Couldn't load routines. Try again in a moment.`
- the player's existing error branch.

## 5. Manage routines writes

**Defect.** `_openEditor` (rituals_builder_screen.dart:290) calls
`notifier.addOrUpdate(routine)` and `notifier.delete(id)` without awaiting them, then pops.
`onReorderItem` (line 141) does the same with `reorder`. A repository failure is an
unhandled async error, and the user sees nothing.

**Shared pieces** (new file `lib/widgets/failure_note.dart`):

- `const String saveFailedCopy = "Couldn't save. Try again.";`
- `FailureNote([String text = saveFailedCopy])` is onboarding's `_SaveFailed` box, moved
  as-is: `surface2` fill, `Radii.inset`, `subhead` in `ink`, horizontal 16 and vertical 12
  padding as named consts, and `Semantics(liveRegion: true)`. Onboarding uses it, and its
  `_saveFailed` constant and `_SaveFailed` widget go away.

**Behaviour.**

- **Save and delete** (in the editor sheet): the sheet awaits the controller call. On
  success it pops, as it does today. On failure it logs the error with context
  (`debugPrint('manage routines: saving <name> failed: $e\n$st')`), stays open with the
  user's edits intact, and shows `FailureNote()` above its footer buttons. For delete, the
  note reads `Couldn't delete. Try again.` Save is disabled while a write is in flight. The
  note clears on the next edit or the next attempt.
- **Reorder** (on the Manage list): the screen awaits `reorder`. On failure it logs, shows
  `FailureNote()` under the nav bar, and the list keeps the repository order, since the
  stream did not change. The note clears on the next successful write.
- The controller's methods keep their signatures and still throw. The screen boundary
  catches the error. The controller does not swallow it.

## 6. Failure copy

Every em-dash failure string in `lib/` becomes two sentences:

| File | Old | New |
|---|---|---|
| budgets_goals_screen.dart:86 | `Couldn't save — try again.` | `saveFailedCopy` |
| post_workout_screen.dart:100 | `Couldn't save — try again.` | `saveFailedCopy` |
| routine_generator_screen.dart:80 | `Couldn't save — try again.` | `saveFailedCopy` |
| email_dashboard_screen.dart:50 | `Sync failed — try again` | `Sync failed. Try again.` |
| email_dashboard_screen.dart:72 | `Couldn't disconnect — try again` | `Couldn't disconnect. Try again.` |
| email_setup_screen.dart:24 | `Connection failed — check the password` | `Connection failed. Check the password.` |
| new_entry_sheet.dart:112 | `Pal's unreachable — log it here.` | `Pal's unreachable. Log it here.` |
| new_entry_sheet.dart:296 | `Couldn't parse that — try again or enter it by hand.` | `Couldn't parse that. Try again or enter it by hand.` |
| export_data_screen.dart:66 | `Couldn't copy — try again.` | `Couldn't copy. Try again.` |

The tests that assert the old strings move to the new ones, including
`test/scenario/pal_money_settings_scenario_test.dart`.

## 7. You header

**Defect.** profile_screen.dart draws its own `_Header` inside a plain `ListView`, so run
A's `LargeTitleScrollView` fix (centred collapsed title, shared inset) never reaches You.

**Fix.**

- `ProfileScreen` renders `LargeTitleScrollView(title: 'You', subtitle: youLine(...))`.
  Its former `ListView` children become `children`, and the bottom inset moves into
  `padding`.
- `_Header` and `_contentTop` are removed. `youLine` stays as it is.
- The subtitle is one line that ellipsises. The test for a long name that wraps under the
  title becomes "ellipsises, no overflow".
- Scrolled until the bar collapses, the compact `You` is horizontally centred and clear of
  the `Spacing.lg` gutter. This is the same layout as every other `LargeTitleScrollView`
  screen.
- Regenerate only `test/golden/goldens/profile_dark.png` and `profile_light.png`.

## Testing

Each fix starts with a failing test that shows the defect.

- **Unit tests:** `test/completed_routines_test.dart`, `test/rituals_test.dart`,
  `test/screens/day_plan_test.dart`, `test/widgets/app_icon_test.dart`,
  `test/controllers/area_detail_controller_test.dart`.
- **Widget tests:** `test/screens/rituals_builder_screen_test.dart`, `test/onboarding_test.dart`,
  `test/profile_test.dart`, `test/large_title_scroll_view_test.dart`, and the screen tests
  whose copy changes.
- **Scenario:** a new `test/scenario/defects_scenario_test.dart` has one step per visible
  change, shot in light and dark through `scenarioTest`. The existing scenario files change
  only where a fix changes what they assert. `final_scenario_test.dart` is left alone,
  because the parallel clean-up run owns it.
- **Goldens:** only the profile goldens are regenerated, because the parallel run
  regenerates the rest.
