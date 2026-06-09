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
import 'package:loop/services/services.dart';
import 'package:loop/theme/app_colors.dart';

/// Pumps the [NewEntrySheet] inside a ProviderScope + GoRouter so that
/// `context.pop()` resolves and the theme extension is available. An optional
/// [pal] override swaps in a fast mock for the "Type it" parse flow.
Future<EntryRepository> _pumpSheet(
  WidgetTester tester,
  LoopDatabase db, {
  PalService? pal,
}) async {
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
        if (pal != null) palServiceProvider.overrideWithValue(pal),
      ],
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

  testWidgets('"Type it" parses "coffee 5" and pre-fills an expense',
      (WidgetTester tester) async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = await _pumpSheet(
      tester,
      db,
      pal: MockPalService(latency: const Duration(milliseconds: 20)),
    );

    // Open the "Type it" field (it sits at the bottom of the scrollable list,
    // which lazily builds — scroll it into view first).
    final typeIt = find.text('Type it');
    await tester.scrollUntilVisible(
      typeIt,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(typeIt);
    await tester.pumpAndSettle();

    // Enter natural-language text and submit to parse.
    await tester.enterText(find.byType(TextField).last, 'coffee 5');
    await tester.tap(find.text('Parse'));
    await tester.pump(); // dismiss the modal, kick off parse
    await tester.pump(const Duration(milliseconds: 40)); // fake latency
    await tester.pumpAndSettle();

    // The mock parses "coffee 5" → a money expense of $5 with category Coffee,
    // pre-filled into the sheet (the amount shows in the fixed display).
    expect(find.text('\$5.00'), findsOneWidget);

    // Tapping Add writes the pre-filled entry, proving type/amount/category all
    // flowed from the parse into the form.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final all = await repo.getAll();
    expect(all, hasLength(1));
    final e = all.single;
    expect(e.type, EntryType.money);
    expect(e.amount, closeTo(-5, 1e-9));
    expect(e.category, 'Coffee');
  });
}
