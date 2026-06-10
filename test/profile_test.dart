import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/profile_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/inset_section.dart';

/// A timestamp this year at [month]/[day] so the entries land in the year-stats
/// window the profile screen aggregates over.
DateTime _thisYear(int month, int day) {
  final y = DateTime.now().year;
  return DateTime(y, month, day, 9, 0);
}

void main() {
  // --- Pure aggregation (buildProfileStats) ---------------------------------
  test('buildProfileStats folds this-year entries + rituals into the grid', () {
    final now = DateTime(2026, 6, 1);
    final entries = <Entry>[
      // This-year money: two expenses (-$30, -$20) + one income (+$100, ignored).
      Entry(
          id: 'm1',
          timestamp: DateTime(2026, 1, 5),
          type: EntryType.money,
          title: 'Groceries',
          amount: -30,
          source: EntrySource.manual),
      Entry(
          id: 'm2',
          timestamp: DateTime(2026, 2, 5),
          type: EntryType.money,
          title: 'Coffee',
          amount: -20,
          source: EntrySource.manual),
      Entry(
          id: 'm3',
          timestamp: DateTime(2026, 2, 6),
          type: EntryType.money,
          title: 'Paycheck',
          amount: 100,
          source: EntrySource.manual),
      // This-year move: 90 + 60 = 150 min → 2 hours.
      Entry(
          id: 'mv1',
          timestamp: DateTime(2026, 3, 1),
          type: EntryType.move,
          title: 'Run',
          duration: 90,
          source: EntrySource.manual),
      Entry(
          id: 'mv2',
          timestamp: DateTime(2026, 3, 2),
          type: EntryType.move,
          title: 'Walk',
          duration: 60,
          source: EntrySource.manual),
      // This-year rituals: 3 kept.
      for (var i = 0; i < 3; i++)
        Entry(
            id: 'r$i',
            timestamp: DateTime(2026, 4, i + 1),
            type: EntryType.rituals,
            title: 'Read',
            source: EntrySource.manual),
      // Last-year entry: must be excluded from totals but set memberSince.
      Entry(
          id: 'old',
          timestamp: DateTime(2024, 12, 1),
          type: EntryType.money,
          title: 'Old',
          amount: -999,
          source: EntrySource.manual),
    ];
    final routines = const [
      RitualRoutine(
          id: 'a',
          name: 'Morning',
          time: '7:00 AM',
          tone: RitualTone.morning,
          icon: 'sunrise.fill',
          blurb: '',
          streak: 12),
      RitualRoutine(
          id: 'b',
          name: 'Evening',
          time: '9:30 PM',
          tone: RitualTone.evening,
          icon: 'moon.stars.fill',
          blurb: '',
          streak: 5),
    ];

    final stats = buildProfileStats(entries, routines, now: now);

    expect(stats.totalSpent, 50); // -30 + -20, income excluded
    expect(stats.moveMinutes, 150);
    expect(stats.moveHours, 2);
    expect(stats.ritualsKept, 3);
    expect(stats.longestStreak, 12);
    expect(stats.memberSinceYear, 2024); // earliest entry year
  });

  // --- Widget: grid + settings render; Rituals & Integrations navigate ------
  testWidgets(
      'You tab renders year-stat grid + settings rows; Rituals navigates, '
      'Integrations targets the email stub', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed a routine (so the Rituals tab has identifiable content) with a streak.
    final ritualRepo = RitualRepository(db);
    await ritualRepo.upsertRoutine(const RitualRoutine(
        id: 'morning',
        name: 'Morning',
        time: '7:00 AM',
        tone: RitualTone.morning,
        icon: 'sunrise.fill',
        blurb: '',
        order: 0,
        streak: 9));

    // Seed this-year entries: one expense, one move, one ritual completion.
    final entryRepo = EntryRepository(db);
    await entryRepo.insert(Entry(
        id: 'e-spend',
        timestamp: _thisYear(1, 10),
        type: EntryType.money,
        title: 'Groceries',
        amount: -42,
        source: EntrySource.manual));
    await entryRepo.insert(Entry(
        id: 'e-move',
        timestamp: _thisYear(2, 10),
        type: EntryType.move,
        title: 'Run',
        duration: 120, // 2 hours
        source: EntrySource.manual));
    await entryRepo.insert(Entry(
        id: 'e-ritual',
        timestamp: _thisYear(3, 10),
        type: EntryType.rituals,
        title: 'Read',
        ritualId: 'r-read',
        source: EntrySource.manual));

    final router = createRouter(initialLocation: '/you');
    final colors = AppColors.light(AppAccent.blue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Header.
    expect(find.text('You'), findsWidgets);

    // Year-stat 2×2 grid: four stat labels.
    expect(find.text('Total spent'), findsOneWidget);
    expect(find.text('Workout hours'), findsOneWidget);
    expect(find.text('Routines kept'), findsOneWidget);
    expect(find.text('Longest streak'), findsOneWidget);

    // Computed values: $42 spent, 2 hours moved, 1 ritual kept, streak 9.
    expect(find.text('\$42'), findsOneWidget);
    expect(find.text('2'), findsWidgets); // hours moved
    expect(find.text('9'), findsOneWidget); // longest streak

    // Settings rows render. ("Routines" also appears as the tab-bar label, so
    // target the settings row specifically.)
    expect(find.widgetWithText(ListRow, 'Routines'), findsOneWidget);
    expect(find.text('Budgets & goals'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Integrations'), findsOneWidget);
    expect(find.text('Email sync'), findsOneWidget); // integrations subtitle
    expect(find.text('Off'), findsOneWidget); // integrations state

    // Second section rows are below the fold — scroll the list to reveal them.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Privacy'), 200,
        scrollable: list);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Export data'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    // --- Integrations row → Email sync Intro ('/email', U20) ---
    await tester.scrollUntilVisible(find.text('Integrations'), -200,
        scrollable: list);
    await tester.tap(find.text('Integrations'));
    await tester.pumpAndSettle();
    expect(find.text('Stop logging card charges by hand.'), findsOneWidget);

    // Back to the profile screen via the Intro nav's "Settings" leading.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Integrations'), findsOneWidget);
  });
}
