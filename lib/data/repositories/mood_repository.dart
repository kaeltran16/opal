import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [MoodCheckin]s. Reactive via `watch*`. Assigns a uuid on insert
/// when the caller passes an empty id.
class MoodRepository {
  MoodRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  Stream<List<MoodCheckin>> watchCheckinsForDay([DateTime? day]) {
    final d = day ?? DateTime.now();
    final start = DateTime(d.year, d.month, d.day);
    return watchCheckinsInRange(start, start.add(const Duration(days: 1)));
  }

  Stream<List<MoodCheckin>> watchCheckinsInRange(DateTime from, DateTime to) {
    final q = _db.select(_db.moodCheckins)
      ..where((t) =>
          t.timestamp.isBiggerOrEqualValue(from) &
          t.timestamp.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  Future<List<MoodCheckin>> getCheckinsInRange(DateTime from, DateTime to) async {
    final q = _db.select(_db.moodCheckins)
      ..where((t) =>
          t.timestamp.isBiggerOrEqualValue(from) &
          t.timestamp.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    return (await q.get()).map((r) => r.toModel()).toList();
  }

  Future<String> insert(MoodCheckin checkin) async {
    final id = checkin.id.isEmpty ? _uuid.v4() : checkin.id;
    await _db
        .into(_db.moodCheckins)
        .insert(checkin.copyWith(id: id).toCompanion());
    return id;
  }

  Future<void> upsert(MoodCheckin checkin) =>
      _db.into(_db.moodCheckins).insertOnConflictUpdate(checkin.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.moodCheckins)..where((t) => t.id.equals(id))).go();
}
