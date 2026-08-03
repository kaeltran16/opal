import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/sleep_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/util/dates.dart';

/// Build a minimal [SleepNight] for testing with only the fields that vary.
SleepNight _night({
  required DateTime night,
  required int asleepMinutes,
  int wakes = 1,
}) =>
    SleepNight(
      id: '',
      night: night,
      asleepMinutes: asleepMinutes,
      inBedMinutes: asleepMinutes + 20,
      bedtime: '23:00',
      wake: '07:00',
      deepMinutes: 60,
      remMinutes: 90,
      coreMinutes: asleepMinutes - 150,
      awakeMinutes: 20,
      wakes: wakes,
      source: EntrySource.health,
    );

/// Nights ascending from [base], one per day. Ascending order is the
/// repository's guarantee and [deriveSleepState] relies on it.
List<SleepNight> _nights(DateTime base, List<int> asleepMinutes) => [
      for (var i = 0; i < asleepMinutes.length; i++)
        _night(
          night: base.add(Duration(days: i)),
          asleepMinutes: asleepMinutes[i],
        ),
    ];

void main() {
  // deriveSleepState is pure, so absolute dates are safe here: no window is
  // applied at this layer. The 30-day window belongs to build() and is tested
  // separately, with relative fixtures.
  group('deriveSleepState', () {
    test('usualMinutes is the median of the nights', () {
      final state = deriveSleepState(
        _nights(DateTime(2026, 6, 19), [360, 390, 420, 450, 480]),
      );

      expect(state.usualMinutes, 420,
          reason: 'median of [360,390,420,450,480] is 420');
      expect(state.syncedNights, 5);
      // lastNight is the most recent (ascending → .last)
      expect(state.lastNight?.asleepMinutes, 480);
      expect(state.week.length, 5,
          reason: 'fewer than 7 nights → all 5 returned');
    });

    test('usualMinutes averages the two middle values for an even count', () {
      final state = deriveSleepState(
        _nights(DateTime(2026, 6, 20), [400, 420, 440, 460]),
      );

      expect(state.usualMinutes, 430,
          reason: 'median of [400,420,440,460] is (420+440)/2 = 430');
    });

    test('syncedNights == 2 satisfies the needs-sync boundary (< 3)', () {
      final state = deriveSleepState(
        _nights(DateTime(2026, 6, 22), [420, 390]),
      );

      expect(state.syncedNights, 2);
      expect(state.syncedNights < 3, isTrue, reason: 'needs-sync threshold');
    });

    test('empty input has no lastNight, 0 usualMinutes, empty read', () {
      final state = deriveSleepState(const []);

      expect(state.lastNight, isNull);
      expect(state.usualMinutes, 0);
      expect(state.read, '');
      expect(state.syncedNights, 0);
      expect(state.week, isEmpty);
      expect(state.month, isEmpty);
    });

    test('week caps at the last 7 nights when more are supplied', () {
      final state = deriveSleepState(
        _nights(DateTime(2026, 6, 15),
            [400, 405, 410, 415, 420, 425, 430, 435]),
      );

      expect(state.week.length, 7);
      // last bar corresponds to the most recent night → isToday = true
      expect(state.week.last.isToday, isTrue);
      expect(state.week.first.minutes, 405,
          reason: 'the oldest of 8 nights is dropped from the strip');
    });
  });

  // The one behaviour that belongs to the provider rather than the pure
  // function. Fixtures are RELATIVE to now on purpose: absolute dates here
  // would rot the moment they fell outside the window — exactly what broke
  // every test in this file before.
  test('build() excludes nights older than the 30-day window', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [loopDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final repo = container.read(sleepRepositoryProvider);
    final today = startOfDay(DateTime.now());
    await repo.insert(_night(
      night: today.subtract(const Duration(days: 40)),
      asleepMinutes: 300,
    ));
    await repo.insert(_night(
      night: today.subtract(const Duration(days: 2)),
      asleepMinutes: 450,
    ));

    container.listen(sleepControllerProvider, (_, _) {});
    final state = await container.read(sleepControllerProvider.future);

    expect(state.syncedNights, 1,
        reason: 'the 40-day-old night is outside the 30-day window');
    expect(state.lastNight?.asleepMinutes, 450);
  });
}
