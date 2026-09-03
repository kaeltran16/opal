# Flutter CI Gate & Green Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a CI gate for the Flutter app and fix the 4 wall-clock-rotted sleep controller tests it would have caught.

**Architecture:** Three independent pieces landed in dependency order. The gate enablers (analyzer lints, golden tagging) come first because the CI gates depend on them; the sleep seam second; the workflow last, so it is green the moment it exists rather than red on arrival. The sleep fix is a rename plus a dead-parameter deletion — `_deriveState` never referenced its `now` argument — which moves the pure math to a layer where absolute test dates cannot rot.

**Tech Stack:** Flutter 3.44.1 / Dart SDK ^3.12.1, Riverpod 3 with codegen, drift, GitHub Actions, `subosito/flutter-action@v2`.

**Spec:** `docs/superpowers/specs/2026-08-03-flutter-ci-and-green-suite-design.md` (commit `58ee8f4`)

## Global Constraints

- **Flutter version is pinned to `3.44.1`** in CI. Never `channel: stable` unpinned.
- **Goldens are excluded from CI** via `flutter test --exclude-tags golden`. They are a machine-local visual baseline.
- **Do NOT run `flutter test --update-goldens`.** Three goldens (`golden: move`, `golden: profile`, `golden: today`) are already drifted and stay red. Re-baselining is a visual review, explicitly out of scope, and blindly accepting the diffs would silently swallow a visual regression.
- **Acceptance criterion:** `flutter test --exclude-tags golden` goes from **4 failures to 0**. A bare `flutter test` will still report the 3 drifted goldens — that is expected, not a regression.
- **The codegen gate must use `git diff --ignore-cr-at-eol --exit-code`.** The repo has `core.autocrlf=true` and no `.gitattributes`, so `build_runner` writes LF into a CRLF tree; a plain `git diff --exit-code` is permanently red locally.
- **Do NOT add `.gitattributes`** or run `dart format` over the repo. Both were explicitly rejected in the spec (a `dart format` dry run reformats 259 of 350 files).
- **Never add a `Co-Authored-By` line** to commits.
- **CI path filters must not include `server/**`** — `worker.yml` owns that, and one change must never fire both workflows.

---

## Task 1: Gate enablers — analyzer lints and golden tagging

`flutter analyze --fatal-infos` currently fails on 3 info lints, and `--exclude-tags golden` does nothing until the golden test is tagged. Both must land before the workflow, or CI is red on its first run.

**Files:**
- Modify: `test/controllers/insights_controller_test.dart:134,153`
- Modify: `test/screens/mood/mood_logger_sheet_test.dart:11`
- Modify: `test/golden/design_system_golden_test.dart:1` (prepend library annotation)
- Create: `dart_test.yaml`

**Interfaces:**
- Consumes: nothing.
- Produces: a `golden` test tag that `flutter test --exclude-tags golden` recognizes (used by Task 3), and a clean `flutter analyze --fatal-infos` (also used by Task 3).

- [ ] **Step 1: Confirm the current analyzer baseline**

Run: `flutter analyze --no-pub`

Expected: exactly 3 issues — two `unnecessary_underscores` at `test\controllers\insights_controller_test.dart:134:48` and `:153:48`, one `unnecessary_import` at `test\screens\mood\mood_logger_sheet_test.dart:11:8`. If you see a different set, stop and report — the plan was written against this baseline.

- [ ] **Step 2: Fix both `unnecessary_underscores` lints**

Both lines are byte-identical, so replace all occurrences in `test/controllers/insights_controller_test.dart`.

Find (2 occurrences, lines 134 and 153):

```dart
    final sub = container.listen(provider, (_, __) {});
```

Replace with:

```dart
    final sub = container.listen(provider, (_, _) {});
```

Dart 3.7+ allows repeated `_` for unused parameters, so the second `_` no longer needs to be `__`.

- [ ] **Step 3: Fix the `unnecessary_import` lint**

In `test/screens/mood/mood_logger_sheet_test.dart`, delete line 11 entirely:

```dart
import 'package:opal/services/pal/mock_pal_service.dart';
```

`MockPalService` is still reachable — line 12's `import 'package:opal/services/services.dart';` re-exports it. Do not touch line 12.

