import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/watch_log.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/services/services.dart';

/// A PalService whose `chat` returns a scripted result or throws [error].
class _FakePal implements PalService {
  _FakePal({this.reply = 'Got it.', this.actions = const [], this.error});

  final String reply;
  final List<PalAction> actions;
  final Object? error;
  int chatCalls = 0;

  @override
  Future<PalAgenda> agenda({List<PlanFact> plan = const [], bool fresh = false}) async =>
      const PalAgenda();

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async {
    chatCalls++;
    if (error != null) throw error!;
    return PalChatResult(reply: reply, actions: actions);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _coffee = LogEntryAction(type: EntryType.money, title: 'Coffee', amount: -4.5);

/// The undo token as the relay hands it back: through the platform codec.
Object? _overTheWire(Object? token) {
  const codec = StandardMessageCodec();
  return codec.decodeMessage(codec.encodeMessage(token));
}

void main() {
  late SharedPreferences prefs;
  late LoopDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  /// A container on the shared [db]; a second one stands in for another engine.
  ProviderContainer engine(PalService pal) {
    final c = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(pal),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  WatchLog watchLog(PalService pal) => engine(pal).read(watchLogProvider);

  Future<List<Entry>> entries() => engine(_FakePal()).read(entryRepositoryProvider).getToday();

  group('log', () {
    test('a spend is saved and shown with today\'s spending against the budget', () async {
      await engine(_FakePal()).read(entryRepositoryProvider).insert(Entry(
            id: '',
            timestamp: clock.now(),
            type: EntryType.money,
            title: 'Lunch',
            amount: -14,
            source: EntrySource.manual,
          ));

      final reply = await watchLog(_FakePal(actions: const [_coffee])).log('Coffee with Minh, 4.50');

      expect(reply[WatchKeys.type], WatchKeys.result);
      expect(reply[WatchKeys.title], 'Logged');
      expect(reply[WatchKeys.item], 'Coffee');
      expect(reply[WatchKeys.amount], '−\$4.50');
      expect(reply[WatchKeys.detail], 'Spending today');
      expect(reply[WatchKeys.value], '\$18.50 of \$85');
      expect(reply[WatchKeys.fraction], closeTo(18.5 / 85, 1e-9));
      expect(reply[WatchKeys.undo], isNotNull);
      expect((await entries()).map((e) => e.title), contains('Coffee'));
    });

    test('a spend with no daily budget shows what was spent', () async {
      final c = engine(_FakePal(actions: const [_coffee]));
      await c.read(goalsRepositoryProvider).upsert(const Goals(dailyBudget: 0));

      final reply = await c.read(watchLogProvider).log('coffee 4.50');

      expect(reply[WatchKeys.detail], 'Spent today');
      expect(reply[WatchKeys.value], '\$4.50');
      expect(reply.containsKey(WatchKeys.fraction), isFalse);
    });

    test('a meal is saved and shown with its slot, kcal range and confidence', () async {
      final c = engine(_FakePal(actions: const [
        LogMealAction(
          name: '2 eggs',
          cal: IntRange(140, 160),
          confidence: NutritionConfidence.med,
          slot: 'Lunch',
        ),
      ]));

      final reply = await c.read(watchLogProvider).log('two eggs');

      expect(reply[WatchKeys.title], 'Logged · Lunch');
      expect(reply[WatchKeys.item], '2 eggs');
      expect(reply[WatchKeys.amount], '140–160');
      expect(reply[WatchKeys.unit], 'kcal');
      expect(reply[WatchKeys.detail], 'fair estimate');
      expect(reply[WatchKeys.bars], 2);
      expect(reply[WatchKeys.undo], isNotNull);
      final now = clock.now();
      final day = DateTime(now.year, now.month, now.day);
      final meals = await c
          .read(nutritionRepositoryProvider)
          .getMealsInRange(day, day.add(const Duration(days: 1)));
      expect(meals.map((m) => m.name), ['2 eggs']);
    });

    test('a question shows the answer, offers no undo and saves nothing', () async {
      final reply = await watchLog(_FakePal(reply: '\$18.50 of \$60 so far.'))
          .log('How much have I spent today?');

      expect(reply[WatchKeys.type], WatchKeys.result);
      expect(reply[WatchKeys.reply], '\$18.50 of \$60 so far.');
      expect(reply.containsKey(WatchKeys.undo), isFalse);
      expect(await entries(), isEmpty);
    });

    test('a goal change shows the answer and can be undone', () async {
      final reply = await watchLog(_FakePal(
        reply: 'Budget set to \$60.',
        actions: const [SetGoalAction(target: GoalTarget.dailyBudget, value: 60)],
      )).log('set my budget to 60');

      expect(reply[WatchKeys.reply], 'Budget set to \$60.');
      expect(reply[WatchKeys.undo], isNotNull);
    });

    test('Pal out of reach replies an error and saves nothing', () async {
      final reply = await watchLog(_FakePal(error: const PalException('offline'))).log('coffee 4.50');

      expect(reply[WatchKeys.error], "Pal couldn't reach the server");
      expect(await entries(), isEmpty);
    });

    test('Pal failing replies an error', () async {
      final reply = await watchLog(_FakePal(error: const PalException('boom', statusCode: 502)))
          .log('coffee 4.50');

      expect(reply[WatchKeys.error], "Pal couldn't answer that just now");
    });

    test('a timed-out chat replies an error and saves nothing', () async {
      final reply = await watchLog(_FakePal(error: TimeoutException('slow'))).log('coffee 4.50');

      expect(reply[WatchKeys.error], "Pal couldn't answer that just now");
      expect(await entries(), isEmpty);
    });

    test('blank text replies an error without calling Pal', () async {
      final pal = _FakePal(actions: const [_coffee]);

      final reply = await watchLog(pal).log('   ');

      expect(reply.containsKey(WatchKeys.error), isTrue);
      expect(pal.chatCalls, 0);
    });
  });

  group('undo', () {
    test('another engine can undo a spend from the token alone', () async {
      final logged = await watchLog(_FakePal(actions: const [_coffee])).log('coffee 4.50');

      final reply = await watchLog(_FakePal()).undo(_overTheWire(logged[WatchKeys.undo]));

      expect(reply[WatchKeys.type], WatchKeys.undone);
      expect(await entries(), isEmpty);
    });

    test('undoing a goal change puts the old value back', () async {
      final c = engine(_FakePal(
        actions: const [SetGoalAction(target: GoalTarget.dailyBudget, value: 60)],
      ));
      await c.read(goalsRepositoryProvider).upsert(const Goals(dailyBudget: 85));
      final logged = await c.read(watchLogProvider).log('set my budget to 60');
      expect((await c.read(goalsRepositoryProvider).get()).dailyBudget, 60);

      await watchLog(_FakePal()).undo(_overTheWire(logged[WatchKeys.undo]));

      expect((await c.read(goalsRepositoryProvider).get()).dailyBudget, 85);
    });

    test('undoing an entry already deleted on the phone still succeeds', () async {
      final logged = await watchLog(_FakePal(actions: const [_coffee])).log('coffee 4.50');
      final c = engine(_FakePal());
      for (final e in await entries()) {
        await c.read(entryRepositoryProvider).deleteById(e.id);
      }

      final reply = await c.read(watchLogProvider).undo(_overTheWire(logged[WatchKeys.undo]));

      expect(reply[WatchKeys.type], WatchKeys.undone);
    });

    test('a token it did not make replies an error', () async {
      final log = watchLog(_FakePal());

      expect((await log.undo(null))[WatchKeys.error], isNotNull);
      expect((await log.undo(const ['x']))[WatchKeys.error], isNotNull);
      expect((await log.undo(const [<String, Object>{}]))[WatchKeys.error], isNotNull);
    });
  });
}
