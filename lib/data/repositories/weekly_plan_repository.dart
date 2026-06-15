import 'package:drift/drift.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes the weekly workout schedule (`weekday -> routineId`).
///
/// The schedule is a small fixed-cardinality table (at most 7 rows, one per ISO
/// weekday). Reads return assignments weekday-ascending; an absent weekday is a
/// Rest day, so callers treat "no row" and "row with null routineId" alike.
class WeeklyPlanRepository {
  WeeklyPlanRepository(this._db);

  final LoopDatabase _db;

  /// All assignments, weekday-ascending (1=Mon..7=Sun). Reactive.
  Stream<List<WeeklyPlanAssignment>> watchSchedule() {
    final q = _db.select(_db.weeklyPlanDays)
      ..orderBy([(t) => OrderingTerm.asc(t.weekday)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  /// One-shot fetch of all assignments, weekday-ascending.
  Future<List<WeeklyPlanAssignment>> getSchedule() async {
    final q = _db.select(_db.weeklyPlanDays)
      ..orderBy([(t) => OrderingTerm.asc(t.weekday)]);
    final rows = await q.get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Assigns [routineId] (null = Rest) to [weekday] (1=Mon..7=Sun), upserting
  /// the single row for that weekday.
  Future<void> upsert(int weekday, String? routineId) =>
      _db.into(_db.weeklyPlanDays).insertOnConflictUpdate(
            WeeklyPlanAssignment(weekday: weekday, routineId: routineId)
                .toCompanion(),
          );
}
