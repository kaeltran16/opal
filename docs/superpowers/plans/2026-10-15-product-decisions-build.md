# Product Decisions 10-15 Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the four product decisions taken 10-15: timed sets for cardio and holds, proposals whose Approve does the real thing with a named Undo, an Autopilot made of a fixed list with saved switches, and a mood check-in that stays listed.

**Architecture:**
- Timed sets add nullable minutes/km columns (schema v11) and an `Exercise.timed` flag. Every aggregate reads a set through `SetLog` getters, so a timed set never counts as 0 kg.
- The agenda contract changes on both sides. The server keeps only three proposal kinds, each with a validated payload, and the model writes only Autopilot subtitles. The client performs approvals through the repositories and records an undo step for each.
- Autopilot switches are the existing `budgetAlerts` / `ritualReminders` settings, behind one controller.

**Tech Stack:** Flutter, Riverpod 3 codegen, drift, flutter_test scenario harness; TypeScript server (zod, vitest) and Cloudflare worker.

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Spec:** `docs/superpowers/specs/2026-10-15-product-decisions-build-design.md`
**Verify:** `sh -c 'c="${ARC_VERIFY_CHANGED:-}"; f=1; s=1; if [ -n "$c" ]; then grep -qE "^(lib|test|pubspec|assets)" "$c" || f=0; grep -q "^server/" "$c" || s=0; fi; if [ $f = 1 ]; then flutter test --exclude-tags "golden || scenario" || exit 1; fi; if [ $s = 1 ]; then (cd server && npx vitest run) && (cd server/worker && npx vitest run) || exit 1; fi'`
**Setup:** `flutter pub get && (cd server && npm ci) && (cd server/worker && npm ci)`
**Check:** `flutter analyze --fatal-infos && (cd server && npx tsc -p tsconfig.json --noEmit)`
**Final:** `flutter test --tags scenario test/scenario/timed_session_scenario_test.dart test/scenario/timed_routine_editor_scenario_test.dart test/scenario/timed_summary_scenario_test.dart test/scenario/proposal_actions_scenario_test.dart test/scenario/autopilot_scenario_test.dart test/scenario/mood_again_scenario_test.dart test/scenario/today_scenario_test.dart test/scenario/you_scenario_test.dart test/scenario/workout_scenario_test.dart test/scenario/defects_scenario_test.dart test/scenario/pal_money_settings_scenario_test.dart`

## Global Constraints

- Baseline on 83d283f: `flutter analyze --fatal-infos` is clean, server vitest passes 182 tests and worker vitest passes 57.
- **Tests first.** Each task writes its failing tests first, then makes them pass. Tests check behaviour, not internals.
- **Code style.** Comments are lower case and say only why. No magic numbers: name them as consts, as the surrounding files do. No new dependencies. No emojis.
- **Accessibility.** Every tappable control is at least 44px and has a semantics label.
- **Codegen.** Riverpod and drift: run `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart` files it changes. Only the task that lists a `.g.dart` file regenerates it.
- **Exact copy.** Save-failure copy is exactly `Couldn't save. Try again.`. App copy follows DESIGN.md: amounts are never bold, and labels use sentence case.
- **Goldens and the clean-up scenario.** Do not regenerate goldens. Do not edit `test/scenario/final_scenario_test.dart`.
- **Commits.** Subjects use the repo's `type(scope): summary` style, with no attribution or co-author trailer.
- **Fake-async stalls.** Widget tests that boot the full `LoopApp` under fake async can stall after a repository write. Wrap such writes in `tester.runAsync`, as the existing tests do.
- **Parallel run.** Run 8602490a edits `prompts.ts`, `today_screen.dart`, `day_plan.dart`, `pal_action_executor.dart` and the Pal service at the same time. Do not reformat or reorganise code you are not changing, so the lead's merge stays small.
- **Scenario files.** Each new scenario file follows `test/scenario/today_scenario_test.dart`: the `scenario` tag, the shared `scenario_harness.dart`, and PNGs written to `ARC_FINAL_OUT`. Each step captures light and dark.

## Review Focus

- **A user routine with a cardio slot made before this change** has `targetMinutes` null. Its session starts at 1 minute, never at "0 kg × 1". Pinned in Task 1.
- **A mixed session (bench plus plank).** It still leads with kg lifted, its plank rows read in minutes, and the plank is in no PR and no volume. Pinned in Tasks 1 and 6.
- **Approving add_ritual for a ritual routine deleted since the agenda was fetched.** The write fails, the proposal stays open, nothing is settled, and the snack bar shows. Pinned in Task 7.
- **Undo after an approve made on You, then switching to Today.** The header names the action, and Undo removes the added step. Pinned in Task 7.
- **Notifications' Budget alerts switched off, then Autopilot opened.** Spend nudge reads off, and the value holds after a relaunch, because the settings are re-read. Pinned in Task 8.

