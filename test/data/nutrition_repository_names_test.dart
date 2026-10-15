import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

void main() {
  test('a meal written in any case is stored in the app case', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = NutritionRepository(db);
    final meal = NutritionMeal(
      id: '',
      timestamp: DateTime(2026, 10, 15, 22),
      slot: 'Snack',
      name: 'matcha latte',
      source: NutritionSource.manual,
      icon: NutritionSource.manual.icon,
      confidence: NutritionConfidence.med,
      cal: const IntRange(120, 200),
      macros: macrosFromCal(const IntRange(120, 200)),
    );

    final id = await repo.insert(meal);
    await repo.upsert(meal.copyWith(id: 'm2', name: 'double oat milk latte'));

    final names = (await repo.getMealsInRange(DateTime(2000), DateTime(2100))).map((m) => m.name);
    expect(names, containsAll(['Matcha latte', 'Double oat milk latte']));
    expect(id, isNotEmpty);
  });
}
