# Watch Workout Remote Implementation Plan

> Bounded run, executed inline in a worktree. No subagents.

**Goal:** During a workout started on the phone, the Watch shows the session and drives it
(Complete set, +30 s, Skip rest, Add set, Skip exercise, Finish) while an HKWorkoutSession
keeps the app frontmost, measures heart rate, active energy and distance, and saves the
workout to Apple Health. Average heart rate and active energy land on the Opal Workout;
the Watch's distance lands on the timed set it was measured for.

**Effort:** effort:01df7794-d257-4f9e-b898-17ada571922c (chunk 17)
**UI:** `docs/design/watch-app/Workout.dc.html` (8 screens, Apple Watch SE 3 44 mm)
**Settled before this plan (chunks 8, 9, 17):** the Dart `WorkoutSession` engine behind
`WorkoutSessionController` stays the single source of truth; the Watch renders snapshots
and sends commands; Complete set logs the planned values (the Watch never edits weight or
reps); workouts start only from the phone via `HKHealthStore.startWatchApp`; the Watch runs
an HKWorkoutSession.
**Builds on:** local main 4d9e7d6 (Watch Pal logging): `OpalWatchMessage.swift`,
`OpalWatchSession`, `OpalWatchRelay`, the `opal/watch` channel, `watch_channel.dart`.

## Design decisions made here

1. **Storage: two nullable columns on `workouts`** (`avg_heart_rate` INTEGER,
   `active_kcal` INTEGER), schema v12 -> v13, and matching `Workout.avgHeartRate` /
   `Workout.activeKcal`. Not the linked move entry's `calories`: the move ring sums move
   entries' calories and `HealthSyncController` already writes the day's Apple Health
   active energy (which includes the Watch workout) as its own move entry, so the
   workout's kcal there would count twice. Distance needs no column: it goes into the
   timed set's existing `set_logs.distance_km` through `logCurrentTimedSet`. Shown on the
   workout detail and post-workout summary as a second stat row when present.
2. **Where the numbers come from.** The Watch is the only side that measures, so it sends
   them; the phone never reads heart rate from HealthKit (Watch-to-phone Health sync lags,
   and it would need a new read permission).
   - Watch Finish: the `finish` command carries the Watch's average heart rate and
     active kcal (`HKLiveWorkoutBuilder` statistics), then the Watch ends its session.
   - Phone Finish: the controller asks the Watch (`endWorkout`, a `sendMessage` with
     reply); the Watch ends its session and replies with the same two numbers. Capped at
     3 s; unreachable or slow -> saved without them (the Health copy still has them).
   - Timed set: Complete set carries the distance the Watch measured since that set
     became current. None measured -> the planned distance, as for weight and reps.
3. **Wire format** (keys in `OpalWatchMessage.swift`, mirrored in `WatchKeys`):
   - Watch -> phone `{type: workout, command, setId?, distanceKm?, heartRate?, kcal?}` with
     `command` one of `state | complete | skipRest | addRest | addSet | skipExercise |
     finish`. The reply is a snapshot.
   - Phone -> Watch snapshot `{type: workout, session, rev, phase, ...}`, display-ready
     like the Pal replies: `phase` is `set | rest | done | ended | none`; `setId`,
     `timed`, `setLabel` ("Set 2 of 4"), `exercise`, `planned` ("60 kg × 8" / "25 min"),
     `best` or `ahead` (same wording and rule as the phone's set card), `restEndsAt`
     (epoch ms), `restTotal` (s, for the ring), `next` ("Set 3 · 60 kg × 8"), `progress`
     ("Bench press · 2 of 4 sets"), `canSkip`, `logged` ("16 of 16 sets").
   - Phone -> Watch push of each snapshot: `sendMessage` when reachable, plus
     `updateApplicationContext` so a Watch that was asleep gets the latest. `session`
     (start time) + `rev` let the Watch drop stale or duplicate ones.
   - Phone -> Watch `{type: workoutEnd}` with reply `{heartRate?, kcal?}`.
4. **Commands are guarded, so retries are safe.** `complete`, `addSet` and `skipExercise`
   carry the `setId` the Watch showed and apply only if it is still the current set;
   `skipRest`/`addRest` apply only while resting. Otherwise the phone just replies with
   the current snapshot. A Try again after a lost reply can't log a set twice.
5. **Rest is sent as a deadline, and the controller catches up after suspension.** The
   phone app is suspended most of a gym session, which freezes the Dart `Timer`, so the
   engine's `restRemaining` is stale when a Watch message wakes it (+30 s or Add set would
   then push a wrong end time). The controller keeps the rest deadline in wall-clock time
   and ticks the engine up to it before every command and on each timer fire; the 10 s
   cue fires on crossing 10 rather than on equality. The engine itself is unchanged. The
   Watch counts down from `restEndsAt` itself and plays its own haptics at 10 s and 0.
6. **Workout messages go to the app engine only.** The session is in memory there.
   `OpalWatchRelay.forward` sends `workout` to the app endpoint, never starts a headless
   engine for it, and answers `{type: workout, phase: none}` itself when there is no app
   engine. Dart -> native calls `startWorkout`, `pushWorkout` and `endWorkout` on the same
   `opal/watch` channel are handled by `OpalWatchSession` (it owns the phone's `WCSession`;
   `startWatchApp` sits beside it). No new Runner Swift file.
7. **Start.** `WorkoutSessionController.build` calls `startWorkout(cardio:)` once the session
   exists, after the Live Activity start. Native skips it unless a Watch is paired and the
   app is installed. Configuration: `.running` for a cardio routine, else
   `.traditionalStrengthTraining`, `locationType = .indoor`. The Watch also enables
   `distanceWalkingRunning` collection explicitly, so a strength session with a treadmill
   set still measures distance.