---

### Task 1: Timed sets data layer

**Depends on:** none
**Model:** claude-opus-5-5
**Files:** `lib/models/set_log.dart`, `lib/models/workout.dart`, `lib/models/routine.dart`, `lib/models/exercise.dart`, `lib/data/db/tables.dart`, `lib/data/db/database.dart`, `lib/data/db/database.g.dart`, `lib/data/db/mappers.dart`, `lib/data/repositories/workout_repository.dart`, `lib/data/repositories/routine_repository.dart`, `lib/data/seed/seed_data.dart`, `lib/data/seed/seeder.dart`, `lib/controllers/workout_session.dart`, `lib/controllers/workout_history_controller.dart`, `lib/controllers/move_controller.dart`, `lib/controllers/post_workout_controller.dart`, `lib/controllers/workout_detail_controller.dart`, `lib/controllers/pal_action_executor.dart`, `lib/services/pal/pal_context_builder.dart`, `test/timed_sets_test.dart`, `test/db_migration_test.dart`, `test/workout_session_test.dart`, `test/workout_history_test.dart`, `test/move_controller_test.dart`, `test/repository_test.dart`, `test/controllers/pal_action_executor_test.dart`, `test/services/pal/pal_context_builder_test.dart`

Spec section 1, the data half.

**Decisions this task carries**
- **Whole minutes.** `int? minutes` and `double? distanceKm` on `SetLog`; `weightKg` and `reps` stay required and hold 0 on a timed set.
- **The flag lives on the exercise.** `Exercise.timed` is true for `Cardio` and `plank`, both in the seed and in the migration backfill.
- **Default length.** `kDefaultTimedMinutes = 1` when a timed slot has no target.
- **Seed targets.** The seed routines get explicit targets on every timed slot.
- **History is not rewritten.** Existing logged sets keep their weight × reps.

**Interfaces (produces; Tasks 4, 5 and 6 rely on these exact names)**

`SetLog`:
- fields `int? minutes`, `double? distanceKm`, both in the constructor, `copyWith`, `==` and `hashCode`;
- `bool get isTimed => minutes != null`;
- `double get volumeKg`, which is 0 when `isTimed`.

`Workout`:
- `int get totalMinutes` and `double get totalKm`, both over done timed sets;
- `bool get isTimedSession`: true when there are done sets and every one is timed;
- `totalVolumeKg` and `prCount` ignore timed sets.

`RoutineExercise`:
- fields `int? targetMinutes`, `double? targetKm`.

`Exercise`:
- `bool timed`, defaulting to false.

`lib/models/routine.dart`:
- `const int kDefaultTimedMinutes = 1`, which Task 5 also uses.

`WorkoutSession` (`lib/controllers/workout_session.dart`):
- `void logCurrentTimedSet({required int minutes, double? distanceKm})` logs the current set as timed, never as a PR, then advances the cursor and starts the rest timer;
- `logCurrentSet` is unchanged for weighted sets;
- `addSet()` on a timed exercise copies minutes/km;
- the constructor seeds timed sets for slots whose exercise is `timed`: `minutes = targetMinutes ?? kDefaultTimedMinutes`, `distanceKm = targetKm`, `weightKg: 0`, `reps: 0`.

`post_workout_controller.dart`:
- `buildMuscleVolumes` counts weighted sets only;
- `buildPrHighlight` skips timed sets;
- `moveEntryForWorkout` gives a timed session the detail `'<m> min'` or `'<m> min · <km> km'` (km to one decimal, trailing `.0` dropped) and sets `Entry.distance` to `totalKm` when it is above 0.

`buildPostWorkoutContext` gains `'minutes': workout.totalMinutes` and `'km'`, which is null when there is no distance.

`routineFromDraft` / `_slotFrom`:
- `GeneratedSetDraft.durationMinutes` maps to `targetMinutes`.

**Schema v11**
- Add the columns `set_logs.minutes` INTEGER NULL, `set_logs.distance_km` REAL NULL, `routine_exercises.target_minutes` INTEGER NULL, `routine_exercises.target_km` REAL NULL, and `exercises.timed` BOOLEAN NOT NULL DEFAULT 0.
- Backfill with `UPDATE exercises SET timed = 1 WHERE "group" = 'Cardio' OR id = 'plank'`.
- Then `UPDATE exercises SET pr_weight_kg = NULL, pr_reps = NULL WHERE timed = 1`, and remove `plank` from `SeedData.demoExercisePrs`. A timed exercise has no stored PR, so nothing reads "0 kg × 90".
- If the catalog seed marker needs bumping so fresh installs get `timed`, do it without wiping the other demo PRs.

