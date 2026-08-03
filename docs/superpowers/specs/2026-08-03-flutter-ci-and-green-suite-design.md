# Flutter CI Gate & Green Test Suite — Design

Date: 2026-08-03

The Flutter test suite is red — 670 pass, **7 fail** — and nothing was watching.
`.github/workflows/` holds only `worker.yml`, path-filtered to `server/worker/**`, so the
677-test Dart suite and `flutter analyze` have never run automatically on any Dart change.

The 7 failures are two unrelated groups:

| Count | Where | Nature |
|---|---|---|
| 4 | `test/controllers/sleep_controller_test.dart` | Wall-clock rot — the subject of Piece 2 |
| 3 | `test/golden/design_system_golden_test.dart` (`golden: move`, `golden: profile`, `golden: today`) | Pre-existing local visual drift — **out of scope**, see below |

The golden drift independently confirms Piece 3's decision: these are a machine-local visual
baseline, they are already stale on this machine, and they have no business gating CI.

The first group and the missing CI are one story. The failing test seeds `DateTime(2026, 6, 19)` with the comment
"well within a 30-day window"; the controller derives its window from `DateTime.now()`. Six
weeks passed, the fixtures fell out of the window, and every assertion now reads 0. A CI gate
would have caught it the week it broke.

Three pieces, in dependency order:

1. **Flutter CI workflow** — the gate that makes the rest stay true.
2. **Sleep clock seam** — fix the 4 rot failures at the layer that owns the behavior.
3. **Gate enablers** — three analyzer lints and golden-test tagging, both required by the gates.

Backend CI is untouched: `worker.yml` already tests, size-checks, deploys, and healthchecks the
Worker, and its 51 + 131 tests pass.

---

## Piece 1 — `.github/workflows/app.yml`

### Problem

No workflow covers Dart code. `worker.yml`'s path filter (`server/worker/**`) means a change to
`lib/` or `test/` triggers no CI at all. The red suite is the direct consequence.

### Design

A separate workflow mirroring `worker.yml`'s shape — own file, path-filtered, `push` +
`pull_request` on `main`. One `test` job, steps in this order:

| Step | Command | Why this order |
|---|---|---|
| Setup | `subosito/flutter-action@v2`, `flutter-version: 3.44.1`, pub cache | Pinned, not `stable` |
| Deps | `flutter pub get` | — |
| Codegen | `dart run build_runner build --delete-conflicting-outputs` | Before analyze/test |
| Codegen gate | `git diff --ignore-cr-at-eol --exit-code` | Stale `.g.dart` fails as itself |
| Analyze | `flutter analyze --fatal-infos` | — |
| Test | `flutter test --exclude-tags golden` | The gate that matters |

**Codegen runs before analyze and test deliberately.** A stale generated file should report as a
stale generated file, not as a downstream test failure with a confusing message.

**The Flutter version is pinned to 3.44.1**, matching local. Tracking `stable` unpinned means a
Flutter release can turn CI red on a day nothing changed. Upgrading becomes a deliberate
one-line commit.

**`--ignore-cr-at-eol` on the codegen gate is load-bearing, not incidental.** Verified locally:
`build_runner` leaves 11 `.g.dart` files showing as modified, and the content diff ignoring line
endings is **empty**. The repo has `core.autocrlf=true` and no `.gitattributes`, so the generator
writes LF into a CRLF working tree. A plain `git diff --exit-code` would pass on an ubuntu runner
but be permanently red locally, making the gate useless as a pre-push check and actively
misleading. The flag keeps the gate reproducible on both platforms while still catching genuine
codegen drift.

Rejected: adding `.gitattributes` with `* text=auto eol=lf` and renormalizing. It fixes the root
cause but costs a whole-repo mechanical commit that this slice otherwise never touches.

