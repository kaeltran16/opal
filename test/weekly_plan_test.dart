import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/weekly_plan_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A Wednesday — Monday of its week is 2026-06-08.
  final wednesday = DateTime(2026, 6, 10, 9, 0);
  final monday = DateTime(2026, 6, 8);

  group('WeeklyPlanRepository', () {
    late LoopDatabase db;

    setUp(() {
      db = LoopDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    test('empty schedule reads as no assignments', () async {
      final repo = WeeklyPlanRepository(db);
      expect(await repo.getSchedule(), isEmpty);
    });

    test('upsert writes a weekday row and reads it back', () async {
      // FK target.
      await db.into(db.routines).insert(RoutinesCompanion.insert(
          id: 'r1', name: 'Push A', tag: 'upper'));
      final repo = WeeklyPlanRepository(db);

      await repo.upsert(1, 'r1');
      var schedule = await repo.getSchedule();
      expect(schedule, hasLength(1));
      expect(schedule.single.weekday, 1);
      expect(schedule.single.routineId, 'r1');

      // Re-assigning the same weekday replaces, not duplicates.
      await repo.upsert(1, null);
      schedule = await repo.getSchedule();
      expect(schedule, hasLength(1));
      expect(schedule.single.routineId, isNull);
    });

    test('watchSchedule emits weekday-ascending and reacts to writes',
        () async {
      await db.into(db.routines).insert(RoutinesCompanion.insert(
          id: 'r1', name: 'Push A', tag: 'upper'));
      final repo = WeeklyPlanRepository(db);
      final stream = repo.watchSchedule();

      expect(await stream.first, isEmpty);

      await repo.upsert(3, 'r1');
      await repo.upsert(1, 'r1');

      final emitted = await stream.firstWhere((s) => s.length == 2);
      expect(emitted.map((a) => a.weekday), [1, 3]);
    });

    test('seeder populates a default schedule referencing seed routines',
        () async {
      await Seeder(db).seedIfNeeded();
      final schedule = await WeeklyPlanRepository(db).getSchedule();
      expect(schedule, isNotEmpty);
      // Every assigned routine id resolves to a seeded routine.
      final routineIds =
          (await RoutineRepository(db).getAll()).map((r) => r.id).toSet();
      for (final a in schedule) {
        if (a.routineId != null) {
          expect(routineIds, contains(a.routineId));
        }
      }
      // Default has Push on Monday.
      final mon = schedule.firstWhere((a) => a.weekday == 1);
      expect(mon.routineId, 'seed-routine-push-a');
    });
  });

  group('buildWeeklyPlan', () {
    final pushRoutine = Routine(
      id: 'push',
      name: 'Push Day A',
      tag: RoutineTag.upper,
      estMin: 55,
      exercises: const [
        RoutineExercise(id: 'p0', exerciseId: 'bench', order: 0),
        RoutineExercise(id: 'p1', exerciseId: 'ohp', order: 1),
        RoutineExercise(id: 'p2', exerciseId: 'incline', order: 2),
      ],
    );
    final cardioRoutine = Routine(
      id: 'cardio',
      name: 'Treadmill Intervals',
      tag: RoutineTag.cardio,
      estMin: 30,
      exercises: const [
        RoutineExercise(id: 'c0', exerciseId: 'treadmill', order: 0),
      ],
    );
    final exercisesById = {
      'bench': const Exercise(
          id: 'bench', name: 'Bench', group: 'Push', muscle: 'Chest', icon: 'x'),
      'ohp': const Exercise(
          id: 'ohp',
          name: 'OHP',
          group: 'Push',
          muscle: 'Shoulders',
          icon: 'x'),
      'incline': const Exercise(
          id: 'incline',
          name: 'Incline',
          group: 'Push',
          muscle: 'Chest',
          icon: 'x'),
      'treadmill': const Exercise(
          id: 'treadmill',
          name: 'Treadmill',
          group: 'Cardio',
          muscle: 'Cardio',
          icon: 'x'),
    };

    test('joins schedule to routine, deriving type/est/muscles/icon', () {
      final plan = buildWeeklyPlan(
        schedule: const [WeeklyPlanAssignment(weekday: 1, routineId: 'push')],
        routines: [pushRoutine],
        exercisesById: exercisesById,
        workouts: const [],
        now: wednesday,
      );

      expect(plan.days, hasLength(7));
      final mon = plan.days.first;
      expect(mon.day, 'Mon');
      expect(mon.routine, 'Push Day A');
      expect(mon.est, 55);
      // Dominant exercise group.
      expect(mon.type, 'Push');
      expect(mon.icon, 'dumbbell.fill');
      // Distinct muscles in slot order.
      expect(mon.muscles, ['Chest', 'Shoulders']);
      expect(mon.isRest, isFalse);
    });

    test('cardio routine gets the run icon', () {
      final plan = buildWeeklyPlan(
        schedule: const [WeeklyPlanAssignment(weekday: 5, routineId: 'cardio')],
        routines: [cardioRoutine],
        exercisesById: exercisesById,
        workouts: const [],
        now: wednesday,
      );
      final fri = plan.days[4];
      expect(fri.type, 'Cardio');
      expect(fri.icon, 'figure.run');
    });

    test('unassigned weekday and unresolved routine id are Rest days', () {
      final plan = buildWeeklyPlan(
        // weekday 2 points at a routine that does not exist.
        schedule: const [WeeklyPlanAssignment(weekday: 2, routineId: 'gone')],
        routines: [pushRoutine],
        exercisesById: exercisesById,
        workouts: const [],
        now: wednesday,
      );
      // Tue (unresolved id) -> Rest, Wed (no row) -> Rest.
      expect(plan.days[1].isRest, isTrue);
      expect(plan.days[1].colorKey, 'rest');
      expect(plan.days[2].isRest, isTrue);
    });

    test('done derives from a workout started within the current week', () {
      final inWeek = Workout(
        id: 'w1',
        routineId: 'push',
        name: 'Push',
        startedAt: monday.add(const Duration(hours: 8)),
      );
      final lastWeek = Workout(
        id: 'w0',
        routineId: 'push',
        name: 'Push',
        startedAt: monday.subtract(const Duration(days: 1)),
      );

      final donePlan = buildWeeklyPlan(
        schedule: const [WeeklyPlanAssignment(weekday: 1, routineId: 'push')],
        routines: [pushRoutine],
        exercisesById: exercisesById,
        workouts: [inWeek],
        now: wednesday,
      );
      expect(donePlan.days.first.done, isTrue);
      expect(donePlan.doneCount, 1);

      // A prior-week workout for the same routine does NOT count as done.
      final notDonePlan = buildWeeklyPlan(
        schedule: const [WeeklyPlanAssignment(weekday: 1, routineId: 'push')],
        routines: [pushRoutine],
        exercisesById: exercisesById,
        workouts: [lastWeek],
        now: wednesday,
      );
      expect(notDonePlan.days.first.done, isFalse);
      expect(notDonePlan.doneCount, 0);
    });

    test('summary counts ignore rest days; minutes sum est', () {
      final plan = buildWeeklyPlan(
        schedule: const [
          WeeklyPlanAssignment(weekday: 1, routineId: 'push'),
          WeeklyPlanAssignment(weekday: 5, routineId: 'cardio'),
        ],
        routines: [pushRoutine, cardioRoutine],
        exercisesById: exercisesById,
        workouts: const [],
        now: wednesday,
      );
      expect(plan.totalCount, 2); // two non-rest days
      expect(plan.totalMinutes, 85); // 55 + 30
      expect(plan.doneCount, 0);
    });

    test('marks today by date and finds it via WeeklyPlan.today', () {
      final plan = buildWeeklyPlan(
        schedule: const [],
        routines: const [],
        exercisesById: const {},
        workouts: const [],
        now: wednesday,
      );
      // Wednesday is offset 2.
      expect(plan.days[2].today, isTrue);
      expect(plan.today, isNotNull);
      expect(plan.today!.day, 'Wed');
    });
  });
}
