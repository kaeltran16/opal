import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/ask_pal_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/db/mappers.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart';

/// A PalService whose `chat()` returns a fixed result (or throws). Other methods
/// are unused here and return harmless defaults.
class _FakePal implements PalService {
  _FakePal({this.result, this.error});

  final PalChatResult? result;
  final Object? error;

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async {
    if (error != null) throw error!;
    return result ?? const PalChatResult(reply: 'ok', actions: []);
  }

  @override
  Future<ParsedEntryDraft> parse(String text) async =>
      const ParsedEntryDraft(type: EntryType.money);
  @override
  Future<String> review(DateTime month) async => '';
  @override
  Future<PalInsights> insights(InsightRange range) async => const PalInsights();
  @override
  Future<WorkoutSuggestion> suggestWorkout({bool another = false}) async =>
      const WorkoutSuggestion(title: '', rationale: '');
  @override
  Future<String> postWorkoutNote(Workout workout) async => '';
  @override
  Future<GeneratedRoutineDraft> generateRoutine(
          String goal, List<Exercise> available) async =>
      const GeneratedRoutineDraft(
        name: 'Push Day',
        tag: RoutineTag.upper,
        exercises: [
          GeneratedExerciseDraft(
            exerciseId: 'e1',
            sets: [GeneratedSetDraft(reps: 8, weightKg: 40)],
          ),
        ],
      );
}

ProviderContainer _container(LoopDatabase db, PalService pal) {
  return ProviderContainer(overrides: [
    loopDatabaseProvider.overrideWithValue(db),
    palServiceProvider.overrideWithValue(pal),
  ]);
}

void main() {
  test('a log_expense action creates a negative money entry and replies', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final pal = _FakePal(
      result: const PalChatResult(reply: 'Logged \$5 for coffee.', actions: [
        LogEntryAction(type: EntryType.money, amount: -5, title: 'coffee', category: 'Coffee'),
      ]),
    );
    final c = _container(db, pal);
    addTearDown(c.dispose);

    await c.read(askPalControllerProvider.notifier).send('add \$5 for coffee');

    final entries = await EntryRepository(db).getAll();
    expect(entries, hasLength(1));
    expect(entries.single.type, EntryType.money);
    expect(entries.single.amount, closeTo(-5, 1e-9));
    expect(entries.single.category, 'Coffee');
    expect(entries.single.source, EntrySource.nlParsed);

    final state = c.read(askPalControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.messages.last.role, PalRole.assistant);
    expect(state.messages.last.text, 'Logged \$5 for coffee.');
    expect(state.messages.last.actions, isNotEmpty);
  });

  test('undo deletes the entry an action created', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final pal = _FakePal(
      result: const PalChatResult(reply: 'Logged it.', actions: [
        LogEntryAction(type: EntryType.move, durationMinutes: 30, title: 'Run'),
      ]),
    );
    final c = _container(db, pal);
    addTearDown(c.dispose);

    final notifier = c.read(askPalControllerProvider.notifier);
    await notifier.send('ran 30 min');
    expect(await EntryRepository(db).getAll(), hasLength(1));

    final idx = c.read(askPalControllerProvider).messages.length - 1;
    await notifier.undo(idx);

    expect(await EntryRepository(db).getAll(), isEmpty);
    expect(c.read(askPalControllerProvider).messages[idx].undone, isTrue);
  });

  test('a set_daily_budget action updates goals; undo restores the prior value', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final goals = GoalsRepository(db);
    await goals.save(const Goals(dailyBudget: 85));

    final pal = _FakePal(
      result: const PalChatResult(reply: 'Set your budget to \$60.', actions: [
        SetGoalAction(target: GoalTarget.dailyBudget, value: 60),
      ]),
    );
    final c = _container(db, pal);
    addTearDown(c.dispose);

    final notifier = c.read(askPalControllerProvider.notifier);
    await notifier.send('set my budget to 60');
    expect((await goals.get()).dailyBudget, 60);

    final idx = c.read(askPalControllerProvider).messages.length - 1;
    await notifier.undo(idx);
    expect((await goals.get()).dailyBudget, 85);
  });

  test('a create_routine action builds and saves a routine; undo deletes it', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final pal = _FakePal(
      result: const PalChatResult(reply: 'Built you a routine.', actions: [
        CreateRoutineAction(goal: 'a push day'),
      ]),
    );
    final c = _container(db, pal);
    addTearDown(c.dispose);

    // seed the catalog exercise the generated routine references (FK is enforced)
    await db.into(db.exercises).insert(const Exercise(
          id: 'e1', name: 'Bench', group: 'Push', muscle: 'Chest', icon: 'dumbbell.fill',
        ).toCompanion());

    final routines = RoutineRepository(db);
    final notifier = c.read(askPalControllerProvider.notifier);
    await notifier.send('build me a push day');

    final saved = await routines.getAll();
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Push Day');
    expect(saved.single.exercises, hasLength(1));

    final idx = c.read(askPalControllerProvider).messages.length - 1;
    await notifier.undo(idx);
    expect(await routines.getAll(), isEmpty);
  });

  test('a chat failure surfaces an error message and clears loading (no hang)', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final pal = _FakePal(error: Exception('boom'));
    final c = _container(db, pal);
    addTearDown(c.dispose);

    await c.read(askPalControllerProvider.notifier).send('add \$5 for coffee');

    final state = c.read(askPalControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.messages.last.role, PalRole.assistant);
    expect(state.messages.last.text.toLowerCase(), contains('couldn'));
  });
}
