import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/pal_inbox_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

/// Builds a [PalNote] with sensible defaults; only the axes the tests care about
/// (category, unread, createdAt) are parameterized.
PalNote _note(
  String id, {
  required EntryType category,
  bool unread = true,
  DateTime? createdAt,
}) => PalNote(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 1),
  kind: NoteKind.spotted,
  category: category,
  icon: 'sparkle',
  title: 'Note $id',
  body: 'body',
  unread: unread,
);

/// Awaits the next [PalInboxState] emission satisfying [test] (a drift write
/// re-runs `watchNotes` asynchronously, so `.future` — which caches the first
/// emission — can't be re-read after a mutation).
Future<PalInboxState> _waitFor(
  ProviderContainer c,
  bool Function(PalInboxState) test,
) async {
  final current = c.read(palInboxControllerProvider).value;
  if (current != null && test(current)) return current;
  final completer = Completer<PalInboxState>();
  final sub = c.listen(palInboxControllerProvider, (_, next) {
    final v = next.value;
    if (v != null && test(v) && !completer.isCompleted) completer.complete(v);
  });
  try {
    return await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    sub.close();
  }
}

void main() {
  late LoopDatabase db;
  late PalNoteRepository repo;
  late ProviderContainer container;

  setUp(() {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    repo = PalNoteRepository(db);
    container = ProviderContainer(
      overrides: [loopDatabaseProvider.overrideWithValue(db)],
    );
    // keep the autoDispose streaming controller alive across awaits.
    container.listen(palInboxControllerProvider, (_, _) {});
    addTearDown(container.dispose);
    addTearDown(db.close);
  });

  test(
    'all filter shows every note newest-first; unreadCount counts unread',
    () async {
      await repo.insert(
        _note('a', category: EntryType.money, createdAt: DateTime(2026, 6, 1)),
      );
      await repo.insert(
        _note(
          'b',
          category: EntryType.move,
          unread: false,
          createdAt: DateTime(2026, 6, 2),
        ),
      );
      await repo.insert(
        _note(
          'c',
          category: EntryType.rituals,
          createdAt: DateTime(2026, 6, 3),
        ),
      );

      final state = await _waitFor(container, (s) => s.notes.length == 3);

      expect(state.filter, InboxFilter.all);
      // newest-first ordering from the repo is preserved.
      expect(state.visible.map((n) => n.id), ['c', 'b', 'a']);
      // a and c are unread, b is read.
      expect(state.unreadCount, 2);
    },
  );

  test('unread filter shows only unread notes', () async {
    await repo.insert(_note('read', category: EntryType.money, unread: false));
    await repo.insert(_note('unread', category: EntryType.move));

    await _waitFor(container, (s) => s.notes.length == 2);

    final notifier = container.read(palInboxControllerProvider.notifier);
    notifier.setFilter(InboxFilter.unread);

    final state = await _waitFor(
      container,
      (s) => s.filter == InboxFilter.unread,
    );
    expect(state.visible.map((n) => n.id), ['unread']);
  });

  test('category filters slice the list by EntryType', () async {
    await repo.insert(_note('m1', category: EntryType.money));
    await repo.insert(_note('m2', category: EntryType.money));
    await repo.insert(_note('mv', category: EntryType.move));
    await repo.insert(_note('r', category: EntryType.rituals));

    await _waitFor(container, (s) => s.notes.length == 4);
    final notifier = container.read(palInboxControllerProvider.notifier);

    notifier.setFilter(InboxFilter.money);
    var state = await _waitFor(container, (s) => s.filter == InboxFilter.money);
    expect(state.visible.map((n) => n.id), containsAll(['m1', 'm2']));
    expect(state.visible, hasLength(2));

    notifier.setFilter(InboxFilter.move);
    state = await _waitFor(container, (s) => s.filter == InboxFilter.move);
    expect(state.visible.map((n) => n.id), ['mv']);

    notifier.setFilter(InboxFilter.rituals);
    state = await _waitFor(container, (s) => s.filter == InboxFilter.rituals);
    expect(state.visible.map((n) => n.id), ['r']);
  });

  test('setFilter re-emits the filtered slice immediately', () async {
    await repo.insert(_note('m', category: EntryType.money));
    await repo.insert(_note('mv', category: EntryType.move));

    await _waitFor(container, (s) => s.notes.length == 2);
    final notifier = container.read(palInboxControllerProvider.notifier);

    notifier.setFilter(InboxFilter.move);

    // synchronous re-emission: the new state is readable without awaiting a
    // fresh DB stream event.
    final state = container.read(palInboxControllerProvider).value!;
    expect(state.filter, InboxFilter.move);
    expect(state.visible.map((n) => n.id), ['mv']);
  });

  test('markAllRead drops unreadCount to zero', () async {
    await repo.insert(_note('a', category: EntryType.money));
    await repo.insert(_note('b', category: EntryType.move));

    var state = await _waitFor(container, (s) => s.unreadCount == 2);
    expect(state.unreadCount, 2);

    await container.read(palInboxControllerProvider.notifier).markAllRead();

    state = await _waitFor(container, (s) => s.unreadCount == 0);
    expect(state.unreadCount, 0);
    expect(state.notes.every((n) => !n.unread), isTrue);
  });

  test('markRead clears the unread flag for a single note', () async {
    await repo.insert(_note('a', category: EntryType.money));
    await repo.insert(_note('b', category: EntryType.move));

    await _waitFor(container, (s) => s.unreadCount == 2);

    await container.read(palInboxControllerProvider.notifier).markRead('a');

    final state = await _waitFor(container, (s) => s.unreadCount == 1);
    expect(state.notes.firstWhere((n) => n.id == 'a').unread, isFalse);
    expect(state.notes.firstWhere((n) => n.id == 'b').unread, isTrue);
  });
}
