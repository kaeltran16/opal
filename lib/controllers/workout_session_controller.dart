import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'providers.dart';
import 'watch_workout.dart';
import 'workout_session.dart';

part 'workout_session_controller.g.dart';

/// Immutable snapshot of the live [WorkoutSession] that the screen renders.
///
/// The engine ([WorkoutSession]) is a mutable, Riverpod-free controller; this
/// state is re-derived from it after every command so widgets rebuild off plain
/// value-equality. The screen is dumb — every field here is read-only.
class ActiveSessionState {
  const ActiveSessionState({
    required this.activeWorkout,
    required this.currentExerciseIndex,
    required this.currentSetIndex,
    required this.currentSet,
    required this.restRemaining,
    required this.isResting,
    required this.isComplete,
    required this.exerciseIds,
    required this.catalog,
  });

  /// The workout being assembled (name/startedAt + all sets, done and pending).
  final Workout activeWorkout;

  final int currentExerciseIndex;
  final int currentSetIndex;

  /// The set awaiting completion, or null once the session is complete.
  final SetLog? currentSet;

  /// Seconds left on the rest timer (0 when not resting).
  final int restRemaining;
  final bool isResting;

  /// True once every seeded set has been logged.
  final bool isComplete;

  /// Distinct exercise ids in routine order.
  final List<String> exerciseIds;

  /// Catalog metadata (name/muscle/equipment/icon/pr) keyed by exercise id, so
  /// the screen can label the current + up-next cards without a second lookup.
  final Map<String, Exercise> catalog;

  /// All sets across every exercise, in seeded order.
  List<SetLog> get sets => activeWorkout.sets;

  /// Sets belonging to the exercise at [currentExerciseIndex] (the hero card).
  List<SetLog> get currentExerciseSets {
    if (currentExerciseIndex >= exerciseIds.length) return const [];
    final id = exerciseIds[currentExerciseIndex];
    return activeWorkout.sets.where((s) => s.exerciseId == id).toList();
  }

  /// Catalog entry for the current exercise, or null past the end.
  Exercise? get currentExercise => currentExerciseIndex >= exerciseIds.length
      ? null
      : catalog[exerciseIds[currentExerciseIndex]];

  /// Catalog entry for the next exercise (the up-next card), or null if last.
  Exercise? get nextExercise => currentExerciseIndex + 1 >= exerciseIds.length
      ? null
      : catalog[exerciseIds[currentExerciseIndex + 1]];
}

/// Wraps the pure [WorkoutSession] engine in a Riverpod Notifier for screen 09.
///
/// Loads the routine + exercise catalog (keyed by [routineId]), constructs one
/// engine, and exposes an immutable [ActiveSessionState] snapshot. Owns the real
/// rest `Timer.periodic`: while resting it ticks the engine each second, re-emits
/// the snapshot, and fires haptic cues at 10s (medium) and 0s (success). The
/// timer is cancelled on rest end and on dispose. Commands delegate to the engine
/// and re-snapshot; persistence on [finish] is U14's concern (plan SF-5).
///
/// The session outlives its screen (minimise, browse other tabs, Resume) until
/// [finish] releases it. A paired Watch mirrors it: the session opens the Watch
/// app with its workout running, and every content change is pushed there as a
/// snapshot ([WatchWorkout] runs the Watch's commands).
@riverpod
class WorkoutSessionController extends _$WorkoutSessionController {
  WorkoutSession? _session;

  // a keep-alive link rather than `keepAlive: true`: finish() runs while the
  // screen still watches, and invalidating then would rebuild a new session
  // (and Live Activity) at once. closing the link disposes once it leaves.
  KeepAliveLink? _keepAlive;
  Map<String, Exercise> _catalog = const {};
  Timer? _timer;

  /// Guard so the 10s medium cue fires once per rest period, not every rebuild.
  bool _tenSecondCueFired = false;

  /// U25 — the running Live Activity for this session. [_activityId] is the id
  /// returned by the native side ([NoopLiveActivityService] off iOS → null);
  /// [_liveActivity] is captured once so the `onDispose` end-call needn't read a
  /// provider mid-teardown.
  LiveActivityService? _liveActivity;
  String? _activityId;

  late WatchWorkoutService _watch;
  WatchReply? _watchSnapshot;
  int _watchRev = 0;

  /// When the running rest ends, in wall-clock time. The engine counts rest in
  /// ticks, and a suspended app's timer doesn't fire, so after a suspension the
  /// engine is ticked up to this before anything reads or changes the rest.
  DateTime? _restEndsAt;

  /// The finish in progress, so a second Finish (phone and Watch at once, or a
  /// double tap) gets the same workout.
  Future<Workout>? _finishing;

