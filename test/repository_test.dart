import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoopDatabase db;

  setUp(() {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('EntryRepository', () {
    test('insert assigns a UUID when id is empty', () async {
      final repo = EntryRepository(db);
      final id = await repo.insert(
        Entry(
          id: '',
          timestamp: DateTime(2026, 6, 9, 8, 30),
          type: EntryType.money,
          title: 'Coffee',
          amount: -4.5,
          source: EntrySource.manual,
        ),
      );
      expect(id, isNotEmpty);
      expect(id.length, greaterThan(10)); // looks like a uuid
      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.single.id, id);
    });

    test('watchToday emits only same-day entries, newest first', () async {
      final repo = EntryRepository(db);
      final day = DateTime(2026, 6, 9);

      // Two today, one yesterday.
      await repo.insert(Entry(
        id: 'today-morning',
        timestamp: DateTime(2026, 6, 9, 7, 0),
        type: EntryType.rituals,
        title: 'Morning pages',
        source: EntrySource.manual,
      ));
      await repo.insert(Entry(
        id: 'today-evening',
        timestamp: DateTime(2026, 6, 9, 19, 0),
        type: EntryType.money,
        title: 'Dinner',
        amount: -22,
        source: EntrySource.manual,
      ));
      await repo.insert(Entry(
        id: 'yesterday',
        timestamp: DateTime(2026, 6, 8, 12, 0),
        type: EntryType.money,
        title: 'Lunch',
        amount: -10,
        source: EntrySource.manual,
      ));

      final today = await repo.watchToday(day).first;
      expect(today.map((e) => e.id), ['today-evening', 'today-morning']);
    });

    test('watchToday reacts to inserts', () async {
      final repo = EntryRepository(db);
      final day = DateTime(2026, 6, 9);
      final stream = repo.watchToday(day);

      // First emission: empty.
      expect(await stream.first, isEmpty);

      await repo.insert(Entry(
        id: 'e1',
        timestamp: DateTime(2026, 6, 9, 10, 0),
        type: EntryType.move,
        title: 'Walk',
        source: EntrySource.health,
      ));

      // Stream should now emit the new entry.
      final next = await stream.firstWhere((rows) => rows.isNotEmpty);
      expect(next.single.id, 'e1');
    });

    test('watchEntriesInRange respects half-open bounds', () async {
      final repo = EntryRepository(db);
      await repo.insert(Entry(
        id: 'in',
        timestamp: DateTime(2026, 6, 9, 0, 0),
        type: EntryType.money,
        title: 'At range start',
        amount: -1,
        source: EntrySource.manual,
      ));
      await repo.insert(Entry(
        id: 'out',
        timestamp: DateTime(2026, 6, 10, 0, 0),
        type: EntryType.money,
        title: 'At range end (excluded)',
        amount: -1,
        source: EntrySource.manual,
      ));
      final rows = await repo
          .watchEntriesInRange(DateTime(2026, 6, 9), DateTime(2026, 6, 10))
          .first;
      expect(rows.map((e) => e.id), ['in']);
    });
  });

  group('WorkoutRepository', () {
    test('round-trips a workout with child sets, preserving order/fields',
        () async {
      // Exercises are FK targets — seed two via the seeder-independent insert.
      // Use the catalog directly through a raw insert via repository-free path:
      final exerciseRepoDb = db;
      await exerciseRepoDb.into(exerciseRepoDb.exercises).insert(
            ExercisesCompanion.insert(
              id: 'bench',
              name: 'Bench',
              group: 'Push',
              muscle: 'Chest',
              icon: 'x',
            ),
          );

      final repo = WorkoutRepository(db);
      final workout = Workout(
        id: 'w1',
        name: 'Push Day',
        routineId: null,
        startedAt: DateTime(2026, 6, 9, 17, 0),
        endedAt: DateTime(2026, 6, 9, 18, 0),
        sets: const [
          SetLog(
            id: 's1',
            exerciseId: 'bench',
            weightKg: 80,
            reps: 5,
            done: true,
          ),
          SetLog(
            id: 's2',
            exerciseId: 'bench',
            weightKg: 92.5,
            reps: 5,
            done: true,
            isPR: true,
          ),
        ],
      );

      final id = await repo.insert(workout);
      expect(id, 'w1');

      final loaded = await repo.getById('w1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Push Day');
      expect(loaded.sets, hasLength(2));
      // Order preserved.
      expect(loaded.sets[0].id, 's1');
      expect(loaded.sets[1].id, 's2');
      // Fields preserved (incl. PR flag + double weight).
      expect(loaded.sets[1].weightKg, 92.5);
      expect(loaded.sets[1].isPR, isTrue);
      // Derived getters compute from persisted children.
      expect(loaded.totalVolumeKg, 80 * 5 + 92.5 * 5);
      expect(loaded.prCount, 1);
      expect(loaded.completedSetCount, 2);
    });

    test('deleteById cascades to child sets (FK ON DELETE CASCADE)', () async {
      await db.into(db.exercises).insert(
            ExercisesCompanion.insert(
              id: 'bench',
              name: 'Bench',
              group: 'Push',
              muscle: 'Chest',
              icon: 'x',
            ),
          );
      final repo = WorkoutRepository(db);
      await repo.insert(Workout(
        id: 'w1',
        name: 'Push',
        startedAt: DateTime(2026, 6, 9, 17, 0),
        sets: const [
          SetLog(id: 's1', exerciseId: 'bench', weightKg: 80, reps: 5),
        ],
      ));

      await repo.deleteById('w1');

      expect(await repo.getById('w1'), isNull);
      final remainingSets = await db.select(db.setLogs).get();
      expect(remainingSets, isEmpty); // cascade removed the orphan set
    });
  });

  group('RoutineRepository', () {
    test('round-trips a routine with ordered exercise slots', () async {
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'bench', name: 'Bench', group: 'Push', muscle: 'Chest', icon: 'x'));
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'ohp', name: 'OHP', group: 'Push', muscle: 'Shoulders', icon: 'x'));

      final repo = RoutineRepository(db);
      await repo.insert(const Routine(
        id: 'r1',
        name: 'Push A',
        tag: RoutineTag.upper,
        exercises: [
          RoutineExercise(id: 're2', exerciseId: 'ohp', order: 1),
          RoutineExercise(id: 're1', exerciseId: 'bench', order: 0),
        ],
      ));

      final loaded = await repo.getById('r1');
      expect(loaded, isNotNull);
      expect(loaded!.tag, RoutineTag.upper);
      // Loaded sorted by stored position.
      expect(loaded.exercises.map((e) => e.id), ['re1', 're2']);
      expect(loaded.exercises.first.exerciseId, 'bench');
    });
  });

  group('RitualRepository', () {
    test('watchRoutines emits in display order, with ordered steps', () async {
      final repo = RitualRepository(db);
      await repo.upsertRoutine(const RitualRoutine(
        id: 'b',
        name: 'Second',
        time: '1:00 PM',
        tone: RitualTone.midday,
        icon: 'sun.max.fill',
        blurb: '',
        order: 1,
      ));
      await repo.upsertRoutine(const RitualRoutine(
        id: 'a',
        name: 'First',
        time: '7:00 AM',
        tone: RitualTone.morning,
        icon: 'sunrise.fill',
        blurb: '',
        order: 0,
        steps: [
          RitualStep(id: 'a-0', title: 'Step one', note: '', icon: 'drop.fill'),
          RitualStep(id: 'a-1', title: 'Step two', note: '', icon: 'drop.fill'),
        ],
      ));
      final routines = await repo.watchRoutines().first;
      expect(routines.map((r) => r.name), ['First', 'Second']);
      expect(routines.first.steps.map((s) => s.title), ['Step one', 'Step two']);
    });

    test('upsertRoutine replaces the full step set', () async {
      final repo = RitualRepository(db);
      await repo.upsertRoutine(const RitualRoutine(
        id: 'm',
        name: 'M',
        time: '7:00 AM',
        tone: RitualTone.morning,
        icon: 'sunrise.fill',
        blurb: '',
        steps: [
          RitualStep(id: 'm-0', title: 'Old', note: '', icon: 'drop.fill'),
        ],
      ));
      await repo.upsertRoutine(const RitualRoutine(
        id: 'm',
        name: 'M',
        time: '7:00 AM',
        tone: RitualTone.morning,
        icon: 'sunrise.fill',
        blurb: '',
        steps: [
          RitualStep(id: 'm-0b', title: 'New', note: '', icon: 'drop.fill'),
        ],
      ));
      final routines = await repo.watchRoutines().first;
      expect(routines.single.steps.map((s) => s.title), ['New']);
    });
  });

  group('GoalsRepository', () {
    test('emits defaults when unset, then saved values', () async {
      final repo = GoalsRepository(db);
      final defaults = await repo.watchGoals().first;
      expect(defaults, const Goals()); // model defaults

      await repo.save(const Goals(
          dailyBudget: 120, dailyMoveKcal: 450, dailyRitualTarget: 3));
      final saved = await repo.get();
      expect(saved.dailyBudget, 120);
      expect(saved.dailyMoveKcal, 450);
      expect(saved.dailyRitualTarget, 3);
    });
  });

  group('Seeder', () {
    test('seeds content on first run', () async {
      await Seeder(db).seedIfNeeded();

      final entries = await EntryRepository(db).getAll();
      expect(entries, isNotEmpty);
      // Has at least some entries dated "today".
      final today = await EntryRepository(db).watchToday().first;
      expect(today, isNotEmpty);

      final routines = await RitualRepository(db).watchRoutines().first;
      expect(routines, hasLength(3));
      expect(routines.first.steps, isNotEmpty);

      final workouts = await WorkoutRepository(db).watchWorkouts().first;
      expect(workouts, isNotEmpty);
      // Seeded push workout has its child sets + a PR.
      final push =
          workouts.firstWhere((w) => w.id == 'seed-workout-today-push');
      expect(push.sets, isNotEmpty);
      expect(push.prCount, 1);

      final goals = await GoalsRepository(db).get();
      expect(goals.dailyBudget, 85.0);
    });

    test('is idempotent — seeding twice does not duplicate', () async {
      final seeder = Seeder(db);
      await seeder.seedIfNeeded();
      final afterFirst = (await EntryRepository(db).getAll()).length;
      final routinesFirst =
          (await RitualRepository(db).watchRoutines().first).length;

      await seeder.seedIfNeeded();
      final afterSecond = (await EntryRepository(db).getAll()).length;
      final routinesSecond =
          (await RitualRepository(db).watchRoutines().first).length;

      expect(afterSecond, afterFirst);
      expect(routinesSecond, routinesFirst);
    });
  });
}
