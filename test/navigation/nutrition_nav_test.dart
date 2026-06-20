import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/widgets/loop_tab_bar.dart';

import '../support/flush_provider_timers.dart';

/// Task 9 — the Nutrition tab + the You relocation off the bar.
///
/// Boots the full seeded app and drives the real router: the Nutrition tab
/// (now in the bar, 4th slot) opens the Nutrition screen, and the Today header
/// avatar (which replaced the old month label) pushes the You/profile screen
/// (no longer a tab).
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

    // Boots to Today; the bar exposes a Nutrition tab (not a You tab).
    expect(
        find.descendant(
            of: find.byType(LoopTabBar), matching: find.text('Nutrition')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(LoopTabBar), matching: find.text('You')),
        findsNothing);

    await tester.tap(find.descendant(
        of: find.byType(LoopTabBar), matching: find.text('Nutrition')));
    await tester.pumpAndSettle();

    // The (stub) Nutrition screen is on screen.
    expect(find.textContaining('Nutrition'), findsWidgets);

    await flushProviderTimers(tester);
  });

  testWidgets('the Today avatar pushes the You/profile screen', (tester) async {
    await bootApp(tester);

    // The Today header avatar (semanticLabel 'You') replaced the month label.
    final avatar = find.bySemanticsLabel('You');
    expect(avatar, findsOneWidget);

    await tester.tap(avatar);
    await tester.pumpAndSettle();

    // The pushed profile screen renders its header + its back-to-Today action.
    expect(find.text('Reviews, patterns, settings'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Today'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
