import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';
import '../db/tables.dart' show GoalsTable;

/// Reads/writes the single [Goals] record.
///
/// If the row is absent (pre-seed / pre-onboarding), reads emit the model
/// defaults so the UI always has targets to render.
class GoalsRepository {
  GoalsRepository(this._db);

  final LoopDatabase _db;

  /// The current goals, defaulting to [Goals]'s defaults when unset.
  Stream<Goals> watchGoals() {
    final q = _db.select(_db.goalsTable)
      ..where((t) => t.id.equals(GoalsTable.singletonId));
    return q.watchSingleOrNull().map((row) => row?.toModel() ?? const Goals());
  }

  /// One-shot read, defaulting to [Goals]'s defaults when unset.
  Future<Goals> get() async {
    final row = await (_db.select(_db.goalsTable)
          ..where((t) => t.id.equals(GoalsTable.singletonId)))
        .getSingleOrNull();
    return row?.toModel() ?? const Goals();
  }

  /// Writes the single goals row (insert or replace).
  Future<void> save(Goals goals) =>
      _db.into(_db.goalsTable).insertOnConflictUpdate(goals.toCompanion());
}
