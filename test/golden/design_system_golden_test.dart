@Tags(['golden'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/analysis/spend_habits.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/spend_habits_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/entry/new_entry_sheet.dart';
import 'package:opal/theme/app_colors.dart';

import '../support/golden_harness.dart';

/// Golden baseline: one capture per main screen per theme.
///
/// Local visual-verification harness only (machine-local Ahem rendering, not
/// wired into CI). Every test runs under the harness's fixed clock and boots
/// the seeded app, so re-running without `--update-goldens` must match.
void main() {
  goldenTest('today', (tester, dark) async {
    await bootApp(tester, dark: dark);
    // a stray DateTime.now() would show today's real date here instead of
    // silently drifting the capture.
    expect(find.textContaining('MON 28 SEP'), findsOneWidget);
  });

  // shell branches and pushed full-screen routes: go() lands on them directly.
  const goScreens = {
    'move': '/move',
    'areas': '/areas',
    'area_nutrition': '/areas/nutrition',
    'area_routines': '/areas/routines',
    'area_sleep': '/areas/sleep',
    'area_mood': '/areas/mood',
    'profile': '/you',
    'spending_detail': '/areas/money',
  };
  for (final MapEntry(key: name, value: path) in goScreens.entries) {
    goldenTest(name, (tester, dark) async {
      await bootApp(tester, dark: dark);
      appRouter(tester).go(path);
      await tester.pumpAndSettle();
    });
  }

  // non-opaque overlays: push() keeps Today underneath, as the app shows them.
  const pushScreens = {
    'pal_composer': '/pal-composer',
  };
  for (final MapEntry(key: name, value: path) in pushScreens.entries) {
    goldenTest(name, (tester, dark) async {
      await bootApp(tester, dark: dark);
      appRouter(tester).push(path);
      await tester.pumpAndSettle();
    });
  }

  // The in-app FAB opens the Pal composer (not the entry sheet), so the New
  // Entry sheet is reached the same way `new_entry_test.dart` does: a
  // self-contained router that navigates straight to the sheet route.
  goldenTest('new_entry', (tester, dark) async {
    ignoreOverflowErrors();

    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const NewEntrySheet(),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loopDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Fixed habit picks: the real provider mines seeded entries against
          // the current daypart, so the golden would otherwise depend on it.
          spendHabitsProvider.overrideWith(
            (ref) => Stream.value(const [
              HabitPick(
                title: 'Verve Coffee',
                averageAmount: 5,
                occurrences: 4,
                category: 'Food & Drink',
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: dark
              ? ThemeData.dark().copyWith(
                  extensions: [AppColors.dark()],
                )
              : ThemeData.light().copyWith(
                  extensions: [AppColors.light()],
                ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/host/new');
    await tester.pumpAndSettle();
  });
}
