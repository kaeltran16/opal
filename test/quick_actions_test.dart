import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';

/// U06 — Quick Actions overlay: pump the real app inside a [ProviderScope],
/// open the overlay via the center FAB, assert the six action tiles render,
/// then tap outside the grid to close it.
void main() {
  const tiles = [
    'Log expense',
    'Log workout',
    'Start workout',
    'Complete ritual',
    'Ask Pal',
    'Voice entry',
  ];

  testWidgets('FAB opens the Quick Actions overlay with 6 tiles; tap-outside closes',
      (WidgetTester tester) async {
    // onboardingComplete=true so the U17 first-run gate lets the app boot
    // straight to Today (rather than redirecting to onboarding).
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
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // No tiles before opening.
    expect(find.text('Log expense'), findsNothing);

    // Tap the center FAB (the raised "+" in the tab bar).
    final fab = find.byIcon(CupertinoIcons.plus);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // All six action tiles render.
    for (final label in tiles) {
      expect(find.text(label), findsOneWidget, reason: 'missing tile: $label');
    }

    // Tap outside the grid (top-left corner of the dim backdrop) to close.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    // Overlay dismissed.
    expect(find.text('Log expense'), findsNothing);
  });
}
