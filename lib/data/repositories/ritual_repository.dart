import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [RitualRoutine]s and their ordered [RitualStep]s.
///
/// Routines are ordered by their display [RitualRoutine.order]; steps by their
/// position within a routine. Step *completion* is NOT stored here — it lives
/// as ritual-type `Entry` rows (see `RitualsController`), the single source of
/// truth shared with the Today rings.
class RitualRepository {
  RitualRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  /// All routines (with steps), display-ordered. Re-emits on any change to
  /// either the routines or steps tables.
  Stream<List<RitualRoutine>> watchRoutines() {
    final routinesQ = _db.select(_db.ritualRoutines)
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    final stepsQ = _db.select(_db.ritualSteps)
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return routinesQ.watch().asyncMap((routineRows) async {
      final stepRows = await stepsQ.get();
      return _assemble(routineRows, stepRows);
    });
  }

  /// One-shot read of all routines (with steps), display-ordered.
  Future<List<RitualRoutine>> getAll() async {
    final routinesQ = _db.select(_db.ritualRoutines)
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    final stepsQ = _db.select(_db.ritualSteps)
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    final routineRows = await routinesQ.get();
    final stepRows = await stepsQ.get();
    return _assemble(routineRows, stepRows);
  }

  List<RitualRoutine> _assemble(
    List<RitualRoutineRow> routineRows,
    List<RitualStepRow> stepRows,
  ) {
    final byRoutine = <String, List<RitualStep>>{};
    for (final s in stepRows) {
      (byRoutine[s.routineId] ??= <RitualStep>[]).add(s.toModel());
    }
    return routineRows
        .map((r) => ritualRoutineFromRow(r, byRoutine[r.id] ?? const []))
        .toList();
  }

  /// Upserts [routine] and replaces its full ordered step set in one
  /// transaction. Assigns a UUID to the routine and to any step with an empty
  /// id; step positions follow list order. Returns the routine id.
  Future<String> upsertRoutine(RitualRoutine routine) async {
    final routineId = routine.id.isEmpty ? _uuid.v4() : routine.id;
    await _db.transaction(() async {
      await _db
          .into(_db.ritualRoutines)
          .insertOnConflictUpdate(routine.copyWith(id: routineId).toCompanion());
      // Replace steps wholesale so reorders/removals are reflected exactly.
      await (_db.delete(_db.ritualSteps)
            ..where((t) => t.routineId.equals(routineId)))
          .go();
      for (var i = 0; i < routine.steps.length; i++) {
        final step = routine.steps[i];
        final stepId = step.id.isEmpty ? _uuid.v4() : step.id;
        await _db
            .into(_db.ritualSteps)
            .insert(step.copyWith(id: stepId).toCompanion(routineId, i));
      }
    });
    return routineId;
  }

  /// Deletes a routine (its steps cascade via FK).
  Future<void> deleteRoutine(String id) =>
      (_db.delete(_db.ritualRoutines)..where((t) => t.id.equals(id))).go();

  /// Persists a new routine display order: writes each routine's row with its
  /// current [RitualRoutine.order] (steps untouched). Callers pass the list in
  /// the desired order with positions assigned.
  Future<void> reorderRoutines(List<RitualRoutine> ordered) =>
      _db.transaction(() async {
        for (final r in ordered) {
          await _db
              .into(_db.ritualRoutines)
              .insertOnConflictUpdate(r.toCompanion());
        }
      });
}
