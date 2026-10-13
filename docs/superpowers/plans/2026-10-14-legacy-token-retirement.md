# Legacy Token Retirement and Oura Clean-up Implementation Plan

> **For agentic workers:** each task below carries its decisions, the files it owns, the interfaces neighbours rely on, and its acceptance with the focused tests that prove it. Write the implementation yourself. Do not spawn subagents or forks.

**Goal:** Remove the last readers of the legacy design tokens, delete the tokens from `lib/theme/`, guard against their return, and close the clean-up items the three Oura runs left.

**Architecture:** Independent deletions, conversions and hygiene fixes run side by side. The retirement waits for every task that removes a legacy reader; the golden regeneration waits for the retirement.

**Tech Stack:** Flutter, Riverpod codegen (`build_runner`), flutter_test goldens and scenario tests.

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Spec:** `docs/superpowers/specs/2026-10-14-legacy-token-retirement-design.md`
**Verify:** `flutter test --exclude-tags "golden || scenario"`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags "golden || scenario"`

## Global Constraints

- The legacy pattern, verbatim: `AppType\.(caption2|footnote|title1|title2|title3|large|amountLg|amount)\b|\bc(olors)?\.(money|move|rituals|nutrition|sleep|mood)(Tint|Ink)?\b|Elevation\.(sm|card)\b|\.glass(Border|Highlight)?\b|\.accent(Ink|Tint)?\b|onAccent|\bsfr\(|AppText\.mono|Radii\.(md|lg)\b`
- Commit subjects use the repo's `type(scope): summary` style, with no attribution or co-author trailer.
- Comments are lower case and only say why. No magic numbers: name values in `lib/theme/` or as named constants. No new dependencies. No emojis.
- Token guard failures are fixed by naming the value in `lib/theme/`, never with a `kept literal` annotation or a looser guard.
- Riverpod codegen: run `dart run build_runner build --delete-conflicting-outputs` after editing a controller file and commit the `.g.dart` files it changes.
- Before deleting or renaming a symbol, grep lib and test for it, including `.g.dart` files and string routes. One surviving reference means it is live.
- Do not edit the parallel run's files: `rituals_controller`, `day_plan`, `rituals_builder_screen`, `providers`, `profile_screen`, `budgets_goals_screen`, `post_workout_screen`, `routine_generator_screen`.
- Follow DESIGN.md and the screens runs A, B and C converted. Area colours appear only on the activity rings.

## Review Focus

1. A legacy token in a doc comment: the guard scans comments too, so a stale `c.accent` or `forType` mention must fail it. Task 7's guard test covers a comment line.
2. Dark theme: every converted view must read in dark. Task 5 and Task 6 acceptance include the dark scenario shots.
3. The ring colours keep their exact values after the rename; a changed value would silently shift the areas goldens. Task 7 pins both themes' values.
4. Deleting the nutrition pending chain must not break the meal detail's linked-expense line (`linkedExpenses`, `linkedEntryId`). Task 3 keeps its existing test green.
5. Renormalising line endings must not alter any file's content. Task 1 checks `git diff --ignore-all-space --stat` is empty before committing anything it touched.

---

### Task 1: Line endings rule
**Depends on:** none
**Model:** claude-sonnet-5-5
**Chunk:** core.autocrlf=true with LF files: after build_runner about 45 unchanged .g.dart files show as modified in run worktrees. Add a .gitattributes eol rule
**Files:** `.gitattributes`

Add `.gitattributes` at the repo root:
- `* text=auto eol=lf`
- `*.sh text eol=lf`
- `*.png binary`, `*.jpg binary`, `*.ttf binary`, `*.otf binary`, `*.wasm binary`

Then run `git add --renormalize .`. The index already stores every text file as LF (`git ls-files --eol`: 615 `i/lf`, 47 binary), so this is expected to stage nothing. If it stages files, commit them only if `git diff --cached --ignore-all-space --stat` shows no change beyond line endings; otherwise unstage them and say why in the report. Name every file it touched in the report, or say it touched none.

Acceptance:
- `git ls-files --eol` shows every text file as `i/lf attr/text=auto eol=lf` (or `attr/text eol=lf` for `.sh`) and the binaries as `-text`.
- After `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs`, `git status --porcelain -- '*.g.dart'` is empty. Report the before and after count of modified `.g.dart` files.

### Task 2: Format area_state
**Depends on:** none
**Model:** claude-haiku-5-5
**Chunk:** lib/analysis/area_state.dart and test/analysis/area_state_test.dart are not dart format-clean on main (the dayShare clamp and the careAreas list).
**Files:** `lib/analysis/area_state.dart`, `test/analysis/area_state_test.dart`

Run `flutter pub get` first so the package's formatter settings resolve, then `dart format` on the two files. Whitespace only; no other edit.

Acceptance: `dart format --output=none --set-exit-if-changed lib/analysis/area_state.dart test/analysis/area_state_test.dart` exits 0, and `flutter test test/analysis/area_state_test.dart` passes.

### Task 3: Delete the nutrition confirm sheet and its chain
**Depends on:** none
**Model:** claude-sonnet-5-5
**Chunk:** nutrition_confirm_sheet.dart still uses 14 legacy tokens (left untouched by contract); it will break when the token-retirement run lands unless converted first.
**Files:** `lib/screens/nutrition/nutrition_confirm_sheet.dart`, `lib/controllers/nutrition_controller.dart`, `lib/controllers/nutrition_controller.g.dart`, `lib/data/repositories/nutrition_repository.dart`, `lib/data/seed/seed_data.dart`, `test/controllers/nutrition_controller_test.dart`, `test/data/nutrition_repository_test.dart`, `test/screens/nutrition_meal_detail_test.dart`, `test/controllers/pal_findings_controller_test.dart`, `test/screens/you/pal_memory_screen_test.dart`

Nothing opens the sheet. Delete, after grepping each symbol:
- `lib/screens/nutrition/nutrition_confirm_sheet.dart` (`showNutritionConfirmSheet`).
- In `nutrition_controller.dart`: `NutritionPending`, `NutritionState.pending`, `_derivePending`, `confirmFromExpense`, `portionFactors`, and the doc text that describes the pending prompt. `_estimate`, `estimateFor`, `slotForHour`, `linkedExpenses` stay (other callers).
- `NutritionRepository.linkedEntryIds`.
- The tests that cover only those: the `pending derivation` and `confirmFromExpense` tests in `nutrition_controller_test.dart`, the `linkedEntryIds` test in `nutrition_repository_test.dart`; drop `pending: null` from the `NutritionState` constructions in the three other test files.
- `seed_data.dart`: the `seed-nutrition-pending` expense stays, id unchanged; only its comment stops calling it a pending nutrition card.

Regenerate `nutrition_controller.g.dart` with build_runner.

Acceptance:
- `grep -rnE "NutritionPending|showNutritionConfirmSheet|confirmFromExpense|portionFactors|linkedEntryIds|nutrition_confirm_sheet" lib test` returns nothing.
- `flutter test test/controllers/nutrition_controller_test.dart test/data/nutrition_repository_test.dart test/screens/nutrition_meal_detail_test.dart test/controllers/pal_findings_controller_test.dart test/screens/you/pal_memory_screen_test.dart` passes, including the meal detail's linked-expense test.

### Task 4: Delete the unused border and donut widgets
**Depends on:** none
**Model:** claude-haiku-5-5
**Chunk:** lib/widgets/dashed_border.dart (DottedBorderBox) has no users since the close-out conversion; delete it
**Files:** `lib/widgets/dashed_border.dart`, `lib/widgets/donut_chart.dart`

Delete both files after grepping `DottedBorderBox`, `dashed_border`, `CategoryDonut`, `DonutPainter` and `donut_chart` across lib and test (on ac99734 only the files themselves match). `AppColors.forType` itself is removed by Task 7, not here.

Acceptance: those greps return nothing; `flutter analyze --fatal-infos` is clean.

### Task 5: Convert the mood logger sheet
**Depends on:** none
**Model:** claude-opus-5-5
**Files:** `lib/screens/mood/mood_logger_sheet.dart`, `lib/screens/mood/widgets/mood_widgets.dart`, `test/screens/mood/mood_logger_sheet_test.dart`, `test/scenario/today_scenario_test.dart`

Bring the mood logger to the sheets runs A and B built:
- `showMoodLogger(BuildContext)` keeps its signature (Today calls it) and opens through `showAppSheet` (`lib/widgets/app_sheet.dart`); read how `weekly_plan_screen.dart` and `routine_editor_screen.dart` call it, and drop the hand-rolled `showModalBottomSheet`, shape and `Radii.lg` corners.
- The Log action is a `PillButton` (`lib/widgets/controls.dart`); Cancel follows those sheets' secondary action.
- `AppType.caption2` labels in `mood_widgets.dart` take the current role the converted screens use for small labels (`AppType.label` or `AppType.caption`, per DESIGN.md section 4), with `c.ink3` for quiet text.
- The mood-scale colours (`moodColor`) are a data scale, not an area colour, and stay.
- Zero legacy-pattern matches in both lib files.

Acceptance:
- `test/screens/mood/mood_logger_sheet_test.dart` still opens the sheet, logs a check-in and closes; add a case that the action is a `PillButton`.
- `test/scenario/today_scenario_test.dart` gains a step that selects the seeded `Mood check-in` row on Today (as the `today action card` scenario does at line 146; that tap only selects it), then taps the card's `Check in` pill (the mood item's `actionLabel` in `day_plan.dart`), asserts the sheet is shown (its title and the `PillButton`), and takes a shot `today_mood_logger_<theme>` in both themes.
- `flutter test test/screens/mood/mood_logger_sheet_test.dart` passes; `flutter test --tags scenario test/scenario/today_scenario_test.dart` passes.

### Task 6: Convert the detail and autopilot call sites
**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `lib/screens/detail/detail_screen.dart`, `lib/screens/you/autopilot_screen.dart`, `lib/controllers/weekly_plan_controller.dart`, `lib/controllers/weekly_plan_controller.g.dart`, `test/scenario/area_page_scenario_test.dart`, `test/scenario/you_scenario_test.dart`

- `detail_screen.dart:238`: the `No sleep data yet` title takes `AppType.title` (DESIGN.md section 4's title role) with `c.ink`.
- `detail_screen.dart:624`: the swipe-delete icon takes `c.bg` (the value `onAccent` aliased).
- `autopilot_screen.dart:86`: the subtitle takes the subtitle style the converted list rows use (`ListRow` in `lib/widgets/inset_section.dart`: `AppType.subhead` with `c.ink3`), not `AppType.footnote`.
- `weekly_plan_controller.dart:17`: reword the `WeekPlanDay` doc comment so it names neither `c.forType` nor `c.accent`; say what the screen actually does with `colorKey` today (read `weekly_plan_screen.dart`). Run build_runner; commit the `.g.dart` only if it changed.

Acceptance:
- The three lib files have zero legacy-pattern matches.
- `area_page_scenario_test.dart`'s sleep empty step (asserts `No sleep data yet`) passes and its shot shows the new title; `you_scenario_test.dart`'s Autopilot step passes. Add an assertion in each that the converted text uses the new style (`AppType.title` font size for the sleep title, `AppType.subhead` font size for the Autopilot subtitle).
- `flutter test --tags scenario test/scenario/area_page_scenario_test.dart test/scenario/you_scenario_test.dart` passes.

### Task 7: Retire the legacy tokens and guard them
**Depends on:** Task 3, Task 4, Task 5, Task 6
**Model:** claude-opus-5-5
**Chunk:** Retire the legacy tokens once nothing reads them
**Chunk:** email_dashboard_screen.dart:138 ProgressBar now draws on c.track; its fill still passes legacy c.move/c.accent
**Files:** `lib/theme/app_colors.dart`, `lib/theme/app_type.dart`, `lib/theme/app_text.dart`, `lib/theme/elevation.dart`, `lib/theme/radii.dart`, `lib/screens/areas/areas_screen.dart`, `lib/controllers/insights_money_controller.dart`, `lib/controllers/insights_money_controller.g.dart`, `lib/controllers/monthly_review_controller.dart`, `lib/controllers/monthly_review_controller.g.dart`, `lib/controllers/recap_controller.dart`, `lib/controllers/recap_controller.g.dart`, `lib/controllers/weekly_review_controller.dart`, `lib/controllers/weekly_review_controller.g.dart`, `lib/controllers/workout_history_controller.dart`, `lib/controllers/workout_history_controller.g.dart`, `lib/models/budget_envelope.dart`, `lib/models/enums.dart`, `lib/models/ritual_routine.dart`, `DESIGN.md`
**Files:** `test/theme/app_colors_test.dart`, `test/theme/app_type_test.dart`, `test/theme/contrast_test.dart`, `test/theme/elevation_test.dart`, `test/theme/radii_test.dart`, `test/theme/token_guard_test.dart`, `test/today_screen_test.dart`, `test/scenario/scenario_harness.dart`

First re-grep lib and test for the legacy pattern; outside `lib/theme/` only `areas_screen.dart` (`c.move`, `c.rituals`) and the theme tests should remain. Any other match is a reader an earlier task missed: convert it here and name it in the report.

Ring colours: add `AppColors.ringMove` and `AppColors.ringRoutines`, carrying the current `move` and `rituals` values in both themes (light `#34C759`, `#AF52DE`; dark `#30D158`, `#BF5AF2`), lerped like the rest. `areas_screen.dart` reads them for `ringColors`.

Delete from `lib/theme/`:
- `AppType`: `caption2`, `footnote`, `title1`, `title2`, `title3`, `large`, `amount`, `amountLg`.
- `AppColors`: `money`, `move`, `rituals`, `nutrition`, `sleep`, `mood` and each `Tint` and `Ink`, `accent`, `accentTint`, `accentInk`, `onAccent`, `glass`, `glassBorder`, `glassHighlight`, `forType`, `inkForType`, and `_glassAlpha` once unused.
- `Elevation.sm`, `Elevation.card` (`fab` stays) and the doc example naming `Elevation.card`.
- `AppFonts.sfr`, `AppFonts.mono`, and the class doc text about them.
- `Radii.md`, `Radii.lg`.

Reword the doc comments that name `forType` in `insights_money_controller.dart`, `monthly_review_controller.dart`, `recap_controller.dart`, `weekly_review_controller.dart`, `workout_history_controller.dart` (the `_groupOrder` comment), `budget_envelope.dart`, `enums.dart`, `ritual_routine.dart`, and the `AppFonts.mono` mention in `scenario_harness.dart`. The `colorToken` strings stay (data; `insightIcon` reads them). Run build_runner; commit `.g.dart` files only if they changed.

DESIGN.md: section 3 "Area colours are retired" names `ringMove` and `ringRoutines` as the only surviving area hues. Section 10 is a record, so its rows stay: the area colour, accent, glass, shadow, type, mono eyebrow and radius rows are updated to say the legacy members were deleted in this run and which ring members remain. No row is removed.

Tests:
- Theme tests drop assertions on retired members and keep the rest. `app_colors_test.dart` pins `ringMove` and `ringRoutines` to the four hex values above.
- `contrast_test.dart`: the area-ink check is removed; a new test asserts `ringMove` and `ringRoutines` differ in lightness by 1.5:1 or more in both themes (DESIGN.md section 3).
- `today_screen_test.dart:495` lists area colours to prove Today uses none; keep that intent with the ring colours.
- `token_guard_test.dart` gains a test: every `.dart` file under `lib/` outside `lib/theme/`, excluding `.g.dart`, has no match for the legacy pattern on any line, comments included, with no annotation escape. Its failure lists `path:line`. Factor the file walk the two tests share into one helper. Prove it bites: temporarily add a `// c.accent` comment line to a lib file, see the test fail, remove it.

Acceptance:
- `grep -rnE '<legacy pattern>' lib test` returns nothing (email_dashboard_screen included, which already passes `c.ink`), and `grep -rnE 'forType|inkForType' lib test` returns nothing (the guard pattern does not cover those names).
- `flutter test test/theme test/today_screen_test.dart test/screens/areas_screen_test.dart test/widgets/activity_rings_test.dart` passes; `flutter analyze --fatal-infos` is clean.
- `flutter test --tags scenario test/scenario/areas_scenario_test.dart` passes and its rings shot keeps the same two colours.
- The report lists which members were kept for the activity rings (`ringMove`, `ringRoutines`).

### Task 8: Bring final_scenario_test's You step up to date
**Depends on:** none
**Model:** claude-sonnet-5-5
**Chunk:** test/scenario/final_scenario_test.dart fails on main: it expects 'Daily routines' and 'MONEY' on You, which the You rebuild (c107c7c) removed. Update its You step
**Files:** `test/scenario/final_scenario_test.dart`

The You step expects `Daily routines` and `MONEY`, which the You rebuild removed; it fails with `Bad state: No element`. Rewrite it to what `lib/screens/profile/profile_screen.dart` shows now: scroll to the rows that follow Goals (`Budgets`, `Reviews`), assert them hit-testable, keep the loop asserting `AREAS`, `Sleep` and `Mood` are absent, and update the stale comment about the Areas group. Check the Today, Areas, Money page, Back and Workout steps against the converted screens and fix any that drifted. Do not delete steps; do not assert on the You header, which the parallel run is changing.

Acceptance: `flutter test --tags scenario test/scenario/final_scenario_test.dart` passes in both themes and writes `final_you_light` and `final_you_dark` shots showing Budgets and Reviews.

### Task 9: Regenerate the goldens
**Depends on:** Task 1, Task 2, Task 7, Task 8
**Model:** claude-opus-5-5
**Chunk:** Regenerate the goldens once the three runs land: the run A shared widgets (ListRow, InsetSection, Segmented, nav bar) change new_entry and other non-move goldens, which were left stale on purpose
**Files:** `test/golden/goldens/area_mood_dark.png`, `test/golden/goldens/area_mood_light.png`, `test/golden/goldens/area_nutrition_dark.png`, `test/golden/goldens/area_nutrition_light.png`, `test/golden/goldens/area_routines_dark.png`, `test/golden/goldens/area_routines_light.png`, `test/golden/goldens/area_sleep_dark.png`, `test/golden/goldens/area_sleep_light.png`, `test/golden/goldens/areas_dark.png`, `test/golden/goldens/areas_light.png`, `test/golden/goldens/move_dark.png`, `test/golden/goldens/move_light.png`
**Files:** `test/golden/goldens/new_entry_dark.png`, `test/golden/goldens/new_entry_light.png`, `test/golden/goldens/pal_composer_dark.png`, `test/golden/goldens/pal_composer_light.png`, `test/golden/goldens/profile_dark.png`, `test/golden/goldens/profile_light.png`, `test/golden/goldens/spending_detail_dark.png`, `test/golden/goldens/spending_detail_light.png`, `test/golden/goldens/today_dark.png`, `test/golden/goldens/today_light.png`

If the parallel run (routines, close-out, You header) has landed on main, merge main into this branch first so the profile goldens include its header change; say in the report whether it had.

Run `flutter test --update-goldens --tags golden`. Open every changed PNG and look at it before staging. A golden that looks broken (clipped or overlapping text, unthemed or wrong-theme colours, empty or missing content, overflow stripes) is never committed. A broken golden means broken rendering: fix the cause in the screen if it is within reach, regenerate and look again; if it is not, fail the task and escalate, naming the image and what is wrong. If merging main touched files beyond the PNGs, the merge commit carries them; the task's own commit stages only PNGs.

Acceptance: `flutter test --tags golden` passes on the committed images, with no image left stale or broken; the report lists each changed golden with a one-line description of what changed.