- [ ] **Step 4: Verify the analyzer is clean**

Run: `flutter analyze --fatal-infos --no-pub`

Expected: `No issues found!` and exit code 0. This is the exact invocation CI will use in Task 3.

- [ ] **Step 5: Tag the golden test as library-scoped**

`@Tags` applies to the *library*, not a declaration, so it must sit at the very top of the file above every import, paired with a `library;` directive. Prepend these three lines to `test/golden/design_system_golden_test.dart` so it begins:

```dart
@Tags(['golden'])
library;

import 'package:drift/native.dart';
```

Leave the rest of the file, including its existing doc comment, untouched.

- [ ] **Step 6: Declare the tag so the runner does not warn**

Create `dart_test.yaml` at the repo root:

```yaml
# Test tags. `golden` marks the machine-local visual baseline in
# test/golden/ — captured on one machine with the Ahem test font, so glyph
# metrics differ on other platforms. CI runs `--exclude-tags golden`; a bare
# `flutter test` still runs them locally.
tags:
  golden:
    description: Machine-local visual baselines; excluded from CI.
```

Without this file the runner emits an "unknown tag" warning for every tagged test.

- [ ] **Step 7: Verify goldens are excluded and the rest still runs**

Run: `flutter test --no-pub --exclude-tags golden`

Expected: **4 failures, all in `test/controllers/sleep_controller_test.dart`.** The 3 golden failures (`golden: move`, `golden: profile`, `golden: today`) must no longer appear — that is what this task bought. The 4 sleep failures are Task 2's job and must still be here.

Also confirm no "unknown tag" warning appears in the output.

- [ ] **Step 8: Verify goldens still run locally when not excluded**

Run: `flutter test --no-pub test/golden/design_system_golden_test.dart`

Expected: 3 failures (`golden: move`, `golden: profile`, `golden: today`), 2 passes (`golden: rituals`, `golden: new_entry`). Tagging must not have made them unrunnable locally — only excludable. **Do not** try to fix these.

- [ ] **Step 9: Commit**

```bash
git add test/controllers/insights_controller_test.dart test/screens/mood/mood_logger_sheet_test.dart test/golden/design_system_golden_test.dart dart_test.yaml
git commit -m "test(ci): clear analyzer infos and tag goldens for exclusion

Prerequisites for the CI gate: --fatal-infos needs a clean analyzer,
and --exclude-tags golden needs the machine-local visual baseline
tagged. Goldens stay runnable locally, just excludable."
```

---

## Task 2: Sleep clock seam

The 4 failures assert pure math but reach it through a provider that windows on `DateTime.now()`. Move the assertions to the pure function, and test the window where it actually lives.

**Files:**
- Modify: `lib/controllers/sleep_controller.dart:80` (rename, drop dead param), `:150` (call site)
- Modify: `test/controllers/sleep_controller_test.dart` (full rewrite)

**Interfaces:**
- Consumes: `SleepRepository.insert(SleepNight)` (assigns a uuid when `night.id` is empty), `SleepRepository.watchNightsInRange(DateTime from, DateTime to)` (`night >= from && night < to`, ascending), `startOfDay(DateTime)` from `lib/util/dates.dart`.
- Produces: `SleepState deriveSleepState(List<SleepNight> nights)` — public, pure, no clock parameter. Expects `nights` ascending by night. Nothing later in this plan consumes it.

- [ ] **Step 1: Confirm the 4 failures and their cause**

Run: `flutter test --no-pub test/controllers/sleep_controller_test.dart`

Expected: `+1 -4` — four failures, each expecting a real number and getting `0`, plus one pass (`empty state has no lastNight…`, which passes only because `0` is what it asserts).

The cause, for context: the tests seed `DateTime(2026, 6, …)`, and `build()` queries a 30-day window ending today. Those June dates are now outside it, so the repository returns nothing.

- [ ] **Step 2: Verify the `now` parameter really is dead before deleting it**

Run: `grep -n "now" lib/controllers/sleep_controller.dart`

Expected: `now` appears only inside `build()` (lines ~144-148, computing `windowStart` and `tomorrow`) and in `_deriveState`'s *signature* at line 80 — never in `_deriveState`'s body. Confirm the body between lines 80 and 135 contains no `now`.