**Acceptance and focused tests (write them first)**
- `test/timed_sets_test.dart`:
  - a timed `SetLog` has `volumeKg == 0`;
  - `Workout.totalMinutes`, `totalKm` and `isTimedSession` hold for timed-only, mixed and empty sessions;
  - `buildMuscleVolumes` has no `Cardio` entry for a treadmill-only session;
  - `moveEntryForWorkout` gives a treadmill session `'20 min · 3.2 km'` with distance 3.2.
- `test/db_migration_test.dart`:
  - a v10 database upgraded to v11 has `timed` true for `treadmill` and `plank` and false for `bench`;
  - old set rows read with `minutes == null`;
  - a plank row holding `pr_weight_kg 0, pr_reps 90` reads with `pr == null` after the upgrade, while bench keeps its PR;
  - a freshly seeded demo database has no plank PR.
- `test/workout_session_test.dart`:
  - a routine with a treadmill slot whose `targetMinutes` is null seeds a timed set with 1 minute;
  - with `targetMinutes: 20, targetKm: 3`, it seeds 20 min and 3 km;
  - `logCurrentTimedSet` never sets `isPR`;
  - a bench then plank routine flags the bench PR and not the plank.
- `test/workout_history_test.dart`: personal records and best-set lookups skip timed sets, and the volume tiles and bars count weighted volume only.
- `test/repository_test.dart`: minutes, km, `targetMinutes`, `targetKm` and `timed` survive a save and load.
- `test/controllers/pal_action_executor_test.dart`: a draft plank set with `durationMinutes: 1` saves a slot with `targetMinutes == 1`.
- `test/services/pal/pal_context_builder_test.dart`: the post-workout context carries `minutes` and `km`.
- **Run:** `flutter test test/timed_sets_test.dart test/db_migration_test.dart test/workout_session_test.dart test/workout_history_test.dart test/repository_test.dart test/controllers/pal_action_executor_test.dart test/services/pal/pal_context_builder_test.dart test/move_controller_test.dart`

- [ ] Write the failing tests above and run them to see them fail
- [ ] Implement the models, schema v11, mappers, repositories, seed, session engine and aggregates
- [ ] Run build_runner, then the focused tests and `flutter analyze --fatal-infos`
- [ ] Commit `feat(workout): timed sets log minutes and km (data layer)`

### Task 2: Server agenda contract and timed post-workout note

**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `server/src/schemas.ts`, `server/src/pal.ts`, `server/src/prompts.ts`, `server/src/pal.test.ts`, `server/src/prompts.test.ts`, `server/worker/src/worker.ts`, `server/worker/test/pal-stateless.test.ts`

Spec sections 2 and 3 (server side) and the post-workout part of section 1.

**Decisions this task carries**
- **Three proposal kinds.** `agendaProposalKinds` becomes `['reschedule_workout', 'close_out', 'add_ritual']`. An off-list kind is dropped, no longer coerced; for example, parse `kind` as `z.string()` and filter.
- **Presentation from the kind.** The server derives `tag`, `colorToken`, `icon`, `approveIcon` and `action`:
  - close_out → Rituals/`rituals`, action `close_out`;
  - add_ritual → Rituals/`rituals`, action `add_ritual`;
  - reschedule_workout → Workout/`move`, action `reschedule_workout`.
- **Model output.** The model writes `title`, `body`, `approveLabel`, `doneLabel`, plus `ritual: {routineId, step}` for add_ritual and `slot: {weekday, routineId}` for reschedule_workout.
- **Request targets.** `agendaBody` gains `targets: {rituals: [{id, name, steps: string[]}], workouts: [{id, name}], week: [{weekday, routineId: string|null}]}`, defaulting to empty lists. `Pal.agenda(ctx, targets, memory)` takes it, and `worker.ts` passes `parsed.data.targets`.
- **One predicate.** `proposalValid(p, targets, currency)` combines:
  - `labelsAgree`;
  - add_ritual: `routineId` is in `targets.rituals`, `step` is trimmed and non-empty, and it is not already a step of that routine (case-insensitive);
  - reschedule_workout: an integer weekday from 1 to 7, `routineId` in `targets.workouts`, and different from that weekday's slot in `targets.week`;
  - close_out: always valid.

  If any proposal is invalid, the agenda is drawn once more; anything still invalid is dropped.
