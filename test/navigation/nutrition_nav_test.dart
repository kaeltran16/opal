import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

import '../support/flush_provider_timers.dart';

/// The Nutrition and You tabs of the four-tab glass shell.
///
/// Boots the full seeded app and drives the real router: the Nutrition tab
/// opens the Nutrition screen, and the You tab opens the profile as a tab root
/// (no back button).
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

  testWidgets('the Nutrition tab opens the Nutrition screen', (tester) async {
    await bootApp(tester);

    expect(
        find.descendant(
            of: find.byType(GlassTabBar), matching: find.text('Nutrition')),
        findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(GlassTabBar), matching: find.text('Nutrition')));
    await tester.pumpAndSettle();

    // The (stub) Nutrition screen is on screen.
    expect(find.textContaining('Nutrition'), findsWidgets);

    await flushProviderTimers(tester);
  });

  testWidgets('the You tab opens the profile as a tab root', (tester) async {
    await bootApp(tester);

    await tester.tap(find.descendant(
        of: find.byType(GlassTabBar), matching: find.text('You')));
    await tester.pumpAndSettle();

    expect(find.text('What Pal remembers'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsNothing);

    await flushProviderTimers(tester);
  });
}
