// test/models/nutrition_meal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';

void main() {
  test('IntRange mid rounds the midpoint', () {
    expect(const IntRange(290, 400).mid, 345);
  });

  test('enum wire round-trips', () {
    expect(NutritionSource.fromWire('takeout'), NutritionSource.takeout);
    expect(NutritionConfidence.fromWire('high').bars, 3);
    expect(NutritionConfidence.med.label, 'fair estimate');
  });

  test('macrosFromCal derives honest ranges', () {
    final m = macrosFromCal(const IntRange(400, 800));
    expect(m.protein.lo, 22); // 400*.22/4
    expect(m.carbs.hi, 100);  // 800*.50/4
    expect(m.fat.hi, 25);     // round(800*.28/9)
  });

  test('copyWith preserves untouched fields', () {
    final meal = NutritionMeal(
      id: 'm1', timestamp: DateTime(2026, 6, 21, 8), slot: 'Breakfast',
      name: 'Oats', source: NutritionSource.home, icon: 'leaf.fill',
      confidence: NutritionConfidence.high, cal: const IntRange(290, 400),
      macros: macrosFromCal(const IntRange(290, 400)), tags: const ['fiber-rich'],
    );
    expect(meal.copyWith(name: 'Oats & berries').tags, ['fiber-rich']);
  });
}
