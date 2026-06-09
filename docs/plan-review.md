# Loop — Plan Review (`docs/plan.md`)

> READ-ONLY review by the planning/review agent. Verifies the 27-unit orchestration plan against
> the design handoff and the realities of **Flutter 3.44.1 stable / iOS-target / Windows-dev /
> web-preview-only**. Package facts verified via context7 + web search (June 2026). Nothing under
> `lib/`, `test/`, `pubspec.yaml`, or `plan.md` was modified.

---

## TL;DR for the orchestrator

- **No hard blockers.** The plan is well-sequenced and the mock-behind-interface strategy is sound.
- **U02 decision:** Use `drift` + `drift_flutter` with real WASM on web (worker + sqlite3.wasm in `web/`); the in-memory shim is the *fallback only*, not the default. Details below.
- **U03 decision:** Use `riverpod_generator` codegen (it is the documented-primary path in Riverpod 3.x), with `build_runner watch` running during dev.
- **2 must-fix-before-U02/U03:** the two open questions above (Section 5) — resolved here.
- **Should-fix items: 6.** Listed and ranked below.

---

## Job A — Adversarial plan review (ranked)

### BLOCKER
None. The dependency graph is acyclic, checkpoints land at the right seams, and every handoff
screen has a home. The risky bets (drift-web, Riverpod codegen) are real but have clean, verified
resolutions (Job B) rather than being blockers.

### SHOULD-FIX

**SF-1 · U02 — `drift/wasm` asset versioning + worker filename is under-specified, and the plan's
parenthetical is slightly wrong.**
The plan says the web setup needs "worker + sqlite3.wasm asset". Two concrete corrections:
- The drift worker file is **`drift_worker.dart.js`** in current drift (the plan's open-question text
  says `drift_worker.js`). Using the wrong name = silent fallback to a slower/unreliable impl.
- Both `sqlite3.wasm` (from the `sqlite3.dart` releases) and `drift_worker.dart.js` (from `drift`
  releases) must be committed into `loop/web/` and **version-matched to `pubspec.lock`**. Drift makes
  these forward-compatible, but a mismatch surfaces only at runtime in Chrome, not at compile time.
- **Fix:** In U02 scope, explicitly: (a) add `drift_flutter` (wraps the platform selection so the same
  `driftDatabase(name:, web: DriftWebOptions(...))` call works on web + device), (b) vendor both asset
  files into `web/` with a README note pinning the versions, (c) make the U02 verify step assert the
  Chrome console does **not** print "missing browser features" / unreliable-impl warnings.

**SF-2 · U03 — Plan does not pin a Riverpod major version; Riverpod is now 3.x with API/codegen
changes.**
The plan lists `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` (correct packages) but
the live version is **flutter_riverpod 3.3.0 / riverpod 3.0.2**. Riverpod 3 unified the `Ref` type
(no more per-provider `FooRef`), and codegen syntax/`build.yaml` options differ from 2.x tutorials.
- **Fix:** Pin `flutter_riverpod: ^3.3.0`, `riverpod_annotation: ^3.x`, `riverpod_generator: ^3.x`,
  `riverpod_lint`, `build_runner`, `custom_lint` in U03. Tell the builder to follow the **3.x** docs
  (the `@riverpod` annotation + `extends _$Name` pattern), not 2.x blog posts, to avoid churn.

**SF-3 · U16 (parse) ↔ U07 seam: the `/parse` return shape leaks into the New Entry form, but no DTO
is defined.** The handoff pins `/parse` output to
`{type, amount:number|null, duration:number|null, category:string|null, title, note:string|null}`.
U07 builds the form first (parse disabled), U16 enables it. If `PalService.parse()` returns a loose
`Map` or a bespoke record, the form-prefill code written in U07 won't line up and U16 becomes a
rewrite.
- **Fix:** Define `PalService.parse()` to return a typed `ParsedEntryDraft` value object (the 6 fields
  above) as part of the `PalService` interface in U03's service-interface pass — **before** U07 wires
  the form. Same applies to `suggestWorkout()` returning `{routineId, reason}` (U12) and `review()`
  returning a narrative string (U18). Pin all `PalService` method signatures in one place up front so
  the mock and the later `HttpPalService` are drop-in.

**SF-4 · `MockHealthService` data shape is referenced by U10/U05 but never defined; "today's movement"
on Today (screen 02) needs it too.** U05 (Today) computes the move ring and a movement summary, and
the handoff's screen 02 timeline + screen 07 show minutes/energy/HR. The plan introduces
`MockHealthService` only at U10's tag, but U05 already needs move data for the ring.
- **Fix:** Clarify in U03/U05 that the move ring on Today is fed from **move-type `Entry` rows**
  (manual + seeded + later workout-derived), while `HealthService` supplies the *supplementary*
  steps/energy/HR summary shown on Move (U10) and optionally screen 02's tiles. State the
  `HealthSample` shape (minutes, activeEnergyKcal, avgHr) when the interface is declared so U05 and U10
  don't disagree.

