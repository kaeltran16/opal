import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/pal_composer_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/services/services.dart';

/// A PalService whose `chat` returns a scripted reply (or throws to simulate the
/// proxy being unreachable). Only `chat` is exercised; the rest are no-ops.
class _FakePal implements PalService {
  _FakePal({this.reply = 'Got it.', this.fails = false, this.actions = const []});
  final String reply;
  final bool fails;
  final List<PalAction> actions;
  final List<({List<PalMessage> history, String message})> chatCalls = [];

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async {
    chatCalls.add((history: history, message: message));
    if (fails) throw const PalException('unreachable');
    return PalChatResult(reply: reply, actions: actions);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerWith(LoopDatabase db, PalService pal) {
    final c = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(pal),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('seed', () {
    test('empty seed starts collapsed with no messages', () {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = containerWith(db, _FakePal());

      final state = container.read(palComposerControllerProvider());
      expect(state.messages, isEmpty);
      expect(state.expanded, isFalse);
      expect(state.isLoading, isFalse);
    });

    test('a non-empty seed expands, shows the user message, and fires a reply',
        () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final pal = _FakePal(reply: 'Seeded reply.');
      final container = containerWith(db, pal);

      // keep the auto-dispose provider alive so the seeded reply microtask
      // resolves against a live Ref (mirrors a mounted widget listening).
      container.listen(
        palComposerControllerProvider(seed: 'log my coffee'),
        (_, _) {},
      );

      // initial synchronous build: the seed message is present, loading.
      final initial =
          container.read(palComposerControllerProvider(seed: 'log my coffee'));
      expect(initial.messages, hasLength(1));
      expect(initial.messages.single.role, PalRole.user);
      expect(initial.messages.single.text, 'log my coffee');
      expect(initial.isLoading, isTrue);
      expect(initial.expanded, isTrue);

      // the microtask reply resolves after a pump.
      await Future<void>.delayed(Duration.zero);
      final after = container.read(palComposerControllerProvider(seed: 'log my coffee'));
      expect(after.isLoading, isFalse);
      expect(after.messages.last.role, PalRole.assistant);
      expect(after.messages.last.text, 'Seeded reply.');
      expect(pal.chatCalls.single.message, 'log my coffee');
      // history excludes the just-sent message.
      expect(pal.chatCalls.single.history, isEmpty);
    });
  });

  group('send', () {
    test('appends the user message then the assistant reply', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = containerWith(db, _FakePal(reply: 'Sure thing.'));
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('what did I spend today?');

      final state = container.read(palComposerControllerProvider());
      expect(state.messages.map((m) => m.role),
          [PalRole.user, PalRole.assistant]);
      expect(state.messages.first.text, 'what did I spend today?');
      expect(state.messages.last.text, 'Sure thing.');
      expect(state.isLoading, isFalse);
      expect(state.expanded, isTrue);
    });

    test('ignores empty / whitespace-only input', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final pal = _FakePal();
      final container = containerWith(db, pal);
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('   ');

      expect(container.read(palComposerControllerProvider()).messages, isEmpty);
      expect(pal.chatCalls, isEmpty);
    });

    test('passes prior turns as history on the second send', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final pal = _FakePal(reply: 'ok');
      final container = containerWith(db, pal);
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('first');
      await notifier.send('second');

      expect(pal.chatCalls, hasLength(2));
      expect(pal.chatCalls[0].history, isEmpty);
      // second call's history is the first user+assistant exchange.
      expect(pal.chatCalls[1].history.map((m) => m.text), ['first', 'ok']);
      expect(pal.chatCalls[1].message, 'second');
    });
  });

  group('offline behavior', () {
    test('a plain message reports the offline reply when Pal is unreachable',
        () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = containerWith(db, _FakePal(fails: true));
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('how am I doing?');

      final state = container.read(palComposerControllerProvider());
      expect(state.isLoading, isFalse);
      final reply = state.messages.last;
      expect(reply.role, PalRole.assistant);
      expect(reply.text, contains("couldn't reach the server"));
      // nothing was logged: no structured payload to fall back to.
      expect(await EntryRepository(db).getAll(), isEmpty);
    });

    test('a starter with a payload logs locally when Pal is unreachable',
        () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = containerWith(db, _FakePal(fails: true));
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.sendStarter(
        'Coffee \$4',
        const StarterEntry(
          type: EntryType.money,
          title: 'Coffee',
          amount: -4,
          category: 'Food',
        ),
      );

      // the entry was persisted offline...
      final stored = await EntryRepository(db).getAll();
      expect(stored, hasLength(1));
      expect(stored.single.title, 'Coffee');
      expect(stored.single.source, EntrySource.manual);

      // ...and the composer confirms it rather than reporting a failure.
      final reply =
          container.read(palComposerControllerProvider()).messages.last;
      expect(reply.text, contains('Logged Coffee'));
      expect(reply.text, contains('offline'));
    });

    test('a starter without a payload falls back to the offline reply',
        () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = containerWith(db, _FakePal(fails: true));
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.sendStarter('Ask me anything', null);

      expect(await EntryRepository(db).getAll(), isEmpty);
      final reply =
          container.read(palComposerControllerProvider()).messages.last;
      expect(reply.text, contains("couldn't reach the server"));
    });
  });

  group('undo', () {
    test('an action turn logs an entry and undo deletes it', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final pal = _FakePal(reply: 'Logged it.', actions: const [
        LogEntryAction(type: EntryType.move, durationMinutes: 30, title: 'Run'),
      ]);
      final container = containerWith(db, pal);
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('ran 30 min');
      expect(await EntryRepository(db).getAll(), hasLength(1));

      final idx = container.read(palComposerControllerProvider()).messages.length - 1;
      await notifier.undo(idx);

      expect(await EntryRepository(db).getAll(), isEmpty);
      expect(container.read(palComposerControllerProvider()).messages[idx].undone, isTrue);
    });

    test('set_daily_budget applies; undo restores the prior value', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final goals = GoalsRepository(db);
      await goals.upsert(const Goals(dailyBudget: 85));
      final pal = _FakePal(reply: 'Set to \$60.', actions: const [
        SetGoalAction(target: GoalTarget.dailyBudget, value: 60),
      ]);
      final container = containerWith(db, pal);
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('set my budget to 60');
      expect((await goals.get()).dailyBudget, 60);

      final idx = container.read(palComposerControllerProvider()).messages.length - 1;
      await notifier.undo(idx);
      expect((await goals.get()).dailyBudget, 85);
    });

    test('a non-action turn records no undo (undo is a no-op)', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = containerWith(db, _FakePal(reply: 'Just chatting.'));
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('how am I doing?');
      final idx = container.read(palComposerControllerProvider()).messages.length - 1;
      await notifier.undo(idx);

      expect(container.read(palComposerControllerProvider()).messages[idx].undone, isFalse);
    });
  });
}
