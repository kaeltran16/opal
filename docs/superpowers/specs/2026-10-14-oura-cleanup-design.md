# Oura conversion clean-up: design

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17

This spec covers the mechanical follow-ups that the Oura conversion runs filed: chunks 36, 42, 43, 44, 45, 46 and 47.
It also covers chunks 29 and 30, which the human decided on 2026-10-14 (the decisions are notes on those chunks).
The code was read at `09259a8`, where units, goldens and scenarios all pass.

## Decisions

1. **Dead mood widgets go (chunk 42).** `MoodMiniScale` and `MoodWeekChart` have no `lib` caller.
   Their only references are their own definitions in `lib/screens/mood/widgets/mood_widgets.dart` and their groups in `test/screens/mood/mood_widgets_test.dart`, so both are deleted with their tests.
   Any private helper that only they use goes too.
2. **MoodOrb is a circle-based blob with no shadow (chunk 43).** This is a rendering defect, not a design delta.
   The prototype's CSS radii (`r% (100-r)% r% (100-r)% / (100-r)% r% (100-r)% r%`) are percentages of the full box.
   The widget takes them as percentages of half the box, so at `t = 0.5` every radius is `size/4` and the orb draws as a rounded square.
   The fix computes each radius from the full `size`, so `t = 0.5` gives `size/2` on every corner, which is a circle.
   The `BoxShadow` is removed because DESIGN.md's Don't list rules out shadows.
   The radial-gradient body stays. (Human's choice.)
3. **Routines that exist with no steps get true copy (chunk 44).** `GlanceNumbers` gains a required `hasRoutines` field.
   `TodayState.glance` becomes the one place that builds `GlanceNumbers` from a `TodayState`.
   `areas_controller.dart` and `today_screen.dart` read `today.glance` instead of building their own copy, and `routinesDone` is 0 whenever the tracked total is 0.
   With routines but no tracked routine, the Areas card and the Routines hero read `0` with the unit `steps in your routines`.
   This matches Pal's `No steps in your routines yet.` line. (Human's choice.)
   With no routines at all, they keep reading `0 routines set up`.
4. **Codegen hashes (chunk 46).** On `09259a8`, `build_runner` rewrites only `lib/controllers/areas_controller.g.dart`.
   `pal_composer_controller.g.dart` is already current. The task that edits `areas_controller.dart` for decision 3 regenerates and commits that file.
   This closes chunk 46 with no runtime change of its own.
5. **Today drops Pal's add-ritual proposal while the close-out row shows (chunk 45).**
   The server's `add_ritual` presentation gets `action: 'add_ritual'` (it is `null` today, the same as `generic`).
   `MockPalService`'s `add-wind-down-ritual` proposal carries the same action, and `PalProposal` gains an `addsRitual` getter next to `navigatesToCloseOut`.
   `buildDayPlan` leaves out `addsRitual` proposals whenever the close-out row exists, following the close-out fold from `1f9681e`.
   With no evening routine that has steps, the proposal keeps its own row.
   The proposal stays reachable on You (chunk 72, the human's call on 2026-10-15, replacing the 2026-10-14 choice to leave it unreachable): You's `Pal suggests` section lists every pending Pal proposal, folded or hidden on Today or not.
   It reuses Today's handling: approve goes through `actOnPlanItem`, Not now settles the item, and the session Today kept in its widget state moves to the kept-alive `planSessionControllerProvider`, so a proposal settled on either screen is gone from both.
   The section is open hairline rows with text buttons under a `headline` heading, so it never competes with You's lead finding. It is hidden when there are no pending proposals and when Pal is offline.
   The live Pal follows only once the server is deployed. This run does not deploy.
6. **The routines error steps settle without a retry loop (chunk 47).** `_pumpUntil` and its 3-minute window leave `routines_onboarding_scenario_test.dart`.
   The manage, player and closeout error steps settle with the harness's normal pump.
   Each step must still fail if `retry: noRetry` is removed from the provider it exercises. The worker checks this once by removing it locally and records the result in the task report.
7. **The fake-async write hang is fixed at its root (chunk 36).** A full-`LoopApp` widget test that taps Add on an expense must pop the sheet with the normal pump, without `tester.runAsync`.
   The report names `BudgetAlertController.checkAfterSpend`'s `watchToday(now).first` as the call that never settles.
   The worker finds why, writes a failing test that shows it, and fixes it in the controller, the repository or the shared test harness.
   A per-test `runAsync` does not count as a fix, and neither does a longer pump.
   One plausible fix is a one-shot query: the alert needs a single read, not a stream, so `EntryRepository` would gain a `get` for a day's entries. The cause, not this guess, decides the fix.
   Once fixed, the `new entry expense` scenario step in `pal_money_settings_scenario_test.dart` drops `_tapToWrite` for a plain tap.
   `test/new_entry_test.dart` gains a full-`LoopApp` test for the expense Add flow with `budgetAlerts` on.
   Any other `_tapToWrite` or `runAsync` write turn that the same root cause explains drops too. One that is still needed keeps a comment saying why.
8. **No routines means a daily target of 0 (chunk 29).** `effectiveDailyRitualTarget` stops falling back to `Goals.dailyRitualTarget`.
   The target becomes `trackedRoutines(routines).length`, and the function drops its now-unused `goals` parameter.
   The stored `dailyRitualTarget` column and onboarding's write of it stay as they are. A schema change is out of scope.
   Every caller is checked for a `0 of 0` reading: `providers.dart`, `recap_controller.dart`, `spending_controller.dart` (including the raw `goals.dailyRitualTarget` read in `DetailTracker`), `today_controller.dart`, `weekly_review_controller.dart`, `pal_context_builder.dart` and `pal_composer_turns.dart`.
   Where a surface would show `0 of 0`, it shows the area page's line instead: `No routines set up yet.` with no routines, and `No steps in your routines yet.` when routines exist but none has a step (`noTargetLine` in `lib/models/goals.dart`).
9. **The composer's coffee starter follows the currency (chunk 30).** The amount is `5 × currency.budgetScale` and the label goes through `formatCurrency`, giving `Verve coffee, $5` in USD and `Verve coffee, 5.000 ₫` in VND.
   One function builds this starter from a `Currency`, and both `_IdleBody._starters` in `pal_composer_screen.dart` and `MockPalService`'s composer suggestion use it.
   The screen reads the currency from settings.
   The mock is told the currency where `providers.dart` builds it, and keeps USD as its default for tests.
   No new `Currency` field is added.

## Constraints

- Follow DESIGN.md. A token-guard failure is fixed with a `lib/theme` name, never an annotation or a looser guard.
- Every fix starts with a failing test that shows the defect.
- Regenerate only the goldens that a change moves, and show the before and after diff in the task report.
- Riverpod codegen: `dart run build_runner build --delete-conflicting-outputs`. Commit only the `.g.dart` files the task's own change rewrites.
- Comments are lower case and say only why. No magic numbers or strings. No new dependencies. No emojis.
- The final verification is `flutter test` (units, golden and scenario) plus `flutter analyze --fatal-infos`. The server change also passes `vitest` in `server/`.

## Out of scope

- Deploying the server.
- Removing `Goals.dailyRitualTarget` from the schema.
- Chunk 35 (Budget options) and the other open chunks on the effort.