Also confirm nothing else calls it:

Run: `grep -rn "_deriveState" lib test`

Expected: exactly two hits — the definition at `lib/controllers/sleep_controller.dart:80` and the call in `build()`. If there are more, stop and report.

- [ ] **Step 3: Rewrite the test file to target the pure function**

Replace the entire contents of `test/controllers/sleep_controller_test.dart` with:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/sleep_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/util/dates.dart';

/// Build a minimal [SleepNight] for testing with only the fields that vary.
SleepNight _night({
  required DateTime night,
  required int asleepMinutes,
  int wakes = 1,
}) =>
    SleepNight(
      id: '',
      night: night,
      asleepMinutes: asleepMinutes,
      inBedMinutes: asleepMinutes + 20,
      bedtime: '23:00',
      wake: '07:00',
      deepMinutes: 60,
      remMinutes: 90,
      coreMinutes: asleepMinutes - 150,
      awakeMinutes: 20,
      wakes: wakes,
      source: EntrySource.health,
    );

/// Nights ascending from [base], one per day. Ascending order is the
/// repository's guarantee and [deriveSleepState] relies on it.
List<SleepNight> _nights(DateTime base, List<int> asleepMinutes) => [
      for (var i = 0; i < asleepMinutes.length; i++)
        _night(
          night: base.add(Duration(days: i)),
          asleepMinutes: asleepMinutes[i],
        ),
    ];

void main() {
  // deriveSleepState is pure, so absolute dates are safe here: no window is
  // applied at this layer. The 30-day window belongs to build() and is tested
  // separately, with relative fixtures.
  group('deriveSleepState', () {
    test('usualMinutes is the median of the nights', () {
      final state = deriveSleepState(
        _nights(DateTime(2026, 6, 19), [360, 390, 420, 450, 480]),
      );

      expect(state.usualMinutes, 420,
          reason: 'median of [360,390,420,450,480] is 420');
      expect(state.syncedNights, 5);
      // lastNight is the most recent (ascending → .last)
      expect(state.lastNight?.asleepMinutes, 480);
      expect(state.week.length, 5,
          reason: 'fewer than 7 nights → all 5 returned');
    });

    test('usualMinutes averages the two middle values for an even count', () {
      final state = deriveSleepState(
        _nights(DateTime(2026, 6, 20), [400, 420, 440, 460]),
      );

      expect(state.usualMinutes, 430,
          reason: 'median of [400,420,440,460] is (420+440)/2 = 430');
    });

    test('syncedNights == 2 satisfies the needs-sync boundary (< 3)', () {
      final state = deriveSleepState(
        _nights(DateTime(2026, 6, 22), [420, 390]),
      );

      expect(state.syncedNights, 2);
      expect(state.syncedNights < 3, isTrue, reason: 'needs-sync threshold');
    });

    test('empty input has no lastNight, 0 usualMinutes, empty read', () {
      final state = deriveSleepState(const []);

      expect(state.lastNight, isNull);
      expect(state.usualMinutes, 0);
      expect(state.read, '');
      expect(state.syncedNights, 0);
      expect(state.week, isEmpty);
      expect(state.month, isEmpty);
    });

    test('week caps at the last 7 nights when more are supplied', () {
      final state = deriveSleepState(
        _nights(DateTime(2026, 6, 15),
            [400, 405, 410, 415, 420, 425, 430, 435]),
      );

      expect(state.week.length, 7);
      // last bar corresponds to the most recent night → isToday = true
      expect(state.week.last.isToday, isTrue);
      expect(state.week.first.minutes, 405,
          reason: 'the oldest of 8 nights is dropped from the strip');
    });
  });

  // The one behaviour that belongs to the provider rather than the pure
  // function. Fixtures are RELATIVE to now on purpose: absolute dates here
  // would rot the moment they fell outside the window — exactly what broke
  // every test in this file before.
  test('build() excludes nights older than the 30-day window', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [loopDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final repo = container.read(sleepRepositoryProvider);
    final today = startOfDay(DateTime.now());
    await repo.insert(_night(
      night: today.subtract(const Duration(days: 40)),
      asleepMinutes: 300,
    ));
    await repo.insert(_night(
      night: today.subtract(const Duration(days: 2)),
      asleepMinutes: 450,
    ));

    container.listen(sleepControllerProvider, (_, _) {});
    final state = await container.read(sleepControllerProvider.future);

    expect(state.syncedNights, 1,
        reason: 'the 40-day-old night is outside the 30-day window');
    expect(state.lastNight?.asleepMinutes, 450);
  });
}
```

Note what changed beyond the seam: the `_makeContainer` helper is gone (only one test needs a container now), and a `_nights` builder removes the repeated per-night `insert` calls.

- [ ] **Step 4: Run the tests to verify they fail for the right reason**

Run: `flutter test --no-pub test/controllers/sleep_controller_test.dart`

Expected: a **compile error**, not an assertion failure — something like `The function 'deriveSleepState' isn't defined`. That is the failing-test state: the tests now demand an API that does not exist yet.

