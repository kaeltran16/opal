import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loop/app.dart';
import 'package:loop/controllers/providers.dart';
import 'package:loop/data/db/database.dart';
import 'package:loop/data/repositories/repositories.dart';
import 'package:loop/models/models.dart';
import 'package:loop/services/services.dart';
import 'package:loop/widgets/activity_rings.dart';
import 'package:loop/widgets/summary_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Fixed goals: $100 budget, 60 move-min, 4 rituals.
    await GoalsRepository(db).save(const Goals(
      dailyBudget: 100,
      dailyMoveMinutes: 60,
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

    // Health: fixed 30 move-minutes today.
    final health = MockHealthService(
      today: HealthSample(
        date: DateTime.now(),
        moveMinutes: 30,
        activeEnergyKcal: 300,
        avgHeartRate: 70,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          healthServiceProvider.overrideWithValue(health),
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

    // 3-up summary tile row present (one per tracker type).
    expect(find.byType(SummaryTile), findsNWidgets(3));
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
  });
}
