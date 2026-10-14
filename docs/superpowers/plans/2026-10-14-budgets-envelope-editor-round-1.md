# Budgets Envelope Editor Round 1: Loading Step Teardown

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Verify:** `flutter test --exclude-tags "golden || scenario"`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter analyze --fatal-infos && flutter test`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-envelope-editor\project\Main.dc.html

**Goal:** The `envelopes_loading` scenario step passes in light and dark, so the run's Final (`flutter analyze --fatal-infos && flutter test`) is green.

**Architecture:** A test-only defect. `_StuckEnvelopes` in `test/scenario/envelope_editor_scenario_test.dart` returns a stream that never emits, so `budgetEnvelopesControllerProvider` is still loading when the scenario harness tears the app down (`flushProviderTimers` pumps an empty widget, which disposes the `ProviderScope`). Since Task 2, the five money providers await `budgetEnvelopesControllerProvider.future`. Riverpod 3 completes that pending future with `Bad state: The provider budgetEnvelopesControllerProvider was disposed during loading state, yet no value could be emitted` (`ElementWithFuture.dispose`), and the test framework reports it as the step's failure. The step's own assertions and screenshot pass. The fix keeps the step's loading screenshot and lets the fake controller emit before teardown.

**Tech Stack:** Flutter, Riverpod 3 with riverpod_generator, flutter_test scenario tests (`scenarioTest`, `shot`) tagged `scenario`.

**Spec:** `docs/superpowers/plans/2026-10-14-budgets-envelope-editor.md` (the run's plan; Task 4 owns the scenario file and the `envelopes_loading` step).

## Global Constraints

- Touch only the file in the task's Files line. No product code changes: in the app, drift's `watchEnvelopes()` emits straight away, so no real screen is left loading at dispose.
- Do not loosen the step: it still asserts `…` on the editor and no `New envelope` row before its `envelopes_loading_<theme>` shot, and that shot still shows the loading state.
- Do not change `scenario_harness.dart` or `flush_provider_timers.dart`, and do not swallow errors (no `FlutterError.onError` override, no try/catch around teardown).
- No goldens move.

## Review Focus

- The `envelopes_loading` screenshot is taken while the controller is still loading, before the fake emits.
- `envelopes_load_error` (which uses `_StuckEnvelopes(error: true)`) still passes unchanged.

---

### Task 1: Loading step emits before teardown

**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `test/scenario/envelope_editor_scenario_test.dart`

Make `envelopes_loading` pass in light and dark without loosening it.

- Give `_StuckEnvelopes` a way for the step to release it, for example a `StreamController<List<BudgetEnvelope>>` the fake owns plus a `release()` that adds `const []`. Keep the `error: true` path as it is.
- In `envelopes_loading`, keep a handle on the fake the override creates, keep the existing assertions and `shot` as they are, then release the fake and pump, so the provider has a value before the harness disposes the scope.
- Close the fake's stream controller when the provider is disposed (`ref.onDispose`) so nothing leaks.
- If releasing with an empty list makes a later frame throw or overflow, fix that in the step instead of working around it, and say what it was in the report.

Tests:
- `flutter test test/scenario/envelope_editor_scenario_test.dart` passes, every step in light and dark.
- Before the fix, `flutter test test/scenario/envelope_editor_scenario_test.dart --plain-name "envelopes_loading (light)"` fails with the `disposed during loading state` StateError. After it, the same command passes.
- `flutter analyze --fatal-infos` is clean.
