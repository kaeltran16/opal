# Today Redesign Round 1 Fix Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the run's Final pass. `routines_onboarding_scenario_test.dart`'s `closeout open` still taps the removed "more later today" fold and the old `Close-out, at 9:30 PM. Do this next` row.

**Architecture:** Test-only fix. Your day lists every item with no fold, so the step taps the Close-out row by its new label.

**Tech Stack:** Flutter, flutter_test scenario harness.

**Spec:** docs/superpowers/plans/2026-10-15-today-redesign.md (decision 8: row labels are `<verb>: <title>, <detail>`; a row tap runs `actOnPlanItem`).

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Verify:** `sh -c 'c="${ARC_VERIFY_CHANGED:-}"; f=1; s=1; if [ -n "$c" ]; then grep -qE "^(lib|test|pubspec|assets)" "$c" || f=0; grep -q "^server/" "$c" || s=0; fi; if [ $f = 1 ]; then flutter test --exclude-tags "golden || scenario" || exit 1; fi; if [ $s = 1 ]; then (cd server && npx vitest run) && (cd server/worker && npx vitest run) || exit 1; fi'`
**Setup:** `flutter pub get && (cd server && npm ci) && (cd server/worker && npm ci)`
**Check:** `flutter analyze --fatal-infos && (cd server && npx tsc -p tsconfig.json --noEmit) && (cd server/worker && npx tsc -p tsconfig.json --noEmit)`
**Final:** `flutter test --tags scenario test/scenario/today_scenario_test.dart test/scenario/undo_toast_scenario_test.dart test/scenario/you_scenario_test.dart test/scenario/defects_scenario_test.dart test/scenario/final_scenario_test.dart test/scenario/routines_onboarding_scenario_test.dart test/scenario/pal_money_settings_scenario_test.dart`
**Prototype:** C:/Users/cktra/Projects/opal/.superpowers/design/today-redesign/project/Main.dc.html

## Global Constraints

- Today has no fold and no `Do this next` tag. Rows are one button each, labelled `<verb>: <title>, <detail>`.
- No production code changes in this round.

## Review Focus

- The step must still prove the row (not the card pill) opens the close-out: the finder targets the Your day row's semantics label, which the card does not carry.

---

### Task 1: closeout open taps the Close-out row in Your day
**Depends on:** none
**Files:** `test/scenario/routines_onboarding_scenario_test.dart`

**Failure:** `flutter test --tags scenario test/scenario/routines_onboarding_scenario_test.dart --plain-name "closeout open"` fails in light and dark with `Bad state: No element` from `_tap` at line 529. That line taps `find.textContaining('more later today')`, the fold Task 6 of the run removed.

**Do:**
- [ ] Run the command above and see both themes fail at line 529.
- [ ] In `scenarioTest('closeout open', ...)`, delete the fold tap (line 529) and replace the row tap (line 531) with the row's current label, the one `today_scenario_test.dart:232` already pins:

```dart
  scenarioTest('closeout open', (tester, dark) async {
    await bootToday(tester, dark: dark);
    // the Your day row opens the close-out, as the card's pill does.
    await _tap(tester, find.bySemanticsLabel('Start: Close-out, 4 steps'));
```

  Remove the `today` finder if nothing else in the test uses it. Keep every expectation and the `shot` after the tap unchanged.
- [ ] Run the command again: both themes pass.
- [ ] Run the run's Final command: it passes.
- [ ] `flutter analyze --fatal-infos` is clean.
- [ ] Commit only `test/scenario/routines_onboarding_scenario_test.dart` with `test(scenario): open the close-out from its Your day row`.