  @override
  Future<ActiveSessionState> build(String routineId) async {
    _keepAlive = ref.keepAlive();
    final liveActivity = ref.read(liveActivityServiceProvider);
    _liveActivity = liveActivity;
    _watch = ref.read(watchWorkoutServiceProvider);
    ref.onDispose(() {
      _timer?.cancel();
      final id = _activityId;
      if (id != null) liveActivity.end(id);
    });

    final repo = ref.watch(routineRepositoryProvider);
    final routine = await repo.getById(routineId);
    if (routine == null) {
      throw StateError('Routine "$routineId" not found');
    }
    // One-shot catalog fetch (not a live stream) so the session keeps no pending
    // drift subscription — the catalog only seeds PR baselines + UI labels.
    final exercises = await repo.getAllExercises();
    _catalog = {for (final e in exercises) e.id: e};

    final session = WorkoutSession(routine: routine, exercises: exercises);
    _session = session;
    // past the awaits, so not during build: a deep-linked session (Live
    // Activity, `/session/:routineId`) reads as running too.
    ref.read(runningSessionProvider.notifier).start(routineId);

    // U25 — mirror the live session onto a Live Activity / Dynamic Island.
    // Fire-and-forget so the native channel round-trip never delays the session
    // screen; the id lands before the user logs a set. No-op off iOS.
    unawaited(liveActivity
        .start(
          routineId: routineId,
          routineName: routine.name,
          startedAt: session.activeWorkout.startedAt,
        )
        .then((id) => _activityId = id));
    unawaited(_watch.start(cardio: routine.tag == RoutineTag.cardio));
    _pushWatch();

    return _snapshot();
  }

  /// The snapshot last sent to the Watch, which is also the answer to its
  /// command.
  WatchReply watchSnapshot() => _watchSnapshot ?? noWorkout;

  void _pushWatch({bool ended = false}) {
    final s = _session;
    if (s == null) return;
    final snapshot = buildWatchSnapshot(
      _snapshot(),
      rev: ++_watchRev,
      restSeconds: s.restSeconds,
      restEndsAt: _restEndsAt,
      ended: ended,
    );
    _watchSnapshot = snapshot;
    unawaited(_watch.push(snapshot));
  }

  /// Live Activity and Watch, on every content change.
  void _syncRemotes() {
    _syncLiveActivity();
    _pushWatch();
  }

  void _catchUpRest() {
    final s = _session;
    final endsAt = _restEndsAt;
    if (s == null || endsAt == null) return;
    final left = (endsAt.difference(clock.now()).inMilliseconds / 1000).ceil();
    while (s.isResting && s.restRemaining > left) {
      s.tick();
    }
  }

  /// Re-reads the rest deadline after a command that started, ended or
  /// extended the rest.
  void _markRest() {
    final s = _session;
    if (s == null) return;
    _restEndsAt =
        s.isResting ? clock.now().add(Duration(seconds: s.restRemaining)) : null;
  }

  /// Pushes the current session state onto the Live Activity. The island timer
  /// self-ticks from `startedAt`, so this is only called on *content* changes
  /// (set logged, rest started/skipped/extended/ended) — never per tick.
  void _syncLiveActivity() {
    final id = _activityId;
    final service = _liveActivity;
    final s = _session;
    if (id == null || service == null || s == null) return;
    final w = s.activeWorkout;
    final exId = s.currentExerciseIndex < s.exerciseIds.length
        ? s.exerciseIds[s.currentExerciseIndex]
        : null;
    unawaited(service.update(
      activityId: id,
      elapsed: clock.now().difference(w.startedAt),
      currentExercise: exId == null ? null : _catalog[exId]?.name,
      completedSets: w.sets.where((set) => set.done).length,
      restRemaining: s.isResting ? Duration(seconds: s.restRemaining) : null,
    ));
  }

  ActiveSessionState _snapshot() {
    final s = _session!;
    return ActiveSessionState(
      activeWorkout: s.activeWorkout,
      currentExerciseIndex: s.currentExerciseIndex,
      currentSetIndex: s.currentSetIndex,
      currentSet: s.currentSet,
      restRemaining: s.restRemaining,
      isResting: s.isResting,
      isComplete: s.isComplete,
      exerciseIds: s.exerciseIds,
      catalog: _catalog,
    );
  }

  void _emit() => state = AsyncData(_snapshot());

