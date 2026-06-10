import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loop/controllers/providers.dart';
import 'package:loop/controllers/rituals_builder_controller.dart';
import 'package:loop/data/db/database.dart';
import 'package:loop/data/repositories/repositories.dart';
import 'package:loop/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Pure math — reindex rewrites each ritual's order to its list position.
  // ---------------------------------------------------------------------------
  test('reindex assigns each ritual order = its list index', () {
    const a = Ritual(id: 'a', title: 'A', icon: 'sparkles', order: 5);
    const b = Ritual(id: 'b', title: 'B', icon: 'sparkles', order: 2);
    const c = Ritual(id: 'c', title: 'C', icon: 'sparkles', order: 9);

    final out = reindex([c, a, b]);

    expect(out.map((r) => r.id).toList(), ['c', 'a', 'b']);
    expect(out.map((r) => r.order).toList(), [0, 1, 2]);
    // unchanged fields are preserved.
    expect(out[1].title, 'A');
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
    // seed two rituals in order.
    await repo.insert(
        const Ritual(id: 'r1', title: 'Pages', icon: 'book.closed.fill', order: 0));
    await repo.insert(
        const Ritual(id: 'r2', title: 'Read', icon: 'books.vertical.fill', order: 1));

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    // hold the autoDispose streaming controller alive across the awaits below.
    container.listen(ritualsBuilderControllerProvider, (_, _) {});

    final notifier =
        container.read(ritualsBuilderControllerProvider.notifier);
    // wait for the initial stream emission before acting.
    await container.read(ritualsBuilderControllerProvider.future);

    // add a new ritual (empty id) → appended with order = current count (2).
    await notifier.addOrUpdate(
        const Ritual(id: '', title: 'Water', icon: 'sparkles'));
    var all = await repo.getAll();
    expect(all.map((r) => r.title).toList(), ['Pages', 'Read', 'Water']);
    expect(all.last.order, 2);

    // reorder: move the last ('Water', index 2) to the front.
    await notifier.reorder(2, 0);
    all = await repo.getAll();
    expect(all.map((r) => r.title).toList(), ['Water', 'Pages', 'Read']);
    expect(all.map((r) => r.order).toList(), [0, 1, 2]);

    // delete 'Pages' (now at index 1) → survivors reindexed gap-free.
    final pages = all.firstWhere((r) => r.title == 'Pages');
    await notifier.delete(pages.id);
    all = await repo.getAll();
    expect(all.map((r) => r.title).toList(), ['Water', 'Read']);
    expect(all.map((r) => r.order).toList(), [0, 1]);
  });
}
