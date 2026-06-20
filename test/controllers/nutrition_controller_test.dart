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

  test('pending derivation: unlinked Food & Drink expense surfaces as pending',
      () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = _makeContainer(db);
    addTearDown(() async {
      container.dispose();
      // let drift's stream-query cancellation settle before closing the db,
      // otherwise a write-triggered re-emit races StreamQueryStore.close.
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final now = DateTime.now();
    final entryRepo = container.read(entryRepositoryProvider);
    final expenseId = await entryRepo.insert(Entry(
      id: '',
      timestamp: DateTime(now.year, now.month, now.day, 12),
      type: EntryType.money,
      title: 'Thai Basil',
      amount: -14.50,
      category: 'Food & Drink',
      source: EntrySource.manual,
    ));

    container.listen(nutritionControllerProvider, (_, _) {});
    final state = await container.read(nutritionControllerProvider.future);

    expect(state.pending, isNotNull);
    expect(state.pending!.expense.id, expenseId);
    expect(state.pending!.guess.name, isNotEmpty);
  });

  test('confirmFromExpense scales calories by 1.25 for Larger portion',
      () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = _makeContainer(db);
    addTearDown(() async {
      container.dispose();
      // let drift's stream-query cancellation settle before closing the db,
      // otherwise a write-triggered re-emit races StreamQueryStore.close.
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });

    final now = DateTime.now();
    final entryRepo = container.read(entryRepositoryProvider);
    final expenseId = await entryRepo.insert(Entry(
      id: '',
      timestamp: DateTime(now.year, now.month, now.day, 19),
      type: EntryType.money,
      title: 'Pad Thai',
      amount: -18.00,
      category: 'Food & Drink',
      source: EntrySource.manual,
    ));

    // read the inserted entry back so we have the assigned id
    final entries = await entryRepo.getEntriesInRange(
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day + 1),
    );
    final expense = entries.firstWhere((e) => e.id == expenseId);

    final guess = MealEstimate(
      name: 'Pad Thai',
      cal: const IntRange(400, 800),
      confidence: NutritionConfidence.med,
    );

    // keep provider alive before calling the action
    container.listen(nutritionControllerProvider, (_, _) {});
    await container.read(nutritionControllerProvider.future);

    await container
        .read(nutritionControllerProvider.notifier)
        .confirmFromExpense(expense, guess, name: 'Pad Thai', portion: 'Larger');

    // read directly from the repository — avoids racing the stream re-emit.
    final nutritionRepo = container.read(nutritionRepositoryProvider);
    final meals = await nutritionRepo.getMealsInRange(
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day + 1),
    );
    expect(meals, isNotEmpty, reason: 'expected at least one meal after confirmFromExpense');
    final meal = meals.firstWhere((m) => m.name == 'Pad Thai');

    // factor = 1.25 → (400*1.25).round() = 500, (800*1.25).round() = 1000
    expect(meal.cal.lo, 500);
    expect(meal.cal.hi, 1000);
    expect(meal.source, NutritionSource.takeout);
    expect(meal.linkedEntryId, expenseId);
  });
}
