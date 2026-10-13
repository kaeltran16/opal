import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/app.dart';
import 'package:opal/controllers/area_detail_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/nutrition/nutrition_meal_detail_screen.dart';
import 'package:opal/screens/profile/profile_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

import '../support/flush_provider_timers.dart';

String _path(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(GlassTabBar)))
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

/// Nutrition under the Areas tab, and the You tab, in the four-tab glass shell.
///
/// Boots the full seeded app and drives the real router: a meal on the Areas
/// Nutrition page opens its detail under /areas/nutrition, and the You tab
/// opens the profile as a tab root (no back button).
void main() {
  Future<void> bootApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          palServiceProvider
              .overrideWithValue(MockPalService(latency: Duration.zero)),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a meal opens its detail under the Areas Nutrition page',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.bySemanticsLabel(RegExp('^Areas'))));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Nutrition')));
    await tester.pumpAndSettle();
    expect(_path(tester), '/areas/nutrition');

    final meal = ProviderScope.containerOf(tester.element(find.byType(LoopApp)))
        .read(areaDetailProvider(Area.nutrition))
        .requireValue
        .meals
        .first;
    final row = find.bySemanticsLabel(
        RegExp('^${RegExp.escape('${meal.slot} at ${meal.time}, ${meal.name}, ')}'));
    await tester.scrollUntilVisible(row, 300,
        scrollable: find
            .descendant(
                of: find.byType(DetailScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    final detail = find.byType(NutritionMealDetailScreen);
    expect(detail, findsOneWidget);
    // a pushed page keeps the shell's location, so read the page's own state.
    expect(GoRouterState.of(tester.element(detail)).uri.path,
        '/areas/nutrition/meal/${meal.id}');

    await flushProviderTimers(tester);
  });

  testWidgets('the You tab opens the profile as a tab root', (tester) async {
    await bootApp(tester);

    await tester.tap(find.descendant(
        of: find.byType(GlassTabBar), matching: find.text('You')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsNothing);

    await flushProviderTimers(tester);
  });
}