- [ ] **Step 5: Make the function public and drop the dead parameter**

In `lib/controllers/sleep_controller.dart`, change the signature at line 80 from:

```dart
SleepState _deriveState(List<SleepNight> nights, DateTime now) {
```

to:

```dart
/// Derives the Sleep view model from [nights], ascending by night (the
/// repository's guarantee). Pure: the 30-day window is applied by the caller's
/// query, so this needs no clock — which is what keeps its tests from rotting.
SleepState deriveSleepState(List<SleepNight> nights) {
```

Leave the body byte-for-byte unchanged. `_median` and `_sleepRead` stay private.

- [ ] **Step 6: Update the call site**

In the same file, inside `build()` (~line 150), change:

```dart
      yield _deriveState(nights, now);
```

to:

```dart
      yield deriveSleepState(nights);
```

`final now = DateTime.now();` **stays** — `build()` still uses it for `windowStart` and `tomorrow`. Deleting it would break the window.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test --no-pub test/controllers/sleep_controller_test.dart`

Expected: **6 passing, 0 failing** — the 5 rewritten tests plus the new window test.

- [ ] **Step 8: Prove the new window test actually bites**

A test that passes for the wrong reason is worse than no test. Temporarily break the window in `lib/controllers/sleep_controller.dart` `build()`, changing:

```dart
    final windowStart = startOfDay(now).subtract(const Duration(days: 30));
```

to:

```dart
    final windowStart = startOfDay(now).subtract(const Duration(days: 3000));
```

Run: `flutter test --no-pub test/controllers/sleep_controller_test.dart`

Expected: the window test **FAILS** with `Expected: <1> Actual: <2>` — the 40-day-old night is now included. If it still passes, the test is not testing the window; stop and report.

**Then revert the `3000` back to `30`** and re-run to confirm 6 passing again. Do not commit the 3000.

- [ ] **Step 9: Verify the acceptance criterion for the whole suite**

Run: `flutter test --no-pub --exclude-tags golden`

Expected: **0 failures.** This is the plan's acceptance criterion. (A bare `flutter test` will still show the 3 drifted goldens — expected, out of scope.)

- [ ] **Step 10: Verify the analyzer is still clean**

Run: `flutter analyze --fatal-infos --no-pub`

Expected: `No issues found!` The rewrite removed the `_makeContainer` helper, so this also confirms no unused-element lint was introduced.

- [ ] **Step 11: Commit**

```bash
git add lib/controllers/sleep_controller.dart test/controllers/sleep_controller_test.dart
git commit -m "test(sleep): test derived state purely, window at the provider

Four tests seeded absolute June dates then read them back through a
provider that windows on DateTime.now(), so they rotted six weeks
later when the fixtures fell outside the window.

