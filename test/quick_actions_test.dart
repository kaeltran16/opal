import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';

import 'support/flush_provider_timers.dart';

/// The ask bar opens the unified **Pal composer** (the single input surface
/// that replaced the old Quick-Actions menu and the FAB). Pump the real app,
/// tap the ask bar, assert the composer surface appears, then dismiss it by
/// tapping the backdrop.
void main() {
  testWidgets('the ask bar opens the Pal composer; tap-outside closes',
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

    final askBar = find.bySemanticsLabel('Ask or log anything');
    expect(askBar, findsOneWidget);
    await tester.tap(askBar);
    await tester.pumpAndSettle();

    // The compact composer surface is up.
    expect(find.text('Log, ask, or start anything'), findsOneWidget);
    expect(find.text('Start a workout'), findsOneWidget);

    // Tap the backdrop (top of the screen, above the sheet) to dismiss.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Log, ask, or start anything'), findsNothing);

    await flushProviderTimers(tester);
  });
}
