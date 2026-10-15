import 'package:clock/clock.dart';
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
    final (start, end) = _dayRange(day);
    return watchEntriesInRange(start, end);
  }

  /// One-shot fetch of [watchToday]'s entries. A single read should not go
  /// through a stream: `.first` on a drift select stream waits on the
  /// subscription's cancel future, which completes only on a real event-loop
  /// turn, so it never settles under a widget test's fake async.
  Future<List<Entry>> getToday([DateTime? day]) {
    final (start, end) = _dayRange(day);
    return getEntriesInRange(start, end);
  }

  /// The half-open calendar day around [day] (defaults to now).
  static (DateTime, DateTime) _dayRange(DateTime? day) {
    final d = day ?? clock.now();
    final start = DateTime(d.year, d.month, d.day);
    return (start, start.add(const Duration(days: 1)));
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

  /// One-shot fetch of entries in the half-open range [from, to), newest first.
  /// For reads that don't need to be reactive (e.g. a closed prior month).
  Future<List<Entry>> getEntriesInRange(DateTime from, DateTime to) async {
    final q = _db.select(_db.entries)
      ..where((t) => t.timestamp.isBiggerOrEqualValue(from) &
          t.timestamp.isSmallerThanValue(to))
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
  /// email imports (`sourceRef` = `EmailImportItem.dedupRef`) so re-syncs
  /// don't re-import the same receipt.
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