_deriveState never referenced its now argument, so the fix is a
rename and a deletion, not a new abstraction: deriveSleepState is
pure and its absolute dates cannot rot. The 30-day window gets one
test at the layer that owns it, with relative fixtures."
```

---

## Task 3: The CI workflow

With the suite green under `--exclude-tags golden` and the analyzer clean, the gate can land green.

**Files:**
- Create: `.github/workflows/app.yml`
- Modify: `.github/workflows/worker.yml:3-4` (stale comment)

**Interfaces:**
- Consumes: the `golden` tag from Task 1, the green suite from Task 2.
- Produces: nothing consumed by later tasks (final task).

- [ ] **Step 1: Dry-run every command the workflow will run**

Do not author the workflow blind. Run each locally, in workflow order, and confirm each exits 0:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
git diff --ignore-cr-at-eol --exit-code
flutter analyze --fatal-infos
flutter test --exclude-tags golden
```

Expected: all five exit 0. The third is the one to watch — `build_runner` will leave ~11 `.g.dart` files looking modified on Windows, and `--ignore-cr-at-eol` is what makes the gate see through that to an empty content diff.

If `git diff --ignore-cr-at-eol --exit-code` fails, there is genuine codegen drift. Inspect it with `git diff --ignore-cr-at-eol --stat`, commit the regenerated files as their own commit, and re-run.

- [ ] **Step 2: Create the workflow**

Create `.github/workflows/app.yml`:

```yaml
name: opal-app CI

# Flutter app gate. The Worker has its own workflow (worker.yml); the two are
# path-filtered so no single change fires both.
#
# Goldens are excluded: test/golden/ is a machine-local visual baseline
# captured with the Ahem test font, so glyph metrics differ on a Linux runner.
# See the header comment in test/golden/design_system_golden_test.dart.
#
# No deploy job: iOS builds are produced locally by scripts/build_ipa.sh and
# sideloaded via AltStore, so there is nothing here to deploy.

on:
  push:
    branches: [main]
    # Spelled out rather than shared via a YAML anchor: GitHub Actions does not
    # support anchors/aliases in workflow files. These two lists MUST stay
    # identical — edit both or neither.
    paths:
      - 'lib/**'
      - 'test/**'
      - 'pubspec.yaml'
      - 'pubspec.lock'
      - 'analysis_options.yaml'
      - 'dart_test.yaml'
      - '.github/workflows/app.yml'
  pull_request:
    paths:
      - 'lib/**'
      - 'test/**'
      - 'pubspec.yaml'
      - 'pubspec.lock'
      - 'analysis_options.yaml'
      - 'dart_test.yaml'
      - '.github/workflows/app.yml'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          # Pinned, not `stable`: an unpinned channel lets a Flutter release
          # turn CI red on a day nothing in this repo changed.
          flutter-version: 3.44.1
          channel: stable
          cache: true

      - run: flutter pub get

      # Codegen before analyze/test, so a stale .g.dart reports as stale
      # codegen rather than as a confusing downstream failure.
      - run: dart run build_runner build --delete-conflicting-outputs

      # --ignore-cr-at-eol: the repo is CRLF (core.autocrlf=true, no
      # .gitattributes) while build_runner writes LF, so a plain diff flags
      # every generated file on a Windows checkout.
      - name: Verify generated files are up to date
        run: git diff --ignore-cr-at-eol --exit-code

      - run: flutter analyze --fatal-infos

      - run: flutter test --exclude-tags golden
```

**Do not refactor the duplicated `paths` lists into a YAML anchor.** GitHub Actions does not support anchors/aliases in workflow files, and the failure mode is nasty: a local YAML parser (including PyYAML) resolves anchors fine, so it validates locally and then fails or silently misbehaves on GitHub. Seven duplicated lines is the cheap, correct trade.

- [ ] **Step 3: Validate the workflow parses and the two path lists match**

Run:

```bash
python -c "import yaml; d=yaml.safe_load(open('.github/workflows/app.yml')); p=d[True]['push']['paths']; q=d[True]['pull_request']['paths']; assert p==q, (p,q); assert 'lib/**' in p and len(p)==7, p; print('ok: 7 paths, push==pull_request'); print(sorted(d['jobs']['test'].keys()))"
```

Expected: `ok: 7 paths, push==pull_request` followed by the job keys. This catches the one mistake duplication invites — the two lists drifting apart.

