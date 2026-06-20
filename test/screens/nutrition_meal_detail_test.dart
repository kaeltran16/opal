import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/nutrition/nutrition_meal_detail_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';

/// Task 11 — meal detail screen smoke test.
///
/// Queries the seeded meal id from the DB (no hardcoding), then overrides
/// [nutritionControllerProvider] with a pre-loaded state so the screen never
/// sits in loading. The seeded meal is available in state.meals synchronously.
void main() {
  testWidgets('meal detail shows meal name and estimated text', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    // Read the first seeded meal id + name from the DB directly — no hardcoding.
    final rows = await db.select(db.nutritionMeals).get();
    expect(rows, isNotEmpty, reason: 'Seeder must insert meals');
    final mealId = rows.first.id;
    final mealName = rows.first.name;

    // Build a canned NutritionState that includes the seeded meal — avoids any
    // stream-timing issues in the test environment.
    final meal = NutritionMeal(
      id: mealId,
      timestamp: DateTime.now(),
      slot: 'Breakfast',
      name: mealName,
      source: NutritionSource.home,
      icon: 'leaf.fill',
      confidence: NutritionConfidence.med,
      cal: const IntRange(290, 400),
      macros: macrosFromCal(const IntRange(290, 400)),
    );
    final cannedState = NutritionState(
      meals: [meal],
      day: NutritionDay(
        cal: const IntRange(290, 400),
        macros: macrosFromCal(const IntRange(290, 400)),
        meals: 1,
        takeout: 0,
        home: 1,
        feel: 'lighter day',
        note: 'a fair mix',
      ),
      week: const [],
      pending: null,
      patterns: const [],
    );

    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          palServiceProvider
              .overrideWithValue(MockPalService(latency: Duration.zero)),
          // Pre-load the controller with a known state — no async stream needed.
          nutritionControllerProvider
              .overrideWith(() => _CannedNutritionController(cannedState)),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          debugShowCheckedModeBanner: false,
          home: NutritionMealDetailScreen(mealId: mealId),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // The meal name appears in the large title.
    expect(find.textContaining(mealName), findsWidgets);

    // The CalRange widget renders "xxx–yyy estimated".
    expect(find.textContaining('estimated'), findsOneWidget);

    // Dispose cleanly.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

/// A trivial [NutritionController] override that immediately emits a fixed
/// [NutritionState]. Used in tests to skip async stream initialization.
class _CannedNutritionController extends NutritionController {
  _CannedNutritionController(this._state);
  final NutritionState _state;

  @override
  Stream<NutritionState> build() async* {
    yield _state;
  }
}
