import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/profile_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/inset_section.dart';

import 'support/flush_provider_timers.dart';

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
    expect(stats.memberSince, DateTime(2024, 12, 1)); // earliest full date
    // best move day: mv1 (90 min) beats mv2 (60 min)
    expect(stats.bestMoveDay, DateTime(2026, 3, 1));
    expect(stats.bestMoveDayMinutes, 90);
  });

  // --- Pure milestone + streak-start helpers --------------------------------
  test('nextStreakMilestone returns the next ladder rung, null past the top',
      () {
    expect(nextStreakMilestone(0), 7);
    expect(nextStreakMilestone(7), 14); // strictly greater
    expect(nextStreakMilestone(11), 14);
    expect(nextStreakMilestone(30), 60);
    expect(nextStreakMilestone(365), isNull); // no fabricated target
    expect(nextStreakMilestone(400), isNull);
  });

  test('streakStartDate counts back inclusively; null for a zero streak', () {
    final today = DateTime(2026, 4, 22, 9, 30); // time-of-day ignored
    expect(streakStartDate(1, today), DateTime(2026, 4, 22)); // today
    expect(streakStartDate(11, today), DateTime(2026, 4, 12));
    expect(streakStartDate(0, today), isNull);
  });

  // --- Widget: redesigned You tab — profile card + inset sections ----------
  // The old "year-stat grid" was removed and replaced with a profile card
  // followed by Goals / Reviews / Integrations / Data / Account sections.
  testWidgets(
      'You tab renders the profile card + inset sections; Daily budget opens '
      'the budget sheet, Integrations targets the email stub',
      (WidgetTester tester) async {
    // seed the onboarding display name so the profile card renders it (the
    // card falls back to "You" only when this is empty).
    SharedPreferences.setMockInitialValues(
        {'settings.displayName': 'Mira Okafor'});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

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

    // Profile card renders the seeded display name (not the "You" fallback).
    expect(find.text('Mira Okafor'), findsOneWidget);
    // Empty DB → no entries → honest tenure placeholder (no fabricated date).
    expect(find.text('Just getting started'), findsOneWidget);

    // Above-the-fold section headers (InsetSection uppercases them) for the
    // new IA — no stat grid, no Money/Bills section.
    expect(find.text('GOALS'), findsOneWidget);
    expect(find.text('REVIEWS'), findsOneWidget);

    // Goals rows render with values from the default Goals record (empty DB).
    expect(find.widgetWithText(ListRow, 'Daily budget'), findsOneWidget);
    expect(find.text('\$85'), findsOneWidget); // dailyBudget default
    expect(find.widgetWithText(ListRow, 'Workout goal'), findsOneWidget);
    expect(find.text('60 min'), findsOneWidget); // dailyMoveMinutes default
    expect(find.widgetWithText(ListRow, 'Daily rituals'), findsOneWidget);

    // The removed stat grid must NOT render.
    expect(find.text('Total spent'), findsNothing);
    expect(find.text('Workout hours'), findsNothing);
    expect(find.text('Longest streak'), findsNothing);

    // Sections below the fold — the ListView is lazy, so scroll to reveal them.
    final list = find.byType(Scrollable).first;

    // Integrations: header + a single Gmail row.
    await tester.scrollUntilVisible(find.text('Email sync'), 200,
        scrollable: list);
    expect(find.text('INTEGRATIONS'), findsOneWidget);
    expect(find.text('Gmail · On'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Export data'), 200,
        scrollable: list);
    expect(find.text('DATA'), findsOneWidget);
    expect(find.text('Export data'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Help & feedback'), 200,
        scrollable: list);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // --- Daily budget row → opens the BudgetSheet ---
    await tester.scrollUntilVisible(find.text('Daily budget'), -200,
        scrollable: list);
    await tester.ensureVisible(find.text('Daily budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily budget'));
    await tester.pumpAndSettle();
    // The sheet has its own "Budget" title + Cancel/Save chrome.
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    // Dismiss the sheet.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Budget'), findsNothing);

    // --- Integrations row → Email sync Intro ('/email', U20) ---
    await tester.scrollUntilVisible(find.text('Email sync'), -200,
        scrollable: list);
    await tester.tap(find.text('Email sync'));
    await tester.pumpAndSettle();
    // Intro headline (rendered across two lines via an embedded newline).
    expect(find.text('Stop logging card\ncharges by hand.'), findsOneWidget);

    // Back to the profile screen via the Intro nav's "You" leading. The list
    // retains its scroll offset, so assert via the Integrations row that's back
    // in view rather than the off-screen profile card.
    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    expect(find.text('Stop logging card\ncharges by hand.'), findsNothing);
    expect(find.widgetWithText(ListRow, 'Email sync'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