(The `d[True]` is not a typo: YAML 1.1 parses the bare key `on` as the boolean `True`. GitHub's own parser treats it as the string `on`, so this quirk affects only this local check, not the workflow.)

- [ ] **Step 4: Fix the stale comment in `worker.yml`**

Phase 6 cutover shipped and `deploy.yml` no longer exists (commit `4f1f613` retired the droplet). Replace lines 3-4 of `.github/workflows/worker.yml`:

```yaml
# Cloudflare Worker deployment path (migration phase 5). Runs independently of
# deploy.yml so the DigitalOcean path stays available until phase 6 cutover.
```

with:

```yaml
# Cloudflare Worker deployment path — the sole backend since the phase 6
# cutover retired the DigitalOcean droplet. The Flutter app has its own
# workflow (app.yml); path filters keep one change from firing both.
```

Comment only — do not touch any step, trigger, or path filter in this file.

- [ ] **Step 5: Confirm the path filters cannot both fire**

Run: `grep -n "paths" -A 9 .github/workflows/app.yml .github/workflows/worker.yml`

Expected: `app.yml` matches `lib/**`, `test/**`, the three root config files, and its own workflow file. `worker.yml` matches only `server/worker/**` and its own file. Confirm no overlap — in particular that `app.yml` does **not** list `server/**`.

Note the deliberate gap: changes under `server/src/**` (the shared TS library) trigger neither workflow. That is pre-existing and out of scope; `server/src` has its own local test command per `server/README.md`.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/app.yml .github/workflows/worker.yml
git commit -m "ci(app): gate the flutter suite on push and PR

The Dart suite has never run in CI — only worker.yml existed, path-
filtered to server/worker/**. Four sleep tests rotted for six weeks
unnoticed as a direct result.

Pins flutter 3.44.1 so a release cannot turn CI red on its own,
runs codegen before analyze/test so stale .g.dart reports as itself,
and excludes the machine-local goldens. No deploy job: iOS artifacts
are built locally and sideloaded."
```

- [ ] **Step 7: Verify the gate on a real run**

CI can only be fully verified by executing on GitHub. Push the branch and open a PR (or push to `main` if that matches your workflow), then confirm the `opal-app CI / test` check runs and passes all five steps.

If it fails, the likeliest causes in order: (a) `git diff --ignore-cr-at-eol --exit-code` finding real codegen drift that was masked locally by line endings, (b) a test that depends on Windows-specific behavior, (c) `flutter-version: 3.44.1` not being available to the action. Report which rather than disabling the failing step.

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: Piece 1 → Task 3 (workflow, all six steps of the gate table, path filters, no-deploy, `worker.yml` comment); Piece 2 → Task 2 (rename, dead-param drop, five rewritten tests, one window test, the bites-check); Piece 3 → Task 1 (three lints, `@Tags`, `dart_test.yaml`). The spec's testing strategy is covered by Task 2 Steps 8-9 (prove-it-bites, acceptance criterion) and Task 3 Step 1 (dry-run before authoring). Every "out of scope" item in the spec appears in Global Constraints as a prohibition.

**Ordering.** Task 1 before Task 3 because `--fatal-infos` and `--exclude-tags golden` are both preconditions for a green first run. Task 2 before Task 3 for the same reason. Tasks 1 and 2 are mutually independent and could swap, but Task 1's Step 7 uses the 4 sleep failures as a signal that it changed only what it meant to, so this order gives a cleaner check.

**Type consistency.** `deriveSleepState(List<SleepNight>)` is named identically in Task 2's Interfaces block, its test code (6 call sites), the signature change in Step 5, and the call site in Step 6. `SleepState` field names used in tests (`usualMinutes`, `syncedNights`, `lastNight`, `read`, `week`, `month`, and `SleepBar.minutes` / `.isToday`) all match the class as defined in `lib/controllers/sleep_controller.dart`. The `golden` tag string is identical in `@Tags(['golden'])`, `dart_test.yaml`, and both `--exclude-tags golden` invocations.

**Placeholder scan.** No TBDs, no "add error handling", no "similar to Task N". Every code step carries the literal code. The one judgment call left to the implementer — Task 3 Step 2's YAML anchor versus duplicated path lists — is stated with its constraint rather than left open.

**Known gap, stated rather than hidden.** Task 3 Step 7 cannot be verified locally; the plan says so and names the three likeliest failure causes instead of asserting it will pass.
