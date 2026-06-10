# Loop — Orchestration Plan (ExpensePal → Flutter)

> **What this is:** an executable build checklist for agents. It translates the SwiftUI/SwiftData
> handoff at `Downloads/expensepal (1)/design_handoff_expensepal/README.md` into Flutter and
> sequences the work. The handoff remains the authoritative pixel/copy/data spec — this plan
> references it by screen number (e.g. *screen 09*) instead of re-stating layouts.
>
> **Reality constraints baked into every decision:**
> - Target = **iOS only**, but dev = **Windows**. Local run target = `flutter run -d chrome` only
>   (no Android/VS C++ toolchain). True iOS look confirmed later via TestFlight on a **borrowed Mac**.
> - SF Pro / SF Symbols don't render true on web. Symbols already substituted via
>   `lib/widgets/app_icon.dart`. Visual checks on Windows are approximate — **that is expected**.
> - Backend (AI `/chat`,`/review`,`/parse` + IMAP worker) = **mock now, build later**, behind interfaces.
> - Native iOS pieces (Live Activities / Dynamic Island, Siri Shortcuts / AppIntents) = **plan now,
>   build on Mac** — they cannot be built or verified on Windows.

---

## Build log & locked decisions (orchestrator)

> Living record maintained by the orchestrator as units complete. Full review rationale in `plan-review.md`.

**Status:** **U01 ✅ · U02 ✅** done.
- U01 — `lib/models/` (9 entities + `enums.dart` + barrel), caller-supplied `String` ids, enums persist via `.wire` tokens, computed `Workout.totalVolumeKg`/`prCount`.
- U02 — real `drift` + `drift_flutter`; `lib/data/{db,repositories,seed}/`; `sqlite3.wasm` 2.9.4 + `drift_worker.dart.js` (drift 2.31.0) vendored in `web/`; 32 tests green, analyze clean, web build OK. Repos take `LoopDatabase` (+ optional `Uuid`); `Seeder(db).seedIfNeeded()` at startup. Drift row classes are `*Row` (e.g. `EntryRow`) to avoid clashing with model names.

**U03 ✅ · U04 ✅ · U05 ✅** — Riverpod 3.x (codegen) + service interfaces/mocks + `SettingsRepository`; go_router `StatefulShellRoute` (Today/Move/Rituals/You + FAB); Today on live drift data. 35 tests, analyze clean, web build OK.

**Routes:** `today`/`move`/`rituals`/`you`; stubs `quickActions` `/quick-actions` (U06), `newEntry` `/entry/new` (U07), `askPal` `/pal` (U16), `spendingDetail` `/today/spending` (U09). Access via `AppRoute.<name>`.
**Key providers:** `entry/goals/ritual/routine/workoutRepositoryProvider`, `settingsRepositoryProvider`, `pal/health/email/notification/hapticsServiceProvider` (mocks), `appSettingsControllerProvider` (theme), `todayStateProvider`.

**Wave 1 integrated → `master` `ee21c46`** (47 tests green, analyze clean, web build OK):
✅ U06 Quick Actions · ✅ U07 New Entry + `Keypad` · ✅ U08 Rituals · ✅ U09 Spending (reusable `DetailScreen`, tracker-parametrized) · ✅ U11 Exercise Library + seed expansion · ✅ U17 Onboarding + redirect gate.
- Added routes: `quickActions`, `newEntry`, `rituals`→RitualsScreen, `manageRituals` (stub `/rituals/manage`), `spendingDetail`→`DetailScreen`, `exerciseLibrary` `/library`, `onboarding` `/onboarding`. Remaining stubs: `move`/`you` placeholders, `moveDetail`/`ritualsDetail`/`askPal`.
- Added providers: `ritualsControllerProvider`, `detailData(DetailTracker)`/`spendingDetail`, `exercises`.

**Wave 2 integrated → `master` `c68f13b`** (53 tests green, analyze clean):
✅ U16 Ask Pal chat + NL parse (wires U07 "Type it") · ✅ U18 Monthly Review · ✅ U19 You/profile + settings.
- Routes now real: `askPal`→`AskPalScreen`, `you`→`ProfileScreen`. Added: `monthlyReview` `/monthly-review`→`MonthlyReviewScreen`, `emailSync` `/email` (stub for U20, target for Profile→Integrations row).
- Added providers: `askPalControllerProvider`, `monthlyReviewControllerProvider`, `profileControllerProvider`.
- Only merge conflict was `router.dart` (all additive — kept both sides). Codegen regen was byte-identical to committed `.g.dart`. Wave-2 worktrees + branches removed.

