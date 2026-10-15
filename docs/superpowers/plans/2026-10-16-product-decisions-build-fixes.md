# Product Decisions 10-15 Build: Browser-Walk Fixes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the two defects the lead's headed-browser walk found in the landed run: a selected "Check in again" keeps leading Today after the check-in is logged, and a timed session's move entry records elapsed time (0 min for a session logged quickly) instead of the minutes it logged.

**Architecture:** Two independent, small changes. Today drops its selection of the mood item when a newer check-in lands, so the clock's pick leads again. `Workout` gains one getter for "the minutes this session counts as", and both History rows and the move entry read it.

**Tech Stack:** Flutter, Riverpod 3 codegen, drift, flutter_test scenario harness.

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Spec:** `docs/superpowers/specs/2026-10-15-product-decisions-build-design.md`

## Global Constraints

- Everything in the run plan's Global Constraints applies (`docs/superpowers/plans/2026-10-15-product-decisions-build.md`): tests first, lower-case why-only comments, no magic numbers, no new dependencies, 44px tappables with semantics labels, commit regenerated `.g.dart` files you cause to change, do not regenerate goldens, do not edit `test/scenario/final_scenario_test.dart`, `type(scope): summary` commit subjects with no attribution or co-author trailer.
- Do not reformat or reorganise code you are not changing: run 8602490a edits `today_screen.dart` and `day_plan.dart` in parallel.

## Review Focus

- **The user selects Check in again, opens the logger and closes it without logging.** Nothing was logged, so the selection stays and Check in again still leads. Pinned in Task 1.
- **A check-in logged somewhere else (the Mood area) while Today has Check in again selected.** It is still a newer check-in, so the selection drops. Pinned in Task 1.
- **A mixed session (bench plus a plank).** It is not a timed session, so its move entry keeps the elapsed duration. Pinned in Task 2.

---

### Task 1: After a check-in, Check in again stops leading

**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `lib/screens/today/today_screen.dart`, `lib/screens/today/day_plan.dart`, `lib/controllers/plan_session_controller.dart`, `lib/controllers/plan_session_controller.g.dart`, `test/screens/day_plan_test.dart`, `test/today_screen_test.dart`, `test/scenario/mood_again_scenario_test.dart`

**The defect (seen in the browser walk).** Since run task 9, the mood item never becomes done: after the day's first check-in it stays open as the trailing `Check in again`. A trailing item leads only when `PlanSession.selected` names it. Tapping `Check in again` selects it, and Check in opens the mood logger. After the user logs, nothing clears the selection, so Today goes straight back to leading with `Check in again` and its Check in button, asking again right after the user answered. Before task 9 the logged check-in made the item done, which dropped it from `open` and so from the lead.

**Decisions**
- The selection drops when a newer check-in lands, not when the sheet closes. Then a check-in logged anywhere (the Mood area, the logger opened from Today) clears it, and closing the logger without logging keeps it.
- `PlanSession` gains `PlanSession deselect()`, which keeps `settled` and `history` and clears `selected`. `PlanSessionController` gains `void deselect()`, which does the same to its state. It never touches history, so the header Undo is unchanged.
- In `TodayScreen`, `ref.listen` on `moodControllerProvider` compares the previous and next `lastCheckin` timestamps. When the next one is newer, or the day's first check-in arrives, and the session's `selected` is the mood item's id (`mood`), call `deselect()`. Use the existing id constant if `day_plan.dart` has one; otherwise add one there and use it in both places rather than repeating the string.

**Acceptance and focused tests (write them first)**
- `test/screens/day_plan_test.dart`: `deselect()` clears `selected` and leaves `settled`, `history` and `undoLabel` unchanged. With `Check in again` selected and a 9:30 PM close-out upcoming at 3 PM, `current` is Check in again; after `deselect()` it is the close-out.
- `test/today_screen_test.dart`:
  - with a check-in today and the close-out upcoming, tap the `Check in again` row, then log a check-in through the logger: the card leads with the close-out again and the timeline still lists `Check in again`;
  - tap the `Check in again` row, open the logger and close it without logging: the card still leads with `Check in again`;
  - with `Check in again` selected, insert a check-in straight through the mood repository (as the Mood area would): the card leads with the close-out again.
- `test/scenario/mood_again_scenario_test.dart`: add a step "after checking in again", light and dark. Select the row, log a check-in, then capture Today with the clock's pick leading and `Check in again` listed.
- **Run:** `flutter test test/screens/day_plan_test.dart test/today_screen_test.dart`

- [ ] Failing tests, implement, regenerate codegen if the controller's stamp changes, focused tests, analyze

---

### Task 2: A timed session's move entry records its logged minutes

**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `lib/models/workout.dart`, `lib/controllers/post_workout_controller.dart`, `lib/controllers/workout_history_controller.dart`, `test/timed_sets_test.dart`

**The defect (seen in the browser walk).** `moveEntryForWorkout` sets `Entry.duration` to the elapsed session time (`workout.duration?.inMinutes`). A treadmill session that logged 25 min · 5.2 km in under a minute of app time saved a move entry of 0 minutes. Pal's day facts then told the user "the 00:28 entry logged 0min", while the History row, the summary and the detail all read 25 min. History rows already use the rule "logged minutes for a timed session, elapsed otherwise" (`workout_history_controller.dart`); the move entry does not.

**Decisions**
- `Workout` gains `int? get countedMinutes => isTimedSession ? totalMinutes : duration?.inMinutes;` with a one-line why comment: a timed session counts the minutes it logged, a weighted session the time it took.
- `moveEntryForWorkout` sets `duration: workout.countedMinutes`.
- The History row in `workout_history_controller.dart` uses `w.countedMinutes ?? 0` in place of its inline ternary, so the rule has one home. Leave its `timedKm` line as it is.
- The History summary "Time" tile and the workout detail "Time" tile keep elapsed time, as run task 6 left them.

**Acceptance and focused tests (write them first)**
- `test/timed_sets_test.dart`, beside the existing `totalMinutes` tests: a timed-only session with 25 logged minutes that ran 1 minute has `countedMinutes` 25. A weighted session that ran 52 minutes has 52. A mixed session (bench plus a 2-minute plank) that ran 40 minutes has 40. A session with no end has null.
- `test/timed_sets_test.dart`: `moveEntryForWorkout` on the timed-only session gives `duration` 25, and on the mixed session gives the elapsed 40.
- **Run:** `flutter test test/timed_sets_test.dart test/workout_history_screen_test.dart`

- [ ] Failing tests, implement, focused tests, analyze