- **Response.** Each proposal adds `ritual` and `slot` (null when absent). Autopilot becomes `[{id, subtitle}]`: model output `[{kind: 'spend_nudge'|'routine_reminders', subtitle}]`, off-list kinds and repeats dropped, `id` equal to the kind.
- **Prompt.**
  - It lists the ritual routines (id, name, steps), the workout routines (id, name) and the week plan by weekday.
  - It describes only the three proposal kinds, with no money-holding wording.
  - For Autopilot it asks for one subtitle per automation, saying what it is watching today and never whether it is on or off. The automations are spend_nudge (alerts when today's spending passes the daily budget) and routine_reminders (a daily reminder to do the routines).
  - Keep the existing amount rule and `PLAIN_TEXT`.
- **Post-workout body.** It gains optional `minutes` and `km` (number, nullable). When `volumeKg` is 0 and `minutes > 0`, the prompt talks about time and distance, never weight.

**Acceptance and focused tests (write them first)**
- `pal.test.ts`:
  - a model reply holding hold_funds and generic proposals returns neither;
  - an add_ritual with an unknown routine id, a blank step or a step already present is dropped after one redraw;
  - a reschedule_workout to a routine already in that weekday's slot is dropped;
  - a valid add_ritual comes back with `action: 'add_ritual'`, `tag: 'Rituals'`, `colorToken: 'rituals'` and its `ritual` payload;
  - autopilot drops an off-list kind and a repeat, and returns `{id: 'spend_nudge', subtitle}`.
- `prompts.test.ts`:
  - the agenda prompt names the targets' ritual and workout ids and has no `hold_funds` or `generic`;
  - the post-workout prompt for `{volumeKg: 0, minutes: 20, km: 3.2}` mentions minutes and not kg.
- `pal-stateless.test.ts`: `/v1/agenda` with and without `targets` returns 200.
- **Run:** `cd server && npx vitest run src/pal.test.ts src/prompts.test.ts` and `cd server/worker && npx vitest run test/pal-stateless.test.ts`

- [ ] Write the failing tests and see them fail
- [ ] Implement the schema, predicate, presentation, prompt and worker pass-through
- [ ] Run the focused tests and `npx tsc -p tsconfig.json --noEmit`
- [ ] Commit `feat(pal): agenda proposes only actionable kinds with validated payloads`

### Task 3: Client agenda contract (proposals and targets)

**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `lib/services/pal/pal_service.dart`, `lib/services/pal/http_pal_service.dart`, `lib/services/pal/mock_pal_service.dart`, `lib/controllers/providers.dart`, `test/services/pal/http_pal_service_test.dart`, `test/services/http_pal_service_test.dart`, `test/services/mock_pal_service_test.dart`, `test/pal_home_test.dart`, `test/scenario/defects_scenario_test.dart`, `test/scenario/pal_money_settings_scenario_test.dart`, `test/scenario/you_scenario_test.dart`

Spec section 2 (client data). The Autopilot types are not changed here; Task 8 owns them.

**Interfaces (produces; Tasks 7 and 8 rely on these)**

`PalProposal`:
- gains `({String routineId, String step})? ritual` and `({int weekday, String routineId})? slot`, included in `==` and `hashCode`;
- gains `const String rescheduleWorkoutAction = 'reschedule_workout'` beside `closeOutAction` and `addRitualAction`;
- gains `bool get reschedulesWorkout`.

`PalContextSource`:
- gains an optional `Future<Map<String, Object?>> Function() agendaTargets`. Its default returns `{'rituals': [], 'workouts': [], 'week': []}`, so the existing tests' fixed sources still compile.
- `HttpPalService.agenda` posts `{'context': ..., 'targets': await context.agendaTargets()}`.
- `providers.dart` builds the real targets from the ritual, routine and weekly-plan repositories:
  - `rituals: [{id, name, steps: [title]}]`;
  - `workouts: [{id, name}]`;
  - `week: [{weekday 1..7, routineId|null}]`.

Decoder:
- keeps a proposal only when `action` is one of the three;
- an add_ritual needs `ritual`, and a reschedule_workout needs `slot`.

`MockPalService.agenda` proposals use only the three kinds, with payloads on seed ids:
- reschedule seed-routine-legs to Friday (weekday 5);
- close_out;
- add_ritual on `evening` with step `Two-minute wind-down`.

The money "Set aside" proposal is removed. Mock Autopilot stays as it is (Task 8).

**Acceptance and focused tests (write them first)**
- `test/services/pal/http_pal_service_test.dart`:
  - the agenda request body carries `targets`;
  - a response with a `hold_funds`/null-action proposal decodes to no proposal;
  - an add_ritual without `ritual` is dropped;
  - a valid reschedule decodes its `slot`.
- `test/services/mock_pal_service_test.dart`: every mock proposal has a known action and a complete payload.
- Update `pal_home_test.dart` and the three scenario files wherever they assumed the mock's money hold proposal: use a mock proposal that still exists. Scenario files that build their own `PalProposal` keep their own data.
- **Run:** `flutter test test/services/pal/http_pal_service_test.dart test/services/http_pal_service_test.dart test/services/mock_pal_service_test.dart test/pal_home_test.dart`

- [ ] Write the failing tests and see them fail
- [ ] Implement the fields, targets seam, decoder filter and mock agenda
- [ ] Run the focused tests and `flutter analyze --fatal-infos`
- [ ] Commit `feat(pal): proposals carry their action payload; agenda sends targets`

### Task 4: Session logs timed sets

**Depends on:** Task 1
**Model:** claude-sonnet-5-5
**Files:** `lib/screens/workout/active_session_screen.dart`, `lib/controllers/workout_session_controller.dart`, `lib/controllers/workout_session_controller.g.dart`, `test/active_session_test.dart`, `test/scenario/timed_session_scenario_test.dart`

Spec section 1, session UI.

**Interface**
- The `WorkoutSessionController` notifier gains `void logCurrentTimedSet({required int minutes, double? distanceKm})`, which wraps the engine method.

**Decisions**
- A timed current set's enter card shows a `Minutes` stepper and a `Distance` stepper in place of Weight and Reps:
  - Minutes: step 1, minimum 1, unit `min`, semantics labels `Fewer minutes` / `More minutes`;
  - Distance: step 0.1, minimum 0, unit `km`, reads `No distance` at 0, which is passed to the engine as null.
- No `Best …` line and no `Ahead of your best` line on a timed set.
- Set rows and the up-next line read `20 min` or `20 min · 3.2 km`.

**Acceptance and focused tests (write them first)**
- `test/active_session_test.dart`:
  - a Treadmill Intervals session shows Minutes/Distance and no `kg`;
  - stepping to 21 min and 3.2 km and completing the set logs `minutes: 21, distanceKm: 3.2`;
  - a bench set still shows kg and reps.
- `test/scenario/timed_session_scenario_test.dart`, step "timed set entry", light and dark. It opens a Treadmill Intervals session and captures the Minutes/Distance enter card. It then taps More minutes and More distance to reach 20 min and 3.2 km, taps complete, and captures the logged row `20 min · 3.2 km`.
- **Run:** `flutter test test/active_session_test.dart`

- [ ] Failing tests, implement, build_runner, focused tests, analyze
- [ ] Commit `feat(workout): session logs minutes and km for timed sets`

### Task 5: Routine editor edits timed targets

**Depends on:** Task 1
**Model:** claude-sonnet-5-5
**Files:** `lib/screens/workout/routine_editor_screen.dart`, `lib/controllers/routine_editor_controller.dart`, `lib/controllers/routine_editor_controller.g.dart`, `test/routine_editor_test.dart`, `test/scenario/timed_routine_editor_scenario_test.dart`

Spec section 1, routine editor.

**Interface**
- `RoutineEditorController` gains `updateTimedTargets(String slotId, {required int sets, required int minutes, double? km})`.

**Decisions**
- A slot whose exercise is `timed` reads `1 × 20 min` or `1 × 20 min · 3 km`, never `× —`.
- Its targets sheet shows Sets, Minutes (step 1, minimum 1) and Distance (step 0.1, minimum 0, `No distance` at 0) in place of Reps and kg.
- A newly added timed exercise starts at 1 set × `kDefaultTimedMinutes`.

**Acceptance and focused tests (write them first)**
- `test/routine_editor_test.dart`:
  - adding Plank shows `1 × 1 min`;
  - the sheet saves 20 min and 3 km to `targetMinutes`/`targetKm`, and the row reads `1 × 20 min · 3 km`;
  - a bench slot is unchanged.
- `test/scenario/timed_routine_editor_scenario_test.dart`, step "timed slot targets", light and dark. It adds Plank in the editor and captures the row `1 × 1 min`. It then opens the targets sheet and captures it, steps to 20 min and 3 km, saves, and captures the row `1 × 20 min · 3 km`.
- **Run:** `flutter test test/routine_editor_test.dart`

- [ ] Failing tests, implement, build_runner, focused tests, analyze
- [ ] Commit `feat(workout): routine editor sets minutes and km for timed slots`

### Task 6: Summary, detail and history lead with time for a timed session

**Depends on:** Task 1, Task 4, Task 5
**Model:** claude-sonnet-5-5
**Chunk:** Build: cardio and timed-hold sets log minutes (optional km) in the session, routine editor and summary
**Files:** `lib/screens/workout/post_workout_screen.dart`, `lib/screens/workout/workout_detail_screen.dart`, `lib/screens/move/workout_history_screen.dart`, `lib/screens/move/move_screen.dart`, `test/post_workout_test.dart`, `test/workout_detail_test.dart`, `test/workout_history_screen_test.dart`, `test/move_screen_test.dart`, `test/scenario/timed_summary_scenario_test.dart`

Spec section 1, summary and detail.

**Decisions**
- When `workout.isTimedSession`:
  - the hero number is `totalMinutes` with the unit `min`, and `· <km> km` beside it when `totalKm > 0`, in place of `<kg>` `kg lifted`;
  - "Muscles worked" is left out whenever `buildMuscleVolumes` is empty.
- A mixed session keeps kg lifted, and its timed rows read in minutes.
- Workout detail follows the same rules.
- History rows for a timed session show minutes (and km); the Move screen's recent rows do the same.
- No `0 kg` and no `0%` appear anywhere for a timed session.

**Acceptance and focused tests (write them first)**
- `test/post_workout_test.dart`:
  - a treadmill-only workout (20 min, 3.2 km) shows `20` `min` and `3.2 km`, and neither `kg lifted` nor `Muscles worked`;
  - a bench plus plank workout shows kg lifted and a plank row in minutes.
- `test/workout_detail_test.dart`: the same two cases.
- `test/workout_history_screen_test.dart`: a treadmill row reads minutes, not tonnes.
- `test/scenario/timed_summary_scenario_test.dart`, light and dark:
  - steps "timed summary" and "timed workout detail";
  - step "timed history and move rows", which captures the History and trends row and the Move screen's recent row for the treadmill session, each reading minutes and km, not tonnes.
- **Run:** `flutter test test/post_workout_test.dart test/workout_detail_test.dart test/workout_history_screen_test.dart test/move_screen_test.dart`

- [ ] Failing tests, implement, focused tests, analyze
- [ ] Commit `feat(workout): timed sessions lead with time on summary, detail and history`

### Task 7: Approve performs the action; Undo names and reverses it

**Depends on:** Task 2, Task 3
**Model:** claude-opus-5-5
**Chunk:** Build: Approve performs close_out, add_ritual and reschedule_workout; agenda drops hold_funds and generic; Undo names its action
**Files:** `lib/screens/today/day_plan.dart`, `lib/screens/today/today_screen.dart`, `lib/controllers/plan_session_controller.dart`, `lib/controllers/plan_session_controller.g.dart`, `lib/screens/profile/profile_screen.dart`, `test/screens/day_plan_test.dart`, `test/today_screen_test.dart`, `test/controllers/plan_session_controller_test.dart`, `test/profile_test.dart`, `test/scenario/today_scenario_test.dart`, `test/scenario/proposal_actions_scenario_test.dart`

Spec section 2, the client behaviour.

**On You (`profile_screen.dart`):**
- Pal suggests' Approve keeps calling `actOnPlanItem(context, ref, item)`; keep that signature.
- Its "Not now" (now `plan.settle(item.id, done: false)` near line 570) changes to `plan.skip(item)`, so the skip records its Undo label.
- Change nothing else on You; Task 8 edits this file after this task.

**Interfaces**

`PlanItem`:
- gains `final PalProposal? proposal`, which `proposalItem` sets.

`day_plan.dart`, change records:
- `sealed class PlanChange`, with `AddedRitualStep(String routineId, String stepId)` and `SetPlanSlot(int weekday, String? priorRoutineId)`;
- `class PlanStep {String id; String label; PlanChange? change}`.

`PlanSession` (stays pure):
- `history` is `List<PlanStep>`;
- `settle(id, {done, label, change})`;
- `PlanStep? get lastStep`;
- `String? get undoLabel`, which returns `<what>` from the spec's copy table.

`PlanSessionController`:
- `Future<void> approve(PlanItem item)`: add_ritual appends the step through `RitualRepository`; reschedule reads the prior slot, then calls `WeeklyPlanRepository.upsert`. It settles only after the write and throws on failure.
- `void skip(PlanItem item)`.
- `Future<void> undo()`: reverses `change` through the repositories, then pops. On failure it throws and keeps the step.
- Approving a proposal with an unknown action throws `StateError`.

`actOnPlanItem`:
- awaits `approve` for `PlanKind.proposal`;
- shows a snack bar `Couldn't save. Try again.` on failure;
- close_out stays `PlanKind.closeOut`, which opens the close-out.

Today header:
- the button reads `Undo · <what>`, with semantics label `Undo <what>`;
- it ellipsises within half the row and is at least 44px tall;
- tapping it awaits `undo()`, and shows the snack bar on failure.

**Acceptance and focused tests (write them first)**
- `test/controllers/plan_session_controller_test.dart` (drift in memory):
  - approving add_ritual for `evening` adds `Two-minute wind-down`, and undo removes it;
  - approving reschedule sets Friday to seed-routine-legs, and undo restores the prior routine id, a null rest day included;
  - approving add_ritual for a missing routine throws, settles nothing and changes nothing;
  - `undoLabel` reads `Two-minute wind-down added`, `Leg Day on Friday` and `Mood check-in skipped`.
- `test/screens/day_plan_test.dart`: `proposalItem` carries the proposal, and close_out still maps to `PlanKind.closeOut`.
- `test/today_screen_test.dart`:
  - after Not today on a row, the header reads `Undo · <title> skipped`, with semantics label `Undo <title> skipped`;
  - tapping it brings the row back;
  - after approving add_ritual on the card, the header names it;
  - the Undo control is at least 44px tall;
  - at 390 wide with text scale 1.3 and a 60-character title, the label ellipsises within half the header row, with no overflow, and the date line stays visible.
- `test/profile_test.dart`: Not now on a You Pal suggests row records a step whose `undoLabel` is `<title> skipped`.
- Update `today_scenario_test.dart` wherever it approved the money hold proposal.
- `test/scenario/proposal_actions_scenario_test.dart`, light and dark:
  - "approve add ritual": the card, then the header `Undo · … added`, then the evening routine showing the new step;
  - "undo restores": tap Undo, and the step is gone and the proposal is back;
  - "approve reschedule": approve the reschedule proposal, then capture Weekly plan showing Friday set to Leg Day and the header `Undo · Leg Day on Friday`;
  - "skip names undo": Not today on a timeline item, then capture the header `Undo · <title> skipped`;
  - "approve fails": with a ritual repository override whose write throws, approve add_ritual and capture the snack bar `Couldn't save. Try again.` with the proposal still on the card.
- **Run:** `flutter test test/controllers/plan_session_controller_test.dart test/screens/day_plan_test.dart test/today_screen_test.dart test/profile_test.dart`

- [ ] Failing tests, implement, build_runner, focused tests, analyze
- [ ] Commit `feat(today): approving a proposal performs it, and Undo names and reverses it`

### Task 8: Autopilot as a fixed list with saved switches

**Depends on:** Task 2, Task 3, Task 7
**Model:** claude-opus-5-5
**Chunk:** Build: Autopilot as a fixed app-defined list with saved switches that drive real behaviour (pick the list first); model writes subtitles only
**Files:** `lib/controllers/autopilot_controller.dart`, `lib/controllers/autopilot_controller.g.dart`, `lib/screens/you/autopilot_screen.dart`, `lib/screens/profile/profile_screen.dart`, `lib/screens/settings/notifications_screen.dart`, `lib/services/pal/pal_service.dart`, `lib/services/pal/http_pal_service.dart`, `lib/services/pal/mock_pal_service.dart`, `test/screens/you/autopilot_screen_test.dart`, `test/profile_test.dart`, `test/screens/settings/settings_screens_test.dart`, `test/controllers/autopilot_controller_test.dart`, `test/services/pal/http_pal_service_test.dart`, `test/services/mock_pal_service_test.dart`, `test/scenario/you_scenario_test.dart`, `test/scenario/autopilot_scenario_test.dart`

Spec section 3. The list is already picked: `spend_nudge` and `routine_reminders` only.

**Interfaces**

`PalAgenda`:
- `autopilot` becomes `Map<String, String> autopilotSubtitles`, keyed by automation id;
- `PalAutopilotItem` is deleted, after a grep for every reference;
- the HTTP decoder reads `autopilot: [{id, subtitle}]`;
- the mock returns subtitles for both ids.

`autopilot_controller.dart`:
- `enum Automation { spendNudge('spend_nudge', 'Spend nudge', <icon>), routineReminders('routine_reminders', 'Routine reminders', <icon>) }`.
- `@Riverpod(keepAlive: true) class Automations` with state `Map<Automation, bool>`, built from `SettingsRepository.budgetAlerts` and `ritualReminders`.
- `Future<void> set(Automation a, bool on)` writes the setting, then:
  - routineReminders on → request permission, then `scheduleDaily` at `reminderTime` with `kRitualReminderTitle`/`Body`;
  - routineReminders off → cancel `NotificationIds.ritualReminder`;
  - spendNudge needs only the setting, which `BudgetAlertController` already reads.
- `String subtitleFor(Automation a, PalAgenda? agenda, TimeOfDay reminderTime)` returns the model's subtitle, or the fallback:
  - spendNudge: `Alerts you when today's spending passes your budget.`
  - routineReminders: `A daily nudge at <h:mm AM>.`

Screens:
- The Notifications screen's Routine reminders and Budget alerts toggles go through `Automations.set`, keeping its permission row behaviour.
- `AutopilotScreen` always lists both rows. The "Couldn't load autopilot." and "Nothing on autopilot yet." states go.
- You's Autopilot value reads `N on` from the provider.

**Acceptance and focused tests (write them first)**
- `test/controllers/autopilot_controller_test.dart` (in-memory prefs, fake notification service):
  - switching routineReminders off persists false and cancels the reminder;
  - switching it on schedules it;
  - a new container reads the saved values;
  - spendNudge off makes `BudgetAlertController.checkAfterSpend` stay quiet past the budget.
- `test/screens/you/autopilot_screen_test.dart`:
  - both rows show with the fallback subtitles when the agenda errors;
  - with an agenda subtitle, the model line shows;
  - flipping Spend nudge off shows off on Notifications' Budget alerts.
- `test/profile_test.dart`: the value reads `2 on`, then `1 on` after one is switched off.
- `test/services/pal/http_pal_service_test.dart`: the autopilot decoder maps `[{id, subtitle}]`.
- `test/scenario/autopilot_scenario_test.dart`, light and dark:
  - "autopilot with model subtitles": both rows with the mock's subtitles;
  - "autopilot offline": with an agenda that errors, both rows with the fallback subtitles;
  - "spend nudge mirrors notifications": switch Spend nudge off, open Notifications, and capture Budget alerts off;
  - "you autopilot value": capture You's Autopilot row reading `1 on`;
  - "autopilot after relaunch": switch Routine reminders off, rebuild the app on the same prefs, and capture Autopilot still showing it off.
- **Run:** `flutter test test/controllers/autopilot_controller_test.dart test/screens/you/autopilot_screen_test.dart test/profile_test.dart test/screens/settings/settings_screens_test.dart test/services/pal/http_pal_service_test.dart test/services/mock_pal_service_test.dart`

- [ ] Failing tests, implement, build_runner, focused tests, analyze
- [ ] Commit `feat(you): Autopilot is a fixed list of saved switches that drive real behaviour`

### Task 9: Today keeps the mood check-in listed as "Check in again"

**Depends on:** Task 7
**Model:** claude-sonnet-5-5
**Chunk:** Build: Today keeps the Mood check-in listed after the first one, as 'Check in again'
**Files:** `lib/screens/today/day_plan.dart`, `test/screens/day_plan_test.dart`, `test/today_screen_test.dart`, `test/scenario/mood_again_scenario_test.dart`

Spec section 4.

**Decisions**
- `PlanItem` gains `final bool trailing` (default false).
- Once the day has a check-in, the mood item stays open: `done: false`, `trailing: true`, title `Check in again`, action `Check in`, id `mood`.
- `DayPlan.open` puts trailing items after everything else, missed items included.
- `palPick` and `current` skip a trailing item unless the session selected it, so a trailing-only day shows the rest lead.
- `later` still lists it.

**Acceptance and focused tests (write them first)**
- `test/screens/day_plan_test.dart`:
  - before any check-in: `Mood check-in` / `Check in`;
  - after one: `Check in again`, open;
  - with a 9:30 PM close-out upcoming at 3 PM, the close-out leads, not Check in again;
  - with nothing else open, `current` is null and `later` lists Check in again;
  - selecting it makes it current;
  - Not today hides it.
- `test/today_screen_test.dart`: after a check-in, the timeline lists `Check in again`; tapping it shows it on the card; Check in opens the mood logger.
- `test/scenario/mood_again_scenario_test.dart`, light and dark:
  - "check in again": the timeline row, then tap it and capture the card;
  - "only check in again left": with every other item done, capture the rest lead `Nothing is left. Rest up.` with `Check in again` listed in the timeline.
- **Run:** `flutter test test/screens/day_plan_test.dart test/today_screen_test.dart`

- [ ] Failing tests, implement, focused tests, analyze
- [ ] Commit `feat(today): keep the mood check-in listed as Check in again`