**Waves 3 + 4 integrated → `master`** (73 tests green, analyze clean, web build OK). Built in-place (no worktrees — per user rule) by fan-out agents owning disjoint feature files; orchestrator did all shared-file wiring (`router.dart`, `providers.dart` codegen, `pubspec.yaml`) + central verification.
- **Wave 3:** ✅ U10 Move tab (`move`→`MoveScreen`; movement summary from `MockHealthService`, recent workouts, other-activity; sub-routes `startWorkout`/`workoutDetail`) · ✅ U13-engine (`workout_session.dart` — pure, Timer-free `WorkoutSession`: set logging, rest countdown, PR detection, `finish()`; 10 unit tests) · ✅ U20 Email Sync (`emailSync`→`EmailIntroScreen` + `emailSetup`/`emailDashboard`; all driven by `MockEmailSyncService`).
- **Wave 4:** ✅ U12 Start picker (`startWorkout`→`StartWorkoutScreen`; Pal's-pick via `suggestWorkout()`) · ✅ U13-UI (`workoutSessionControllerProvider(routineId)` Notifier wraps the engine with a real rest `Timer` + haptics at 10s/0s; `activeSession` focus route `/session/:routineId`) · ✅ U15 Workout detail (`workoutDetail` `/move/workout/:id`; 8-week `fl_chart` volume bars, per-exercise set tables, Pal note).
- Added: `fl_chart` dep; `RoutineRepository.getAll()`; `app_icon` `play.fill`/`star.fill`. New providers: `moveStateProvider`, `startWorkoutProvider`/`palPickControllerProvider`, `workoutSessionControllerProvider`, `workoutDetailProvider`/`workoutNoteProvider`, `emailSyncController`/`syncStatusProvider`/`emailDashboardControllerProvider`. `postWorkout` `/post-workout` stub added (U14 target).

**Wave 5 integrated → `master`** (82 tests green, analyze clean, web build OK; **uncommitted — awaiting approval**). Orchestrator built U14 directly (full context already loaded); U21b fanned out to 2 parallel agents owning disjoint feature files, orchestrator owned all shared wiring (`router.dart`, `start_workout_screen.dart`, `app_icon.dart`) + the single batched `build_runner` + central verification.
- **U14 Post-Workout Summary** (`postWorkout`→`PostWorkoutScreen`): finished `Workout` handed via route `extra` from `active_session_screen` (was discarded before). Celebration hero (Time/Volume/PRs), muscles-worked pills + proportional stacked bar, per-exercise **done-set** chips with PR highlight, Pal note. Save (SF-5) persists the `Workout` (completed sets only, blanked ids → fresh UUIDs so re-running a routine never collides) **+** a linked move `Entry` (`type: move`, `source: manual`, `workoutId`), then returns to Move; latches `SaveState.saved` to block double-write. New `post_workout_controller.dart`: pure `buildMuscleVolumes`, `moveEntryForWorkout`, `postWorkoutNoteProvider(Workout)`, `postWorkoutControllerProvider`. Added `square.and.arrow.up` to `app_icon`.
- **U21b Builders** (`[Windows-now]`, SF-6): ✅ **Routine Editor** (`routineEditor` `/move/routine-editor`, optional `?routineId` = create vs edit; name/tag/rest/toggles, exercise picker, target edits, drag-reorder; `RoutineRepository.update()`; reachable from Start-Workout 'New routine'). ✅ **Rituals Builder** (`manageRituals`→`RitualsBuilderScreen`; add/edit/delete + drag-reorder; icon grid + cadence + reminder; `RitualRepository.reorder()`). Both reorder via `ReorderableListView.onReorderItem`; their controllers read authoritative repo order (not the lagging stream snapshot) so rapid add-then-reorder can't race.

**U21 polish integrated → `master`** (83 tests green, analyze clean, web build OK; **uncommitted — awaiting approval**). Done solo (cross-cutting). Centralized through shared primitives rather than per-screen churn; per user decision, all haptics route through `HapticsService` (widgets are `ConsumerWidget`).
- **Interaction primitives:** new `PressScale` (`ConsumerStatefulWidget`: scale 0.97/80ms, 0.92 FAB, light haptic on press-down via service) wraps FAB, tab items, Quick-Action tiles, close button, `SummaryTile`, `NavIconButton`. `ListRow`→`StatefulWidget` with brief `fill` highlight (180ms) + `Semantics(button,label:title)`. `CheckButton` gains `Semantics(button,checked)`.
- **ActivityRings:** `StatefulWidget` entrance anim — 0→value 800ms ease-out, 60ms staggered per ring (single controller + per-ring `Interval`+`easeOut`); later value changes snap. Added `Semantics` label with per-ring %.
- **Empty/error (verbatim):** Today empty-state "Nothing logged yet. Tap + to start your day."; Today error stripped of raw `$e`; Ask Pal empty greeting → verbatim handoff copy ({name}→"there", no name field). Email sync error states already present; Pal-chat error deferred to U23 (mock can't fail, no handoff string) — YAGNI.
- **Semantic haptics at call-sites:** set-complete=light / PR=success in `workout_session_controller` (PR via `prCount` delta); sync-complete=success in `email_sync_controller`. Ritual-toggle light already wired.
- **A11y:** `semanticLabel` on every `NavIconButton` call-site (Notifications/Search/More/Streak/Add ritual).
- **Tests:** +1 (empty-Today copy); extended active-session test to assert light-on-complete. PR-success path shares the branch, not separately asserted.

**DONE:** U01–U21, U21b.  **REMAINING:** backend U22–U24, native U25–U27 — both blocked on infra unavailable here (deployed server / Mac). All Windows-buildable client work is complete.

**Dispatch lessons:** (1) agents must run `flutter test` directly (NOT wrapped in PowerShell `Out-String`/buffered capture). (2) **No-worktree parallelism:** agents must NOT touch shared files (`router.dart`/`providers.dart`/`pubspec.yaml`) or run `build_runner`/`flutter test` — the orchestrator owns those (concurrent codegen corrupts the shared `.dart_tool`). (3) Riverpod 3.x: use `AsyncValue.asData?.value`, not `.valueOrNull`. (4) Widget tests with a **local** router + an autoDispose drift stream provider leak drift's zero-duration `StreamQueryStore.markAsClosed` timer at teardown — end the test with `await tester.pumpWidget(const SizedBox()); await tester.pump(Duration.zero);` to flush it (bump to `pump(const Duration(seconds: 1))` if a mock-latency timer is also in flight; tests using `createRouter` with keepAlive providers don't hit this). (5) autoDispose Notifier/Stream controllers **dispose mid-`await`** in `ProviderContainer` tests (error: "disposed during loading state") — pin with `container.listen(provider, (_, _) {})` before the first await. (6) Use plain `test()`, not `testWidgets`, for container-only controller/repo tests: `testWidgets` runs the binding's no-pending-timer invariant which the drift cleanup timer trips even with no widget tree. (7) `ReorderableListView.onReorder` is deprecated → `onReorderItem` (identical signature, but `newIndex` is already post-removal-adjusted — drop any manual `if (newIndex > oldIndex) newIndex -= 1`). (8) `set_logs` + `routine_exercises` carry an FK to `exercises(id)` — seed the catalog (`Seeder(db).seedIfNeeded()`) in any test that inserts sets/slots, and don't assert absolute table counts against a seeded DB (use a baseline delta).

**Git:** baseline `4ee45cd` → foundation `18146dc` → wave-1 `ee21c46` → wave-2 `c68f13b` → waves 3+4 (this commit). Built directly on `master`; the stale `unit/u10-move-tab` worktree at `f096b29` is unused (worktrees abandoned per user rule).

**Locked decisions (from review, `plan-review.md` — no blockers found):**
- **U02 storage:** use **real `drift` + `drift_flutter`**, with `sqlite3.wasm` and **`drift_worker.dart.js`** (exact filename) vendored into `loop/web/`, version-matched to `pubspec.lock`. `flutter run -d chrome` serves wasm fine; OPFS degrades gracefully. In-memory / `sqflite_common_ffi` shim = documented fallback only, not default.
- **U03 state:** **`riverpod_generator` codegen** with `@riverpod`; pin **flutter_riverpod 3.x** and follow 3.x APIs (not 2.x). `build_runner` already required by drift, so no extra tooling cost.

**Should-fix items folded into later units:**
- **SF-3 (PalService seam):** define the typed service return DTOs up front — `ParsedEntryDraft` (parse), chat message, review-text, workout-suggestion, plus `SyncStatus`/`HealthSample` — when the interfaces are introduced. Pulled into **U03** so the U16↔U07 and sync seams don't force a later rewrite.
- **SF-4 (Health early):** `HealthService` interface + `MockHealthService` + `HealthSample` move **earlier into U03** (U05 Today needs move-minutes); U10 just consumes it.
- **SF-5 (Workout↔Entry linkage contract):** on workout save (**U14**) write the `Workout` *and* a linked move `Entry` with `workoutId` set + `source: manual`; U10 recent-list and U15 detail resolve via `workoutId`. Stated here so U13–U15 honor one contract.
- **SF-6 (Builders gap):** add **U21b — Builders & reorder** `[Windows-now]` (Routine Editor, Rituals Builder, drag-reorder for rituals + routine exercises), after U21; all the "Manage" / "New routine" stubs route here. *(Open: cut from v1 instead? Say so and I'll mark out-of-scope.)*
- SF-1 / SF-2 are captured inside the U02 / U03 decisions above.

**Stale note:** Section 0 "Current state" predates U01 — `lib/models/` now exists.

---

## 0. Current state (verified by reading `lib/`)

**Already built and working** (do NOT rebuild — reuse):

| Area | Files | Notes |
|---|---|---|
| Design tokens | `lib/theme/app_colors.dart` | `AppColors` ThemeExtension (light/dark) + `AppAccent` enum (8 accents, light+dark hexes). `context.colors`, `colors.forType('money'\|'move'\|'rituals')`. |
| Typography | `lib/theme/app_text.dart` | `AppFonts.sf / sfr / mono`, tabular figures. SF Rounded approximated (no bundled rounded face yet). |
| Icons | `lib/widgets/app_icon.dart` | `AppIcon('flame.fill')` → Cupertino/Material substitute map. |
| Components | `lib/widgets/` | `ActivityRings`, `LargeTitleNavBar` + `NavIconButton`, `InsetSection` + `ListRow`, `LoopTabBar` (+ raised FAB), `ProgressBar`, `CheckButton`, `Segmented<T>`, `RingStat`, `SummaryTile`. |
| Today screen | `lib/screens/today_screen.dart` | Screen 02, hardcoded from `mock_data.dart`. Rings + Pal-insight card + timeline buckets. **Stateless, no storage.** |
| Shell | `lib/screens/home_shell.dart` | String-keyed tab switch (`'today'` real, rest `_Placeholder`), Quick-Actions stub sheet, preview-only **Tweaks** gear (brightness + accent live in `_LoopAppState`). |
| Mock data | `lib/data/mock_data.dart` | Single display-only `Entry` (`type:String`, `value:Object?`). **Not** the rich handoff model. |

**Not yet present (this plan introduces it):** any state management, any persistence, real routing,
the rich domain model, services/interfaces, charts, notifications, haptics, and screens 01, 03–18.

**Gaps to fix early:** `home_shell` hardwires tabs as strings and rebuilds `_buildTheme` from
`setState`; brightness/accent are not persisted. The foundation units below replace this.

---

## 1. Stack decisions

| SwiftUI / handoff concept | Flutter approach | Package | Rationale (1 line) |
|---|---|---|---|
| `@Model` / SwiftData store | Repository over a local DB | **drift** (`drift`, `sqlite3_flutter_libs`) | Typed, reactive `Stream` queries (mirror `@Query`), runs on web via `drift/wasm` so Windows preview persists too; relational fits Workout↔SetLog↔Routine. |
| `@Query` reactive reads | Drift `.watch()` streams → Riverpod providers | — | DB change → stream → provider → screen rebuild, same feel as SwiftData. |
| State management (none chosen) | **Riverpod** | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` | Compile-safe DI; lets us swap mock↔real services and the DB by overriding providers in tests/main; ephemeral session state fits `Notifier`. |
| Navigation (`NavigationStack`, tabs, sheets) | **go_router** with a `StatefulShellRoute` for the 4 tabs + FAB | `go_router` | Declarative routes, per-tab nav stacks, typed deep links (needed later for Live Activity / Siri tap-through), modal sheets as routes. |
| Swift Charts (volume bars, breakdown bars) | **fl_chart** for bar/line; plain `Container`/`CustomPaint` for simple progress bars | `fl_chart` | Most-maintained Flutter chart lib; renders fine on web. Simple budget/category bars stay as existing `ProgressBar`. |
| `UserNotifications` (ritual reminders, budget alerts, sync-done) | `flutter_local_notifications` behind a `NotificationService` interface | `flutter_local_notifications`, `timezone` | Scheduling abstracted; **on web/Windows it is a no-op stub** — only verifiable on a real iOS device (TestFlight). |
| HealthKit (workouts, steps, active energy) | `HealthService` **interface** + `MockHealthService` now; `health` pkg impl deferred | `health` (Mac-later) | HealthKit has no web/Windows backing; abstract behind interface, feed mock samples on Windows. **Real data only verifiable on device.** |
| Haptics (`UIImpactFeedbackGenerator`) | `HapticsService` interface wrapping `HapticFeedback` | `flutter`'s `HapticFeedback` | No-op on web; light/medium/success map to `lightImpact`/`mediumImpact`/`heavyImpact`. **Feel only verifiable on device.** |
| LLM proxy (`/chat`,`/review`,`/parse`, workout pick, post-workout note) | `PalService` interface + `MockPalService` now; `HttpPalService` later | `http` (later) | Client codes against `PalService`; mock returns canned, on-brand strings + fake latency/typing. Real proxy is a separate `[backend-later]` unit. Keys never in app. |
| Email/IMAP worker | `EmailSyncService` interface + `MockEmailSyncService` now; real worker later | `http` (later) | Mock emits the staged `syncStatus` stream + fake imports so screens 16–18 build fully. Real IMAP worker + push = `[backend-later]`. |
| Secure credential ref (app password) | `flutter_secure_storage` behind `EmailSyncService` (Mac/device verify) | `flutter_secure_storage` | Keychain-backed on iOS; mock keeps it in memory on Windows. |
| `@AppStorage("accent")` + brightness | `shared_preferences` behind a `SettingsRepository` | `shared_preferences` | Persists accent/brightness/onboarding-complete across launches incl. web. |
| Live Activities / Dynamic Island | **Native — `[Mac-later]`** | `live_activities` (eval) or hand-written ActivityKit | ActivityKit only; cannot build/verify on Windows. Plan deep-link contract now. |
| Siri Shortcuts | **Native — `[Mac-later]`** | `flutter_siri_suggestions` / AppIntents | AppIntents only; in-app hint chip can be drawn on Windows, the intent donation can't. |

**Flag — only verifiable on a real iOS device (TestFlight / Mac):** true SF Pro + SF Rounded
rendering, SF Symbols, haptics feel, local-notification delivery, HealthKit data, secure-storage
keychain, Live Activities, Siri intents, real sheet/blur/nav physics.

---

## 2. Architecture & boundaries

Layering (top → bottom): **screens → controllers (Riverpod) → services/repositories (interfaces) →
data sources (drift DB, mock services, later HTTP/native)**. Screens never touch the DB or `http`
directly; they read providers. Every external dependency (DB, Pal, Email, Health, Notifications,
Haptics) sits behind an interface so the mock and the real impl are swappable via a Riverpod
provider override — mock in `main_dev.dart`/tests, real impl wired later with no screen changes.

State flow: drift `watch()` → repository → `Notifier`/`AsyncNotifier` provider → screen. Ephemeral
workout/chat/sync state lives in scoped `Notifier`s, not the DB (persisted only on save).

Target folder structure under `lib/` (extends what exists):

```
lib/
  main.dart                 # composes prod providers (real DB + mock services for now)
  app.dart                  # MaterialApp.router + theme wiring (moved out of main)
  router.dart               # go_router: StatefulShellRoute (4 tabs+FAB), sheets, deep links
  theme/                    # EXISTING: app_colors.dart, app_text.dart
  widgets/                  # EXISTING shared components (+ new shared bits e.g. Keypad, GradientHero)
  models/                   # rich domain: entry.dart, workout.dart, set_log.dart, routine.dart,
                            #   ritual.dart, goals.dart, email_account.dart, exercise.dart, enums.dart
  data/
    db/                     # drift database + DAOs (entries, workouts, routines, rituals, goals)
    repositories/           # EntryRepo, WorkoutRepo, RoutineRepo, RitualRepo, GoalsRepo, SettingsRepo
    seed/                   # seed/mock fixtures (migrate current mock_data.dart here)
  services/
    pal/                    # PalService (abstract) + mock_pal_service.dart  [+ http impl later]
    email/                  # EmailSyncService (abstract) + mock_email_sync_service.dart [+ real later]
    health/                 # HealthService (abstract) + mock_health_service.dart [+ health impl Mac-later]
    notifications/          # NotificationService (abstract) + noop/local impls
    haptics/                # HapticsService (abstract) + impl
  controllers/              # Riverpod providers/notifiers per feature (today, workout_session, chat,
                            #   rituals, spending, email_sync, onboarding, settings)
  screens/                  # one folder/file per screen group (today/ move/ rituals/ workout/ pal/
                            #   email/ profile/ onboarding/)
  native/                   # Mac-later: live_activities.dart, siri_intents.dart bridges (stubs on Windows)
```

Keep each unit small and single-purpose. A unit adds at most one screen or one service or one
foundation concern — never both.

---

## 3. Build order — work units

Tags: `[Windows-now]` build+verify on web preview · `[mock]` depends on a mocked service ·
`[Mac-later]` native, deferred to borrowed-Mac session · `[backend-later]` real server/IMAP, deferred.
All Windows-now client work is front-loaded; `[mock]` units cluster after services exist;
`[Mac-later]`/`[backend-later]` are pushed to the end.

### Phase A — Foundation (refactor under the existing Today screen)

**U01 — Rich domain models** `[Windows-now]`
Handoff ref: "Data model sketch", "State Management". Depends on: —
Scope: Create `lib/models/` Dart classes for Entry, Workout, SetLog, Routine, RoutineExercise,
Ritual, Goals, EmailAccount, Exercise, and the enums (EntryType, EntrySource, RoutineTag, Cadence,
Provider, SyncStatus). Pure immutable Dart (`copyWith`, equality) — no persistence yet. Replaces the
thin display-only `Entry` in `mock_data.dart`.
Verify by: `flutter test` — add a unit test constructing each model + a derived getter (e.g. Workout
`totalVolumeKg`).

**U02 — Drift DB + repositories + seed** `[Windows-now]`
Handoff ref: "State Management". Depends on: U01
Scope: Add `drift` + `sqlite3_flutter_libs` (+ `drift/wasm` for web). Define tables/DAOs for the
models; expose `EntryRepository`, `WorkoutRepository`, `RoutineRepository`, `RitualRepository`,
`GoalsRepository` with `watch*()` streams. Migrate `mock_data.dart` into `data/seed/` and seed the
DB on first run.
Verify by: `flutter test` — repo test inserts entries, `watchToday()` stream emits them; `flutter run
-d chrome` still launches (DB initializes on web).

**U03 — Riverpod wiring + SettingsRepository** `[Windows-now]`
Handoff ref: Accent options / `@AppStorage`. Depends on: U02
Scope: Add `flutter_riverpod`. Create providers for each repository and service interface (services
default to mocks). Add `SettingsRepository` over `shared_preferences` for accent + brightness +
onboardingComplete; move theme state out of `_LoopAppState` into a provider. Wrap app in
`ProviderScope`.
Verify by: `flutter run -d chrome`, change accent/brightness in Tweaks, hot-restart → selection
persists. `flutter test` for SettingsRepository.

**U04 — go_router shell + real tab navigation** `[Windows-now]`
Handoff ref: "Tab bar" component, screens 02/07/13/15. Depends on: U03
Scope: Replace `home_shell.dart` string switch with `MaterialApp.router` + `StatefulShellRoute`
(Today / Move / Rituals / You + center FAB). Keep `LoopTabBar` as the visual; wire branches.
Placeholder bodies for Move/Rituals/You until their units. Keep the preview-only Tweaks gear.
Verify by: `flutter run -d chrome`, tap each of the 4 tabs → distinct routes/placeholders; back
behavior per-tab; Today still renders.

**U05 — Today screen on live data** `[Windows-now]`
Handoff ref: screen 02. Depends on: U04
Scope: Rewire existing `today_screen.dart` to read from `EntryRepository`/`GoalsRepository` providers
instead of `const todayEntries`. Compute rings (money/move/rituals), summary tiles, and timeline
buckets from queried data. Reuse all existing widgets. Add the 3-up `SummaryTile` row (currently
absent) and wire tile→detail nav (routes stubbed).
Verify by: `flutter run -d chrome`, Today renders from DB; `flutter test` updated to pump with a
ProviderScope override seeding fixed entries and asserting rings/timeline.

> ### ✅ CHECKPOINT 1 — Foundation review (after U05)

### Phase B — Core daily-tracking loop

**U06 — Quick Actions overlay** `[Windows-now]`
Handoff ref: screen 03. Depends on: U04
Scope: Replace the stub FAB sheet with the 6-tile dim-overlay grid (Log expense, Log workout, Start
workout, Complete ritual, Ask Pal, Voice entry), scale-up-from-FAB animation, tap-outside/× to close.
Tiles route to the relevant screen/sheet (some stubbed until built).
Verify by: `flutter run -d chrome`, tap FAB → 6-tile overlay; tap outside closes; tiles navigate.

**U07 — New Entry sheet (manual)** `[Windows-now]`
Handoff ref: screen 04. Depends on: U05, U06
Scope: Modal sheet — `Segmented` (Expense/Workout/Ritual, reuse), big SF-Rounded display, custom 3×4
keypad widget (new shared `widgets/keypad.dart`), quick-pick tiles, optional category/note/time.
On Add → write Entry via repository (`source: manual`). "✨ Type it" button present but disabled (NL
parse arrives in U16).
Verify by: `flutter test` widget test — type `5`,`.`,`7`,`5` on keypad → display shows `$5.75`, tap
Add → repo received an Entry; new row appears on Today after pop.

**U08 — Rituals tab + toggle** `[Windows-now]` `[mock]`(haptics)
Handoff ref: screen 13. Depends on: U05
Scope: Rituals landing — today's 5 rituals (`InsetSection`+`ListRow`+`CheckButton`), streak subtitle,
"3/5 today" progress card (reuse `ProgressBar`), Manage button (stub). Toggle writes a ritual Entry +
fires `HapticsService.light` (no-op on web).
Verify by: `flutter run -d chrome`, Rituals tab, tap a check → fills, count increments, Today rings
update. `flutter test` for toggle→repo.

**U09 — Spending Detail (template)** `[Windows-now]`
Handoff ref: screen 06 (template reused for Move/Rituals detail). Depends on: U05
Scope: Detail template — hero total + budget bar, category breakdown rows (amount + bar from money
entries), recent transactions grouped by day, "Ask Pal about spending" pill (routes to U15, stubbed).
Build as a reusable `DetailScreen` parametrized by type so Move/Rituals detail reuse it.
Verify by: `flutter run -d chrome`, tap Today money tile → Spending detail renders category bars from
seeded money entries.

**U10 — Move tab** `[Windows-now]` `[mock]`(health)
Handoff ref: screen 07. Depends on: U05, U09
Scope: Move landing — today's-movement 3-col summary (minutes/energy/HR from `MockHealthService`),
"Start workout" CTA (→ U12), recent-workouts list (from `WorkoutRepository`, → U18 detail), other
activity section, "See all" footer.
Verify by: `flutter run -d chrome`, Move tab shows recent workouts from mock data + movement summary;
Start workout CTA navigates.

> ### ✅ CHECKPOINT 2 — Core daily loop review (after U10)

### Phase C — Workout engine (the hard part)

**U11 — Exercise Library + exercise/routine seed** `[Windows-now]`
Handoff ref: screen 11. Depends on: U02
Scope: Seed the exercise catalog + sample routines (from handoff `workout-data.jsx`) into the DB.
Build Library screen: search, filter chips (All/Push/Pull/Legs/Core/Cardio), muscle-grouped sections
with PR values.
Verify by: `flutter run -d chrome`, Library lists seeded exercises; typing filters; chips filter by
group.

**U12 — Start Workout (pre-session picker)** `[Windows-now]` `[mock]`(Pal pick)
Handoff ref: screen 08. Depends on: U10, U11
Scope: Routine picker — Pal's-pick gradient card (calls `PalService.suggestWorkout()` mock; "Another"
regenerates), Strength 2-col grid, Cardio rows, quick-actions (New routine/Library/Freestyle — stubs
ok). Selecting a routine → Active Session (U13).
Verify by: `flutter run -d chrome`, Start Workout shows routines + a mock Pal suggestion; picking one
opens Active Session.

**U13 — Active Session engine (HARDEST)** `[Windows-now]` `[mock]`(haptics)
Handoff ref: screen 09 + "Ephemeral (active session)" state + "Rest timer tick". Depends on: U12
Scope: The live workout. A `WorkoutSessionController` (Notifier) holds `activeWorkout`,
`currentExerciseIndex/SetIndex`, `restTimer`. Colored header band + elapsed timer, rest-timer banner
(+30s/Skip, haptic at 10s/0s — no-op web), current-exercise card, set table (done/active/upcoming
states), Add set, Up-next card, progress dots. Check active set → log kg/reps → advance → start rest
timer. PR detection compares `weight×reps` vs history. No tab bar (focus route). Finish → confirm
sheet → U14. **Keep timer/PR logic in the controller, fully unit-testable.**
Verify by: `flutter test` — controller tests: completing a set advances index + starts rest timer;
timer counts down to 0; a heavier-than-history set is flagged `isPR`; Finish builds a Workout with
correct `totalVolumeKg`/`prCount`. Plus `flutter run -d chrome` walk-through of one full session.

**U14 — Post-Workout Summary** `[Windows-now]` `[mock]`(Pal note)
Handoff ref: screen 10. Depends on: U13
Scope: Celebration hero (gradient, Time/Volume/PRs stats), muscles-worked pills + stacked bar, per-
exercise set chips with PR highlight, Share + "Save to timeline". Save persists the Workout +
a linked move Entry via repositories.
Verify by: `flutter run -d chrome`, finishing U13 → summary shows correct stats; Save → workout
appears in Move recent list + Today timeline. `flutter test` for save→repo.

**U15 — Workout Detail (past session)** `[Windows-now]` `[mock]`(Pal note)
Handoff ref: screen 12. Depends on: U14, U11
Scope: Past-session replay — 4-col summary tiles, **8-week volume bar chart (fl_chart)**, full per-
exercise set tables with PR badges, "Pal's note" card (`PalService` mock). Opened from Move recent
list + Today timeline strength rows.
Verify by: `flutter run -d chrome`, tap a recent workout → detail with volume chart + set tables +
mock Pal note.

> ### ✅ CHECKPOINT 3 — Workout engine review (after U15)

### Phase D — Pal (mock) + remaining screens

**U16 — Ask Pal chat (mock) + NL parse** `[Windows-now]` `[mock]`
Handoff ref: screen 05 + `/chat` + `/parse` prompts. Depends on: U05, U07
Scope: Chat screen — message bubbles (user/assistant), 3-dot typing indicator, input bar + send,
empty-state suggestion chips. Calls `PalService.chat()` mock (canned on-brand replies + fake latency).
Enable the "✨ Type it" field in U07 → `PalService.parse()` mock returns structured fields and pre-
fills the form.
Verify by: `flutter run -d chrome`, send a message → typing dots → mock reply; in New Entry, "Type it"
"coffee 5" pre-fills an expense.

**U17 — Onboarding (first-run gate)** `[Windows-now]`
Handoff ref: screen 01. Depends on: U03
Scope: 4-step flow (welcome / budget chips / move-goal chips / pick-5 rituals), progress dots, hero
glyph, CTA. On finish writes `Goals` + selected `Ritual`s + sets `onboardingComplete` in
`SettingsRepository`. `router.dart` redirect gates the app on this flag.
Verify by: `flutter run -d chrome` with prefs cleared → onboarding shows; complete it → lands on
Today; restart → skips onboarding. `flutter test` for the gate redirect.

**U18 — Monthly Review (mock)** `[Windows-now]` `[mock]`
Handoff ref: screen 14 + `/review` prompt. Depends on: U05
Scope: Month title + narrative card (`PalService.review()` mock, Regenerate pill), "By the numbers"
4 stat rows (from repos), "Patterns Pal found" 3 insight rows.
Verify by: `flutter run -d chrome`, Monthly Review renders stats + a mock narrative; Regenerate swaps
the text.

**U19 — You / profile + settings** `[Windows-now]`
Handoff ref: screen 15. Depends on: U04, U17
Scope: Avatar + "Member since", this-year 2×2 grid (from repos), settings `InsetSection` (Rituals →
U08, Budgets&goals, Notifications, HealthKit, **Integrations → Email sync**, Privacy, Export, About).
Integrations row routes to 16/17/18 based on `EmailAccount` presence.
Verify by: `flutter run -d chrome`, You tab shows year stats + settings list; Integrations row routes
to email Intro (no account).

**U20 — Email Sync screens (mock)** `[Windows-now]` `[mock]`
Handoff ref: screens 16/17/18. Depends on: U19
Scope: Intro (value prop + provider list), Setup (3-step instructions, credential form with 16-char
auto-format, Advanced collapsible, Test-connection states, Save gated on test), Dashboard (connection
chip, sync-job hero with staged status line + animated progress, Sync-now, schedule chip, recent
imports with NEW badge fade, Disconnect). All driven by `MockEmailSyncService` (emits the staged
`syncStatus` stream + fake imports). Credentials go through `flutter_secure_storage` (in-memory on web).
Verify by: `flutter run -d chrome`, Intro→Setup→Test(mock success)→Save→Dashboard; Sync-now cycles the
status line and inserts mock imports with NEW badge.

**U21 — Polish pass** `[Windows-now]`
Handoff ref: "Interactions & Behavior", "Copy / Microcopy", "Component specs". Depends on: U05–U20
Scope: Button press-scale, row-tap highlight, sheet/nav timings, empty states (verbatim copy),
error states, accessibility labels/semantics, ring entrance animation, haptic call-sites wired
(no-op web). No new screens.
Verify by: `flutter run -d chrome` sweep of all screens; `flutter analyze` clean; `flutter test` green.

> ### ✅ CHECKPOINT 4 — Pre-backend / pre-Mac review (after U21)

### Phase E — Backend (deferred, separately tagged)

**U22 — LLM proxy server** `[backend-later]`
Handoff ref: "LLM proxy", "AI Prompts". Depends on: U16, U18, U15 (consumers exist)
Scope: Standalone server (separate repo/folder, NOT in `lib/`) exposing `/chat`, `/review`, `/parse`
forwarding to Anthropic Messages API with the exact system prompts; key server-side only. Out of scope
for Windows-Flutter agents; build when backend work starts.
Verify by: `curl` each endpoint returns a well-formed response; not part of `flutter test`.

**U23 — Real PalService (HttpPalService)** `[backend-later]`
Handoff ref: same. Depends on: U22
Scope: `HttpPalService implements PalService` (the `http` impl); swap the Riverpod provider override
in `main.dart` from mock → http. **Zero screen changes** (interface unchanged).
Verify by: app talks to the deployed proxy; Ask Pal returns live responses on a real build.

**U24 — Email IMAP worker + push** `[backend-later]`
Handoff ref: "Email proxy". Depends on: U20, U22-infra
Scope: Server worker — stores IMAP creds, scheduled scan (15m), sender filter, receipt parse, dedupe,
push structured Entries back + sync-status reporting. Plus `RealEmailSyncService` swapped in via
provider override. Out of scope for Windows agents.
Verify by: a test inbox import produces deduped Entries on device with push on completion.

### Phase F — Native iOS (deferred to borrowed-Mac session)

**U25 — Live Activities / Dynamic Island** `[Mac-later]`
Handoff ref: "Dynamic Island Live Activities". Depends on: U13 (workout), U17 (streak), U16 (Pal)
Scope: ActivityKit Live Activity (workout timer ticks live, streak, Pal listening). Deep-link tap →
source screen via the go_router routes defined earlier. Define the deep-link/state contract during
U13/U04 so this just wires up. **Cannot build/verify on Windows.**
Verify by: on device — start a workout, Dynamic Island shows ticking timer; tap returns to screen 09.

**U26 — Siri Shortcuts / AppIntents** `[Mac-later]`
Handoff ref: "Siri Shortcut chip". Depends on: U07 (log expense), U12 (start workout)
Scope: `LogExpenseIntent` + `StartWorkoutIntent` via AppIntents; donate so Siri/Spotlight surface
them; the in-app glass hint chip (drawable on Windows) points at the same intents and runs+deep-links
on device. **Intent donation only verifiable on device.**
Verify by: on device — "Hey Siri, log expense" runs the intent and deep-links; chip tap does likewise.

**U27 — Native services real impls + device QA** `[Mac-later]`
Handoff ref: HealthKit / Notifications / Haptics / fonts. Depends on: all client units
Scope: Swap in real `HealthService` (`health` pkg), `NotificationService`
(`flutter_local_notifications`), confirm haptics; bundle/verify SF Pro Rounded face; full TestFlight
visual QA pass against the handoff. **This is where all "device-only" flags get confirmed.**
Verify by: TestFlight build — HealthKit import populates Move; ritual reminder fires; haptics felt;
typography/symbols match handoff.

> ### ✅ CHECKPOINT 5 — Mac handoff review (before U25–U27)

---

## 4. Checkpoints

| # | After unit | Look at |
|---|---|---|
| **1** | U05 | Foundation: drift persists across restart, Riverpod providers feed Today, go_router tabs switch, accent/brightness persist. Confirm architecture before building 15 screens on it. |
| **2** | U10 | Core daily loop: log an entry (U07) → Today updates; toggle a ritual → rings update; Move + Spending detail render from data. The everyday path works end-to-end on mock data. |
| **3** | U15 | Workout engine: full session walkthrough — set logging, rest timer, PR detection, save, post-summary, past-session detail w/ chart. The riskiest logic; review controller unit tests here. |
| **4** | U21 | All client screens done on Windows: review the whole app cold against the handoff before any backend/native work. Decide what (if anything) needs a quick TestFlight look. |
| **5** | before U25 | Mac handoff: confirm the deep-link/state contracts (U04/U13) and the list of device-only items so the limited Mac sessions are spent efficiently. |

---

## 5. Risks & open questions

**Riskiest units**
- **U13 — Active Session engine (hardest).** Rest timer (live tick + haptic at 10s/0s), set logging
  state machine, advance/up-next, and PR detection (max `weight×reps` per exercise vs history).
  Mitigation: put ALL of it in a `WorkoutSessionController` with pure, unit-tested logic; the widget
  is dumb. Haptic feel and the live Dynamic Island timer can't be verified until device (U25/U27).
- **U02 — drift on web.** `drift/wasm` setup (worker + sqlite3 wasm asset) is the fiddliest Windows-
  preview piece; if it fights us, fall back to an in-memory/`sqflite_common_ffi`-web shim for preview
  while keeping the real drift schema for device. Verify `flutter run -d chrome` boots early.
- **U20 — Email sync animation choreography.** Staged status cross-fades, progress tween, NEW-badge
  6s fade, "up to date" green flash — lots of timed UI. Drive entirely off the mock service's
  `syncStatus` stream so timing is centralized and the real worker later just emits the same stream.

**Cannot be verified on Windows (defer to TestFlight/Mac)**
- True SF Pro / SF Rounded + SF Symbols rendering; haptics feel; local-notification delivery;
  HealthKit data; secure-storage keychain; Live Activities / Dynamic Island; Siri intents; real iOS
  sheet/blur/nav physics. All routed through interfaces so the app runs (as no-ops/mocks) on web.

**Open questions for the orchestrator/user**
- **SF Pro Rounded face:** bundle a substitute rounded font for closer Windows preview, or accept
  the system-font approximation until device? (Affects every big numeral.)
- **drift-on-web vs preview shim:** acceptable to use a lighter persistence shim for the Chrome
  preview if `drift/wasm` is troublesome, as long as the device build uses real drift? (Decide at U02.)
- **Chat persistence:** handoff says messages reset per session, persist opt-in — ship reset-only for
  v1, or wire opt-in persistence now? (Affects U16 scope.)
- **LLM model:** handoff suggests `claude-haiku-4-5` for latency; confirm model id when U22 is built
  (verify against current Claude API at backend time).
- **Riverpod codegen:** use `riverpod_generator` (annotations) or hand-written providers? Recommend
  codegen for safety; flag the build_runner step if the team prefers to avoid generators.
```
