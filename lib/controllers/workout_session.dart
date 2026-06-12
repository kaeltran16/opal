import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/set_log.dart';
import '../models/workout.dart';

/// Pure, framework-free engine for an in-progress workout (screen 09).
///
/// Holds the ephemeral session state described in the handoff
/// ("Ephemeral (active session)"): the [activeWorkout] being built, the
/// current exercise/set cursor, and a rest timer. It exposes plain methods so
/// the UI/Riverpod Notifier can drive it deterministically — the clock ticks
/// via [tick] rather than a real `Timer`, keeping every branch unit-testable.
///
/// Deliberately a small mutable controller (not Riverpod, no Flutter, no
/// codegen): the Notifier wrapper added later snapshots these fields after each
/// call. Haptic cues (10s/0s) are a UI concern and live outside this engine.
class WorkoutSession {
  WorkoutSession({
    required Routine routine,
    required List<Exercise> exercises,
    String workoutId = 'active',
    DateTime? startedAt,
    int? restSeconds,
  })  : _routine = routine,
        _exercisePrVolume = _seedPrHistory(exercises),
        _restSeconds = restSeconds ?? routine.restSeconds,
        _workout = Workout(
          id: workoutId,
          routineId: routine.id,
          name: routine.name,
          startedAt: startedAt ?? DateTime.now(),
          sets: _seedSets(routine),
        );

  final Routine _routine;
  final int _restSeconds;

  /// Best historical `weight × reps` per exercise id, used as the PR baseline.
  /// Updated as new PRs are logged so later sets must beat the session best too.
  final Map<String, double> _exercisePrVolume;

  Workout _workout;

  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;

  int _restRemaining = 0;
  bool _restRunning = false;

  // ── State the UI reads ────────────────────────────────────────────────────

  /// The workout being assembled (name/startedAt from the routine, all sets).
  Workout get activeWorkout => _workout;

  /// All sets across every exercise, in seeded (exercise, then set) order.
  List<SetLog> get sets => _workout.sets;

  /// Default rest length applied when a set is logged.
  int get restSeconds => _restSeconds;

  int get currentExerciseIndex => _currentExerciseIndex;
  int get currentSetIndex => _currentSetIndex;

  /// Seconds left on the rest timer (never negative).
  int get restRemaining => _restRemaining;

  /// Whether the rest timer is actively counting down.
  bool get isResting => _restRunning;

  /// Distinct exercise ids in routine order (one entry per [RoutineExercise]).
  List<String> get exerciseIds =>
      _routine.orderedExercises.map((re) => re.exerciseId).toList();

  /// The set currently awaiting completion, or null once everything is done.
  SetLog? get currentSet {
    final i = _absoluteCurrentIndex;
    if (i == null) return null;
    return _workout.sets[i];
  }

  /// True once every set has been logged (no active set remains).
  bool get isComplete => _absoluteCurrentIndex == null;

  // ── Commands ──────────────────────────────────────────────────────────────

  /// Logs [weightKg]/[reps] against the current set, runs PR detection, advances
  /// the cursor to the next not-done set, and starts the rest timer.
  ///
  /// No-op if there is no active set (session already complete).
  void logCurrentSet({required double weightKg, required int reps}) {
    final index = _absoluteCurrentIndex;
    if (index == null) return;

    final target = _workout.sets[index];
    final volume = weightKg * reps;
    // strict-beat against the running best (history seeds it; session PRs raise it)
    final best = _exercisePrVolume[target.exerciseId];
    final isPR = best == null ? volume > 0 : volume > best;
    if (isPR) _exercisePrVolume[target.exerciseId] = volume;

    final logged = target.copyWith(
      weightKg: weightKg,
      reps: reps,
      done: true,
      isPR: isPR,
    );
    _replaceSet(index, logged);

    _advanceCursor();
    _startRest();
  }