  /// (Re)starts the periodic tick if the engine is resting; cancels it otherwise.
  void _syncTimer() {
    final s = _session;
    if (s == null) return;
    if (s.isResting) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    } else {
      _timer?.cancel();
      _timer = null;
      _tenSecondCueFired = false;
    }
  }

  void _onTick() {
    final s = _session;
    if (s == null) return;
    final before = s.restRemaining;
    _catchUpRest();

    // on crossing rather than at exactly 10: a catch-up can step past it
    if (before > 10 && s.restRemaining <= 10 && s.isResting && !_tenSecondCueFired) {
      _tenSecondCueFired = true;
      ref.read(hapticsServiceProvider).medium();
    }
    if (!s.isResting) {
      // rest just hit 0 — success cue, stop the clock, switch the island back
      // to the elapsed timer.
      ref.read(hapticsServiceProvider).success();
      _restEndsAt = null;
      _syncTimer();
      _syncRemotes();
    }
    _emit();
  }

  /// Logs the current set (PR detection + cursor advance + rest start handled by
  /// the engine), then re-snapshots and arms the rest timer.
  void logCurrentSet({required double weightKg, required int reps}) {
    final s = _session;
    if (s == null) return;
    _tenSecondCueFired = false;
    final prBefore = s.activeWorkout.prCount;
    s.logCurrentSet(weightKg: weightKg, reps: reps);
    // success cue when this set set a new PR, light cue otherwise
    final haptics = ref.read(hapticsServiceProvider);
    if (s.activeWorkout.prCount > prBefore) {
      haptics.success();
    } else {
      haptics.light();
    }
    _markRest();
    _syncTimer();
    _syncRemotes();
    _emit();
  }

  /// Logs the current set as a timed set (minutes and optional km). A timed
  /// set is never a PR, so it only fires the light cue.
  void logCurrentTimedSet({required int minutes, double? distanceKm}) {
    final s = _session;
    if (s == null) return;
    _tenSecondCueFired = false;
    s.logCurrentTimedSet(minutes: minutes, distanceKm: distanceKm);
    ref.read(hapticsServiceProvider).light();
    _markRest();
    _syncTimer();
    _syncRemotes();
    _emit();
  }

  /// Appends another set to the current exercise.
  void addSet() {
    final s = _session;
    if (s == null) return;
    _catchUpRest();
    s.addSet();
    _pushWatch();
    _emit();
  }

  /// Skips the rest of the current exercise (the last one completes the
  /// session).
  void skipExercise() {
    final s = _session;
    if (s == null) return;
    s.skipExercise();
    _markRest();
    _syncTimer();
    _syncRemotes();
    _emit();
  }

  /// Dismisses the rest timer immediately.
  void skipRest() {
    final s = _session;
    if (s == null) return;
    s.skipRest();
    _markRest();
    _syncTimer();
    _syncRemotes();
    _emit();
  }

  /// Extends the running rest by 30 seconds (the +30s pill).
  void addRestTime() {
    final s = _session;
    if (s == null) return;
    _catchUpRest();
    s.addRestTime(30);
    _markRest();
    _syncTimer();
    _syncRemotes();
    _emit();
  }

  /// Finalizes the session and returns the completed [Workout]. Does NOT persist
  /// — saving the workout + linked move entry is U14's job (plan SF-5). Clears
  /// the running session and releases this one, so the next start is fresh.
  ///
  /// The Watch's heart rate and energy go onto the workout: a Finish from the
  /// Watch brings them as [fromWatch]; a Finish here asks the Watch to end its
  /// workout, waiting a few seconds at most (no Watch, no numbers).
  Future<Workout> finish({WatchWorkoutStats? fromWatch}) =>
      _finishing ??= _finish(fromWatch);

  Future<Workout> _finish(WatchWorkoutStats? fromWatch) async {
    final s = _session;
    if (s == null) {
      throw StateError('finish() called before the session loaded');
    }
    _timer?.cancel();
    _timer = null;
    final endedAt = clock.now();
    final stats = fromWatch ?? await _watch.end();
    final workout = s
        .finish(endedAt: endedAt)
        .copyWith(avgHeartRate: stats?.heartRate, activeKcal: stats?.kcal);
    // U25 — tear down the Live Activity now the session is over.
    final id = _activityId;
    if (id != null) {
      _liveActivity?.end(id);
      _activityId = null;
    }
    _restEndsAt = null;
    _pushWatch(ended: true);
    _emit();
    ref.read(runningSessionProvider.notifier).clear();
    _keepAlive?.close();
    _keepAlive = null;
    return workout;
  }
}

/// The routine id of the session that is running, or null. Only one runs at a
/// time; `openWorkoutSession` reads it to resume rather than start another.
@Riverpod(keepAlive: true)
class RunningSession extends _$RunningSession {
  @override
  String? build() => null;

  void start(String routineId) => state = routineId;

  void clear() => state = null;
}
