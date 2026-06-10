import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/rituals_builder_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

RitualRoutine _routine(String id, String name, {int order = 0}) => RitualRoutine(
      id: id,
      name: name,
      time: '7:00 AM',
      tone: RitualTone.morning,
      icon: 'sparkles',
      blurb: '',
      order: order,
      steps: [
        RitualStep(id: '$id-step-0', title: 'Step', note: '', icon: 'sparkles'),
      ],
    );

void main() {
  // ---------------------------------------------------------------------------
  // Pure math — reindex rewrites each routine's order to its list position.
  // ---------------------------------------------------------------------------
  test('reindex assigns each routine order = its list index', () {
    final a = _routine('a', 'A', order: 5);
    final b = _routine('b', 'B', order: 2);
    final c = _routine('c', 'C', order: 9);

    final out = reindex([c, a, b]);

    expect(out.map((r) => r.id).toList(), ['c', 'a', 'b']);
    expect(out.map((r) => r.order).toList(), [0, 1, 2]);
    // unchanged fields are preserved.
    expect(out[1].name, 'A');
  });

  // ---------------------------------------------------------------------------
  // Controller + in-memory repo — add / reorder / delete persist correctly.
  // ---------------------------------------------------------------------------
  test('controller add/reorder/delete persists through the repository',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = RitualRepository(db);
    // seed two routines in order.
    await repo.upsertRoutine(_routine('r1', 'Pages', order: 0));
    await repo.upsertRoutine(_routine('r2', 'Read', order: 1));

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    // hold the autoDispose streaming controller alive across the awaits below.
    container.listen(ritualsBuilderControllerProvider, (_, _) {});

    final notifier = container.read(ritualsBuilderControllerProvider.notifier);
    // wait for the initial stream emission before acting.
    await container.read(ritualsBuilderControllerProvider.future);

    // add a new routine (empty id) → appended with order = current count (2).
    await notifier.addOrUpdate(_routine('', 'Water'));
    var all = await repo.getAll();
    expect(all.map((r) => r.name).toList(), ['Pages', 'Read', 'Water']);
    expect(all.last.order, 2);

    // reorder: move the last ('Water', index 2) to the front.
    await notifier.reorder(2, 0);
    all = await repo.getAll();
    expect(all.map((r) => r.name).toList(), ['Water', 'Pages', 'Read']);
    expect(all.map((r) => r.order).toList(), [0, 1, 2]);

    // delete 'Pages' (now at index 1) → survivors reindexed gap-free.
    final pages = all.firstWhere((r) => r.name == 'Pages');
    await notifier.delete(pages.id);
    all = await repo.getAll();
    expect(all.map((r) => r.name).toList(), ['Water', 'Read']);
    expect(all.map((r) => r.order).toList(), [0, 1]);
  });

  test('addOrUpdate replaces the full step set on an existing routine',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = RitualRepository(db);
    await repo.upsertRoutine(_routine('r1', 'Morning', order: 0));

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    container.listen(ritualsBuilderControllerProvider, (_, _) {});

    final notifier = container.read(ritualsBuilderControllerProvider.notifier);
    await container.read(ritualsBuilderControllerProvider.future);

    final edited = (await repo.getAll()).first.copyWith(steps: const [
      RitualStep(id: 'a', title: 'Water', note: '', icon: 'drop.fill'),
      RitualStep(id: 'b', title: 'Stretch', note: '', icon: 'leaf.fill'),
    ]);
    await notifier.addOrUpdate(edited);

    final after = (await repo.getAll()).single;
    expect(after.steps.map((s) => s.title).toList(), ['Water', 'Stretch']);
  });
}
