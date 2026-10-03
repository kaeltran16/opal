# Oura-style redesign: fix round 1

Fixes the defect the final stage found on the merged result. The spec is
`docs/superpowers/specs/2026-10-04-oura-redesign-today-area-pages-design.md`; its State
rule says no goal set (no routines) is On track in neutral ink.

### Task 1: Today's Routines ring with no routines, and the time column on done rows
**Depends on:** none

Two changes on Today, both in `lib/screens/today/today_screen.dart`.

Design decisions
- Routines ring. Today feeds `GlanceNumbers` from `today.ritualsDone` and
  `today.ritualsTarget`. `TodayState.ritualsTarget` is `effectiveDailyRitualTarget`, which
  falls back to the stored `Goals.dailyRitualTarget` (default 5) when there are no
  routines, and `ritualsDone` falls back to the legacy step-entry count. So with no
  routines the ring reads 0 of 5 and turns Worth watching, then Needs care, while the
  Routines area page reads On track. Use the area page's rule (`_routines` in
  `lib/controllers/area_detail_controller.dart`): the total is the number of routines, and
  with none the total and the done count are both 0. With routines present nothing
  changes. Do not change `TodayState`, `effectiveDailyRitualTarget` or `areaGlances`;
  other screens read them.
- Time column. A timeline row prints `Any` when the item has no `minuteOfDay`. That is
  right for an open untimed item and wrong for a done row (last night's sleep, a finished
  workout): a done row with no time shows an empty time column of the same width, so the
  rows stay aligned. Open rows are unchanged.
- The fixtures hide the first defect by seeding `dailyRitualTarget: 0`
  (`test/support/today_fixture.dart`, `test/scenario/today_scenario_test.dart`). The new
  test and scenario step below must use default `Goals()` so they fail on the old code.
- The run's Verify runs the golden tests on this Flutter (only the last `--exclude-tags`
  flag is kept), and the seeded Today has done rows, so after the change run
  `flutter test --tags golden --update-goldens`, check that only the `today` baselines
  changed, and commit them with the task.

Files owned: `lib/screens/today/today_screen.dart`, `test/today_screen_test.dart`,
`test/support/today_fixture.dart`, `test/scenario/today_scenario_test.dart`,
`test/golden/goldens/today_*.png` (or wherever the two `today` baselines live).

Acceptance and tests (`flutter test test/today_screen_test.dart`)
- With no routines and default `Goals()` (stored ritual target 5), at 12:00 and at 21:30,
  the Routines ring's semantics read On track, its fraction is 0 and it draws in neutral
  ink, not a state colour.
- With no routines and stray ritual step entries logged today, the ring is still fraction
  0 and On track.
- With three routines and one complete, the ring reads as it did before this task.
- A done row with no time (last night's sleep) shows no `Any` text; an open untimed row
  still shows `Any`; a done row with a time (a logged meal) still shows its clock label.
- Scenario steps in `test/scenario/today_scenario_test.dart`, each in light and dark:
  `today_no_routines_default_goals_<theme>` (no routines, default goals, clock at 21:30,
  asserting the Routines ring reads On track before shooting), and the existing seeded
  Today step re-shot, asserting the sleep row has no `Any`.
- `flutter test --tags golden` passes with the regenerated `today` baselines.
