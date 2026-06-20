import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/mock_pal_service.dart';

void main() {
  test('estimateMeal returns a sane range + confidence', () async {
    final pal = MockPalService(latency: Duration.zero);
    final e = await pal.estimateMeal('chicken & rice bowl');
    expect(e.cal.lo, lessThan(e.cal.hi));
    expect(e.name, isNotEmpty);
    expect(NutritionConfidence.values, contains(e.confidence));
    expect(e.macros.protein.lo, greaterThan(0));
  });
}
