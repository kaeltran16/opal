# Product decisions 10-15: timed sets, real proposals, real Autopilot, mood again

Effort c4342184, chunks 117-120. The decision records are the done notes on chunks 113-116. This spec turns those decisions into a design. Every call below was made without a human, as the recommended option, and says why.

Baseline on 83d283f: `flutter analyze --fatal-infos` is clean, server vitest passes 182 tests and worker vitest passes 57. Run 8602490a is working E2E chunks 96-112 at the same time and edits the composer, `prompts.ts`, `today_screen.dart`, `day_plan.dart`, the Pal service and `pal_action_executor.dart`. The lead merges main and resolves conflicts so both runs' behaviour survives.

## 1. Cardio and timed-hold sets log minutes, with optional km

### Decisions

- **Which exercises are timed: a stored `Exercise.timed` flag.** The session has to know whether a set is timed before anything is logged, and existing routine slots carry no duration. The flag is true for the `Cardio` group and for timed holds. In the seed catalog the only timed hold is `plank`. Why a flag, not a name or group rule in code: a rule keyed on names is a hidden list, and a custom exercise later needs a field anyway.
- **A set is timed when `SetLog.minutes != null`.** `SetLog` gains `int? minutes` and `double? distanceKm`. `weightKg` and `reps` stay non-null and hold 0 on a timed set. Why: making them nullable means rebuilding the SQLite tables, while adding nullable columns is a plain `addColumn`. Every aggregate reads the set through the `SetLog` getters, so the 0s never show.
- **Whole minutes.** They match the generator's integer `duration`, `GeneratedSetDraft.durationMinutes` and `Entry.duration`. A 30-second plank logs as 1 minute. km is optional, steps by 0.1, and is stored null when 0.
- **Routine slots carry `int? targetMinutes` and `double? targetKm`.** This is the "duration field routine sets already carry": `_slotFrom` in `pal_action_executor.dart` maps `GeneratedSetDraft.durationMinutes` to `targetMinutes` instead of dropping it. Run 8602490a's chunk 103 touches the same function, and the lead keeps both changes at merge.
- **Seeding a session.** A slot whose exercise is timed seeds timed sets with `minutes = targetMinutes ?? kDefaultTimedMinutes`, where `kDefaultTimedMinutes = 1`, and `distanceKm = targetKm`. The seed routines that use timed exercises (Treadmill Intervals, and any seed slot on plank) get explicit targets, so the demo data never starts at 1 minute.
- **Schema v11 migration.** Columns added: `set_logs.minutes` INTEGER NULL, `set_logs.distance_km` REAL NULL, `routine_exercises.target_minutes` INTEGER NULL, `routine_exercises.target_km` REAL NULL, and `exercises.timed` BOOLEAN NOT NULL DEFAULT 0. The backfill runs `timed = 1` WHERE `"group" = 'Cardio'` OR `id = 'plank'`. Existing logged sets stay weight × reps, because history is not rewritten.
- **Aggregates.**
  - `SetLog.volumeKg` is 0 for a timed set, by rule and not by the stored 0s.
  - A timed set is never a PR: the session engine never flags one, and PR baselines skip it.
  - A timed exercise has no stored PR. The demo overlay's `plank: ExercisePR(weightKg: 0, reps: 90)` is removed from the seed, and the v11 migration clears `pr_weight_kg` and `pr_reps` where `timed = 1`, so no screen reads "0 kg × 90".
  - History "Personal records" and best-set lookups skip timed sets.
  - Muscle share (`buildMuscleVolumes`) counts weighted sets only.
  - `Workout` gains `totalMinutes` and `totalKm` (sums over done timed sets) and `isTimedSession`: true when it has done sets and every one of them is timed.
  - `moveEntryForWorkout` gives a timed session the detail `"<m> min"` or `"<m> min · <km> km"`, not `"N sets · 0 kg"`, and sets `Entry.distance` to the km total when there is one.
- **Session UI.** A timed set's enter card has a Minutes stepper (step 1, minimum 1) and an optional km stepper (step 0.1, minimum 0, shown as "No distance" at 0), in place of Weight and Reps. It shows no "Best …" line and no "Ahead of your best" line. Set rows read `20 min` or `20 min · 3.2 km`. Rest still runs between sets.
- **Routine editor.** A timed slot's row reads `1 × 20 min` or `1 × 20 min · 3 km`. Its targets sheet has Sets, Minutes and an optional km stepper instead of Reps and kg.
- **Summary and detail.**
  - A timed session leads with the time. The hero number is `totalMinutes` with the unit `min` (and `· <km> km` beside it when there is distance), in place of `<kg>` `kg lifted`.
  - The "Muscles worked" section is left out when no weighted volume was logged, so a timed-only session never shows "Cardio 0%".
  - A mixed session (strength plus plank) still leads with kg lifted, and its plank rows read in minutes.
  - Workout detail follows the same rules.
  - History rows for a timed session show minutes and km instead of tonnes. Volume bars and trends count weighted volume only.
