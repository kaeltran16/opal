import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/mood_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/services.dart';

/// No-op haptics so controller actions don't crash on non-device platforms.
class _NoHaptics implements HapticsService {
  @override
  Future<void> light() async {}
  @override
  Future<void> medium() async {}
  @override
  Future<void> success() async {}
}

ProviderContainer _makeContainer(LoopDatabase db) => ProviderContainer(
      overrides: [
        loopDatabaseProvider.overrideWithValue(db),
        hapticsServiceProvider.overrideWithValue(_NoHaptics()),
      ],
    );

void main() {
  group('MoodController', () {
    test('empty state: todayLean defaults to 0.5, mostTag is null, week has 7 entries',
        () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      final container = _makeContainer(db);
      addTearDown(() async {
        container.dispose();
        await Future<void>.delayed(Duration.zero);
        await db.close();
      });

      // keep the autodispose stream provider alive while awaiting first emit
      container.listen(moodControllerProvider, (_, _) {});
      // invalidate so the stream rebuilds and its first emission reflects the
      // just-written rows — re-reading .future alone returns the stale initial
      // emission (the stream re-emit races this read).
      container.invalidate(moodControllerProvider);
      final state = await container.read(moodControllerProvider.future);

      expect(state.todayCheckins, isEmpty);
      expect(state.todayLean, 0.5);
      expect(state.mostTag, isNull);
      expect(state.lastCheckin, isNull);
      expect(state.week, hasLength(7));
      // all week bars have null value when no data
      expect(state.week.every((b) => b.value == null), isTrue);
      // last bar is today
      expect(state.week.last.isToday, isTrue);
    });

    test('logCheckin persists a row and re-emits state with todayLean + mostTag',
        () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      final container = _makeContainer(db);
      addTearDown(() async {
        container.dispose();
        await Future<void>.delayed(Duration.zero);
        await db.close();
      });

      container.listen(moodControllerProvider, (_, _) {});
      // await initial emit before calling action
      await container.read(moodControllerProvider.future);

      await container.read(moodControllerProvider.notifier).logCheckin(0.7, 'Calm');

      // verify persistence directly — avoids racing the stream re-emit
      final repo = container.read(moodRepositoryProvider);
      final now = DateTime.now();
      final checkins = await repo.getCheckinsInRange(
        DateTime(now.year, now.month, now.day),
        DateTime(now.year, now.month, now.day + 1),
      );
      expect(checkins, hasLength(1));
      expect(checkins.single.pleasantness, 0.7);
      expect(checkins.single.tag, 'Calm');
      expect(checkins.single.source, EntrySource.manual);

      // await the re-emit triggered by the insert
      // invalidate so the stream rebuilds and its first emission reflects the
      // just-written rows — re-reading .future alone returns the stale initial
      // emission (the stream re-emit races this read).
      container.invalidate(moodControllerProvider);
      final state = await container.read(moodControllerProvider.future);
      expect(state.todayCheckins, hasLength(1));
      expect(state.todayLean, closeTo(0.7, 0.001));
      expect(state.mostTag, 'Calm');
      expect(state.lastCheckin, isNotNull);
      expect(state.lastCheckin!.tag, 'Calm');
    });

    test('logCheckin with null tag: mostTag stays null', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      final container = _makeContainer(db);
      addTearDown(() async {
        container.dispose();
        await Future<void>.delayed(Duration.zero);
        await db.close();
      });

      container.listen(moodControllerProvider, (_, _) {});
      await container.read(moodControllerProvider.future);

      await container.read(moodControllerProvider.notifier).logCheckin(0.3, null);

      // invalidate so the stream rebuilds and its first emission reflects the
      // just-written rows — re-reading .future alone returns the stale initial
      // emission (the stream re-emit races this read).
      container.invalidate(moodControllerProvider);
      final state = await container.read(moodControllerProvider.future);
      expect(state.todayLean, closeTo(0.3, 0.001));
      expect(state.mostTag, isNull);
    });

    test('todayLean is mean of multiple check-ins', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      final container = _makeContainer(db);
      addTearDown(() async {
        container.dispose();
        await Future<void>.delayed(Duration.zero);
        await db.close();
      });

      container.listen(moodControllerProvider, (_, _) {});
      await container.read(moodControllerProvider.future);

      final notifier = container.read(moodControllerProvider.notifier);
      await notifier.logCheckin(0.2, 'Anxious');
      await notifier.logCheckin(0.8, 'Calm');
      await notifier.logCheckin(0.8, 'Calm');

      // invalidate so the stream rebuilds and its first emission reflects the
      // just-written rows — re-reading .future alone returns the stale initial
      // emission (the stream re-emit races this read).
      container.invalidate(moodControllerProvider);
      final state = await container.read(moodControllerProvider.future);
      // mean of 0.2, 0.8, 0.8 = 0.6
      expect(state.todayLean, closeTo(0.6, 0.001));
      // 'Calm' appears twice vs 'Anxious' once
      expect(state.mostTag, 'Calm');
      expect(state.todayCheckins, hasLength(3));
    });

    test('week bar for today has non-null value after logCheckin', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      final container = _makeContainer(db);
      addTearDown(() async {
        container.dispose();
        await Future<void>.delayed(Duration.zero);
        await db.close();
      });

      container.listen(moodControllerProvider, (_, _) {});
      await container.read(moodControllerProvider.future);

      await container.read(moodControllerProvider.notifier).logCheckin(0.6, null);

      // invalidate so the stream rebuilds and its first emission reflects the
      // just-written rows — re-reading .future alone returns the stale initial
      // emission (the stream re-emit races this read).
      container.invalidate(moodControllerProvider);
      final state = await container.read(moodControllerProvider.future);
      final todayBar = state.week.last;
      expect(todayBar.isToday, isTrue);
      expect(todayBar.value, isNotNull);
      expect(todayBar.value!, closeTo(0.6, 0.001));
      // prior 6 days should still be null (no data seeded for them)
      for (final bar in state.week.take(6)) {
        expect(bar.value, isNull);
      }
    });
  });
}
