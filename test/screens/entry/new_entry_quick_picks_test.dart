import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/analysis/spend_habits.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/spend_habits_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/screens/entry/new_entry_sheet.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LoopDatabase> _pumpSheet(
  WidgetTester tester, {
  required List<HabitPick> habits,
}) async {
  // Tall viewport so the whole sheet (a lazy ListView) builds its quick-picks.
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        routes: [GoRoute(path: 'new', builder: (context, state) => const NewEntrySheet())],
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      // A closed `Stream.value` emits once and completes, so no drift timer
      // outlives the test.
      spendHabitsProvider.overrideWith((ref) => Stream.value(habits)),
    ],
    child: MaterialApp.router(
      theme: ThemeData.light().copyWith(extensions: [AppColors.light()]),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  router.go('/host/new');
  await tester.pumpAndSettle();
  return db;
}

void main() {
  testWidgets('New Entry renders mined habit picks when the history has them',
      (tester) async {
    await _pumpSheet(tester, habits: const [
      HabitPick(
        title: 'Oat latte',
        averageAmount: 6,
        occurrences: 4,
        category: 'Food & Drink',
      ),
    ]);

    expect(find.text('Oat latte'), findsOneWidget);
    expect(find.text('CATEGORY'), findsOneWidget);
  });

  testWidgets('New Entry hides the pick section on a thin history',
      (tester) async {
    await _pumpSheet(tester, habits: const []);

    // No invented merchant, and no bare heading over an empty row.
    expect(find.text('CATEGORY'), findsNothing);
  });

  testWidgets('a tapped habit pick logs the mined amount, title and category',
      (tester) async {
    final db = await _pumpSheet(tester, habits: const [
      HabitPick(
        title: 'Oat latte',
        averageAmount: 6.5,
        occurrences: 4,
        category: 'Food & Drink',
      ),
    ]);

    await tester.tap(find.text('Oat latte'));
    await tester.pumpAndSettle();

    // The hero display shows the mined average before it is committed.
    expect(find.text('\$6.50'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.entries).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Oat latte');
    expect(rows.single.category, 'Food & Drink');
    expect(rows.single.amount, -6.5); // negative = expense
  });
}