**SF-5 · Entry↔Workout linkage (the `workoutId`/`source: health` round-trip) is implied but not
called out, and it spans U13→U14→U15→U10.** Saving a workout (U14) must write both a `Workout` and a
linked move `Entry` (`workoutId` set, `source` health/manual) so it appears on Today's timeline (U05)
*and* Move's recent list (U10) *and* opens screen 12 detail (U15). The models support it
(`Entry.workoutId`, `Workout.id`) but the plan never states the write contract, so three units could
implement three slightly different linkages.
- **Fix:** Add one sentence to U14 scope: "Save writes a `Workout` via `WorkoutRepository` AND a
  derived move `Entry{type:move, workoutId:<id>, source:health|manual, duration, calories}` via
  `EntryRepository`; Today timeline + Move recent list both read through this Entry, and a strength
  Entry's `workoutId` is what opens screen 12." Define this once; U10/U15 consume it.

**SF-6 · Routine Editor / "Manage rituals" / "New routine" are stubbed everywhere but never given a
unit.** The handoff names a **Routine Editor** (referenced from Library screen 11 and Start Workout
screen 08 "New routine"), and screen 13 has a **Rituals Builder** ("Manage rituals" button), plus
drag-reorder for rituals/routine exercises (Interactions table). The plan stubs all of these
("Manage button (stub)", "New routine ... stubs ok") and never schedules a unit to build them.
- **Fix:** This is a deliberate v1 scope cut — make it *explicit*. Either (a) add a small `[Windows-now]`
  unit "U21b — Routine Editor + Rituals Builder + drag-reorder" before the polish pass, or (b) add a
  one-line "Out of v1 scope: routine/ritual editing is create-via-seed only; editors deferred" note in
  Section 0 so the Checkpoint-4 reviewer doesn't flag it as missing. Right now it's silently absent.

### NICE-TO-HAVE

**NH-1 · Section 0 "Current state" is already stale.** It says models/state/persistence are "not yet
present", but `lib/models/` is fully built (Entry, Workout, SetLog, Routine, Ritual, Goals,
EmailAccount, Exercise, enums + barrel) — i.e. **U01 is done** (and done well: enums carry stable
`wire` tokens, volume/PR are computed getters, value equality is implemented). Expected, since a
builder runs concurrently. No action needed beyond being aware the plan's snapshot lags reality.

**NH-2 · `flutter_local_notifications` + `timezone` add Windows-build weight for a no-op.** On web the
service is a stub anyway. Consider not adding the real package to `pubspec.yaml` until the Mac session
(U27) — keep only the `NotificationService` interface + noop impl in the Windows phase so the web
build stays lean and the dependency can't break `flutter run -d chrome`.

**NH-3 · `health` package similarly should stay out of `pubspec.yaml` until U27** (Mac). The plan
already says "impl deferred"; just confirm the package line itself isn't added early, since it pulls
iOS/Android platform code that does nothing useful on web.

**NH-4 · Evening reflection card (screen 02) has no explicit unit.** It's an after-18:00 LLM card on
Today. It's a `PalService` consumer like U18. Fold it into U16 (Pal mock) or U05 scope with one line,
so it isn't lost.

**NH-5 · `fl_chart` is the right call and renders on web** (pure `CustomPaint`, no platform channels).
Only used in U15 (8-week volume bars). Fine as-is — flagged only to confirm the bet is safe on the web
preview.

**NH-6 · `go_router` `StatefulShellRoute` is correct and current.** Use the
`StatefulShellRoute.indexedStack` constructor (the 2026-standard variant; preserves per-tab nav state),
feed `navigationShell.currentIndex` / `navigationShell.goBranch()` into the existing `LoopTabBar`. The
center FAB is **not** a branch — keep it as an overlay action that pushes a modal route (matches the
existing `home_shell` `_showQuickActions`). Worth one clarifying line in U04 so the builder doesn't try
to make the FAB a 5th branch.

---

## Job B — Resolved open questions (Section 5)

### ★ BLOCKS U02 — drift-on-web

**Recommendation: Ship real `drift` on web from day one via `drift_flutter`. Do NOT default to the
shim.**

