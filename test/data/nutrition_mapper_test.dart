import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/db/mappers.dart';
import 'package:opal/models/models.dart';

void main() {
  test('NutritionMeal survives a DB round-trip', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final meal = NutritionMeal(
      id: 'm1', timestamp: DateTime(2026, 6, 21, 12, 40), slot: 'Lunch',
      name: 'Turkey sandwich', source: NutritionSource.takeout, icon: 'fork.knife',
      confidence: NutritionConfidence.med, cal: const IntRange(560, 820),
      macros: macrosFromCal(const IntRange(560, 820)),
      note: 'estimated from Tartine order', tags: const ['from expense', 'high-carb'],
      linkedEntryId: 'e1',
    );
    await db.into(db.nutritionMeals).insert(meal.toCompanion());
    final row = await db.select(db.nutritionMeals).getSingle();
    expect(row.toModel(), meal);
    await db.close();
  });
}
