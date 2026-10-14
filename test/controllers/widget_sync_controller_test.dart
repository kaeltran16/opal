import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/controllers/widget_sync_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/services/widget_sync/widget_sync_service.dart';
import 'package:opal/util/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the most recent synced snapshot.
class _RecordingWidgetSync implements WidgetSyncService {
  WidgetSnapshot? last;

  @override
  Future<void> sync(WidgetSnapshot snapshot) async => last = snapshot;
}

RitualRoutine _routine(String id, List<String> stepIds) => RitualRoutine(
      id: id,
      name: id,
      time: '7:00 AM',
      tone: RitualTone.morning,
      icon: 'sun.max',
      blurb: '',
      steps: [
        for (final s in stepIds) RitualStep(id: s, title: s, note: '', icon: 'circle'),
      ],
    );

// two routines, one complete, against a stored target of 5: the widget must
// count routines, not the stored target.
TodayState _sampleState() => TodayState(
      entries: [
        Entry(id: '1', timestamp: DateTime(2026, 10, 13, 9), type: EntryType.money, title: 'Coffee', amount: -42.0, source: EntrySource.manual),
        Entry(id: '2', timestamp: DateTime(2026, 10, 13, 10), type: EntryType.move, title: 'Walk', duration: 30, calories: 18, source: EntrySource.manual),
        Entry(id: '3', timestamp: DateTime(2026, 10, 13, 8), type: EntryType.rituals, title: 'Meditate', ritualId: 'm1', source: EntrySource.manual),
      ],
      goals: const Goals(dailyBudget: 60, dailyMoveKcal: 40, dailyRitualTarget: 5),
      routines: [
        _routine('morning', ['m1']),
        _routine('evening', ['e1']),
      ],
    );

GlanceNumbers _numbers({
  double spent = 38,
  double budget = 60,
  int moveKcal = 310,
  int moveGoal = 500,
  int routinesDone = 2,
  int routinesTotal = 4,
}) =>
    GlanceNumbers(
      spent: spent,
      budget: budget,
      moveKcal: moveKcal,
      moveGoal: moveGoal,
      routinesDone: routinesDone,
      routinesTotal: routinesTotal,
      hasRoutines: routinesTotal > 0,
    );

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 10, 13, hour, minute);

