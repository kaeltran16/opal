/// A single logged set within a [Workout].
///
/// Mirrors the handoff's `[{exerciseId, weight, reps, done, isPR}]`. Pure data:
/// PR detection (comparing `weight × reps` against history) is a
/// repository/controller concern and lives outside the model.
class SetLog {
  const SetLog({
    required this.id,
    required this.exerciseId,
    required this.weightKg,
    required this.reps,
    this.done = false,
    this.isPR = false,
  });

  /// Caller-supplied id (never self-generated).
  final String id;

  /// FK to [Exercise.id].
  final String exerciseId;

  /// Logged weight in kilograms.
  final double weightKg;

  final int reps;

  /// Whether this set has been completed during the session.
  final bool done;

  /// Whether this set is a personal record (set by the controller on save).
  final bool isPR;

  /// Volume contribution of this set: weight × reps.
  double get volumeKg => weightKg * reps;

  SetLog copyWith({
    String? id,
    String? exerciseId,
    double? weightKg,
    int? reps,
    bool? done,
    bool? isPR,
  }) {
    return SetLog(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      done: done ?? this.done,
      isPR: isPR ?? this.isPR,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetLog &&
          other.id == id &&
          other.exerciseId == exerciseId &&
          other.weightKg == weightKg &&
          other.reps == reps &&
          other.done == done &&
          other.isPR == isPR;

  @override
  int get hashCode =>
      Object.hash(id, exerciseId, weightKg, reps, done, isPR);

  @override
  String toString() =>
      'SetLog(id: $id, exerciseId: $exerciseId, ${weightKg}kg × $reps, done: $done, isPR: $isPR)';
}
