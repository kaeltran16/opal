import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/pal_note_repository.dart';
import 'package:opal/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoopDatabase db;
  late PalNoteRepository repo;

  setUp(() {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    repo = PalNoteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  PalNote note({
    required String id,
    required DateTime createdAt,
    NoteKind kind = NoteKind.nudge,
    EntryType category = EntryType.money,
    bool unread = true,
  }) => PalNote(
    id: id,
    createdAt: createdAt,
    kind: kind,
    category: category,
    icon: 'sparkles',
    title: 'Title $id',
    body: 'Body $id',
    unread: unread,
  );

  group('PalNoteRepository', () {
    test('insert assigns a UUID when id is empty', () async {
      final id = await repo.insert(
        note(id: '', createdAt: DateTime(2026, 6, 9)),
      );
      expect(id, isNotEmpty);
      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.single.id, id);
    });

    test('round-trips all fields on insert', () async {
      final original = PalNote(
        id: 'n1',
        createdAt: DateTime(2026, 6, 9, 8, 30),
        kind: NoteKind.reminder,
        category: EntryType.rituals,
        icon: 'bell.fill',
        title: 'Drink water',
        body: 'You logged less today.',
        actionLabel: 'Log now',
        unread: false,
      );
      await repo.insert(original);
      final loaded = (await repo.getAll()).single;
      expect(loaded, original);
    });

    test('getAll returns notes newest first', () async {
      await repo.insert(note(id: 'old', createdAt: DateTime(2026, 6, 1)));
      await repo.insert(note(id: 'new', createdAt: DateTime(2026, 6, 9)));
      await repo.insert(note(id: 'mid', createdAt: DateTime(2026, 6, 5)));
      final all = await repo.getAll();
      expect(all.map((n) => n.id), ['new', 'mid', 'old']);
    });

    test('watchNotes emits newest first and reacts to inserts', () async {
      final stream = repo.watchNotes();
      expect(await stream.first, isEmpty);

      await repo.insert(note(id: 'a', createdAt: DateTime(2026, 6, 1)));
      await repo.insert(note(id: 'b', createdAt: DateTime(2026, 6, 9)));

      final next = await stream.firstWhere((rows) => rows.length == 2);
      expect(next.map((n) => n.id), ['b', 'a']);
    });

    test('upsert updates an existing note in place', () async {
      await repo.insert(note(id: 'n1', createdAt: DateTime(2026, 6, 9)));
      await repo.upsert(
        note(
          id: 'n1',
          createdAt: DateTime(2026, 6, 9),
        ).copyWith(title: 'Edited'),
      );
      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.single.title, 'Edited');
    });

    test('markRead clears unread for one note only', () async {
      await repo.insert(note(id: 'a', createdAt: DateTime(2026, 6, 9)));
      await repo.insert(note(id: 'b', createdAt: DateTime(2026, 6, 8)));

      await repo.markRead('a');

      final byId = {for (final n in await repo.getAll()) n.id: n.unread};
      expect(byId['a'], isFalse);
      expect(byId['b'], isTrue);
    });

    test('markRead is a no-op for an absent id', () async {
      await repo.insert(note(id: 'a', createdAt: DateTime(2026, 6, 9)));
      await repo.markRead('missing');
      expect((await repo.getAll()).single.unread, isTrue);
    });

    test('markAllRead clears unread on every note', () async {
      await repo.insert(note(id: 'a', createdAt: DateTime(2026, 6, 9)));
      await repo.insert(note(id: 'b', createdAt: DateTime(2026, 6, 8)));

      await repo.markAllRead();

      final all = await repo.getAll();
      expect(all.every((n) => !n.unread), isTrue);
    });

    test('deleteById removes only the targeted note', () async {
      await repo.insert(note(id: 'a', createdAt: DateTime(2026, 6, 9)));
      await repo.insert(note(id: 'b', createdAt: DateTime(2026, 6, 8)));

      await repo.deleteById('a');

      final all = await repo.getAll();
      expect(all.map((n) => n.id), ['b']);
    });
  });
}
