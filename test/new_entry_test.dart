import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:loop/controllers/providers.dart';
import 'package:loop/data/db/database.dart';
import 'package:loop/data/repositories/repositories.dart';
import 'package:loop/models/models.dart';
import 'package:loop/screens/entry/new_entry_sheet.dart';
import 'package:loop/theme/app_colors.dart';

/// Pumps the [NewEntrySheet] inside a ProviderScope + GoRouter so that
/// `context.pop()` resolves and the theme extension is available.
Future<EntryRepository> _pumpSheet(WidgetTester tester, LoopDatabase db) async {
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
      overrides: [loopDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        theme: ThemeData.light().copyWith(
          extensions: [AppColors.light(AppAccent.blue)],
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Navigate to the sheet route.
  router.go('/host/new');
  await tester.pumpAndSettle();

  return EntryRepository(db);
}

void main() {
  testWidgets(
      'typing 5 . 7 5 shows \$5.75 and Add writes a manual expense Entry',
      (WidgetTester tester) async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = await _pumpSheet(tester, db);

    // Default kind is Expense; display starts at $0.00.
    expect(find.text('\$0.00'), findsOneWidget);

    // Tap keypad: 5, ., 7, 5 (each key's text is unique to the keypad, which is
    // pinned at the bottom of the sheet).
    Future<void> tapKey(String key) async {
      await tester.tap(find.text(key));
      await tester.pump();
    }

    await tapKey('5');
    await tapKey('.');
    await tapKey('7');
    await tapKey('5');

    // Display reflects the typed amount.
    expect(find.text('\$5.75'), findsOneWidget);

    // Tap Add.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // An Entry reached the repository: a manual money expense of -5.75.
    final all = await repo.getAll();
    expect(all, hasLength(1));
    final e = all.single;
    expect(e.type, EntryType.money);
    expect(e.source, EntrySource.manual);
    expect(e.amount, closeTo(-5.75, 1e-9));
  });

  testWidgets('Add is disabled until a valid value is entered',
      (WidgetTester tester) async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = await _pumpSheet(tester, db);

    // Tapping Add with an empty buffer does nothing.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(await repo.getAll(), isEmpty);
  });
}