List<(DateTime, String)> _schedule(WidgetRow row) =>
    [for (final s in row.states) (s.at, s.state)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, _RecordingWidgetSync)> startController() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final recorder = _RecordingWidgetSync();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      widgetSyncServiceProvider.overrideWithValue(recorder),
      todayStateProvider.overrideWith((ref) => Stream.value(_sampleState())),
    ]);
    addTearDown(container.dispose);

    // Explicit listener keeps the auto-dispose stream provider alive while it
    // emits; the controller's own listener then drives the sync call.
    final sub = container.listen(todayStateProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(widgetSyncControllerProvider); // instantiate -> sets listener
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return (container, recorder);
  }

  test('maps each todayState emission onto a sync call', () async {
    final now = _at(11);
    await withClock(Clock.fixed(now), () async {
      final (_, recorder) = await startController();

      final state = _sampleState();
      expect(recorder.last, isNotNull);
      expect(recorder.last!.toJson(),
          buildWidgetSnapshot(state.glance, Currency.usd, now).toJson());
      expect(recorder.last!.routines.value, '1 of 2 done');
      expect(recorder.last!.money.value, r'$18 left of $60');
    });
  });

  group('TodayState.glance', () {
    // a ritual entry logged before the routines lost their steps.
    final legacy = Entry(
      id: 'legacy',
      timestamp: DateTime(2026, 10, 13, 8),
      type: EntryType.rituals,
      title: 'Stretch',
      ritualId: 'gone',
      source: EntrySource.manual,
    );

    test('routines with no steps read none done', () {
      final n = TodayState(
        entries: [legacy],
        goals: const Goals(dailyRitualTarget: 5),
        routines: [_routine('stretch', const [])],
      ).glance;

      expect(n.routinesTotal, 0);
      expect(n.routinesDone, 0);
      expect(n.hasRoutines, isTrue);
    });

    test('no routines read none done and none set up', () {
      final n = TodayState(
        entries: [legacy],
        goals: const Goals(dailyRitualTarget: 5),
        routines: const [],
      ).glance;

      expect(n.routinesTotal, 0);
      expect(n.routinesDone, 0);
      expect(n.hasRoutines, isFalse);
    });
  });

  test('a currency change re-syncs with the new currency', () async {
    await withClock(Clock.fixed(_at(11)), () async {
      final (container, recorder) = await startController();

      await container
          .read(appSettingsControllerProvider.notifier)
          .setCurrency(Currency.vnd);

      expect(recorder.last!.money.value, contains(Currency.vnd.symbol));
      expect(recorder.last!.money.value, isNot(contains(r'$')));
    });
  });

  group('buildWidgetSnapshot', () {
    test('canvas watch at 11:00', () {
      final s = buildWidgetSnapshot(_numbers(), Currency.usd, _at(11));

      expect(s.move.value, '310 of 500 kcal');
      expect(s.routines.value, '2 of 4 done');
      expect(s.money.value, r'$22 left of $60');
      expect(s.move.fraction, closeTo(0.62, 1e-9));
      expect(s.routines.fraction, closeTo(0.5, 1e-9));
      expect(s.money.fraction, isNull);
      expect(s.money.states.first.state, 'watch');
      expect(s.money.states.first.word, 'Worth watching');
      expect(s.move.states.first.state, 'good');
      expect(s.routines.states.first.state, 'good');
    });

    test('canvas care at 11:00', () {
      final s = buildWidgetSnapshot(_numbers(spent: 64), Currency.usd, _at(11));

      expect(s.money.value, r'$4 over $60');
      expect(s.money.states.first.state, 'care');
      expect(s.money.states.first.word, 'Needs care');
    });

    test('canvas ahead at 11:00', () {
      final s = buildWidgetSnapshot(
        _numbers(moveKcal: 520, routinesDone: 4, spent: 29),
        Currency.usd,
        _at(11),
      );

      expect(s.move.value, '520 of 500 kcal');
      expect(s.move.fraction, 1.0);
      expect(s.move.states.first.state, 'thriving');
      expect(s.routines.value, '4 of 4 done');
      expect(s.routines.states.first.state, 'thriving');
      expect(s.money.value, r'$31 left of $60');
      expect(s.money.states.first.state, 'good');
    });

    test('schedule flips at the rule boundaries', () {
      final s = buildWidgetSnapshot(
        _numbers(moveKcal: 0, routinesDone: 0, spent: 30),
        Currency.usd,
        _at(7),
      );

      // behind pace by a quarter of the waking day from 10:45; under half from
      // 21:00 is care.
      final progress = [
        (_at(7), 'good'),
        (_at(10, 45), 'watch'),
        (_at(21), 'care'),
      ];
      expect(_schedule(s.move), progress);
      expect(_schedule(s.routines), progress);
      // half the budget spent stays a quarter ahead of pace through 10:45.
      expect(_schedule(s.money), [(_at(7), 'watch'), (_at(10, 46), 'good')]);
      expect(s.until, DateTime(2026, 10, 14));
    });

    test('one minute before midnight', () {
      final s = buildWidgetSnapshot(
        _numbers(),
        Currency.usd,
        DateTime(2026, 10, 13, 23, 59, 42),
      );

      for (final row in [s.move, s.routines, s.money]) {
        expect(row.states, hasLength(1));
        expect(row.states.single.at, _at(23, 59));
      }
      expect(s.until, DateTime(2026, 10, 14));
    });

    test('unset goals', () {
      final s = buildWidgetSnapshot(
        _numbers(moveGoal: 0, routinesDone: 0, routinesTotal: 0, budget: 0),
        Currency.usd,
        _at(11),
      );

      expect(s.move.value, '310 kcal');
      expect(s.move.fraction, 0);
      expect(s.routines.value, 'None today');
      expect(s.routines.fraction, 0);
      expect(s.money.value, 'No budget');
    });

    test('currency follows the setting', () {
      final s = buildWidgetSnapshot(
        _numbers(spent: 38000, budget: 60000),
        Currency.vnd,
        _at(11),
      );

      expect(s.money.value, contains(Currency.vnd.symbol));
      expect(s.money.value, isNot(contains(r'$')));
      expect(s.money.value,
          '${formatCurrency(22000, Currency.vnd)} left of ${formatCurrency(60000, Currency.vnd)}');
    });

    test('toJson matches the v2 contract', () {
      final s = buildWidgetSnapshot(
        _numbers(moveKcal: 0, routinesDone: 0, spent: 30),
        Currency.usd,
        _at(7),
      );
      final json = s.toJson();

      expect(json.keys, unorderedEquals(['until', 'move', 'routines', 'money']));
      expect(json['until'], DateTime(2026, 10, 14).millisecondsSinceEpoch ~/ 1000);
      final money = json['money']! as Map<String, Object?>;
      expect(money.containsKey('fraction'), isFalse);
      expect((json['move']! as Map<String, Object?>)['fraction'], 0.0);
      for (final key in ['move', 'routines', 'money']) {
        final row = json[key]! as Map<String, Object?>;
        expect(row['value'], isA<String>());
        final states = (row['states']! as List).cast<Map<String, Object?>>();
        expect(states.first['at'], _at(7).millisecondsSinceEpoch ~/ 1000);
        for (final st in states) {
          expect(st.keys, unorderedEquals(['at', 'state', 'word']));
          expect(st['at'], isA<int>());
          expect(st['at']! as int, lessThan(json['until']! as int));
        }
        for (var i = 1; i < states.length; i++) {
          expect(states[i]['at']! as int, greaterThan(states[i - 1]['at']! as int));
          expect(states[i]['state'], isNot(states[i - 1]['state']));
        }
      }
    });
  });
}
