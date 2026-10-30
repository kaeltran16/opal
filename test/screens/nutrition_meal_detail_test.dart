import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/nutrition/nutrition_meal_detail_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/theme/app_type.dart';

import '../support/flush_provider_timers.dart';
import '../support/seeded_clock.dart';

const _home = 'Nutrition page';
const _note = 'You said: extra chicken, no sour cream.';

final _expense = Entry(
  id: 'expense-1',
  timestamp: DateTime(2026, 10, 14, 12, 30),
  type: EntryType.money,
  title: 'Chipotle',
  amount: -125000,
  source: EntrySource.email,
);

NutritionMeal _meal({String? note, String? linkedEntryId, List<String> tags = const []}) =>
    NutritionMeal(
      id: 'meal-1',
      timestamp: DateTime(2026, 10, 14, 12, 30),
      slot: 'Lunch',
      name: 'Chicken burrito bowl',
      source: NutritionSource.home,
      icon: 'fork.knife',
      confidence: NutritionConfidence.med,
      cal: const IntRange(290, 400),
      macros: macrosFromCal(const IntRange(290, 400)),
      note: note,
      tags: tags,
      linkedEntryId: linkedEntryId,
    );

NutritionState _state(List<NutritionMeal> meals, {Map<String, Entry> linked = const {}}) =>
    NutritionState(
      meals: meals,
      day: NutritionDay(
        cal: const IntRange(290, 400),
        macros: macrosFromCal(const IntRange(290, 400)),
        meals: meals.length,
        takeout: 0,
        home: meals.length,
        feel: 'lighter day',
        note: 'a fair mix',
      ),
      week: const [],
      patterns: const [],
      linkedExpenses: linked,
    );

/// Pumps a home route with the meal detail pushed on top, so back and Delete
/// have somewhere to return to. [controller] replaces the real controller;
/// without a [mealId] it opens the first seeded meal.
Future<(LoopDatabase, String)> _pump(
  WidgetTester tester, {
  String? mealId,
  NutritionController Function()? controller,
  String currency = 'USD',
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'settings.onboardingComplete': true,
    'settings.currency': currency,
  });
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  addTearDown(db.close);
  final id = mealId ?? (await db.select(db.nutritionMeals).get()).first.id;

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Center(child: Text(_home))),
        routes: [
          GoRoute(
            path: 'meal/:id',
            builder: (_, state) =>
                NutritionMealDetailScreen(mealId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(MockPalService(latency: Duration.zero)),
        if (controller != null) nutritionControllerProvider.overrideWith(controller),
      ],
      child: MaterialApp.router(
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  router.push('/meal/$id');
  await tester.pumpAndSettle();
  return (db, id);
}

void main() {
  testWidgets('a linked meal shows its estimate, macros, note, tags and actions',
      (tester) async {
    final meal = _meal(note: _note, linkedEntryId: _expense.id, tags: ['high protein', 'quick']);
    await _pump(
      tester,
      mealId: meal.id,
      currency: 'VND',
      controller: () => _CannedNutritionController(
          _state([meal], linked: {_expense.id: _expense})),
    );

    expect(find.text('Lunch · 12:30 PM'), findsOneWidget);
    expect(find.text('Chicken burrito bowl'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Nutrition'), findsOneWidget);

    final kcal = tester.widget<Text>(find.text('345'));
    expect(kcal.style?.fontSize, AppType.display.fontSize);
    expect(find.text('kcal, likely 290–400'), findsOneWidget);
    expect(find.text('From what you logged, fair estimate'), findsOneWidget);

    expect(find.text('Macros'), findsOneWidget);
    for (final macro in ['Protein', 'Carbs', 'Fat']) {
      expect(find.text(macro), findsOneWidget);
    }
    expect(find.text(_note), findsOneWidget);
    expect(find.text('high protein · quick'), findsOneWidget);

    expect(find.text('Chipotle'), findsOneWidget);
    expect(find.text('Linked expense'), findsOneWidget);
    // the user's currency, never a hardcoded dollar. vnd trails its symbol
    // after a no-break space.
    expect(find.text('125.000 ₫'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);

    expect(find.bySemanticsLabel('Adjust estimate'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('a meal added by hand has no note line or amount', (tester) async {
    final meal = _meal();
    await _pump(
      tester,
      mealId: meal.id,
      controller: () => _CannedNutritionController(_state([meal])),
    );

    expect(find.text('Added by hand'), findsOneWidget);
    expect(find.text('Not from an expense'), findsOneWidget);
    expect(find.text(_note), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);

    await flushProviderTimers(tester);
  });

  testWidgets('loading shows its ink3 line inside the chrome', (tester) async {
    await _pump(tester, mealId: 'meal-1', controller: _PendingNutritionController.new);

    final text = tester.widget<Text>(find.text('Loading…'));
    expect(text.style?.color, AppColors.light().ink3);
    expect(find.bySemanticsLabel('Back to Nutrition'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('a missing meal shows its ink3 line inside the chrome', (tester) async {
    await _pump(
      tester,
      mealId: 'gone',
      controller: () => _CannedNutritionController(_state([_meal()])),
    );

    final text = tester.widget<Text>(find.text('Meal not found.'));
    expect(text.style?.color, AppColors.light().ink3);
    expect(find.bySemanticsLabel('Back to Nutrition'), findsOneWidget);

    await tester.tap(find.text('Nutrition'));
    await tester.pumpAndSettle();
    expect(find.text(_home), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('Adjust estimate opens the add sheet in edit mode', (tester) async {
    final meal = _meal();
    await _pump(
      tester,
      mealId: meal.id,
      controller: () => _CannedNutritionController(_state([meal])),
    );

    await tester.tap(find.bySemanticsLabel('Adjust estimate'));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Adjust estimate')),
        findsOneWidget);
    expect(find.text('Chicken burrito bowl'), findsWidgets);

    await flushProviderTimers(tester);
  });

  testWidgetsSeeded('Delete removes the meal and returns', (tester) async {
    final (db, seeded) = await _pump(tester);
    expect(find.byType(NutritionMealDetailScreen), findsOneWidget);
    expect(find.text('Meal not found.'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();

    expect(find.text(_home), findsOneWidget);
    final rows = await (db.select(db.nutritionMeals)..where((m) => m.id.equals(seeded))).get();
    expect(rows, isEmpty);

    await flushProviderTimers(tester);
  });
}

/// Emits a fixed [NutritionState], skipping the async stream setup.
class _CannedNutritionController extends NutritionController {
  _CannedNutritionController(this._state);
  final NutritionState _state;

  @override
  Stream<NutritionState> build() async* {
    yield _state;
  }
}

/// Never emits, so the screen stays loading.
class _PendingNutritionController extends NutritionController {
  @override
  Stream<NutritionState> build() => StreamController<NutritionState>().stream;
}
