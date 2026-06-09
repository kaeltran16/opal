/// A personal record for an [Exercise]: the best logged `weight × reps`.
///
/// Corresponds to the handoff's `pr: {weight, reps}` sub-object. Optional on an
/// exercise (a never-performed lift has no PR).
class ExercisePR {
  const ExercisePR({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;

  /// Volume of the PR set: weight × reps.
  double get volumeKg => weightKg * reps;

  ExercisePR copyWith({double? weightKg, int? reps}) =>
      ExercisePR(weightKg: weightKg ?? this.weightKg, reps: reps ?? this.reps);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExercisePR &&
          other.weightKg == weightKg &&
          other.reps == reps;

  @override
  int get hashCode => Object.hash(weightKg, reps);

  @override
  String toString() => 'ExercisePR(${weightKg}kg × $reps)';
}

/// A catalog exercise (Exercise Library entry, screen 11).
///
/// Mirrors the prototype's exercise record `{id, name, group, muscle, sf,
/// equipment, pr}`. `group`/`muscle`/`equipment` are free-form strings here
/// (the prototype uses display strings like "Push" / "Chest" / "Barbell")
/// rather than a fixed enum, to stay faithful to the seed data shape.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.group,
    required this.muscle,
    required this.icon,
    this.equipment,
    this.pr,
  });

  /// Caller-supplied id (never self-generated).
  final String id;
  final String name;

  /// Filter group, e.g. "Push" / "Pull" / "Legs" / "Core" / "Cardio".
  final String group;

  /// Primary muscle, e.g. "Chest".
  final String muscle;

  /// SF Symbol name for the exercise.
  final String icon;

  /// Equipment label, e.g. "Barbell". Nullable.
  final String? equipment;

  /// Best recorded set for this exercise. Nullable (never performed).
  final ExercisePR? pr;

  Exercise copyWith({
    String? id,
    String? name,
    String? group,
    String? muscle,
    String? icon,
    String? equipment,
    ExercisePR? pr,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      muscle: muscle ?? this.muscle,
      icon: icon ?? this.icon,
      equipment: equipment ?? this.equipment,
      pr: pr ?? this.pr,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Exercise &&
          other.id == id &&
          other.name == name &&
          other.group == group &&
          other.muscle == muscle &&
          other.icon == icon &&
          other.equipment == equipment &&
          other.pr == pr;

  @override
  int get hashCode =>
      Object.hash(id, name, group, muscle, icon, equipment, pr);

  @override
  String toString() => 'Exercise(id: $id, name: $name, group: $group)';
}
