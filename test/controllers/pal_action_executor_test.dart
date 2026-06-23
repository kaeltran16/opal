import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/pal_action_executor.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/services/services.dart';

/// A PalService whose only exercised seam is [generateRoutine]; it returns a
/// fixed draft (or throws) so we can drive the CreateRoutineAction branch and
/// its failure path deterministically. Everything else is unused here.
class _FakePal implements PalService {
  _FakePal({this.routineFails = false});

  @override
  Future<PalAgenda> agenda() async => const PalAgenda();

  final bool routineFails;
  int generateCalls = 0;

  @override
  Future<GeneratedRoutineDraft> generateRoutine(
    String goal,
    List<Exercise> available,
  ) async {
    generateCalls++;
    if (routineFails) throw const PalException('routine generation failed');
    return const GeneratedRoutineDraft(
      name: 'Generated Push',
      tag: RoutineTag.upper,
      exercises: [
        GeneratedExerciseDraft(
          exerciseId: 'bench',
          sets: [GeneratedSetDraft(reps: 8, weightKg: 50)],
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Seeds the `bench` catalog row so a generated routine's exercise slot has a
/// valid FK target (routine_exercises references the exercises table).
Future<void> _seedBench(LoopDatabase db) => db.into(db.exercises).insert(
      ExercisesCompanion.insert(
        id: 'bench',
        name: 'Bench',
        group: 'Push',
        muscle: 'Chest',
        icon: 'x',
      ),
    );

Entry _existing(String id) => Entry(
      id: id,
      timestamp: DateTime(2026, 6, 1, 9),
      type: EntryType.money,
      title: 'Seed',
      amount: -5,
      source: EntrySource.manual,
    );

/// Exposes a [Ref] from the container so we can drive the free function
/// [applyPalActions], which takes the same `ref` the chat controllers hand it.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  Ref refWith(LoopDatabase db, PalService pal) {
    final c = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(pal),
    ]);
    addTearDown(c.dispose);
    return c.read(_refProvider);
  }

  group('applyPalActions — happy path', () {
    test('logs an entry and reports its id', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ref = refWith(db, _FakePal());

      final applied = await applyPalActions(ref, [
        const LogEntryAction(
          type: EntryType.money,
          title: 'Coffee',
          amount: -4,
          category: 'Food',
        ),
      ]);

      expect(applied.entryIds, hasLength(1));
      final stored = await EntryRepository(db).getAll();
      expect(stored.where((e) => e.title == 'Coffee'), hasLength(1));
    });

    test('applies a goal change and captures the prior goals snapshot', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final goals = GoalsRepository(db);
      await goals.upsert(const Goals(dailyBudget: 100));
      final ref = refWith(db, _FakePal());

      final applied = await applyPalActions(ref, [
        const SetGoalAction(target: GoalTarget.dailyBudget, value: 60),
      ]);

      expect((await goals.get()).dailyBudget, 60);
      // prior snapshot is what undo would restore.
      expect(applied.priorGoals?.dailyBudget, 100);
    });

    test('creates a routine via the PalService draft and reports its id',
        () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedBench(db);
      final pal = _FakePal();
      final ref = refWith(db, pal);

      final applied = await applyPalActions(ref, [
        const CreateRoutineAction(goal: 'build a push day', name: 'My Push'),
      ]);

      expect(pal.generateCalls, 1);
      expect(applied.routineIds, hasLength(1));
      final routine = await RoutineRepository(db).getById(applied.routineIds.single);
      expect(routine?.name, 'My Push'); // name override wins over draft name
    });
  });

  group('applyPalActions — meal', () {
    test('logs a meal and rolls it back on reverse', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ref = refWith(db, _FakePal());

      final applied = await applyPalActions(ref, [
        const LogMealAction(
          name: 'Burrito', cal: IntRange(520, 820),
          confidence: NutritionConfidence.med, slot: 'Lunch'),
      ]);

      expect(applied.mealIds, hasLength(1));
      final repo = NutritionRepository(db);
      final after = await repo.getMealsInRange(
          DateTime(2000), DateTime(2100));
      expect(after.single.name, 'Burrito');
      expect(after.single.cal, const IntRange(520, 820));
      expect(after.single.source, NutritionSource.manual);

      // reverse (mirrors the controller's undo) clears it
      await repo.deleteById(applied.mealIds.single);
      expect(await repo.getMealsInRange(DateTime(2000), DateTime(2100)), isEmpty);
    });
  });

  group('applyPalActions — rollback on mid-loop failure', () {
    test('rolls back an already-inserted entry when a later action throws',
        () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final entries = EntryRepository(db);
      await entries.insert(_existing('keep-me'));
      // routine generation throws, so the earlier LogEntryAction must be undone.
      final ref = refWith(db, _FakePal(routineFails: true));

      await expectLater(
        applyPalActions(ref, [
          const LogEntryAction(
            type: EntryType.money,
            title: 'Should be rolled back',
            amount: -9,
          ),
          const CreateRoutineAction(goal: 'boom'),
        ]),
        throwsA(isA<PalException>()),
      );

      final remaining = await entries.getAll();
      // the pre-existing entry survives; the mid-turn insert was reversed.
      expect(remaining.map((e) => e.title), ['Seed']);
    });

    test('restores prior goals when a later action throws', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final goals = GoalsRepository(db);
      await goals.upsert(const Goals(dailyBudget: 100, dailyMoveKcal: 500));
      final ref = refWith(db, _FakePal(routineFails: true));

      await expectLater(
        applyPalActions(ref, [
          const SetGoalAction(target: GoalTarget.dailyBudget, value: 40),
          const CreateRoutineAction(goal: 'boom'),
        ]),
        throwsA(isA<PalException>()),
      );

      // goals reverted to the snapshot taken before the first mutation.
      expect((await goals.get()).dailyBudget, 100);
    });

    test('rolls back a created routine and a logged entry together', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedBench(db);
      final entries = EntryRepository(db);
      final routines = RoutineRepository(db);

      // log + first routine land, the second routine throws — both prior
      // mutations must be reversed.
      final ref = refWith(db, _CountingFailPal(failOnCall: 2));

      await expectLater(
        applyPalActions(ref, [
          const LogEntryAction(type: EntryType.rituals, title: 'meditate'),
          const CreateRoutineAction(goal: 'first ok'),
          const CreateRoutineAction(goal: 'second boom'),
        ]),
        throwsA(isA<PalException>()),
      );

      expect(await entries.getAll(), isEmpty);
      expect(await routines.getAll(), isEmpty);
    });
  });
}

/// PalService that succeeds for the first [failOnCall]-1 generateRoutine calls
/// then throws — lets us land a routine before the failing one, proving both
/// the entry and the first routine get rolled back.
class _CountingFailPal implements PalService {
  _CountingFailPal({required this.failOnCall});

  @override
  Future<PalAgenda> agenda() async => const PalAgenda();

  final int failOnCall;
  int _calls = 0;

  @override
  Future<GeneratedRoutineDraft> generateRoutine(
    String goal,
    List<Exercise> available,
  ) async {
    _calls++;
    if (_calls >= failOnCall) throw const PalException('boom');
    return const GeneratedRoutineDraft(
      name: 'OK Routine',
      tag: RoutineTag.upper,
      exercises: [
        GeneratedExerciseDraft(
          exerciseId: 'bench',
          sets: [GeneratedSetDraft(reps: 5, weightKg: 60)],
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
