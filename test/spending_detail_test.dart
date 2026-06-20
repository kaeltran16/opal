import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/spending_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/theme/app_colors.dart';

/// A timestamp today at [hour]:[minute].
DateTime _todayAt(int hour, int minute) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, hour, minute);
}

/// Minimal app wrapper providing the AppColors ThemeExtension the screen reads.
Widget _wrap(Widget child) {
  final colors = AppColors.light(AppAccent.blue);
  return MaterialApp(
    theme: ThemeData(extensions: [colors]),
    home: child,
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // Pure model logic (buildDetailData) — total + category folding.
  // ---------------------------------------------------------------------------
  test('buildDetailData computes total + category breakdown for money', () {
    final entries = [
      Entry(
        id: '1',
        timestamp: _todayAt(8, 0),
        type: EntryType.money,
        title: 'Verve Coffee',
        amount: -6,
        category: 'Food & Drink',
        source: EntrySource.manual,
      ),
      Entry(
        id: '2',
        timestamp: _todayAt(9, 0),
        type: EntryType.money,
        title: 'Tartine',
        amount: -14,
        category: 'Food & Drink',
        source: EntrySource.manual,
      ),
      Entry(
        id: '3',
        timestamp: _todayAt(10, 0),
        type: EntryType.money,
        title: 'Whole Foods',
        amount: -30,
        category: 'Groceries',
        source: EntrySource.manual,
      ),
      Entry(
        id: '4',
        timestamp: _todayAt(11, 0),
        type: EntryType.money,
        title: 'Muni',
        amount: -2.50,
        category: 'Transit',
        source: EntrySource.manual,
      ),
      // Income — must NOT count toward spending total.
      Entry(
        id: '5',
        timestamp: _todayAt(12, 0),
        type: EntryType.money,
        title: 'Refund',
        amount: 20,
        category: 'Food & Drink',
        source: EntrySource.manual,
      ),
      // Non-money — ignored by the money tracker.
      Entry(
        id: '6',
        timestamp: _todayAt(13, 0),
        type: EntryType.move,
        title: 'Run',
        duration: 30,
        source: EntrySource.health,
      ),
    ];

    final data = buildDetailData(
      DetailTracker.money,
      entries,
      const Goals(dailyBudget: 85),
    );

    // 6 + 14 + 30 + 2.50 = 52.50 (income + non-money excluded).
    expect(data.total, closeTo(52.50, 1e-9));
    expect(data.target, 85);

    // Categories sorted largest-first: Groceries 30, Food & Drink 20, Transit 2.50.
    expect(data.categories.map((e) => e.label).toList(),
        ['Groceries', 'Food & Drink', 'Transit']);
    expect(data.categories.first.amount, 30);
    expect(data.categories.first.fraction, closeTo(30 / 52.50, 1e-9));

    // All entries today → a single day group with 4 included entries.
    expect(data.days.length, 1);
    expect(data.days.first.entries.length, 4);
  });

  test('hero totals today only; recent list keeps full history (move)', () {
    final now = DateTime(2026, 6, 20, 20, 0);
    DateTime at(int daysAgo, int hour) =>
        DateTime(now.year, now.month, now.day - daysAgo, hour, 0);
    final entries = [
      Entry(
        id: 't1',
        timestamp: at(0, 7),
        type: EntryType.move,
        title: 'Run',
        calories: 287,
        source: EntrySource.health,
      ),
      Entry(
        id: 't2',
        timestamp: at(0, 17),
        type: EntryType.move,
        title: 'Push day',
        calories: 312,
        source: EntrySource.manual,
      ),
      // historical — must feed the recent list but NOT the hero total.
      Entry(
        id: 'h1',
        timestamp: at(2, 7),
        type: EntryType.move,
        title: 'Old run',
        calories: 1000,
        source: EntrySource.health,
      ),
    ];

    final data = buildDetailData(
      DetailTracker.move,
      entries,
      const Goals(dailyMoveKcal: 500),
      now: now,
    );

    // 287 + 312 = 599 — today only, not 1599.
    expect(data.total, 599);
    expect(data.target, 500);
    expect(data.progress, closeTo(599 / 500, 1e-9));
    // breakdown shares the hero's today base (single "Other" row).
    expect(data.categories.single.amount, 599);
    // recent list still spans both days.
    expect(data.days.length, 2);
  });

  // ---------------------------------------------------------------------------
  // Widget — renders total + category rows from seeded money entries.
  // ---------------------------------------------------------------------------
  testWidgets('DetailScreen renders total + category rows from seeded entries',
      (tester) async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await GoalsRepository(db).upsert(const Goals(dailyBudget: 85));

    final entries = EntryRepository(db);
    await entries.insert(Entry(
      id: 'e1',
      timestamp: _todayAt(8, 0),
      type: EntryType.money,
      title: 'Verve Coffee',
      detail: 'Coffee · cortado',
      amount: -6,
      category: 'Food & Drink',
      source: EntrySource.manual,
    ));
    await entries.insert(Entry(
      id: 'e2',
      timestamp: _todayAt(10, 0),
      type: EntryType.money,
      title: 'Whole Foods',
      amount: -30,
      category: 'Groceries',
      source: EntrySource.manual,
    ));
    await entries.insert(Entry(
      id: 'e3',
      timestamp: _todayAt(11, 0),
      type: EntryType.money,
      title: 'Muni',
      amount: -4,
      category: 'Transit',
      source: EntrySource.manual,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loopDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: _wrap(const DetailScreen(tracker: DetailTracker.money)),
      ),
    );
    await tester.pumpAndSettle();

    // Title.
    expect(find.text('Spending'), findsOneWidget);

    // Hero total: 6 + 30 + 4 = 40.
    expect(find.text('\$40'), findsWidgets);

    // Category breakdown rows render their labels + amounts.
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Food & Drink'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
    expect(find.text('\$30'), findsWidgets);

    // Ask Pal pill.
    expect(find.text('Ask Pal about spending'), findsOneWidget);
  });
}
