import 'set_log.dart';

/// Internal value-equality helper for ordered lists of [SetLog].
bool _listEquals(List<SetLog> a, List<SetLog> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A strength/cardio session with its logged sets.
///
/// Mirrors the handoff's `@Model class Workout`. In the handoff
/// `totalVolumeKg` and `prCount` are stored derived fields; here they are
/// computed getters over [sets] so they can never drift out of sync.
/// Cross-session aggregates (8-week volume trend, streaks) stay in the
/// repository layer — only intra-workout derivations live here.
class Workout {
  const Workout({
    required this.id,
    this.routineId,
    required this.name,
    required this.startedAt,
    this.endedAt,
    this.sets = const [],
  });

  /// Caller-supplied id (never self-generated).
  final String id;

  /// FK to [Routine.id]; null for a freestyle session.
  final String? routineId;

  /// Display name, e.g. "Push Day A".
  final String name;

  final DateTime startedAt;

  /// Null while the session is still active.
  final DateTime? endedAt;

  /// Ordered set logs for this session.
  final List<SetLog> sets;

  /// Sum of `weight × reps` over completed ([SetLog.done]) sets only.
  double get totalVolumeKg => sets
      .where((s) => s.done)
      .fold(0.0, (sum, s) => sum + s.volumeKg);

  /// Number of completed sets flagged as a personal record.
  int get prCount => sets.where((s) => s.done && s.isPR).length;

  /// Count of completed sets.
  int get completedSetCount => sets.where((s) => s.done).length;

  /// Elapsed/total duration, or null while still active.
  Duration? get duration => endedAt?.difference(startedAt);

  /// True once the session has ended.
  bool get isComplete => endedAt != null;

  Workout copyWith({
    String? id,
    String? routineId,
    String? name,
    DateTime? startedAt,
    DateTime? endedAt,
    List<SetLog>? sets,
  }) {
    return Workout(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      sets: sets ?? this.sets,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workout &&
          other.id == id &&
          other.routineId == routineId &&
          other.name == name &&
          other.startedAt == startedAt &&
          other.endedAt == endedAt &&
          _listEquals(other.sets, sets);

  @override
  int get hashCode => Object.hash(
        id,
        routineId,
        name,
        startedAt,
        endedAt,
        Object.hashAll(sets),
      );

  @override
  String toString() =>
      'Workout(id: $id, name: $name, sets: ${sets.length}, volume: ${totalVolumeKg}kg, PRs: $prCount)';
}
