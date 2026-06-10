import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes timeline [Entry]s. Reactive via `watch*` streams.
///
/// Models take caller-supplied ids; on insert this repository assigns a UUID
/// when the caller passes an empty id (the common case from UI/services).
class EntryRepository {
  EntryRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  /// All entries, newest first.
  Stream<List<Entry>> watchAll() {
    final q = _db.select(_db.entries)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  /// Entries whose timestamp falls on the same calendar day as [day]
  /// (defaults to now), newest first.
  Stream<List<Entry>> watchToday([DateTime? day]) {
    final d = day ?? DateTime.now();
    final start = DateTime(d.year, d.month, d.day);
    final end = start.add(const Duration(days: 1));
    return watchEntriesInRange(start, end);
  }

  /// Entries in the half-open range [from, to), newest first.
  Stream<List<Entry>> watchEntriesInRange(DateTime from, DateTime to) {
    final q = _db.select(_db.entries)
      ..where((t) => t.timestamp.isBiggerOrEqualValue(from) &
          t.timestamp.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  /// One-shot fetch of all entries, newest first.
  Future<List<Entry>> getAll() async {
    final q = _db.select(_db.entries)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
    final rows = await q.get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Inserts [entry]; assigns a UUID if [entry.id] is empty. Returns the id.
  Future<String> insert(Entry entry) async {
    final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
    await _db.into(_db.entries).insert(entry.copyWith(id: id).toCompanion());
    return id;
  }

  /// Whether an entry with this [sourceRef] already exists. Used to dedup
  /// email imports (`sourceRef` = the email message-id) so re-syncs don't
  /// re-import the same receipt.
  Future<bool> existsBySourceRef(String sourceRef) async {
    final q = _db.select(_db.entries)
      ..where((t) => t.sourceRef.equals(sourceRef))
      ..limit(1);
    return (await q.get()).isNotEmpty;
  }

  /// Upserts [entry] (insert or replace by id).
  Future<void> upsert(Entry entry) =>
      _db.into(_db.entries).insertOnConflictUpdate(entry.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.entries)..where((t) => t.id.equals(id))).go();
}
