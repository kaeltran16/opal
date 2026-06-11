import 'enums.dart';

/// Internal value-equality helper for ordered lists of [RoutineExercise].
bool _exListEquals(List<RoutineExercise> a, List<RoutineExercise> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One exercise slot inside a [Routine] — references an [Exercise] plus the
/// planned set/rep/weight targets and ordering.
///
/// The handoff models `exercises: [RoutineExercise]` as an ordered list owned
/// by the routine; [order] is kept explicit so persistence (U02) can store it
/// as a column rather than relying on list index.
class RoutineExercise {
  const RoutineExercise({
    required this.id,
    required this.exerciseId,
    required this.order,
    this.targetSets = 3,
    this.targetReps,
    this.targetWeightKg,
  });

  /// Caller-supplied id (never self-generated).
  final String id;

  /// FK to [Exercise.id].
  final String exerciseId;

  /// Position within the routine (0-based).
  final int order;

  final int targetSets;

  /// Planned reps per set. Nullable.
  final int? targetReps;

  /// Planned working weight in kg. Nullable.
  final double? targetWeightKg;

  RoutineExercise copyWith({
    String? id,
    String? exerciseId,
    int? order,
    int? targetSets,
    int? targetReps,
    double? targetWeightKg,
  }) {
    return RoutineExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      order: order ?? this.order,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineExercise &&
          other.id == id &&
          other.exerciseId == exerciseId &&
          other.order == order &&
          other.targetSets == targetSets &&
          other.targetReps == targetReps &&
          other.targetWeightKg == targetWeightKg;

  @override
  int get hashCode => Object.hash(
        id,
        exerciseId,
        order,
        targetSets,
        targetReps,
        targetWeightKg,
      );

  @override
  String toString() =>
      'RoutineExercise(id: $id, exerciseId: $exerciseId, order: $order)';
}

/// A reusable workout template.
///
/// Mirrors the handoff's `@Model class Routine`.
class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.tag,
    this.exercises = const [],
    this.restSeconds = 120,
    this.warmupReminder = false,
    this.autoProgress = false,
    this.estMin,
    this.distanceKm,
    this.pace,
  });

  /// Caller-supplied id (never self-generated).
  final String id;
  final String name;
  final RoutineTag tag;

  /// Ordered exercise slots.
  final List<RoutineExercise> exercises;

  /// Default rest between sets, in seconds.
  final int restSeconds;
  final bool warmupReminder;
  final bool autoProgress;

  /// Authored session-length estimate in minutes. Null falls back to a derived
  /// heuristic at the display layer.
  final int? estMin;

  /// Planned distance in km for cardio routines. Null for strength.
  final double? distanceKm;

  /// Display pace string for cardio routines, e.g. "5:00 /km". Null otherwise.
  final String? pace;

  /// Number of exercises in the routine.
  int get exerciseCount => exercises.length;

  /// Exercises sorted by their explicit [RoutineExercise.order].
  List<RoutineExercise> get orderedExercises {
    final copy = [...exercises]..sort((a, b) => a.order.compareTo(b.order));
    return copy;
  }

  Routine copyWith({
    String? id,
    String? name,
    RoutineTag? tag,
    List<RoutineExercise>? exercises,
    int? restSeconds,
    bool? warmupReminder,
    bool? autoProgress,
    int? estMin,
    double? distanceKm,
    String? pace,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      exercises: exercises ?? this.exercises,
      restSeconds: restSeconds ?? this.restSeconds,
      warmupReminder: warmupReminder ?? this.warmupReminder,
      autoProgress: autoProgress ?? this.autoProgress,
      estMin: estMin ?? this.estMin,
      distanceKm: distanceKm ?? this.distanceKm,
      pace: pace ?? this.pace,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Routine &&
          other.id == id &&
          other.name == name &&
          other.tag == tag &&
          _exListEquals(other.exercises, exercises) &&
          other.restSeconds == restSeconds &&
          other.warmupReminder == warmupReminder &&
          other.autoProgress == autoProgress &&
          other.estMin == estMin &&
          other.distanceKm == distanceKm &&
          other.pace == pace;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        tag,
        Object.hashAll(exercises),
        restSeconds,
        warmupReminder,
        autoProgress,
        estMin,
        distanceKm,
        pace,
      );

  @override
  String toString() =>
      'Routine(id: $id, name: $name, tag: ${tag.wire}, exercises: ${exercises.length})';
}
