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
    this.minutes,
    this.distanceKm,
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

  /// Whole minutes of a timed set (cardio or a hold); null on a weighted set.
  /// A timed set stores 0 in [weightKg] and [reps].
  final int? minutes;

  /// Optional distance of a timed set; null when none was logged.
  final double? distanceKm;

  bool get isTimed => minutes != null;

  /// Volume contribution of this set: weight × reps, and 0 for a timed set
  /// whatever its stored numbers.
  double get volumeKg => isTimed ? 0 : weightKg * reps;

  SetLog copyWith({
    String? id,
    String? exerciseId,
    double? weightKg,
    int? reps,
    bool? done,
    bool? isPR,
    int? minutes,
    double? distanceKm,
  }) {
    return SetLog(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      done: done ?? this.done,
      isPR: isPR ?? this.isPR,
      minutes: minutes ?? this.minutes,
      distanceKm: distanceKm ?? this.distanceKm,
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
          other.isPR == isPR &&
          other.minutes == minutes &&
          other.distanceKm == distanceKm;

  @override
  int get hashCode =>
      Object.hash(id, exerciseId, weightKg, reps, done, isPR, minutes, distanceKm);

  @override
  String toString() =>
      'SetLog(id: $id, exerciseId: $exerciseId, ${weightKg}kg × $reps, done: $done, isPR: $isPR)';
}
