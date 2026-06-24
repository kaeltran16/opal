import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';

import '../support/flush_provider_timers.dart';

/// Task 13 smoke test — opens the add sheet, taps a quick pick, saves; asserts
/// the new meal name appears in the meals list on the landing screen.
void main() {
  // Pumps the app on the nutrition landing and opens the add-meal sheet.
  Future<void> openAddSheet(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final router = createRouter(initialLocation: '/nutrition');
    final colors = AppColors.light(AppAccent.indigo);

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
    expect(find.text('TODAY'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Add a meal'),
      -300,
      scrollable: scrollable,
    );
    await tester.tap(find.bySemanticsLabel('Add a meal'));
    await tester.pumpAndSettle();
  }

  testWidgets('add sheet: tap quick pick + Save adds meal to landing',
      (tester) async {
    await openAddSheet(tester);

    // Sheet is open — header and quick picks visible.
    expect(find.text('Add a meal'), findsOneWidget);
    expect(find.text('OR PICK A COMMON ONE'), findsOneWidget);

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

  testWidgets('estimate keeps the typed name (no title-cased overwrite)',
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
    expect(find.text('OR PICK A COMMON ONE'), findsNothing);

    // Re-estimating must not clobber the name either.
    await tester.tap(find.text('Estimate'));
    await tester.pumpAndSettle();
    expect(find.text('pho beef brisket'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('Start over returns to the quick-pick grid', (tester) async {
    await openAddSheet(tester);
    expect(find.text('OR PICK A COMMON ONE'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'pho');
    await tester.tap(find.text('Estimate'));
    await tester.pumpAndSettle();
    // estimate replaced the quick picks.
    expect(find.text('OR PICK A COMMON ONE'), findsNothing);

    final sheetScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Start over'),
      200,
      scrollable: sheetScrollable,
    );
    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();

    // quick picks are back.
    expect(find.text('OR PICK A COMMON ONE'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
