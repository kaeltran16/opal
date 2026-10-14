# Oura Conversion Clean-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close nine follow-up chunks of the Oura conversion: dead mood widgets, the MoodOrb shape, stepless-routines copy, stale codegen, Today's duplicate wind-down row, the scenario retry loop, the fake-async write hang, the no-routines target, and the currency of the composer's coffee starter.

**Architecture:** Each chunk is a local fix in code that already exists. `TodayState.glance` becomes the one builder of `GlanceNumbers`. `effectiveDailyRitualTarget` loses its stored fallback. A new `addsRitual` proposal action lets the day plan drop Pal's add-ritual proposal beside the close-out row. One starter builder serves the composer screen and the mock Pal.

**Tech Stack:** Flutter, Riverpod 3 with codegen, drift, flutter_test with the scenario harness; the TypeScript server tested with vitest.

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Spec:** `docs/superpowers/specs/2026-10-14-oura-cleanup-design.md`
**Verify:** `flutter test --exclude-tags "golden || scenario" && if [ -z "$ARC_VERIFY_CHANGED" ] || grep -q '^server/' "$ARC_VERIFY_CHANGED"; then (cd server && npx vitest run); fi && if [ -z "$ARC_VERIFY_CHANGED" ]; then flutter test --tags "golden || scenario" && flutter analyze --fatal-infos; fi`
**Setup:** `flutter pub get && (cd server && npm ci)`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario/today_scenario_test.dart test/scenario/area_page_scenario_test.dart test/scenario/areas_scenario_test.dart test/scenario/routines_onboarding_scenario_test.dart test/scenario/pal_money_settings_scenario_test.dart test/scenario/defects_scenario_test.dart test/scenario/workout_scenario_test.dart`

## Global Constraints

- Baseline is main at `09259a8`: units, goldens and scenarios pass, and `flutter analyze --fatal-infos` is clean.
- Every fix starts with a failing test that shows the defect, then makes it pass. Tests check behaviour, and must fail when the intent is violated.
- Follow DESIGN.md. Fix a token-guard failure with a `lib/theme` name, never with an annotation or a looser guard.
- Regenerate only the goldens your change moves (`flutter test --update-goldens <golden test> --tags golden`). Put the before and after of each moved golden in the task report, and say why it moved.
- Riverpod codegen: `dart run build_runner build --delete-conflicting-outputs`. Commit only the `.g.dart` files your change rewrites. On `09259a8`, the only stale one is `lib/controllers/areas_controller.g.dart`, and Task 4 owns it.
- Comments are lower case and say only why. Use named consts, not magic numbers or strings. No new dependencies. No emojis.
- Every view or state a task changes gets a light and dark scenario step (`scenarioTest` plus `shot`) that shows it. The Final line runs those scenario files.

## Review Focus

1. Routines exist but every one has no steps, and a routine is marked done in legacy entries: Areas, the Routines hero and Today's care rule must all read 0 done, never `1 of 0`. Task 4 tests this.
2. No routines at all: no surface may read `0 of 0` or `of 5`. Recap, the weekly review, the spending rituals detail, Pal context and the composer's routine turn all need checking. Task 6 tests each one.
3. Pal online with both a `close_out` and an `add_ritual` proposal while the evening routine has no steps: the add-ritual row must still show. Task 3 tests this.
4. Currency switched to VND after the composer opens: the starter label and amount must follow the new currency, not a value cached at first build. Task 7 tests this.
5. Expense Add with `budgetAlerts` on and the spend crossing the budget, so the notification path runs: the sheet must pop and the alert must be scheduled once. Task 5 tests this.

---

### Task 1: Mood widgets: delete the dead ones, fix the orb
**Depends on:** none
**Model:** claude-sonnet-5-5
**Chunk:** mood widgets dead code: MoodMiniScale and MoodWeekChart have no lib callers, only mood_widgets_test
**Chunk:** MoodOrb rendering: draws as a rounded square with an offset shadow block in scenario shots; check against DESIGN.md
**Files:** `lib/screens/mood/widgets/mood_widgets.dart`, `test/screens/mood/mood_widgets_test.dart`

Spec decisions 1 and 2.

- Before deleting, grep `MoodMiniScale` and `MoodWeekChart` across `lib`, `test` and `docs`, counting type-only uses and string references. On `09259a8`, the only references are the definitions and the `MoodMiniScale` and `MoodWeekChart` test groups. Delete both classes, every private helper only they use (for example the `_WeekBars`-style painter that reads `MoodWeekChart._mid`), and both test groups.
- MoodOrb: the prototype CSS is `border-radius: r% (100-r)% r% (100-r)% / (100-r)% r% (100-r)% r%`, where each percentage is of the full box. Compute every radius from the full `size`: the horizontal radius is `r/100 × size` or `(100-r)/100 × size`, and the vertical radius is the complement, corner by corner as the CSS orders them. At `t = 0.5` every corner is `Radius.circular(size / 2)`. Remove the `BoxShadow`, because DESIGN.md's Don't list rules out shadows. Keep the radial gradient and the vertical squish. Name the 14.0 and 0.16 factors as consts if you touch those lines.
- Tests in `test/screens/mood/mood_widgets_test.dart`:
  - At `t: 0.5`, the orb's `BoxDecoration.borderRadius` resolves to `size / 2` on all four corners. This fails on `09259a8`, where every corner is `size / 4`.
  - At `t: 0.0` and `t: 1.0`, each corner's horizontal and vertical radii sum to `size`.
  - The decoration has no `boxShadow`.
- The existing `today mood logger` step in `test/scenario/today_scenario_test.dart` shows the orb. No new step is needed, and this task does not edit that file.

### Task 2: Routines scenario error steps without a retry loop
**Depends on:** none
**Model:** claude-sonnet-5-5
**Chunk:** routines_onboarding_scenario_test: the _pumpUntil 3-minute retry loop in the manage, player and closeout error steps is redundant since routines providers use noRetry
**Files:** `test/scenario/routines_onboarding_scenario_test.dart`

Spec decision 6.

- Delete `_pumpUntil`, `_retryWindow` and `_retryStep`. The `manage error`, `player error` and `closeout error` steps settle with `tester.pumpAndSettle()` (or a single `pump()` if an indeterminate animation keeps pumpAndSettle from settling; say which in the report) and then assert as they do now.
- Proof that the steps still guard `noRetry`: locally, remove `retry: noRetry` from one provider at a time, regenerate, and confirm that the error step exercising it fails. The three providers are `RitualsBuilderController` (`lib/controllers/rituals_builder_controller.dart`, manage), `RitualsController` (`lib/controllers/rituals_controller.dart:85`, which the player and closeout screens watch) and `ritualRoutinesStreamProvider` (`lib/controllers/providers.dart`). Restore each and regenerate before the next. Record in the report which step failed for each removal and with what message.
- The experiment is reverted and never committed, so those provider files and their `.g.dart` files stay off this task's Files line. The worktree must be clean of them before the task completes.
- Run: `flutter test --tags scenario test/scenario/routines_onboarding_scenario_test.dart`.

### Task 3: Today drops Pal's add-ritual proposal beside the close-out row
**Depends on:** none
**Model:** claude-opus-5-5
**Chunk:** Today: Pal's 'Add a 2-min wind-down ritual' proposal shows as its own row next to the Close-out row and may read as a duplicate wind-down item
**Files:** `server/src/pal.ts`, `server/src/pal.test.ts`, `lib/services/pal/pal_service.dart`, `lib/services/pal/mock_pal_service.dart`, `lib/screens/today/day_plan.dart`, `test/screens/day_plan_test.dart`, `test/services/http_pal_service_test.dart`, `test/services/mock_pal_service_test.dart`, `test/pal_home_test.dart`, `test/scenario/today_scenario_test.dart`, `test/scenario/defects_scenario_test.dart`, `test/golden/goldens/today_light.png`, `test/golden/goldens/today_dark.png`

Spec decision 5.

- Server: in `PROPOSAL_PRESENTATION` (`server/src/pal.ts`), `add_ritual` gets `action: 'add_ritual'`. Add a vitest case in `server/src/pal.test.ts` beside the close_out case at line 33, checking that an `add_ritual` proposal comes out with `{ icon: 'sparkles', approveIcon: 'plus', action: 'add_ritual' }`.
- Client: `PalProposal` gains `bool get addsRitual => action == 'add_ritual';` next to `navigatesToCloseOut`, with both action strings as named consts. `MockPalService`'s `add-wind-down-ritual` proposal gets `action: 'add_ritual'`. `HttpPalService` already passes `action` through. Add a case to `test/services/http_pal_service_test.dart` that decodes `"action": "add_ritual"` into `addsRitual == true`.
- `buildDayPlan`: when the close-out row is built (`closeOut != null`), leave out every proposal with `addsRitual`. When there is no close-out row, an `addsRitual` proposal is an ordinary proposal row. Update the doc comment on `buildDayPlan`.
- Tests in `test/screens/day_plan_test.dart`:
  - With an evening routine that has steps and an agenda holding `close_out` and `add_ritual` proposals, the plan has one `closeOut` item and no `proposal:` item for the add-ritual proposal.
  - With the evening routine stepless (or absent) and the same agenda, the add-ritual proposal is a `proposal` row.
  - A plain proposal with `action == null` is still a row in both cases.
- Scenario: add a step to `today_scenario_test.dart` named `today wind-down folded`. With Pal online on the mock agenda, it shows the Close-out row, checks that `Add a 2-min wind-down ritual` is absent from Today, and takes a light and dark `shot`. If an existing step in `defects_scenario_test.dart` asserts on that proposal, update it.
- Goldens: if `today_light.png` or `today_dark.png` move, regenerate them and report the diff.
- Pal Home still lists the add-ritual proposal. If `test/pal_home_test.dart` or `test/services/mock_pal_service_test.dart` assert on the proposal's fields, update them for the new action.
- Run: `flutter test test/screens/day_plan_test.dart test/services/http_pal_service_test.dart test/services/mock_pal_service_test.dart test/pal_home_test.dart`, then `cd server && npx vitest run src/pal.test.ts`, then `flutter test --tags scenario test/scenario/today_scenario_test.dart test/scenario/defects_scenario_test.dart`.

### Task 4: Stepless routines read true copy; regenerate the stale areas codegen
**Depends on:** Task 3
**Model:** claude-sonnet-5-5
**Chunk:** Routines area hero and Areas card read '0 routines set up' when routines exist but none has a step; needs copy and a GlanceNumbers field that knows routines exist
**Chunk:** Stale codegen hashes on main: build_runner rewrites areas_controller.g.dart, pal_composer_controller.g.dart and others; regenerate and commit (no runtime effect)
**Files:** `lib/screens/today/today_logic.dart`, `lib/controllers/today_controller.dart`, `lib/controllers/areas_controller.dart`, `lib/controllers/areas_controller.g.dart`, `lib/controllers/area_detail_controller.dart`, `lib/controllers/area_detail_controller.g.dart`, `lib/screens/today/today_screen.dart`, `test/controllers/areas_controller_test.dart`, `test/controllers/area_detail_controller_test.dart`, `test/analysis/area_state_test.dart`, `test/controllers/widget_sync_controller_test.dart`, `test/scenario/widget_payload_scenario_test.dart`, `test/screens/areas_screen_test.dart`, `test/screens/shell_test.dart`, `test/support/today_fixture.dart`, `test/scenario/area_page_scenario_test.dart`, `test/scenario/areas_scenario_test.dart`, `test/scenario/defects_scenario_test.dart`, `test/scenario/today_scenario_test.dart`, `test/golden/goldens/areas_light.png`, `test/golden/goldens/areas_dark.png`, `test/golden/goldens/area_routines_light.png`, `test/golden/goldens/area_routines_dark.png`

Spec decisions 3 and 4.

- Interface other tasks rely on: `GlanceNumbers` gains `required bool hasRoutines` (whether any routine exists, stepless or not). `TodayState.glance` is the single builder: `routinesTotal: trackedRoutines(routines).length`, `routinesDone: total == 0 ? 0 : ritualsDone`, `hasRoutines: routines.isNotEmpty`. `areas_controller.dart` (around line 399) and `today_screen.dart` (around line 184) use `today.glance` and delete their own copies and the comments that go with them.
- Copy, as named consts in the controllers:
  - Areas card (`areas_controller.dart` `_routines`): with `total > 0`, `of $total done` as now. Otherwise the unit is `routines set up` when `!hasRoutines` and `steps in your routines` when `hasRoutines`.
  - Routines hero (`area_detail_controller.dart` `_routines`): with `total > 0`, `of $total routines done` as now. Otherwise the unit is `routines set up` when `routines.isEmpty` and `steps in your routines` when routines exist. The hero number stays `0`, and the Pal lines stay as they are.
- Codegen: run build_runner once your edits are in, and commit `lib/controllers/areas_controller.g.dart`, plus `area_detail_controller.g.dart` if it changes. On `09259a8`, `areas_controller.g.dart` is already stale; that is chunk 46.
- Tests:
  - `areas_controller_test.dart`: routines exist with no steps gives `0 steps in your routines`; no routines still gives `0 routines set up`.
  - `area_detail_controller_test.dart`: the same two cases on `unit`.
  - A `TodayState.glance` test: stepless routines with a legacy `ritualsDone > 0` give `routinesDone == 0` and `hasRoutines == true`.
  - Update every other `GlanceNumbers(` construction in the listed tests.
This task runs after Task 3 because both edit `defects_scenario_test.dart` and `today_scenario_test.dart`.

- Scenario:
  - Update the existing `routines_area_no_steps` step in `test/scenario/defects_scenario_test.dart` (around line 296). It seeds stepless routines and today asserts `routines set up`; it should expect `steps in your routines` instead, next to Pal's `No steps in your routines yet.`. Do not add a duplicate step.
  - Add the stepless state for the Areas card to `areas_scenario_test.dart`, expecting `0 steps in your routines`, with light and dark shots.
  - Add `today care stepless` to `today_scenario_test.dart`. It seeds routines that have no steps plus a legacy ritual entry, so `ritualsDone > 0`. It asserts that Routines is not forced as a Needs care lead and that no `1 of 0` text shows. Light and dark shots.
- Run: `flutter test test/controllers/areas_controller_test.dart test/controllers/area_detail_controller_test.dart test/analysis/area_state_test.dart test/controllers/widget_sync_controller_test.dart test/screens/areas_screen_test.dart test/screens/shell_test.dart`, then `flutter test --tags scenario test/scenario/defects_scenario_test.dart test/scenario/areas_scenario_test.dart test/scenario/today_scenario_test.dart`.

### Task 5: Full-app writes settle under fake async
**Depends on:** none
**Model:** claude-opus-5-5
**Chunk:** Widget tests that boot the full LoopApp under fake async: a repository write completes but the following pop never runs without a real async turn (tester.runAsync). t-4's expense Add test uses the workout kind because of it; BudgetAlertController.checkAfterSpend's drift watchToday().first never settles.
**Files:** `lib/controllers/budget_alert_controller.dart`, `lib/controllers/budget_alert_controller.g.dart`, `lib/data/repositories/entry_repository.dart`, `test/controllers/notification_delivery_test.dart`, `test/repository_test.dart`, `test/new_entry_test.dart`, `test/scenario/pal_money_settings_scenario_test.dart`, `test/scenario/workout_scenario_test.dart`, `test/support/golden_harness.dart`, `test/support/flush_provider_timers.dart`, `test/flutter_test_config.dart`

Spec decision 7. Use the `diagnosing-bugs` skill, not `systematic-debugging`.

- Reproduce first: in `test/new_entry_test.dart`, add a test that boots the full `LoopApp` through the shared harness (`bootToday` in `test/support/golden_harness.dart`, or the same overrides), with `settings.budgetAlerts` on and a daily budget the spend crosses. It opens `/entry/new` (expense kind), types an amount, taps Add, calls `pumpAndSettle` with no `runAsync`, and expects the sheet gone, one money entry written, and the budget alert scheduled once. It must fail (hang or time out) on `09259a8`.
- Find out why `watchToday(now).first` never completes in that setup: drift's stream-query cache shared with the live Today stream, a zero-duration or debounce timer that fake time never reaches, or something else. Name the cause in the commit message and in the report.
- Fix it at the root in the controller, the repository or the shared harness. A per-test `runAsync` or a longer pump is not a fix. If the cause is that a one-shot read goes through a stream, add `Future<List<Entry>> getToday([DateTime? day])` (or `getEntriesInRange`) to `EntryRepository`, have `checkAfterSpend` use it, and cover it in `test/repository_test.dart`. Keep `notification_delivery_test.dart` passing.
- In `pal_money_settings_scenario_test.dart`, the `new entry expense` step taps Add through `_tap`, not `_tapToWrite`. Every other `_tapToWrite` that the same cause explains moves to `_tap`. If `_tapToWrite` then has no callers, delete it and `_writeTurn`. Where a real async turn is still needed, keep it with a comment saying why.
- Check `test/scenario/workout_scenario_test.dart`'s `_settleDb` the same way. Its `runAsync` drift tick (line 179, eight callers) is another write turn. If the root cause explains it, replace it with the normal pump and delete `_settleDb` and `_dbTick`. If it does not, keep it and give it a comment naming the different cause. Record the outcome in the report.
- Run: `flutter test test/new_entry_test.dart test/controllers/notification_delivery_test.dart test/repository_test.dart`, then `flutter test --tags scenario test/scenario/pal_money_settings_scenario_test.dart test/scenario/workout_scenario_test.dart`.

### Task 6: No routines means a daily routines target of 0
**Depends on:** Task 3, Task 4
**Model:** claude-sonnet-5-5
**Chunk:** Onboarding Skip on step 4 with every routine off finishes and seeds no routines (existing behaviour, kept); confirm that is intended
**Files:** `lib/models/goals.dart`, `lib/controllers/providers.dart`, `lib/controllers/providers.g.dart`, `lib/controllers/recap_controller.dart`, `lib/controllers/recap_controller.g.dart`, `lib/controllers/spending_controller.dart`, `lib/controllers/spending_controller.g.dart`, `lib/controllers/today_controller.dart`, `lib/controllers/weekly_review_controller.dart`, `lib/controllers/weekly_review_controller.g.dart`, `lib/services/pal/pal_context_builder.dart`, `lib/screens/pal/pal_composer_turns.dart`, `lib/controllers/area_detail_controller.dart`, `test/screens/pal/pal_composer_turns_test.dart`, `test/scenario/area_page_scenario_test.dart`, `test/models_test.dart`, `test/completed_routines_test.dart`, `test/controllers/weekly_review_controller_test.dart`, `test/weekly_review_test.dart`, `test/screens/recap_screen_test.dart`, `test/spending_detail_test.dart`, `test/services/pal/pal_context_builder_test.dart`, `test/services/pal_context_builder_test.dart`, `test/rituals_test.dart`, `test/onboarding_test.dart`, `test/support/today_fixture.dart`, `test/scenario/defects_scenario_test.dart`

Spec decision 8. This task runs after Task 4 (`today_controller.dart`, `today_fixture.dart`) and Task 3 (`defects_scenario_test.dart`).

- `effectiveDailyRitualTarget(List<RitualRoutine> routines)` returns `trackedRoutines(routines).length` and drops the `goals` parameter. Update its doc comment and every caller: `providers.dart:297`, `recap_controller.dart:199`, `spending_controller.dart:243`, `today_controller.dart:88`, `weekly_review_controller.dart:154`, `pal_context_builder.dart:46` and `:210`. `DetailTracker.rituals` in `spending_controller.dart:96` reads `goals.dailyRitualTarget` raw; route it through the same rule.
- `Goals.dailyRitualTarget`, its column, the seed and onboarding's write stay as they are. Leave `pal_action_executor.dart` alone.
- Everywhere a target of 0 would render `0 of 0` or `of 0` (Recap's `of $ritualsTarget` sub, the weekly review's, the spending rituals detail, the composer turn in `pal_composer_turns.dart:151`), show `No routines set up yet.`, the area page's line. The literal lives only at `lib/controllers/area_detail_controller.dart:395` today. Move it to a public const `kNoRoutinesLine` in `lib/models/goals.dart`, next to the target rule, and have the area page and every new use read it. Pal context sends `ritualsTarget: 0` and a 0 pct, as it does now.
- `test/repository_test.dart` and `test/screens/settings/budgets_goals_screen_test.dart` read the stored `dailyRitualTarget`, which does not change, so they need no edit. Grep them to confirm. `repository_test.dart` belongs to Task 5.
- Unit tests:
  - `effectiveDailyRitualTarget([])` is 0, in `test/models_test.dart`.
  - With no routines, Recap (`test/screens/recap_screen_test.dart`), the weekly review (`test/controllers/weekly_review_controller_test.dart` and `test/weekly_review_test.dart`) and the spending rituals detail (`test/spending_detail_test.dart`) each show `No routines set up yet.`, not `0 of 0` or `of 5`.
  - The composer's `Rituals today` turn, in a new `test/screens/pal/pal_composer_turns_test.dart`, shows the line with no routines and `1 of 2` with two tracked routines.
  - Update existing tests that expected the fallback of 5, including `test/rituals_test.dart` and `test/onboarding_test.dart`.
- Scenario steps, each booting `TodayDay(routines: [])`, asserting `No routines set up yet.` and no `of 5` or `0 of 0`, with light and dark shots:
  - `recap no routines` and `weekly review no routines` (`/weekly-review`), plus `composer rituals turn no routines` (open the composer, log the `Finished morning pages` starter with Pal offline, show the turn), all in `defects_scenario_test.dart`.
  - The spending rituals detail is now the Routines area page (`ritualsDetail` redirects to `areaRoutines`). Extend the existing `area routines empty` step in `area_page_scenario_test.dart` to assert no `of 5` or `0 of 0`.
- Run: `flutter test test/models_test.dart test/completed_routines_test.dart test/weekly_review_test.dart test/controllers/weekly_review_controller_test.dart test/screens/recap_screen_test.dart test/spending_detail_test.dart test/services/pal_context_builder_test.dart test/services/pal/pal_context_builder_test.dart test/rituals_test.dart test/onboarding_test.dart test/screens/pal/pal_composer_turns_test.dart test/controllers/area_detail_controller_test.dart`, then `flutter test --tags scenario test/scenario/defects_scenario_test.dart test/scenario/area_page_scenario_test.dart`.

### Task 7: The composer's coffee starter follows the currency
**Depends on:** Task 3, Task 5, Task 6
**Model:** claude-sonnet-5-5
**Chunk:** Pal composer: the static fallback starter 'Verve coffee, $5' (pal_composer_screen.dart _IdleBody._starters, and the mock service's composer suggestion) hardcodes $ and logs 5 in the user's currency, so a VND user logs 5 dong. Needs a product call on the per-currency amount.
**Files:** `lib/services/pal/coffee_starter.dart`, `lib/screens/pal/pal_composer_screen.dart`, `lib/services/pal/mock_pal_service.dart`, `lib/controllers/providers.dart`, `lib/controllers/providers.g.dart`, `test/services/pal/coffee_starter_test.dart`, `test/services/pal/mock_pal_service_suggestions_test.dart`, `test/screens/pal/pal_composer_starters_test.dart`, `test/screens/pal/pal_composer_sheet_test.dart`, `test/scenario/pal_money_settings_scenario_test.dart`, `test/golden/goldens/pal_composer_light.png`, `test/golden/goldens/pal_composer_dark.png`

Spec decision 9. This task runs after Task 3 (`mock_pal_service.dart`), Task 5 (`pal_money_settings_scenario_test.dart`) and Task 6 (`providers.dart`).

- Interface: in a new `lib/services/pal/coffee_starter.dart`, add `const double coffeeStarterAmount = 5;` and one function that builds the starter from a `Currency`. Its label is `'Verve coffee, ${formatCurrency(coffeeStarterAmount * c.budgetScale, c)}'` (`$5` in USD, `5.000 ₫` in VND). Its payload is a `StarterEntry(type: EntryType.money, title: 'Verve coffee', amount: -coffeeStarterAmount * c.budgetScale, ...)`. Pick a return shape that both callers can use without duplicating label or payload (for example a `PalSuggestion`, which the screen maps to its `_Starter`). The screen uses category `Coffee` and the mock `Food & Drink`; settle on one canonical `kSpendCategories` value and say which.
- `_IdleBody._starters` stops being a const list. The screen reads `settings.currency` (as `providers.dart` already does at line 221) and rebuilds the starters on a currency change.
- `MockPalService` takes `Currency Function() currency` in its constructor, defaulting to `() => Currency.usd`. It calls the function on each `suggestions(SuggestionSurface.composer)` call and builds the suggestion with the shared builder.
- `palService` is `keepAlive`, so `providers.dart:177` passes `() => ref.read(settingsRepositoryProvider).currency`. It reads rather than watches: a currency switch neither rebuilds the service nor leaves the mock stale, because the currency is read per call.
- No new `Currency` field.
- Tests: `test/services/pal/coffee_starter_test.dart` covers USD (`Verve coffee, $5`, amount -5) and VND (`Verve coffee, 5.000 ₫`, amount -5000). `pal_composer_starters_test.dart` checks that the idle composer shows the VND label when settings say VND, and that tapping it offline logs -5000. In `test/services/pal/mock_pal_service_suggestions_test.dart`, the mock's composer suggestion reads `Verve coffee, 5.000 ₫` with amount -5000 when its currency function returns VND, and follows a switch between two calls.
- Scenario: add `composer starter vnd` to `pal_money_settings_scenario_test.dart`. It opens the composer idle with VND set and checks the `5.000 ₫` starter (shot). Then, with Pal offline, it taps the starter and asserts one money entry `Verve coffee` with amount -5000 in the repository (shot). Light and dark.
- Run: `flutter test test/services/pal/coffee_starter_test.dart test/services/pal/mock_pal_service_suggestions_test.dart test/screens/pal/pal_composer_starters_test.dart test/screens/pal/pal_composer_sheet_test.dart`, then `flutter test --tags scenario test/scenario/pal_money_settings_scenario_test.dart`.
