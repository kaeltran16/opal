import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/controllers/correlations_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

void main() {
  test('surfaces a strong move-money relationship from real entries', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = EntryRepository(db);
    final now = DateTime.now();
    // 28 days: every 3rd day a workout (300 kcal) + light spend; else heavy spend.
    for (var i = 0; i < 28; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final workout = i % 3 == 0;
      if (workout) {
        await repo.insert(Entry(
            id: 'w$i', timestamp: day.add(const Duration(hours: 7)),
            type: EntryType.move, title: 'run', calories: 300,
            source: EntrySource.manual));
      }
      await repo.insert(Entry(
          id: 'm$i', timestamp: day.add(const Duration(hours: 18)),
          type: EntryType.money, title: 'spend',
          amount: workout ? -20.0 : -60.0, category: 'Food', source: EntrySource.manual));
    }

    final c = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(c.dispose);

    final out = await c.read(surfacedCorrelationsProvider.future);
    expect(out, isNotEmpty);
    expect(out.first.involves(Dimension.move), isTrue);
    expect(out.first.involves(Dimension.money), isTrue);
  });
}
