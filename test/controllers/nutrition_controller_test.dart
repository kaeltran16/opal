import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/services.dart';

void main() {
  test('day rollup sums calorie + macro ranges across today\'s meals', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(MockPalService(latency: Duration.zero)),
    ]);
    addTearDown(() async {
      container.dispose();
      // let drift's stream-query cancellation settle before closing the db,
      // otherwise a write-triggered re-emit races StreamQueryStore.close.
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final now = DateTime.now();
    final repo = container.read(nutritionRepositoryProvider);
    await repo.insert(NutritionMeal(
        id: '',
        timestamp: DateTime(now.year, now.month, now.day, 8),
        slot: 'Breakfast',
        name: 'Oats',
        source: NutritionSource.home,
        icon: 'leaf.fill',
        confidence: NutritionConfidence.high,
        cal: const IntRange(300, 400),
        macros: macrosFromCal(const IntRange(300, 400))));
    await repo.insert(NutritionMeal(
        id: '',
        timestamp: DateTime(now.year, now.month, now.day, 13),
        slot: 'Lunch',
        name: 'Bowl',
        source: NutritionSource.home,
        icon: 'leaf.fill',
        confidence: NutritionConfidence.med,
        cal: const IntRange(500, 700),
        macros: macrosFromCal(const IntRange(500, 700))));

    // keep the autodispose stream provider alive while we await its first
    // emit (matches pal_inbox_controller_test) — otherwise it disposes mid-load.
    container.listen(nutritionControllerProvider, (_, _) {});
    final state = await container.read(nutritionControllerProvider.future);
    expect(state.day.cal.lo, 800);
    expect(state.day.cal.hi, 1100);
    expect(state.day.meals, 2);
    expect(state.day.home, 2);
  });
}
