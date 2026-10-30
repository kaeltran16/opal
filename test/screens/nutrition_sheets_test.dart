import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/controllers/area_detail_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/nutrition/nutrition_add_sheet.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/theme/app_type.dart';

import '../support/flush_provider_timers.dart';
import '../support/seeded_clock.dart';

/// Task 13 smoke test — opens the add sheet from the Nutrition area page's Add a
/// meal, taps a quick pick, saves; asserts the new meal name appears in the
/// page's meals list.
const _pickLabel = 'Or pick a common one';

void main() {
  // Pumps the app on the Nutrition area page; returns the page.
  Future<Finder> bootPage(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final router = createRouter(initialLocation: '/nutrition');
    final colors = AppColors.light();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          palServiceProvider.overrideWithValue(
              MockPalService(latency: const Duration(milliseconds: 1))),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // the old path redirects to the Areas Nutrition page.
    final page = find.byWidgetPredicate(
        (w) => w is DetailScreen && w.area == Area.nutrition);
    expect(page, findsOneWidget);
    return page;
  }

  // Pumps the app on the Nutrition area page and opens the add-meal sheet.
  Future<void> openAddSheet(WidgetTester tester) async {
    final page = await bootPage(tester);

    // hit-testable, so it is not left under the floating tab bar.
    final add = find.bySemanticsLabel('Add a meal').hitTestable();
    await tester.scrollUntilVisible(
      add,
      100,
      scrollable:
          find.descendant(of: page, matching: find.byType(Scrollable)).first,
    );
    await tester.tap(add);
    await tester.pumpAndSettle();
  }

  testWidgetsSeeded('add sheet: tap quick pick + Save adds meal to landing',
      (tester) async {
    await openAddSheet(tester);

    // Sheet is open — header and quick picks visible.
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Add a meal')),
        findsOneWidget);
    expect(find.text(_pickLabel), findsOneWidget);

    // Tap the 'Banana' quick pick (scroll the sheet body to it first — the
    // describe card can push the grid below the fold on short viewports).
    final sheetScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Banana'),
      200,
      scrollable: sheetScrollable,
    );
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();

    // Estimate preview should now be showing (CalRange renders the name field).
    // The name field is seeded with 'Banana'; tap Save.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Sheet should have closed. The save completes synchronously in the mock,
    // so the landing list should include 'Banana' once the stream settles.
    // The meal was just added so it renders in the meals section. A simple
    // find.text works if it's in the visible or off-screen tree.
    expect(find.text('Banana'), findsWidgets);

    await flushProviderTimers(tester);
  });

  testWidgetsSeeded('estimate keeps the typed name (no title-cased overwrite)',
      (tester) async {
    await openAddSheet(tester);

    // Type a lowercase description; the mock's estimate name title-cases it, so a
    // title-cased field would prove the old overwrite bug. We expect it kept as-is.
    await tester.enterText(find.byType(TextField).last, 'pho beef brisket');
    await tester.tap(find.text('Estimate'));
    await tester.pumpAndSettle();

    // estimate result is showing, and the field still holds the typed text.
    expect(find.text('pho beef brisket'), findsOneWidget);
    expect(find.text('Pho Beef Brisket'), findsNothing);
    expect(find.text(_pickLabel), findsNothing);

    // Re-estimating must not clobber the name either.
    await tester.tap(find.text('Estimate'));
    await tester.pumpAndSettle();
    expect(find.text('pho beef brisket'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgetsSeeded('Start over returns to the quick-pick grid', (tester) async {
    await openAddSheet(tester);
    expect(find.text(_pickLabel), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'pho');
    await tester.tap(find.text('Estimate'));
    await tester.pumpAndSettle();
    // estimate replaced the quick picks.
    expect(find.text(_pickLabel), findsNothing);

    final sheetScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Start over'),
      200,
      scrollable: sheetScrollable,
    );
    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();

    // quick picks are back.
    expect(find.text(_pickLabel), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgetsSeeded('slot pills select with semantics selected', (tester) async {
    await openAddSheet(tester);

    await tester.tap(find.bySemanticsLabel('Dinner'));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(find.bySemanticsLabel('Dinner')),
        isSemantics(isSelected: true, isButton: true));
    for (final other in ['Breakfast', 'Lunch', 'Snack', 'Drink']) {
      expect(tester.getSemantics(find.bySemanticsLabel(other)),
          isSemantics(isSelected: false));
    }

    await flushProviderTimers(tester);
  });

  testWidgetsSeeded('Estimate fills the result with a score number', (tester) async {
    await openAddSheet(tester);

    await tester.enterText(find.byType(TextField).last, 'pho');
    await tester.tap(find.text('Estimate'));
    await tester.pumpAndSettle();

    final score = find.byWidgetPredicate((w) =>
        w is Text &&
        w.style?.fontSize == AppType.score.fontSize &&
        w.style?.fontWeight == AppType.score.fontWeight);
    expect(score, findsOneWidget);
    expect(find.textContaining('kcal, likely '), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgetsSeeded('edit-mode Save updates the meal in place', (tester) async {
    final page = await bootPage(tester);
    final container = ProviderScope.containerOf(tester.element(page));
    final before = container.read(areaDetailProvider(Area.nutrition)).requireValue.meals;
    final meal = before.first;

    showNutritionAddSheet(tester.element(page), meal: meal);
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Adjust estimate')),
        findsOneWidget);
    // editing seeds the estimate, so the result shows instead of the quick picks.
    expect(find.text(_pickLabel), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'Renamed meal');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final after = container.read(areaDetailProvider(Area.nutrition)).requireValue.meals;
    expect(after.length, before.length);
    expect(after.singleWhere((m) => m.id == meal.id).name, 'Renamed meal');

    await flushProviderTimers(tester);
  });
}
