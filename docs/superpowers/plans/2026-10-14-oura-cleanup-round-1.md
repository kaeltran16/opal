# Oura Conversion Clean-up: Fix Round 1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close two defects the first pass left inside its goal: when routines exist but none has a step, the target-0 surfaces read `No routines set up yet.`, and the close-out screen test still waits out a 3-minute retry loop.

**Architecture:** The two lines and two units that name the target-0 case move to `lib/models/goals.dart`, next to `kNoRoutinesLine`. One function picks the line from whether routines exist. Recap and the weekly review carry `hasRoutines`, the same way `GlanceNumbers` does. The close-out test settles with the normal pump, as the routines scenario steps already do.

**Tech Stack:** Flutter, Riverpod 3 with codegen, drift, flutter_test with the scenario harness.

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Spec:** `docs/superpowers/specs/2026-10-14-oura-cleanup-design.md`
**Verify:** `flutter test --exclude-tags "golden || scenario" && if [ -z "$ARC_VERIFY_CHANGED" ] || grep -q '^server/' "$ARC_VERIFY_CHANGED"; then (cd server && npx vitest run); fi && if [ -z "$ARC_VERIFY_CHANGED" ]; then flutter test --tags "golden || scenario" && flutter analyze --fatal-infos; fi`
**Setup:** `flutter pub get && (cd server && npm ci)`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario/today_scenario_test.dart test/scenario/area_page_scenario_test.dart test/scenario/areas_scenario_test.dart test/scenario/routines_onboarding_scenario_test.dart test/scenario/pal_money_settings_scenario_test.dart test/scenario/defects_scenario_test.dart test/scenario/workout_scenario_test.dart`

## Global Constraints

- The base is this run's merged branch: units, goldens and scenarios pass, and `flutter analyze --fatal-infos` is clean.
- Every fix starts with a failing test that shows the defect, then makes it pass. Tests check behaviour, and must fail when the intent is violated.
- Follow DESIGN.md. Fix a token-guard failure with a `lib/theme` name, never with an annotation or a looser guard.
- Regenerate only the goldens your change moves. Put the before and after of each moved golden in the task report, and say why it moved.
- Riverpod codegen: `dart run build_runner build --delete-conflicting-outputs`. Commit only the `.g.dart` files your change rewrites.
- Comments are lower case and say only why. Use named consts, not magic numbers or strings. No new dependencies. No emojis.
- Every view a task changes gets a light and dark scenario step (`scenarioTest` plus `shot`) that shows it.
- Never write a `Co-Authored-By` or other attribution trailer into a commit.

## Review Focus

1. Routines exist and none has a step: Recap, the weekly review and the composer's `Rituals today` turn read `No steps in your routines yet.`, and never `No routines set up yet.` or `0 of 0`. Task 1 tests this.
2. No routines at all: those three surfaces still read `No routines set up yet.`. Task 1 keeps the existing tests for this.
3. The close-out load fails: the error copy shows after the normal pump, and the test fails if `retry: noRetry` is removed from `ritualRoutinesStreamProvider`. Task 2 tests this.

---

### Task 1: Stepless routines read the stepless line on every target-0 surface
**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `lib/models/goals.dart`, `lib/controllers/recap_controller.dart`, `lib/controllers/recap_controller.g.dart`, `lib/controllers/weekly_review_controller.dart`, `lib/controllers/weekly_review_controller.g.dart`, `lib/screens/pal/pal_composer_turns.dart`, `lib/controllers/areas_controller.dart`, `lib/controllers/area_detail_controller.dart`, `test/models_test.dart`, `test/screens/recap_screen_test.dart`, `test/controllers/weekly_review_controller_test.dart`, `test/weekly_review_test.dart`, `test/screens/pal/pal_composer_turns_test.dart`, `test/scenario/defects_scenario_test.dart`

Spec decisions 3 and 8. Decision 8 says a target-0 surface shows "the area page's line". The area page reads `No steps in your routines yet.` when routines exist but none has a step (`area_detail_controller.dart:401`). Recap (`recap_controller.dart:137`), the weekly review (`weekly_review_controller.dart:115`) and the composer turn (`pal_composer_turns.dart:154`) read `kNoRoutinesLine` for both cases. That is false when routines exist.

**Interfaces:**
- Produces, in `lib/models/goals.dart`:
  - `const kNoStepsLine = 'No steps in your routines yet.';`, next to `kNoRoutinesLine`.
  - `String noTargetLine({required bool hasRoutines})`, which returns `kNoStepsLine` when `hasRoutines` is true, otherwise `kNoRoutinesLine`.
  - `const kNoRoutinesUnit = 'routines set up';` and `const kNoStepsUnit = 'steps in your routines';`. These replace the private `_noRoutinesUnit` and `_noStepsUnit` copies in `areas_controller.dart:117-118` and `area_detail_controller.dart:147-148`, which are deleted.
- `RecapData` and `WeeklyStats` each gain `required this.hasRoutines` (a `bool`), set to `routines.isNotEmpty` in `buildRecapData` and `buildWeeklyStats`.

- [ ] **Step 1: Write the failing tests.**
  - `test/models_test.dart`: `noTargetLine(hasRoutines: false)` is `kNoRoutinesLine`, and `noTargetLine(hasRoutines: true)` is `kNoStepsLine`.
  - `test/screens/recap_screen_test.dart`: with one routine that has no steps, Recap shows `kNoStepsLine` and not `kNoRoutinesLine`.
  - `test/controllers/weekly_review_controller_test.dart` and `test/weekly_review_test.dart`: with one stepless routine, the routines tile's sub is `kNoStepsLine`.
  - `test/screens/pal/pal_composer_turns_test.dart`: with `TodayState(routines: [<one routine with steps: []>])`, the `Rituals today` turn shows `kNoStepsLine` and no ` of `.
  - Keep every existing no-routines test as it is. They must still pass.
- [ ] **Step 2: Run the tests and confirm the new cases fail** (`noTargetLine` is undefined, or the old line shows).
- [ ] **Step 3: Implement.**
  - Add the consts and `noTargetLine` to `goals.dart`.
  - Add `hasRoutines` to `RecapData` and `WeeklyStats`.
  - Recap and the weekly review use `noTargetLine(hasRoutines: hasRoutines)` when `ritualsTarget == 0`.
  - The composer turn uses `noTargetLine(hasRoutines: today.routines.isNotEmpty)`.
  - `area_detail_controller.dart:401` reads `kNoStepsLine`.
  - Both controllers read the public unit consts.
  - Run codegen. Commit only the `.g.dart` files it rewrites.
- [ ] **Step 4: Add the scenario steps.** Add `recap_stepless_routines` and `composer_rituals_turn_stepless` to `defects_scenario_test.dart`, in the file's underscore style. Each boots `TodayDay(routines: [<one routine with no steps>])` (as `today_scenario_test.dart:73` builds `_stepless`, with `legacyRitual: true`), asserts `No steps in your routines yet.` with no `No routines set up yet.`, `0 of 0` or `1 of 0`, and takes light and dark shots. The composer step follows the existing `composer_rituals_turn_no_routines` step.
- [ ] **Step 5: Run.**
  - `flutter test test/models_test.dart test/screens/recap_screen_test.dart test/controllers/weekly_review_controller_test.dart test/weekly_review_test.dart test/screens/pal/pal_composer_turns_test.dart test/controllers/area_detail_controller_test.dart test/controllers/areas_controller_test.dart test/spending_detail_test.dart`
  - `flutter test --tags scenario test/scenario/defects_scenario_test.dart test/scenario/area_page_scenario_test.dart test/scenario/areas_scenario_test.dart`
  - `flutter analyze --fatal-infos`
- [ ] **Step 6: Commit** only the files above, with the subject `fix(routines): stepless routines read the stepless line on recap, weekly review and the composer`.

### Task 2: The close-out screen test settles without a retry loop
**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `test/screens/evening_close_out_screen_test.dart`

Spec decision 6 applied to the same pattern in the close-out widget test. `test/screens/evening_close_out_screen_test.dart:22` declares `_retryWindow = Duration(minutes: 3)`, and the `a failing load shows calm copy and no card` test (around line 125) pumps one second at a time until the error shows. `ritualRoutinesStreamProvider` already has `retry: noRetry`, and the override already throws an `Exception`, which riverpod's default retry would retry.

- [ ] **Step 1:** Replace the loop with `await tester.pumpAndSettle();`. Delete `_retryWindow` and the comment above the loop.
- [ ] **Step 2:** Run `flutter test test/screens/evening_close_out_screen_test.dart` and confirm it passes.
- [ ] **Step 3:** In a throwaway local edit, remove `retry: noRetry` from `ritualRoutinesStreamProvider` in `lib/controllers/providers.dart`, regenerate, and confirm the failing-load test now fails. Then revert every `lib/` change (`git checkout -- lib/`) and confirm `git status` shows only the test file. Record the result in the task report. If the test passes without `noRetry` (for example because `overrideWith` drops the provider's retry), stop and report instead of committing.
- [ ] **Step 4:** Commit only `test/screens/evening_close_out_screen_test.dart`, with the subject `test(close-out): settle the failing-load test without a retry loop`.
