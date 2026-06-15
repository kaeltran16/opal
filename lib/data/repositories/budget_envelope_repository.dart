import 'package:drift/drift.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes per-category budget [BudgetEnvelope]s. Reactive via `watch*`.
///
/// Envelopes carry caller-supplied ids (seed `env-*` / a UUID for user rows).
class BudgetEnvelopeRepository {
  BudgetEnvelopeRepository(this._db);

  final LoopDatabase _db;

  /// All envelopes, position-ascending. Reactive.
  Stream<List<BudgetEnvelope>> watchEnvelopes() {
    final q = _db.select(_db.budgetEnvelopes)
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  /// One-shot fetch of all envelopes, position-ascending.
  Future<List<BudgetEnvelope>> getEnvelopes() async {
    final q = _db.select(_db.budgetEnvelopes)
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    final rows = await q.get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Upserts [envelope] (insert or replace by id).
  Future<void> upsert(BudgetEnvelope envelope) =>
      _db.into(_db.budgetEnvelopes).insertOnConflictUpdate(envelope.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.budgetEnvelopes)..where((t) => t.id.equals(id))).go();
}
