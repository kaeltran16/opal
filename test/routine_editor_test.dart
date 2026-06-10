import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loop/controllers/providers.dart';
import 'package:loop/controllers/routine_editor_controller.dart';
import 'package:loop/data/db/database.dart';
import 'package:loop/data/seed/seeder.dart';
import 'package:loop/models/models.dart';

/// Builds a ProviderContainer with the standard in-memory overrides used
/// across the suite.
ProviderContainer _container(SharedPreferences prefs, LoopDatabase db) =>
    ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
      ],
    );

void main() {
  // ---------------------------------------------------------------------------
  // Pure — reindex rewrites order to match list position.
  // ---------------------------------------------------------------------------
  test('reindex assigns order to match list position', () {
    RoutineExercise ex(String id, int order) =>
        RoutineExercise(id: id, exerciseId: 'e-$id', order: order);

    // A list whose stored orders are stale after a move (b moved before a).
    final reordered = reindex([ex('b', 1), ex('a', 0), ex('c', 2)]);

    expect(reordered.map((e) => e.id).toList(), ['b', 'a', 'c']);
    expect(reordered.map((e) => e.order).toList(), [0, 1, 2]);
  });

  // ---------------------------------------------------------------------------
  // Create path — build a new routine via the controller and persist it.
  // ---------------------------------------------------------------------------
  test('controller creates a new routine with ordered exercises', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final container = _container(prefs, db);
    addTearDown(container.dispose);

    final provider = routineEditorControllerProvider(null);
    container.listen(provider, (_, _) {}); // hold across awaits (autoDispose)
    await container.read(provider.future);
    final c = container.read(provider.notifier);

    c.setName('Test Routine');
    c.setTag(RoutineTag.full);
    c.setRest(90);
    c.toggleWarmup(true);
    c.addExercise('bench');
    c.addExercise('squat');
    await c.save();

    final repo = container.read(routineRepositoryProvider);
    final all = await repo.getAll();
    final created = all.firstWhere((r) => r.name == 'Test Routine');

    expect(created.tag, RoutineTag.full);
    expect(created.restSeconds, 90);
    expect(created.warmupReminder, true);
    expect(created.orderedExercises.map((e) => e.exerciseId).toList(),
        ['bench', 'squat']);
    expect(created.orderedExercises.map((e) => e.order).toList(), [0, 1]);
  });

  // ---------------------------------------------------------------------------
  // Edit path — load a seeded routine, rename + reorder, persist via update.
  // ---------------------------------------------------------------------------
  test('controller edits a seeded routine: rename + reorder persist', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final container = _container(prefs, db);
    addTearDown(container.dispose);

    final provider = routineEditorControllerProvider('seed-routine-legs');
    container.listen(provider, (_, _) {}); // hold across awaits (autoDispose)
    final loaded = await container.read(provider.future);
    final c = container.read(provider.notifier);

    // Sanity: the seeded leg day loaded with its slots in order.
    final originalFirst = loaded.draft.orderedExercises.first.exerciseId;
    expect(originalFirst, 'squat');

    c.setName('Leg Day v2');
    // Move the first slot to the end (onReorderItem gives a post-removal index).
    c.reorder(0, loaded.draft.exercises.length - 1);
    await c.save();

    final repo = container.read(routineRepositoryProvider);
    final updated = await repo.getById('seed-routine-legs');

    expect(updated, isNotNull);
    expect(updated!.name, 'Leg Day v2');
    // The previously-first exercise now sits last, and order is contiguous.
    expect(updated.orderedExercises.last.exerciseId, originalFirst);
    expect(updated.orderedExercises.map((e) => e.order).toList(),
        List.generate(updated.exercises.length, (i) => i));
  });
}
