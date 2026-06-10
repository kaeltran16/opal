import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [PalNote]s, newest first.
class PalNoteRepository {
  PalNoteRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  Stream<List<PalNote>> watchNotes() {
    final q = _db.select(_db.palNotes)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  Future<List<PalNote>> getAll() async {
    final q = _db.select(_db.palNotes)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final rows = await q.get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Inserts [note]; assigns a UUID if its id is empty. Returns the id.
  Future<String> insert(PalNote note) async {
    final id = note.id.isEmpty ? _uuid.v4() : note.id;
    await _db.into(_db.palNotes).insert(note.copyWith(id: id).toCompanion());
    return id;
  }

  Future<void> upsert(PalNote note) =>
      _db.into(_db.palNotes).insertOnConflictUpdate(note.toCompanion());

  /// Marks a single note read (no-op if absent).
  Future<void> markRead(String id) => (_db.update(_db.palNotes)
        ..where((t) => t.id.equals(id)))
      .write(const PalNotesCompanion(unread: Value(false)));

  /// Marks every note read.
  Future<void> markAllRead() => (_db.update(_db.palNotes))
      .write(const PalNotesCompanion(unread: Value(false)));

  Future<void> deleteById(String id) =>
      (_db.delete(_db.palNotes)..where((t) => t.id.equals(id))).go();
}
