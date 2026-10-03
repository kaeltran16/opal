@Tags(['scenario'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/settings/appearance_screen.dart';
import 'package:opal/screens/shell/loop_shell.dart';
import 'package:opal/services/pal/mock_pal_service.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

/// Boots the seeded app with no saved brightness. `bootApp` always saves one,
/// which would hide the default this scenario is here to show.
Future<void> _bootWithoutSavedBrightness(WidgetTester tester) async {
  ignoreOverflowErrors();
  SharedPreferences.setMockInitialValues({'settings.onboardingComplete': true});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(
          MockPalService(latency: Duration.zero, seed: 0),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Brightness _brightnessAt(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder)).brightness;

void main() {
  scenarioTest('theme', (tester, dark) async {
    // every step asserts one brightness, so the light pass has nothing to add.
    if (!dark) return;

    await _bootWithoutSavedBrightness(tester);

    expect(find.byType(LoopShell), findsOneWidget);
    expect(_brightnessAt(tester, find.byType(LoopShell)), Brightness.dark);
    await shot(tester, 'theme_default_dark');

    appRouter(tester).go('/you/appearance');
    await tester.pumpAndSettle();

    final screen = find.byType(AppearanceScreen);
    expect(screen, findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(
      find.textContaining(RegExp('accent', caseSensitive: false)),
      findsNothing,
    );
    expect(_brightnessAt(tester, screen), Brightness.dark);
    await shot(tester, 'theme_appearance_dark');

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(_brightnessAt(tester, screen), Brightness.light);
    await shot(tester, 'theme_appearance_switched_light');
  });
}
