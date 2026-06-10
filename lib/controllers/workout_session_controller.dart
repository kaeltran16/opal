import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';
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
@riverpod
class WorkoutSessionController extends _$WorkoutSessionController {
  WorkoutSession? _session;
  Map<String, Exercise> _catalog = const {};
  Timer? _timer;

  /// Guard so the 10s medium cue fires once per rest period, not every rebuild.
  bool _tenSecondCueFired = false;

  @override
  Future<ActiveSessionState> build(String routineId) async {
    ref.onDispose(() => _timer?.cancel());

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
    return _snapshot();
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
    s.tick();

    if (s.restRemaining == 10 && !_tenSecondCueFired) {
      _tenSecondCueFired = true;
      ref.read(hapticsServiceProvider).medium();
    }
    if (!s.isResting) {
      // rest just hit 0 — success cue, stop the clock.
      ref.read(hapticsServiceProvider).success();
      _syncTimer();
    }
    _emit();
  }

  /// Logs the current set (PR detection + cursor advance + rest start handled by
  /// the engine), then re-snapshots and arms the rest timer.
  void logCurrentSet({required double weightKg, required int reps}) {
    final s = _session;
    if (s == null) return;
    _tenSecondCueFired = false;
    s.logCurrentSet(weightKg: weightKg, reps: reps);
    _syncTimer();
    _emit();
  }

  /// Appends another set to the current exercise.
  void addSet() {
    final s = _session;
    if (s == null) return;
    s.addSet();
    _emit();
  }

  /// Dismisses the rest timer immediately.
  void skipRest() {
    final s = _session;
    if (s == null) return;
    s.skipRest();
    _syncTimer();
    _emit();
  }

  /// Extends the running rest by 30 seconds (the +30s pill).
  void addRestTime() {
    final s = _session;
    if (s == null) return;
    s.addRestTime(30);
    _syncTimer();
    _emit();
  }

  /// Finalizes the session and returns the completed [Workout]. Does NOT persist
  /// — saving the workout + linked move entry is U14's job (plan SF-5).
  Workout finish() {
    final s = _session;
    if (s == null) {
      throw StateError('finish() called before the session loaded');
    }
    _timer?.cancel();
    _timer = null;
    final workout = s.finish();
    _emit();
    return workout;
  }
}
