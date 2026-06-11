import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';

import 'support/flush_provider_timers.dart';

/// Handoff #2 — the center FAB now opens the unified **Pal composer** (the
/// single input surface that replaced the old Quick-Actions menu). Pump the
/// real app, tap the FAB, assert the composer surface appears, then dismiss it
/// by tapping the dim backdrop.
void main() {
  testWidgets('FAB opens the Pal composer; tap-outside closes',
      (WidgetTester tester) async {
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

    // Composer not present before opening.
    expect(find.text('Log, ask, or start anything'), findsNothing);

    // Tap the center FAB (the raised "+" in the tab bar).
    final fab = find.byIcon(CupertinoIcons.plus);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // The compact composer surface is up.
    expect(find.text('Log, ask, or start anything'), findsOneWidget);
    expect(find.text('Start a workout'), findsOneWidget);

    // Tap the dim backdrop (top of the screen, above the sheet) to dismiss.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Log, ask, or start anything'), findsNothing);

    await flushProviderTimers(tester);
  });
}
