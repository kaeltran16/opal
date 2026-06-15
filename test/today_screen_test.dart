import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/widgets/activity_rings.dart';
import 'package:opal/widgets/summary_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';

/// A timestamp today at [hour]:[minute] so the entries land in `watchToday()`.
DateTime _todayAt(int hour, int minute) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, hour, minute);
}

void main() {
  testWidgets(
      'Today renders rings, 3-up summary tiles, and timeline from live data',
      (WidgetTester tester) async {
    // onboardingComplete=true so the U17 first-run gate doesn't redirect this
    // full-app boot away from Today.
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Fixed goals: $100 budget, 60 move-kcal, 4 rituals.
    await GoalsRepository(db).upsert(const Goals(
      dailyBudget: 100,
      dailyMoveKcal: 60,
      dailyRitualTarget: 4,
    ));

    // Fixed entries: one expense (morning), one ritual (morning), one
    // dinner expense (evening). Spent = 50, rituals done = 1.
    final entries = EntryRepository(db);
    await entries.insert(Entry(
      id: 'e-coffee',
      timestamp: _todayAt(8, 0),
      type: EntryType.money,
      title: 'Verve Coffee',
      detail: 'Coffee · cortado',
      amount: -10,
      category: 'Coffee',
      source: EntrySource.manual,
    ));
    await entries.insert(Entry(
      id: 'e-pages',
      timestamp: _todayAt(7, 0),
      type: EntryType.rituals,
      title: 'Morning pages',
      detail: '15 min · journal',
      duration: 15,
      source: EntrySource.manual,
    ));
    await entries.insert(Entry(
      id: 'e-dinner',
      timestamp: _todayAt(19, 30),
      type: EntryType.money,
      title: 'Tartine',
      detail: 'Dinner',
      amount: -40,
      category: 'Dining',
      source: EntrySource.email,
    ));
    // Move: a logged workout today burning 30 kcal → move ring 30/60 (move-kcal
    // is derived from logged move entries' calories, not HealthKit).
    await entries.insert(Entry(
      id: 'e-run',
      timestamp: _todayAt(18, 0),
      type: EntryType.move,
      title: 'Evening run',
      detail: '30 min',
      duration: 30,
      calories: 30,
      source: EntrySource.manual,
    ));

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

    // Rings rendered with computed fractions: money 50/100, move 30/60,
    // rituals 1/4.
    final rings = tester.widget<ActivityRings>(find.byType(ActivityRings));
    expect(rings.values[0], closeTo(0.5, 1e-9)); // money
    expect(rings.values[1], closeTo(0.5, 1e-9)); // move
    expect(rings.values[2], closeTo(0.25, 1e-9)); // rituals

    // Rings hero shows one stat per tracker type (money / move / rituals).
    expect(find.byType(RingStat), findsNWidgets(3));
    // Spent total reflects the two expenses ($50).
    expect(find.text('\$50'), findsWidgets);

    // Timeline buckets render their entry titles. Scroll to reveal the
    // lazily-built rows.
    final listFinder = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Verve Coffee'),
      300,
      scrollable: listFinder,
    );
    expect(find.text('Verve Coffee'), findsOneWidget);
    expect(find.text('Morning pages'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Tartine'),
      300,
      scrollable: listFinder,
    );
    expect(find.text('Tartine'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('Today shows the empty-state copy when nothing is logged',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Tall surface so the empty-state line (below rings + tiles + timeline
    // header) is laid out rather than culled by the lazy ListView.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Goals exist so TodayState builds, but no entries are inserted.
    await GoalsRepository(db).upsert(const Goals(
      dailyBudget: 100,
      dailyMoveKcal: 60,
      dailyRitualTarget: 4,
    ));

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

    expect(find.text('Nothing logged yet. Tap + to start your day.'),
        findsOneWidget);

    await flushProviderTimers(tester);
  });
}
