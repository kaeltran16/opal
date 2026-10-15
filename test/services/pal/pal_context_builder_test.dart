import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_context_builder.dart';
import 'package:opal/util/format.dart';

void main() {
  test('buildChatContext includes hourOfDay and weekday from now', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: const Goals(dailyBudget: 50, dailyMoveKcal: 400, dailyRitualTarget: 3),
      todayEntries: const [],
      weekEntries: const [],
      moveStreakDays: 0,
      now: DateTime(2026, 6, 20, 8), // Saturday 08:00
    );
    expect(ctx['hourOfDay'], 8);
    expect(ctx['weekday'], DateTime.saturday); // 6
  });

  test('buildChatContext with no routines sends a ritual goal of 0, not the stored 3', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: const Goals(dailyBudget: 50, dailyMoveKcal: 400, dailyRitualTarget: 3),
      todayEntries: const [],
      weekEntries: const [],
      moveStreakDays: 0,
      now: DateTime(2026, 6, 20, 8),
    );
    expect(ctx['ritualGoal'], 0);
  });

  test('buildChatContext carries the currency descriptor and formats entries with it', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: const Goals(dailyBudget: 50, dailyMoveKcal: 400, dailyRitualTarget: 3),
      todayEntries: [
        Entry(id: '1', timestamp: DateTime(2026, 6, 20, 8), type: EntryType.money,
            title: 'Coffee', amount: -5, source: EntrySource.manual),
      ],
      weekEntries: const [],
      moveStreakDays: 0,
      currency: Currency.vnd,
      now: DateTime(2026, 6, 20, 8),
    );
    expect(ctx['currency'], Currency.vnd.toWire());
    expect((ctx['todayEntries'] as List).single, contains('₫'));
  });

  test('the post-workout context carries timed minutes and km', () {
    Workout w(List<SetLog> sets) => Workout(
        id: 'w', name: 'Run', startedAt: DateTime(2026, 10, 15, 7), sets: sets);
    const run = SetLog(
        id: 't',
        exerciseId: 'treadmill',
        weightKg: 0,
        reps: 0,
        minutes: 20,
        distanceKm: 3.2,
        done: true);

    final ctx = buildPostWorkoutContext(
        workout: w(const [run]), lastSessionVolumeKg: null, daysAgoLastSession: null);
    expect(ctx['minutes'], 20);
    expect(ctx['km'], 3.2);
    expect(ctx['volumeKg'], 0);

    final strength = buildPostWorkoutContext(
        workout: w(const [
          SetLog(id: 'b', exerciseId: 'bench', weightKg: 60, reps: 5, done: true),
        ]),
        lastSessionVolumeKg: null,
        daysAgoLastSession: null);
    expect(strength['minutes'], 0);
    expect(strength.containsKey('km'), isTrue);
    expect(strength['km'], isNull);
  });

  test('formatEntryLine writes the time on the app 12-hour clock', () {
    final line = formatEntryLine(
      Entry(id: '1', timestamp: DateTime(2026, 6, 20, 22, 37), type: EntryType.rituals,
          title: 'Read', source: EntrySource.manual),
      Currency.usd,
    );
    expect(line, '10:37 PM Read (rituals)');
  });
}
