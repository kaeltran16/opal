import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  test('LogMealAction values define equality', () {
    const a = LogMealAction(
      name: 'Burrito', cal: IntRange(520, 820),
      confidence: NutritionConfidence.med, slot: 'Lunch');
    const b = LogMealAction(
      name: 'Burrito', cal: IntRange(520, 820),
      confidence: NutritionConfidence.med, slot: 'Lunch');
    expect(a, b);
    expect(a, isA<PalAction>());
  });
}