8. **Finish.** `WorkoutSessionController.finish` becomes `Future<Workout> finish({
   WatchWorkoutStats? fromWatch})`. The phone screen awaits it (asks the Watch, up to 3 s);
   the Watch command passes its numbers and the phone skips asking. A Watch Finish opens
   the summary on the phone: `WatchWorkout` emits the finished workout on a stream and
   `LoopApp` pushes `postWorkout` (replacing the session route when that is on top),
   the same way it handles native deep links.
9. **Watch app structure.** `OpalWatchLink` stays the single `WCSession` delegate and
   forwards workout messages to a new `OpalWatchWorkout` (`ios/OpalWatch/OpalWatchWorkout.swift`):
   the HKWorkoutSession + `HKLiveWorkoutBuilder`, the latest snapshot, commands, the
   per-set distance baseline and rest haptics. `@WKApplicationDelegateAdaptor` receives
   `handle(_ workoutConfiguration:)`. The root shows the workout while one is running,
   Pal logging otherwise. Screens in `ios/OpalWatch/OpalWatchWorkoutViews.swift`: a
   two-page `TabView` (controls left, set/rest/done right, as in Apple's Workout app);
   always-on dims and hides the buttons (`isLuminanceReduced`), the rest uses
   `Text(timerInterval:)` so it keeps counting each second. A failed command shows
   screen 8 (Can't reach your iPhone, Try again re-sends the same command); the
   HKWorkoutSession keeps recording.
   Not drawn, added because otherwise the Watch is stuck: phase `none` (the phone app was
   closed and the in-memory session is gone) shows "No workout on your iPhone" with an
   End button that ends and saves the Watch workout.
10. **Watch target capabilities:** `ios/OpalWatch/OpalWatch.entitlements` (HealthKit),
    `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` and
    `WKBackgroundModes = [workout-processing]` in `OpalWatch/Info.plist`.
    `configure_native_targets.rb` sets `CODE_SIGN_ENTITLEMENTS` and adds the two Watch
    files; `project.pbxproj` edited by hand to match, as 4d9e7d6 did.
11. **Providers without codegen where new.** `watchWorkoutServiceProvider` and
    `watchWorkoutProvider` are plain `Provider`s like `watchLogProvider`.
    `WorkoutSessionController` is an existing `@riverpod` class and must change, so its
    hash in `workout_session_controller.g.dart` goes stale and I can't compute the new one
    here; drift's `database.g.dart` for the two columns is written by hand after the
    `distance_km`/`ended_at` patterns. **Expected: the first app.yml run fails the codegen
    diff**; I copy the exact lines from its log, commit and push again.

## Known limits (left for chunk 18 or later)

- Weight/reps stepped on the phone screen live in that widget, not the engine, so a
  Complete set from the Watch logs the plan, not the phone's unsaved edits (as decided).
- Delivery to a suspended phone app, iOS background time per command and Watch-to-phone
  latency are unverified until a real workout.
- A Watch Finish while the phone app is suspended leaves the summary waiting on the phone
  until it is opened; it is saved only when the user taps Save there, as today.
- No HKWorkoutSession crash recovery and no routine picker on the Watch.

## Tasks

1. **Model + DB.** `Workout.avgHeartRate`, `Workout.activeKcal` (+ copyWith, ==, hashCode);
   `Workouts` columns, schema 13 with `addColumn` x2; `database.g.dart` by hand; mappers.
   Tests: v12 -> v13 migration (columns exist, null); repository round trip.
2. **Dart link.** `lib/services/watch/watch_workout_service.dart`: `WatchWorkoutStats`,
   `WatchWorkoutService` (`start`, `push`, `end` with the 3 s cap) over `watchChannel`,
   Noop off iOS. `WatchKeys` gain the workout keys. `bindWatchChannel` gets an optional
   `workout` handler (app engine only). Tests: channel calls and `end` timeout/garbage.
3. **Snapshot + commands.** `lib/controllers/watch_workout.dart`: pure
   `buildWatchSnapshot(...)`, `WatchWorkout.handle(message)` dispatching to the running
   session with the guards of decision 4, the finished-on-Watch stream, providers.
   Tests: snapshot per phase (set, ahead, rest, timed, done, none), guards, timed distance
   fallback, finish with stats.
4. **Controller.** Start the Watch, push snapshots on every content change (where the Live
   Activity syncs, plus Add set), rest deadline catch-up, async `finish`. Screen `_finish`
   awaits; `LoopApp` opens the summary on a Watch Finish. Summary + detail stat row.
   Update tests that call `finish()` synchronously.
5. **Phone native.** `OpalWatchMessage` keys; `OpalWatchSession`: accept `workout`, push,
   `endWorkout`, `startWatchApp`; `OpalWatchRelay`: route `workout` to the app engine only
   and delegate the three Dart calls.
6. **Watch.** `OpalWatchWorkout.swift`, `OpalWatchWorkoutViews.swift`, app delegate adaptor
   + root switch in `OpalWatchApp.swift`, forwarding in `OpalWatchLink`, entitlements,
   Info.plist, `configure_native_targets.rb`, `project.pbxproj`.
7. **Land + verify.** Self-review, one commit `feat(watch): ...`, merge into main, push
   main from the main checkout (carries 4d9e7d6 too), dispatch ios.yml, read ios.yml and
   app.yml, fix codegen from the log (decision 11) and anything else red, note on chunk 17.