**Path filters:** `lib/**`, `test/**`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`,
`dart_test.yaml`, `.github/workflows/app.yml`. Deliberately **not** `server/**` — `worker.yml`
owns that, and the two workflows must never both fire on one change.

**No deploy job.** iOS artifacts are built locally by `scripts/build_ipa.sh` and sideloaded via
AltStore/SideStore; there is nothing for CI to deploy. An unsigned-ipa build job would be
speculative.

**Also in this piece:** `worker.yml`'s header comment still says it "runs independently of
deploy.yml so the DigitalOcean path stays available until phase 6 cutover." Phase 6 shipped and
`deploy.yml` is gone (commit `4f1f613`). Correct the comment; no behavior change.

---

## Piece 2 — Sleep clock seam

### Problem

Four of the file's five tests fail, all asserting 0 where they expect a real number:

```
usualMinutes is the median of seeded nights          expected 420, actual 0
usualMinutes uses average of two middle values       expected 430, actual 0
syncedNights == 2 satisfies the needs-sync boundary  expected 2,   actual 0
week contains at most 7 entries even with more seeded expected 7,  actual 0
```

The fifth — `empty state has no lastNight, 0 usualMinutes, empty read` — passes, but only because
0 and empty are exactly what it asserts. It is passing for the wrong reason: it would pass against
a repository that returned nothing under any circumstances.

The tests seed absolute June dates, then read state through
`container.read(sleepControllerProvider.future)`. `SleepController.build()`
(`lib/controllers/sleep_controller.dart:142`) computes a 30-day window from `DateTime.now()`
(`:144-147`) and queries `watchNightsInRange(windowStart, tomorrow)` (`:149`). As of August the
June fixtures are
outside that window, so the repository returns nothing and `deriveState` gets an empty list.

This is not a code regression. It is wall-clock rot: the test asserts pure math but reaches it
through a time-windowed query.

### Design

**The derive function needs no clock at all.** `_deriveState(List<SleepNight> nights, DateTime now)`
**never references `now`** — the trailing-14 median, the 7-night week strip, the 30-night
sparkline, `lastNight`, and `syncedNights` are all pure functions of the night list. The window is
applied by the repository query in `build()`, not here. The parameter is dead.

So the seam is a rename and a deletion, not a new abstraction:

- `_deriveState(nights, now)` → **`deriveSleepState(List<SleepNight> nights)`**. Public, same body,
  dead `now` param dropped. `build()` keeps calling it, minus the argument. No behavior change.
- **All five** tests in the file call `deriveSleepState([...])` directly with absolute dates — the
  four failing ones plus the empty-state test, which is rewritten too so it stops passing for the
  wrong reason. Every assertion they make is pure, so they stop depending on a window and stop
  rotting.
- **One new provider-level test**, with fixtures relative to `DateTime.now()`, for the behavior
  that genuinely belongs to `build()`: a night older than 30 days is excluded from the window.
  This is the assertion the old tests were making by accident; it belongs at the layer that owns
  the window.

Net: pure math tested purely, the window tested where it lives, neither coupled to the calendar.

This matches the codebase's own established convention rather than inventing one. `lib/analysis/`
(4 files) and 11 controllers already expose derive functions taking `DateTime now` /
`DateTime? now`, and 18 test files inject it. `sleep_controller.dart:58` even carries the comment
*"Private helpers (top-level so they're unit-testable without the provider)"* — the seam was
intended; the test bypassed it.

Rejected alternatives:

- **A `nowProvider` Riverpod seam.** Uniform injectable clock at the provider layer. Rejected: it
  introduces a new abstraction where a working convention exists, touches many controllers, and
  a live clock provider needs an invalidation policy nothing currently requires.
- **Relative fixtures only.** Rewrite the five tests to seed off `DateTime.now().subtract(…)` and
  keep going through the provider. Cheapest, and it does stop the rot, but it keeps pure
  assertions coupled to a moving reference and cannot pin window boundaries deterministically.

### Blast radius

One file. The earlier "40 test files use hardcoded 2026 dates" count was the population, not the
risk. Filtering it: 18 files already inject `now:` into pure functions; `move_controller_test.dart`
passes an explicit `now` local (just not as a named argument);
`pal_inbox_controller_test.dart`'s absolute dates are `createdAt` values for sort/filter with no
window; `weekly_plan_test.dart` uses relative dates. `sleep_controller_test.dart` is the only file
that seeds absolute dates *and* reads them back through a provider that windows on
`DateTime.now()`.

---

## Piece 3 — Gate enablers

### Three analyzer lints

`--fatal-infos` fails on the current output, so these go first:

| File | Lint |
|---|---|
| `test/controllers/insights_controller_test.dart:134,153` | `unnecessary_underscores` (×2) |
| `test/screens/mood/mood_logger_sheet_test.dart:11` | `unnecessary_import` |

`lib/` is already clean — all three are in tests.

### Golden-test tagging

`test/golden/design_system_golden_test.dart` states its own constraint: *"Local
visual-verification harness only (not wired into CI)"* (`:23`) and *"the baseline only needs to be
self-consistent on this machine"* (`:33`). Goldens render with the Ahem test font and the committed PNGs
were captured on Windows; an ubuntu runner would fail on glyph metrics. `test/golden/failures/`
is already gitignored.

- `@Tags(['golden'])` at the top of `design_system_golden_test.dart`.
- A new `dart_test.yaml` declaring the `golden` tag, so `--exclude-tags golden` works and the
  runner does not warn about an unknown tag.

Goldens stay runnable locally with a bare `flutter test`.

---

## Testing strategy

- **Acceptance criterion, stated against the CI command:** `flutter test --exclude-tags golden`
  goes from **4 failures to 0**. Not "the suite goes green" — a bare `flutter test` will still
  report the 3 drifted goldens, and that is expected, not a regression this slice introduces.
  The criterion is observable, not asserted.
- **The new window test must be proven to bite.** A test that passes for the wrong reason is worse
  than no test. Verify it fails when the window is removed — temporarily widen the range in
  `build()` and confirm red — rather than assuming.
- **Every CI command is dry-run locally first** so the workflow is not authored blind. CI itself
  can only be fully verified by its first run on a PR; that is inherent, not a gap to paper over.
- No new tests for Piece 1 or Piece 3 — a workflow file and three lint fixes are verified by
  running them.

## Out of scope

Named so they do not creep in:

- **The 259-file `dart format` reformat.** A dry run reformats 259 of 350 files. Excluded from CI
  and from this slice: it would bury every real change in mechanical churn.
- **Dependency upgrades.** Several majors behind (fl_chart 0.69→1.2, flutter_local_notifications
  18→22, flutter_secure_storage 9→10, go_router 16→17, riverpod_annotation 3→4, drift 2.31→2.34;
  `sqlite3_flutter_libs`' latest resolvable is tagged `0.6.0+eol`). Deliberately sequenced *after*
  this slice — without a green suite and a CI gate you cannot tell what an upgrade broke.
- **The note producer** (Life OS steps 2–3). The next slice, designed at
  `docs/superpowers/specs/2026-06-22-analysis-family-design.md`.
- **Triaging the remaining absolute-date test files.** They pass today and there is no evidence
  they are at risk. Population, for a future reader: `pal_action_executor_test`,
  `sleep_sync_controller_test`, `widget_sync_controller_test`, `nutrition_mapper_test`,
  `nutrition_repository_test`, `email_sync_test`, `mood_checkin_test`, `nutrition_meal_test`,
  `sleep_night_test`, `models_test`, `pal_note_repository_test`, `post_workout_test`,
  `repository_test`, `nutrition_widgets_test`, `sleep_screen_test`, `http_health_service_test`,
  `http_pal_service_test`, `dates_test`, `workout_detail_test`, `workout_history_test`,
  `workout_session_test`.
- **`.gitattributes` normalization.** Rejected in Piece 1 in favor of `--ignore-cr-at-eol`.
- **The 3 drifted goldens** (`golden: move`, `golden: profile`, `golden: today`). Re-baselining
  them is a visual review — someone has to look at the diffs in `test/golden/failures/` and decide
  whether each change is intended before running `--update-goldens`. That judgment is not part of
  this slice, and it must not be automated away: blindly re-baselining would silently accept
  whatever visual regression caused the drift. Tagging them out of CI (Piece 3) is not a
  workaround for the drift — the exclusion is correct on its own terms, per the file's own comment,
  and would stand even if all five passed.

## Pointers

- Failing tests: `test/controllers/sleep_controller_test.dart` (4, in scope) and
  `test/golden/design_system_golden_test.dart` (3, out of scope)
- Seam: `lib/controllers/sleep_controller.dart` (`_deriveState` at :80, `build()` at :142)
- Existing convention: `lib/analysis/{correlations,budget_forecast,spend_habits,spend_patterns}.dart`
- Workflow to mirror: `.github/workflows/worker.yml`
- Golden constraint: `test/golden/design_system_golden_test.dart:23`, `:33`
- Next slice: `docs/superpowers/specs/2026-06-22-analysis-family-design.md`
