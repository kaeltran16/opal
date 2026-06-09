import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [Ritual]s, ordered by their explicit display [order].
class RitualRepository {
  RitualRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  /// All rituals sorted by their display order.
  Stream<List<Ritual>> watchRituals() {
    final q = _db.select(_db.rituals)
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  Future<List<Ritual>> getAll() async {
    final q = _db.select(_db.rituals)
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    final rows = await q.get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Inserts [ritual]; assigns a UUID if its id is empty. Returns the id.
  Future<String> insert(Ritual ritual) async {
    final id = ritual.id.isEmpty ? _uuid.v4() : ritual.id;
    await _db.into(_db.rituals).insert(ritual.copyWith(id: id).toCompanion());
    return id;
  }

  /// Upserts [ritual] (insert or replace by id).
  Future<void> upsert(Ritual ritual) =>
      _db.into(_db.rituals).insertOnConflictUpdate(ritual.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.rituals)..where((t) => t.id.equals(id))).go();
}
