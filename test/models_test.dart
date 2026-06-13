import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';

void main() {
  group('Entry', () {
    final base = Entry(
      id: 'e1',
      timestamp: DateTime(2026, 4, 23, 8, 30),
      type: EntryType.money,
      title: 'Verve Coffee',
      detail: 'Coffee · cortado',
      amount: -5.75,
      category: 'Food & Drink',
      source: EntrySource.manual,
    );

    test('expense/income derived getters', () {
      expect(base.isExpense, isTrue);
      expect(base.isIncome, isFalse);
      final income = base.copyWith(amount: 100.0);
      expect(income.isIncome, isTrue);
      expect(income.isExpense, isFalse);
    });

    test('copyWith round-trip preserves untouched fields', () {
      final copy = base.copyWith(title: 'Tartine');
      expect(copy.title, 'Tartine');
      expect(copy.amount, -5.75);
      expect(copy.id, 'e1');
      // Round-trip back to the original value.
      expect(copy.copyWith(title: 'Verve Coffee'), base);
    });

    test('value equality and hashCode', () {
      final same = Entry(
        id: 'e1',
        timestamp: DateTime(2026, 4, 23, 8, 30),
        type: EntryType.money,
        title: 'Verve Coffee',
        detail: 'Coffee · cortado',
        amount: -5.75,
        category: 'Food & Drink',
        source: EntrySource.manual,
      );
      expect(same, base);
      expect(same.hashCode, base.hashCode);
      expect(base.copyWith(title: 'Other'), isNot(base));
    });
  });

  group('SetLog', () {
    test('volume getter', () {
      const s = SetLog(id: 's1', exerciseId: 'x1', weightKg: 90, reps: 5);
      expect(s.volumeKg, 450);
    });

    test('copyWith and equality', () {
      const s = SetLog(id: 's1', exerciseId: 'x1', weightKg: 90, reps: 5);
      final done = s.copyWith(done: true, isPR: true);
      expect(done.done, isTrue);
      expect(done.isPR, isTrue);
      expect(done.copyWith(done: false, isPR: false), s);
      expect(done, isNot(s));
    });
  });

  group('Workout', () {
    final workout = Workout(
      id: 'w1',
      name: 'Push Day A',
      startedAt: DateTime(2026, 4, 23, 17, 45),
      endedAt: DateTime(2026, 4, 23, 18, 37),
      sets: const [
        // Two done sets contribute to volume; one PR.
        SetLog(id: 's1', exerciseId: 'x1', weightKg: 90, reps: 5, done: true, isPR: true),
        SetLog(id: 's2', exerciseId: 'x1', weightKg: 85, reps: 6, done: true),
        // Upcoming/undone set is excluded from volume + prCount.
        SetLog(id: 's3', exerciseId: 'x2', weightKg: 50, reps: 8, isPR: true),
      ],
    );

    test('totalVolumeKg sums only done sets', () {
      // 90*5 + 85*6 = 450 + 510 = 960; the undone 50*8 set is excluded.
      expect(workout.totalVolumeKg, 960);
    });

    test('prCount counts only done PR sets', () {
      expect(workout.prCount, 1);
    });

    test('completedSetCount and duration', () {
      expect(workout.completedSetCount, 2);
      expect(workout.duration, const Duration(minutes: 52));
      expect(workout.isComplete, isTrue);
    });

    test('active workout has null duration', () {
      final active = Workout(
        id: 'w2',
        name: 'Freestyle',
        startedAt: DateTime(2026, 4, 23, 9),
      );
      expect(active.duration, isNull);
      expect(active.isComplete, isFalse);
      expect(active.totalVolumeKg, 0);
    });

    test('copyWith and equality with nested sets', () {
      final copy = workout.copyWith(name: 'Push Day B');
      expect(copy.name, 'Push Day B');
      expect(copy.totalVolumeKg, 960);
      expect(copy.copyWith(name: 'Push Day A'), workout);
    });
  });

  group('Routine / RoutineExercise', () {
    final routine = Routine(
      id: 'r1',
      name: 'Push Day A',
      tag: RoutineTag.upper,
      exercises: const [
        RoutineExercise(id: 're2', exerciseId: 'x2', order: 1),
        RoutineExercise(id: 're1', exerciseId: 'x1', order: 0),
      ],
    );

    test('orderedExercises sorts by order', () {
      expect(routine.orderedExercises.map((e) => e.id).toList(),
          ['re1', 're2']);
      expect(routine.exerciseCount, 2);
    });

    test('copyWith and equality', () {
      final copy = routine.copyWith(name: 'Pull Day A', tag: RoutineTag.full);
      expect(copy.tag, RoutineTag.full);
      expect(copy.copyWith(name: 'Push Day A', tag: RoutineTag.upper), routine);
    });
  });

  group('RitualRoutine', () {
    const routine = RitualRoutine(
      id: 'morning',
      name: 'Morning',
      time: '7:00 AM',
      tone: RitualTone.morning,
      icon: 'sunrise.fill',
      blurb: 'Ease into the day',
      streak: 11,
      steps: [
        RitualStep(
          id: 'morning-step-0',
          title: 'Glass of water',
          note: 'Rehydrate first thing.',
          icon: 'drop.fill',
        ),
      ],
    );

    test('copyWith and equality', () {
      final copy = routine.copyWith(streak: 12);
      expect(copy.streak, 12);
      expect(copy.copyWith(streak: 11), routine);
      expect(copy, isNot(routine));
    });

    test('tone maps to a tracker color key', () {
      expect(routine.colorKey, 'money');
      expect(routine.tone.colorKey, 'money');
      expect(RitualTone.midday.colorKey, 'move');
      expect(RitualTone.evening.colorKey, 'rituals');
    });
  });

  group('Goals', () {
    test('defaults match handoff', () {
      const g = Goals();
      expect(g.dailyBudget, 85.0);
      expect(g.dailyMoveKcal, 500);
      expect(g.dailyRitualTarget, 5);
    });

    test('copyWith and equality', () {
      const g = Goals();
      final custom = g.copyWith(dailyBudget: 120);
      expect(custom.dailyBudget, 120);
      expect(custom.copyWith(dailyBudget: 85), g);
    });
  });

  group('EmailAccount', () {
    const account = EmailAccount(
      address: 'hello@example.com',
      provider: Provider.gmail,
      appPasswordRef: 'keychain://abc',
      senderFilters: ['amazon.com', 'uber.com'],
    );

    test('defaults', () {
      expect(account.imapHost, 'imap.gmail.com');
      expect(account.imapPort, 993);
      expect(account.autoSyncInterval, 15);
      expect(account.lastSyncedAt, isNull);
    });

    test('copyWith and equality with list field', () {
      final synced = account.copyWith(lastSyncedAt: DateTime(2026, 6, 9));
      expect(synced.lastSyncedAt, DateTime(2026, 6, 9));
      expect(synced.copyWith(), synced);
      expect(synced, isNot(account));
    });
  });

  group('Exercise / ExercisePR', () {
    const exercise = Exercise(
      id: 'x1',
      name: 'Bench Press',
      group: 'Push',
      muscle: 'Chest',
      icon: 'dumbbell.fill',
      equipment: 'Barbell',
      pr: ExercisePR(weightKg: 90, reps: 5),
    );

    test('PR volume getter', () {
      expect(exercise.pr!.volumeKg, 450);
    });

    test('copyWith and equality', () {
      final copy = exercise.copyWith(
        pr: const ExercisePR(weightKg: 95, reps: 5),
      );
      expect(copy.pr!.weightKg, 95);
      expect(copy.copyWith(pr: const ExercisePR(weightKg: 90, reps: 5)),
          exercise);
    });
  });

  group('enums', () {
    test('wire round-trips', () {
      expect(EntryType.fromWire('rituals'), EntryType.rituals);
      expect(EntrySource.fromWire('nlParsed'), EntrySource.nlParsed);
      expect(RoutineTag.fromWire('cardio'), RoutineTag.cardio);
      expect(RitualTone.fromWire('evening'), RitualTone.evening);
      expect(NoteKind.fromWire('spotted'), NoteKind.spotted);
      expect(Provider.fromWire('outlook'), Provider.outlook);
      expect(SyncStatus.fromWire('upToDate'), SyncStatus.upToDate);
      expect(SyncStatus.error.wire, 'error');
    });
  });
}
