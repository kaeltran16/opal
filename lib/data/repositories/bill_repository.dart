import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [Bill]s, ordered by due date (soonest first).
class BillRepository {
  BillRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  Stream<List<Bill>> watchBills() {
    final q = _db.select(_db.bills)
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  Future<List<Bill>> getAll() async {
    final q = _db.select(_db.bills)
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    final rows = await q.get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Inserts [bill]; assigns a UUID if its id is empty. Returns the id.
  Future<String> insert(Bill bill) async {
    final id = bill.id.isEmpty ? _uuid.v4() : bill.id;
    await _db.into(_db.bills).insert(bill.copyWith(id: id).toCompanion());
    return id;
  }

  Future<void> upsert(Bill bill) =>
      _db.into(_db.bills).insertOnConflictUpdate(bill.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.bills)..where((t) => t.id.equals(id))).go();
}