- **Pal post-workout note.** The `/v1/post-workout-note` context gains `minutes` and `km` (totals over done timed sets; `km` is null when there is none). When `volumeKg` is 0 and `minutes > 0`, the prompt speaks about time and distance, not weight. The fields are optional on the server, so an older client still parses.

## 2. Approve does what it says; Undo names what it undoes

### Decisions

- **Three proposal kinds, nothing else.** These are `close_out`, `add_ritual` and `reschedule_workout`. `hold_funds` and `generic` leave the enum, the prompt and the mock. The server drops any proposal whose kind is off-list, where before it coerced it to `generic`. Why: the app holds no money, and a generic approve can do nothing.
- **Presentation follows the kind.** The server derives `tag`, `colorToken`, `icon`, `approveIcon` and `action` from the kind. close_out and add_ritual map to Rituals/`rituals`; reschedule_workout maps to Workout/`move`. The model writes only `title`, `body`, `approveLabel`, `doneLabel` and the payload. As a consequence, Money in Needs care no longer has a proposal to lead with, and Today falls through to the clock, which is the honest result.
- **Payloads.** An add_ritual proposal carries `ritual: {routineId, step}`. A reschedule_workout proposal carries `slot: {weekday 1..7, routineId}`. "Sets the plan slot" means approving sets that one weekday to that routine. It does not also clear another day: that is what the decision says, and moving a session is two separate slot changes.
- **The model gets the targets.** The `/v1/agenda` body gains `targets: {rituals: [{id, name, steps: [title]}], workouts: [{id, name}], week: [{weekday, routineId|null}]}`. It defaults to empty lists for an older client. `PalContextSource` gains an `agendaTargets` seam, built from the ritual, routine and weekly-plan repositories.
- **Server validation, in one predicate.** A proposal is kept only when all of these hold:
  - its labels agree on amounts (the existing `labelsAgree`);
  - an add_ritual payload names a ritual id from `targets.rituals`, with a non-empty step that is not already in that routine (case-insensitive);
  - a reschedule_workout payload names a weekday from 1 to 7 and a routine id from `targets.workouts` that differs from that weekday's current slot.

  If any proposal fails, the agenda is drawn once more, as `labelsAgree` already does; a proposal that still fails is dropped. close_out needs no payload.
- **Wire shape (response).** The proposal object stays as it is (`id, tag, colorToken, icon, title, body, approveLabel, approveIcon, doneLabel, action`), plus `ritual: {routineId, step} | null` and `slot: {weekday, routineId} | null`. `action` is now always one of the three kinds. The client decoder drops a proposal whose action is unknown or whose payload is missing, so a stale server cannot bring back a do-nothing approve.
- **What Approve does.**
  - close_out opens the close-out. This already works through `PlanKind.closeOut`, and a test now pins it.
  - add_ritual appends a step titled `step` (icon `sparkles`, empty note) to that ritual routine through `RitualRepository`.
  - reschedule_workout reads the weekday's prior routine id and then calls `WeeklyPlanRepository.upsert(weekday, routineId)`.

  Only after the write succeeds is the proposal settled. If the write fails, the proposal stays open, nothing changes, and `actOnPlanItem` shows `Couldn't save. Try again.` as a snack bar. That is the app's existing pattern for a failed action outside a form (`new_entry_sheet.dart`), and it works the same on Today and on You's Pal suggests.
