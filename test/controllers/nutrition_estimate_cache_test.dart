import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/services.dart';

/// Counts model calls so the test can assert a repeat description never reaches
/// Pal. Returns a fixed estimate: the point is call count, not the numbers.
class _CountingPal extends MockPalService {
  _CountingPal() : super(latency: Duration.zero);

  int estimateCalls = 0;

  @override
  Future<MealEstimate> estimateMeal(String description) async {
    estimateCalls++;
    return const MealEstimate(
      name: 'Pho bo',
      cal: IntRange(450, 620),
      confidence: NutritionConfidence.med,
    );
  }
}

class _NoHaptics implements HapticsService {
  @override
  Future<void> light() async {}
  @override
  Future<void> medium() async {}
  @override
  Future<void> success() async {}
}

void main() {
  late LoopDatabase db;
  late _CountingPal pal;
  late ProviderContainer container;

  setUp(() {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    pal = _CountingPal();
    container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(pal),
      hapticsServiceProvider.overrideWithValue(_NoHaptics()),
    ]);
    addTearDown(() async {
      container.dispose();
      // let drift's stream-query cancellation settle before closing the db.
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });
  });

  NutritionController controller() =>
      container.read(nutritionControllerProvider.notifier);

  test('the first estimate for a description asks Pal', () async {
    final est = await controller().estimateFor('pho bo');

    expect(pal.estimateCalls, 1);
    expect(est.cal, const IntRange(450, 620));
  });

  test('a repeat description is served from the cache without asking Pal',
      () async {
    final first = await controller().estimateFor('pho bo');
    final second = await controller().estimateFor('pho bo');

    expect(pal.estimateCalls, 1);
    expect(second, first);
  });

  test('the same dish written differently still hits the cache', () async {
    final first = await controller().estimateFor('Pho bo!');
    final second = await controller().estimateFor('  pho   BO ');

    expect(pal.estimateCalls, 1);
    expect(second, first);
  });

  test('a different dish asks Pal again', () async {
    await controller().estimateFor('pho bo');
    await controller().estimateFor('pho ga');

    expect(pal.estimateCalls, 2);
  });

  test('a cached estimate keeps its original confidence', () async {
    await controller().estimateFor('pho bo');
    final cached = await controller().estimateFor('pho bo');

    expect(cached.confidence, NutritionConfidence.med);
  });
}
