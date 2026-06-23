import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [SleepNight]s. Read-only to the user — only the sleep sync and
/// the seeder write here. Reactive via `watch*`. Assigns a uuid on insert when
/// the caller passes an empty id.
class SleepRepository {
  SleepRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  Stream<List<SleepNight>> watchNightsInRange(DateTime from, DateTime to) {
    final q = _db.select(_db.sleepNights)
      ..where((t) =>
          t.night.isBiggerOrEqualValue(from) &
          t.night.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.night)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  Future<List<SleepNight>> getNightsInRange(DateTime from, DateTime to) async {
    final q = _db.select(_db.sleepNights)
      ..where((t) =>
          t.night.isBiggerOrEqualValue(from) &
          t.night.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.night)]);
    return (await q.get()).map((r) => r.toModel()).toList();
  }

  Future<String> insert(SleepNight night) async {
    final id = night.id.isEmpty ? _uuid.v4() : night.id;
    await _db.into(_db.sleepNights).insert(night.copyWith(id: id).toCompanion());
    return id;
  }

  Future<void> upsert(SleepNight night) =>
      _db.into(_db.sleepNights).insertOnConflictUpdate(night.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.sleepNights)..where((t) => t.id.equals(id))).go();
}