Verified (context7 + drift.simonbinder.eu, June 2026): `drift/wasm` works on Flutter web today. Setup
cost is small and well-trodden:
1. Add `drift`, `drift_flutter`, `sqlite3_flutter_libs`; dev: `drift_dev`, `build_runner`.
2. Drop **`sqlite3.wasm`** (from `sqlite3.dart` releases) and **`drift_worker.dart.js`** (from `drift`
   releases) into `loop/web/`, version-matched to `pubspec.lock` (drift keeps these
   forward-compatible, so exact-match isn't fatal but should be pinned).
3. Open the DB with `driftDatabase(name: 'loop_db', web: DriftWebOptions(sqlite3Wasm:
   Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.dart.js')))` — the same call works
   on device. Drift auto-selects OPFS when available and degrades gracefully otherwise.
4. `flutter run -d chrome` serves wasm with the correct `application/wasm` MIME by default. OPFS's
   COOP/COEP headers are a *production-hosting* concern, not a `flutter run` concern — fine for preview.

**Do X for U02:** Build U02 on real drift + `drift_flutter` with the two assets vendored in `web/`.
Keep `sqflite_common_ffi`/in-memory **only as a documented fallback** if a specific Chrome shows the
"missing browser features" warning; the device build is unaffected either way. The U02 verify step
must boot `flutter run -d chrome` and confirm no unreliable-impl warning in the console — front-load
this so a web-persistence problem surfaces at U02, not at Checkpoint 1.

### ★ BLOCKS U03 — Riverpod codegen vs hand-written

**Recommendation: Use `riverpod_generator` (codegen).**

In Riverpod **3.x** (live: flutter_riverpod 3.3.0), the `@riverpod` annotation is the documented-primary
authoring style and `riverpod_lint` rules assume it. Codegen removes the `provider`-vs-`Ref`-type
boilerplate, makes family/async providers far less error-prone, and is exactly the compile-safe DI the
plan's swap-mock↔real strategy wants. The only cost is one `dart run build_runner watch` running during
dev — acceptable for this project's size, and the same `build_runner` is needed for **drift** (U02)
anyway, so it's not a *new* tool.

**Do X for U03:** Adopt `@riverpod`-annotated providers/notifiers; pin Riverpod 3.x; run
`build_runner watch`; add `riverpod_lint` + `custom_lint`. Follow 3.x docs (unified `Ref`), not 2.x
tutorials. (If the team ever wants zero generators, hand-written `NotifierProvider` is viable — but
since drift already mandates `build_runner`, there is no overhead saving, so codegen wins.)

### LLM model id (blocks nothing now — U22, backend time)

**Recommendation: Do NOT hardcode `claude-haiku-4-5` from the handoff.** It is server-side only and
deferred to U22/U23. When U22 is built, verify the current model id against the live Claude API at that
time (the handoff value may be stale). The Flutter app never names a model — it calls `/chat` `/review`
`/parse` on the proxy. No app-side action.

### SF Pro Rounded face (affects U07, U21, every big numeral)

**Recommendation: Accept the system-font approximation for the Windows web preview; do not bundle a
substitute now.** True SF Rounded only renders on-device anyway (already flagged device-only), and a
bundled look-alike (e.g. a rounded Google font) risks *diverging* from the real iOS look and creating
false confidence during review. The existing `AppFonts.sfr` approximation is the right preview posture.
Confirm the real face on TestFlight in U27. (If a closer preview is genuinely wanted, bundle it as a
*preview-only* font flag, never as the shipping face — but default is: don't bother.)

### Chat persistence (affects U16 scope)

**Recommendation: Ship reset-per-session only for v1.** The handoff explicitly says messages reset per
session with persistence *opt-in*; opt-in persistence adds a chat table + settings toggle + history UI
for marginal v1 value. Keep `messages` in an ephemeral `Notifier` (matches the "Ephemeral" state spec).
Leave a one-line TODO seam so opt-in persistence can be added later without reworking the chat
controller. Keeps U16 tight.

---

## Notes on what's solid (not manufacturing issues)

- Layering (screens → controllers → repos/services → data sources) with every external dep behind a
  swappable Riverpod-overridable interface is the correct shape for mock-now/real-later and tests.
- Front-loading all `[Windows-now]` work and clustering `[mock]`/`[Mac-later]`/`[backend-later]` at the
  end is the right ordering for this constrained environment.
- U13 (Active Session) correctly isolates timer/PR/state-machine logic in a pure, unit-tested
  controller — the single most important risk-mitigation in the plan.
- Checkpoints land at genuine architectural seams (post-foundation, post-daily-loop, post-workout,
  pre-backend, pre-Mac). Good gates.
- The `wire`-token enums and computed `totalVolumeKg`/`prCount` already in `lib/models/` will make U02
  serialization and U13 PR logic cleaner than the plan assumes.
