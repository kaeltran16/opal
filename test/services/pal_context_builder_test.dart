import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_context_builder.dart';

void main() {
  final goals = const Goals(dailyBudget: 60, dailyMoveMinutes: 30, dailyRitualTarget: 5);

  Entry money(double amount, {String? category, DateTime? at}) => Entry(
        id: '', timestamp: at ?? DateTime(2026, 6, 10, 8), type: EntryType.money,
        title: category ?? 'Spend', amount: amount, category: category, source: EntrySource.manual,
      );
  Entry move(int min, {DateTime? at}) => Entry(
        id: '', timestamp: at ?? DateTime(2026, 6, 10, 9), type: EntryType.move,
        title: 'Walk', duration: min, source: EntrySource.manual,
      );
  Entry ritual({DateTime? at}) => Entry(
        id: '', timestamp: at ?? DateTime(2026, 6, 10, 7), type: EntryType.rituals,
        title: 'Meditate', source: EntrySource.manual,
      );

  test('buildChatContext folds today + week numbers', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: goals,
      todayEntries: [money(-12, category: 'Coffee'), move(20), ritual(), ritual(), ritual()],
      weekEntries: [money(-200, category: 'Coffee'), move(140), ritual()],
      moveStreakDays: 11,
    );

    expect(ctx['userName'], 'Kael');
    expect(ctx['dailyBudget'], 60);
    expect(ctx['spentToday'], 12); // absolute value of the expense
    expect(ctx['movedTodayMin'], 20);
    expect(ctx['ritualsDoneToday'], 3);
    expect(ctx['weekBudget'], 420); // 60 * 7
    expect(ctx['weekRitualGoal'], 35); // 5 * 7
    expect(ctx['moveStreakDays'], 11);
    expect((ctx['todayEntries'] as List).length, 5);
  });

  test('buildPostWorkoutContext reads volume + PRs from the workout', () {
    final workout = Workout(
      id: 'w1', routineId: 'r1', name: 'Push A',
      startedAt: DateTime(2026, 6, 10, 17), endedAt: DateTime(2026, 6, 10, 18),
      sets: const [
        SetLog(id: 's1', exerciseId: 'bench', weightKg: 60, reps: 5, done: true, isPR: true),
        SetLog(id: 's2', exerciseId: 'bench', weightKg: 60, reps: 5, done: true, isPR: false),
      ],
    );

    final ctx = buildPostWorkoutContext(workout: workout, lastSessionVolumeKg: 540, daysAgoLastSession: 4);

    expect(ctx['routineName'], 'Push A');
    expect(ctx['prCount'], 1);
    expect((ctx['prExercises'] as List), contains('bench'));
    expect(ctx['lastSessionVolumeKg'], 540);
    expect(ctx['daysAgoLastSession'], 4);
  });
}
