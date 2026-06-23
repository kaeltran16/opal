import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/sleep_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

ProviderContainer _makeContainer(LoopDatabase db) => ProviderContainer(
      overrides: [
        loopDatabaseProvider.overrideWithValue(db),
      ],
    );

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

void main() {
  // 5 nights with known asleepMinutes: [360, 390, 420, 450, 480]
  // Sorted: [360, 390, 420, 450, 480], length=5 (odd), median = index 2 = 420.
  test('usualMinutes is the median of seeded nights', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = _makeContainer(db);
    addTearDown(() async {
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final repo = container.read(sleepRepositoryProvider);
    final base = DateTime(2026, 6, 19); // well within a 30-day window
    await repo.insert(_night(night: base, asleepMinutes: 360));
    await repo.insert(_night(night: base.add(const Duration(days: 1)), asleepMinutes: 390));
    await repo.insert(_night(night: base.add(const Duration(days: 2)), asleepMinutes: 420));
    await repo.insert(_night(night: base.add(const Duration(days: 3)), asleepMinutes: 450));
    await repo.insert(_night(night: base.add(const Duration(days: 4)), asleepMinutes: 480));

    container.listen(sleepControllerProvider, (_, _) {});
    final state = await container.read(sleepControllerProvider.future);

    expect(state.usualMinutes, 420,
        reason: 'median of [360,390,420,450,480] is 420');
    expect(state.syncedNights, 5);
    // lastNight is the most recent (ascending → .last)
    expect(state.lastNight?.asleepMinutes, 480);
    expect(state.week.length, 5, reason: 'fewer than 7 nights → all 5 returned');
  });

  // even-count median: 4 nights [400, 420, 440, 460]
  // sorted: [400, 420, 440, 460], mid=2, (420+440)/2 = 430
  test('usualMinutes uses average of two middle values for even count', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = _makeContainer(db);
    addTearDown(() async {
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final repo = container.read(sleepRepositoryProvider);
    final base = DateTime(2026, 6, 20);
    await repo.insert(_night(night: base, asleepMinutes: 400));
    await repo.insert(_night(night: base.add(const Duration(days: 1)), asleepMinutes: 420));
    await repo.insert(_night(night: base.add(const Duration(days: 2)), asleepMinutes: 440));
    await repo.insert(_night(night: base.add(const Duration(days: 3)), asleepMinutes: 460));

    container.listen(sleepControllerProvider, (_, _) {});
    final state = await container.read(sleepControllerProvider.future);

    expect(state.usualMinutes, 430,
        reason: 'median of [400,420,440,460] is (420+440)/2 = 430');
  });

  test('syncedNights == 2 satisfies the needs-sync boundary (< 3)', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = _makeContainer(db);
    addTearDown(() async {
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final repo = container.read(sleepRepositoryProvider);
    final base = DateTime(2026, 6, 22);
    await repo.insert(_night(night: base, asleepMinutes: 420));
    await repo.insert(_night(night: base.add(const Duration(days: 1)), asleepMinutes: 390));

    container.listen(sleepControllerProvider, (_, _) {});
    final state = await container.read(sleepControllerProvider.future);

    expect(state.syncedNights, 2);
    expect(state.syncedNights < 3, isTrue, reason: 'needs-sync threshold');
  });

  test('empty state has no lastNight, 0 usualMinutes, empty read', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = _makeContainer(db);
    addTearDown(() async {
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    container.listen(sleepControllerProvider, (_, _) {});
    final state = await container.read(sleepControllerProvider.future);

    expect(state.lastNight, isNull);
    expect(state.usualMinutes, 0);
    expect(state.read, '');
    expect(state.syncedNights, 0);
    expect(state.week, isEmpty);
    expect(state.month, isEmpty);
  });

  // week strip: with 8 nights seeded, only the last 7 appear in [week].
  test('week contains at most 7 entries even with more nights seeded', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = _makeContainer(db);
    addTearDown(() async {
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final repo = container.read(sleepRepositoryProvider);
    final base = DateTime(2026, 6, 15);
    for (var i = 0; i < 8; i++) {
      await repo.insert(_night(
        night: base.add(Duration(days: i)),
        asleepMinutes: 400 + i * 5,
      ));
    }

    container.listen(sleepControllerProvider, (_, _) {});
    final state = await container.read(sleepControllerProvider.future);

    expect(state.week.length, 7);
    // last bar corresponds to the most recent night → isToday = true
    expect(state.week.last.isToday, isTrue);
  });
}
