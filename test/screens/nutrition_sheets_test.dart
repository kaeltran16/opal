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
  testWidgets('add sheet: tap quick pick + Save adds meal to landing',
      (tester) async {
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

    // Confirm landing loaded past the loading state.
    expect(find.text('TODAY'), findsOneWidget);

    // The + (plus) NavIconButton may be in the sticky header; scroll until
    // visible to be safe, then tap it.
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Add a meal'),
      -300,
      scrollable: scrollable,
    );
    await tester.tap(find.bySemanticsLabel('Add a meal'));
    await tester.pumpAndSettle();

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
}
