import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [Subscription]s, ordered by next charge date (soonest first).
class SubscriptionRepository {
  SubscriptionRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  Stream<List<Subscription>> watchSubscriptions() {
    final q = _db.select(_db.subscriptions)
      ..orderBy([(t) => OrderingTerm.asc(t.nextChargeDate)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  Future<List<Subscription>> getAll() async {
    final q = _db.select(_db.subscriptions)
      ..orderBy([(t) => OrderingTerm.asc(t.nextChargeDate)]);
    final rows = await q.get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Inserts [sub]; assigns a UUID if its id is empty. Returns the id.
  Future<String> insert(Subscription sub) async {
    final id = sub.id.isEmpty ? _uuid.v4() : sub.id;
    await _db
        .into(_db.subscriptions)
        .insert(sub.copyWith(id: id).toCompanion());
    return id;
  }

  Future<void> upsert(Subscription sub) =>
      _db.into(_db.subscriptions).insertOnConflictUpdate(sub.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.subscriptions)..where((t) => t.id.equals(id))).go();
}
