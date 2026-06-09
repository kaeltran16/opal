import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [Routine]s with their owned ordered [RoutineExercise]s.
class RoutineRepository {
  RoutineRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  /// All routines (alphabetical), each with its exercise slots in order.
  Stream<List<Routine>> watchRoutines() {
    final q = _db.select(_db.routines)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q.watch().asyncMap((rows) async {
      final result = <Routine>[];
      for (final row in rows) {
        result.add(routineFromRow(row, await _loadExercises(row.id)));
      }
      return result;
    });
  }

  /// One-shot fetch of a single routine (with exercises), or null.
  Future<Routine?> getById(String id) async {
    final row = await (_db.select(_db.routines)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return routineFromRow(row, await _loadExercises(id));
  }

  Future<List<RoutineExercise>> _loadExercises(String routineId) async {
    final q = _db.select(_db.routineExercises)
      ..where((t) => t.routineId.equals(routineId))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    final rows = await q.get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Inserts [routine] and its exercise slots in one transaction.
  /// Assigns UUIDs to the routine and/or any slot with an empty id.
  Future<String> insert(Routine routine) async {
    final routineId = routine.id.isEmpty ? _uuid.v4() : routine.id;
    await _db.transaction(() async {
      await _db
          .into(_db.routines)
          .insert(routine.copyWith(id: routineId).toCompanion());
      for (final ex in routine.exercises) {
        final exId = ex.id.isEmpty ? _uuid.v4() : ex.id;
        await _db
            .into(_db.routineExercises)
            .insert(ex.copyWith(id: exId).toCompanion(routineId));
      }
    });
    return routineId;
  }

  Future<void> deleteById(String id) =>
      (_db.delete(_db.routines)..where((t) => t.id.equals(id))).go();
}