  /// Appends another set to the current exercise, copying the last seeded set's
  /// target weight/reps (not done). Returns the new set.
  SetLog addSet() {
    final exerciseId = exerciseIds[_currentExerciseIndex];
    final exerciseSets =
        _workout.sets.where((s) => s.exerciseId == exerciseId).toList();

    // derive the next id from the max existing numeric suffix so ids never
    // collide after a logged set was inserted earlier in the run.
    var maxSuffix = -1;
    for (final s in exerciseSets) {
      final n = int.tryParse(s.id.split('-').last);
      if (n != null && n > maxSuffix) maxSuffix = n;
    }

    // seed a sensible default when the exercise has no set to copy from
    final template = exerciseSets.isEmpty
        ? SetLog(id: '', exerciseId: exerciseId, weightKg: 0, reps: 0)
        : exerciseSets.last;

    // insert after the last set of this exercise to keep grouping contiguous;
    // when none exist yet, append at the end.
    final lastIndex = _workout.sets.lastIndexWhere(
      (s) => s.exerciseId == exerciseId,
    );
    final insertAt = lastIndex == -1 ? _workout.sets.length : lastIndex + 1;

    final newSet = template.copyWith(
      id: '$exerciseId-set-${maxSuffix + 1}',
      done: false,
      isPR: false,
    );
    final updated = [..._workout.sets]..insert(insertAt, newSet);
    _workout = _workout.copyWith(sets: updated);
    return newSet;
  }

  /// Dismisses the rest timer immediately.
  void skipRest() {
    _restRemaining = 0;
    _restRunning = false;
  }

  /// Extends the running rest timer by [seconds] (e.g. the +30s pill).
  void addRestTime(int seconds) {
    _restRemaining += seconds;
    if (_restRemaining > 0) _restRunning = true;
  }

  /// Advances the rest clock by one second. Stops (and clamps at 0) on expiry.
  /// No-op when not resting.
  void tick() {
    if (!_restRunning) return;
    _restRemaining -= 1;
    if (_restRemaining <= 0) {
      _restRemaining = 0;
      _restRunning = false;
    }
  }

  /// Finalizes the session: stamps [Workout.endedAt] and returns the completed
  /// workout. Computed `totalVolumeKg`/`prCount` cover the done sets.
  Workout finish({DateTime? endedAt}) {
    _workout = _workout.copyWith(endedAt: endedAt ?? DateTime.now());
    return _workout;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Absolute index into [sets] of the current set, or null if complete.
  int? get _absoluteCurrentIndex {
    if (_currentExerciseIndex >= exerciseIds.length) return null;
    final exerciseId = exerciseIds[_currentExerciseIndex];
    final matches = <int>[];
    for (var i = 0; i < _workout.sets.length; i++) {
      if (_workout.sets[i].exerciseId == exerciseId) matches.add(i);
    }
    if (_currentSetIndex >= matches.length) return null;
    return matches[_currentSetIndex];
  }

  void _replaceSet(int index, SetLog set) {
    final updated = [..._workout.sets];
    updated[index] = set;
    _workout = _workout.copyWith(sets: updated);
  }

  /// Moves the cursor to the next not-done set, walking forward through the
  /// current exercise then into later exercises. Lands past the end when done.
  void _advanceCursor() {
    final ids = exerciseIds;
    var ex = _currentExerciseIndex;
    var setIdx = _currentSetIndex + 1;

    while (ex < ids.length) {
      final exerciseSets =
          _workout.sets.where((s) => s.exerciseId == ids[ex]).toList();
      while (setIdx < exerciseSets.length) {
        if (!exerciseSets[setIdx].done) {
          _currentExerciseIndex = ex;
          _currentSetIndex = setIdx;
          return;
        }
        setIdx++;
      }
      ex++;
      setIdx = 0;
    }

    // no remaining set — park the cursor past the last exercise
    _currentExerciseIndex = ids.length;
    _currentSetIndex = 0;
  }

  void _startRest() {
    _restRemaining = _restSeconds;
    _restRunning = _restSeconds > 0;
  }

  /// Seeds one [SetLog] per planned set across all routine exercises, using the
  /// slot's target weight/reps as prefilled values (0 when the routine omits a
  /// target). Ids are deterministic so the UI can key rows stably.
  static List<SetLog> _seedSets(Routine routine) {
    final sets = <SetLog>[];
    for (final re in routine.orderedExercises) {
      for (var i = 0; i < re.targetSets; i++) {
        sets.add(SetLog(
          id: '${re.id}-set-$i',
          exerciseId: re.exerciseId,
          weightKg: re.targetWeightKg ?? 0,
          reps: re.targetReps ?? 0,
        ));
      }
    }
    return sets;
  }

  /// Baseline PR volumes from the exercise catalog (`weight × reps`).
  static Map<String, double> _seedPrHistory(List<Exercise> exercises) {
    final map = <String, double>{};
    for (final e in exercises) {
      final pr = e.pr;
      if (pr != null) map[e.id] = pr.volumeKg;
    }
    return map;
  }
}
