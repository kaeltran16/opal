import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/services.dart';

/// No-op haptics so controller actions don't crash on non-device platforms.
class _NoHaptics implements HapticsService {
  @override
  Future<void> light() async {}
  @override
  Future<void> medium() async {}
  @override
  Future<void> success() async {}
}

ProviderContainer _makeContainer(LoopDatabase db) => ProviderContainer(
      overrides: [
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider
            .overrideWithValue(MockPalService(latency: Duration.zero)),
        hapticsServiceProvider.overrideWithValue(_NoHaptics()),
      ],
    );

void main() {
  test('updateMeal edits the meal in place and does not change the meal count',
      () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = _makeContainer(db);
    addTearDown(() async {
      container.dispose();
      // let drift's stream-query cancellation settle before closing the db.
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final now = DateTime.now();
    final repo = container.read(nutritionRepositoryProvider);
    final id = await repo.insert(NutritionMeal(
      id: '',
      timestamp: DateTime(now.year, now.month, now.day, 19),
      slot: 'Dinner',
      name: 'Pad Thai',
      source: NutritionSource.manual,
      icon: NutritionSource.manual.icon,
      confidence: NutritionConfidence.low,
      cal: const IntRange(400, 600),
      macros: macrosFromCal(const IntRange(400, 600)),
    ));

    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final before = await repo.getMealsInRange(dayStart, dayEnd);
    expect(before, hasLength(1));
    final original = before.single;

    container.listen(nutritionControllerProvider, (_, _) {});
    await container.read(nutritionControllerProvider.future);

    await container.read(nutritionControllerProvider.notifier).updateMeal(
          original,
          slot: 'Lunch',
          name: 'Chicken bowl',
          est: const MealEstimate(
            name: 'Chicken bowl',
            cal: IntRange(520, 680),
            confidence: NutritionConfidence.med,
          ),
        );

    final after = await repo.getMealsInRange(dayStart, dayEnd);
    // no duplicate: still exactly one meal, same id.
    expect(after, hasLength(1));
    final updated = after.single;
    expect(updated.id, id);
    expect(updated.slot, 'Lunch');
    expect(updated.name, 'Chicken bowl');
    expect(updated.cal, const IntRange(520, 680));
    // identity preserved: source, timestamp unchanged.
    expect(updated.source, NutritionSource.manual);
    expect(updated.timestamp, original.timestamp);
  });
}
