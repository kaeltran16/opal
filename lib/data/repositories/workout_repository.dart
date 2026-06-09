import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [Workout]s with their owned child [SetLog]s.
///
/// A workout and its sets are persisted together; reads reassemble the
/// aggregate so callers above the repository never see drift rows.
class WorkoutRepository {
  WorkoutRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  /// All workouts (newest start first), each with its sets in stored order.
  Stream<List<Workout>> watchWorkouts() {
    final workoutQ = _db.select(_db.workouts)
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    return workoutQ.watch().asyncMap((rows) async {
      final result = <Workout>[];
      for (final row in rows) {
        result.add(workoutFromRow(row, await _loadSets(row.id)));
      }
      return result;
    });
  }

  /// One-shot fetch of a single workout (with sets), or null.
  Future<Workout?> getById(String id) async {
    final row = await (_db.select(_db.workouts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return workoutFromRow(row, await _loadSets(id));
  }

  Future<List<SetLog>> _loadSets(String workoutId) async {
    final q = _db.select(_db.setLogs)
      ..where((t) => t.workoutId.equals(workoutId))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    final rows = await q.get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Inserts [workout] and all its [SetLog]s in one transaction.
  /// Assigns a UUID to the workout and/or any set with an empty id.
  /// Returns the workout id.
  Future<String> insert(Workout workout) async {
    final workoutId = workout.id.isEmpty ? _uuid.v4() : workout.id;
    await _db.transaction(() async {
      await _db
          .into(_db.workouts)
          .insert(workout.copyWith(id: workoutId).toCompanion());
      for (var i = 0; i < workout.sets.length; i++) {
        final set = workout.sets[i];
        final setId = set.id.isEmpty ? _uuid.v4() : set.id;
        await _db
            .into(_db.setLogs)
            .insert(set.copyWith(id: setId).toCompanion(workoutId, i));
      }
    });
    return workoutId;
  }

  /// Deletes a workout and (via cascade) its sets.
  Future<void> deleteById(String id) =>
      (_db.delete(_db.workouts)..where((t) => t.id.equals(id))).go();
}