- **Undo reverses the real change.** Each `PlanSession` history step records what it did:
  - a skip ("Not today" or "Not now");
  - an added ritual step (routine id and the new step's id);
  - a plan-slot change (weekday and the prior routine id, which may be null for a rest day).

  Every skip goes through `PlanSessionController.skip(item)`, which records the label. That includes You's Pal suggests "Not now" (`profile_screen.dart`), so an Undo after a skip on You also names it.

  Undo first reverses the change through the same repositories and only then pops the step. If the reversal fails, the step stays and the same snack bar shows. `PlanSession` stays pure data, and `PlanSessionController` does the I/O.
- **Undo copy.** The header button reads `Undo · <what>`. Its semantics label is `Undo <what>`. It ellipsises within half the row and stays 44px tall. The `<what>` text is app copy, never model copy:

  | Last step | `<what>` |
  |---|---|
  | skip | `<item title> skipped` |
  | add_ritual | `<step> added` |
  | reschedule_workout | `<routine name> on <Weekday>` |

## 3. Autopilot is a fixed, app-defined list with saved switches

### The list (picked first, as the decision asks)

| Id | Title | Switch drives | Persisted as |
|---|---|---|---|
| `spend_nudge` | Spend nudge | the over-budget alert and the weekly-pace and category-spike alerts (`BudgetAlertController`) | `SettingsRepository.budgetAlerts` |
| `routine_reminders` | Routine reminders | the daily routine reminder: on schedules it at the saved time, off cancels it | `SettingsRepository.ritualReminders` |

Left out:
- **Weekly review draft.** Nothing in the app drafts or delivers a review on a schedule. Making it real means weekly notification scheduling plus notification-tap routing, which is a new feature and not a switch. It is filed as a follow-up in the report.
- **Bills watch.** The app has no bills data.

Why reuse the existing settings keys: Notifications already has a switch for each of these behaviours. A second store would let the two screens disagree, so each behaviour has one switch value, read and written by both screens.

### Decisions

- **The list lives in the app** as an enum with id, title, icon and fallback subtitle. Autopilot always shows both rows, whether Pal is offline or the agenda failed. "Couldn't load autopilot." and "Nothing on autopilot yet." go away.
- **One controller owns the switches.** It reads from and writes to `SettingsRepository` and performs the side effect. Turning `routine_reminders` on asks for permission and schedules the daily reminder at `reminderTime`; turning it off cancels it. Notifications' Routine reminders and Budget alerts toggles go through the same controller, so flipping one shows on the other and on You's Autopilot count. The values survive a relaunch because they are the stored settings.
- **The model writes subtitles only.** The agenda model's autopilot output becomes `[{kind: 'spend_nudge'|'routine_reminders', subtitle}]`. The server drops off-list kinds and repeats, and the response becomes `autopilot: [{id, subtitle}]` with `id` set to the kind. The prompt asks for one short line per automation saying what it is watching today, grounded in the day's numbers, and never claiming the switch is on or off. The client uses the model's subtitle for a known id, and otherwise the fallback:
  - spend_nudge: `Alerts you when today's spending passes your budget.`
  - routine_reminders: `A daily nudge at <reminder time>.`
- You's Autopilot row value counts the switches that are on in the fixed list, as `N on`.

## 4. Mood check-in stays listed as "Check in again"

### Decisions

- Once the day has a check-in, the `mood` item is no longer done. It stays open with the title `Check in again` and the action `Check in`, which opens the mood logger as before. The id stays `mood`, so a skip still settles it.
- **It never takes the lead on its own.** A `trailing` item is ordered after everything else, missed items included, and the clock never picks it as the current item. If it is the only open item, the card shows the rest lead (`Nothing is left. Rest up.`) and the timeline lists `Check in again`. Tapping the row selects it, and then the card offers it. Why: an untimed open item would otherwise lead over the evening close-out all day.
- Before the first check-in, nothing changes: `Mood check-in` with `Check in`.

## Testing

- **Tests come first in each task.** Focused unit tests cover the model getters, the migration, the session engine, the aggregates, the server predicate and the prompts, the client decoder, the PlanSession undo steps and the controller I/O, the Autopilot controller and settings round-trip, and the day plan ordering.
- **Every changed view gets a scenario step**, each in its own new scenario file so parallel tasks never share one:
  - timed session entry;
  - routine editor timed slot;
  - timed summary and detail;
  - approve add_ritual, then Undo with its label;
  - Autopilot after a relaunch;
  - Check in again.
- **Final gate, in the engine:** `flutter analyze --fatal-infos`, `flutter test`, server and worker vitest, and the scenarios. Each changed view, state and interaction has its own scenario step.
- **Final gate, the lead's own step:** after the engine's final stage and the merge of main, and before `wsh jarvis complete`, the lead walks the changed flows in a headed browser against DESIGN.md (web build with seed data, against the local worker) and records the result in the report. Why it is not in the plan's Final line: driving a headed Chrome needs an attached, visible browser that an unattended merge queue cannot count on. The scenarios render the same views headlessly with real fonts. No deploy.
