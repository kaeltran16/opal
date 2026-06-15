import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/monthly_review_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/review/monthly_review_screen.dart';
import 'package:opal/services/pal/pal_context_builder.dart' show ritualStreakDays;
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';

import 'support/flush_provider_timers.dart';

/// A timestamp on the [day]th of the current month at [hour]:00.
DateTime _thisMonthAt(int day, int hour) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, day, hour);
}

/// A PalService whose `review()` returns a different canned string on each
/// call, so a Regenerate tap is guaranteed to swap the text.
class _SequencedPalService implements PalService {
  int _i = 0;
  static const _reviews = [
    'FIRST_REVIEW — a steady month.',
    'SECOND_REVIEW — movement was your anchor.',
  ];

  @override
  Future<String> review(DateTime anchor, ReviewRange range) async =>
      _reviews[_i++ % _reviews.length];

  @override
  Future<PalInsights> insights(InsightRange range) async => const PalInsights(
        patterns: [
          InsightPattern(
            colorToken: 'rituals',
            title: 'Morning rituals lower food spending',
            detail: 'On days you journal, food costs drop 32%',
          ),
        ],
      );

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async =>
      const PalChatResult(reply: '');

  @override
  Future<ParsedEntryDraft> parse(String text) async =>
      const ParsedEntryDraft(type: EntryType.money);

  @override
  Future<WorkoutSuggestion> suggestWorkout({
    bool another = false,
    String? excludeRoutineId,
  }) async =>
      const WorkoutSuggestion(title: '', rationale: '');

  @override
  Future<String> postWorkoutNote(Workout workout) async => '';

  @override
  Future<GeneratedRoutineDraft> generateRoutine(
          String goal, List<Exercise> available) async =>
      const GeneratedRoutineDraft(
          name: '', tag: RoutineTag.custom, exercises: []);
}

Widget _wrap(Widget child) {
  final colors = AppColors.light(AppAccent.blue);
  return MaterialApp(theme: ThemeData(extensions: [colors]), home: child);
}

/// Pumps until [finder] matches. The stats block is fed by an async,
/// stream-backed provider and the screen has no animation to keep
/// [WidgetTester.pumpAndSettle] alive until the first emission lands. Bounded
/// so a genuine failure surfaces fast instead of hanging the suite.
Future<void> _pumpUntil(WidgetTester tester, Finder finder,
    {int maxFrames = 60}) async {
  for (var i = 0; i < maxFrames && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  // ---------------------------------------------------------------------------
  // Pure math — buildMonthlyStats folds entries + rituals into the 4 stats.
  // ---------------------------------------------------------------------------
  test('buildMonthlyStats computes spent / moved / kept / streak', () {
    final month = DateTime(2026, 4);
    final entries = [
      Entry(
        id: '1',
        timestamp: DateTime(2026, 4, 2, 8),
        type: EntryType.money,
        title: 'Coffee',
        amount: -6,
        source: EntrySource.manual,
      ),
      Entry(
        id: '2',
        timestamp: DateTime(2026, 4, 3, 9),
        type: EntryType.money,
        title: 'Groceries',
        amount: -30,
        source: EntrySource.manual,
      ),
      // Income — excluded from "Total spent".
      Entry(
        id: '3',
        timestamp: DateTime(2026, 4, 4, 9),
        type: EntryType.money,
        title: 'Refund',
        amount: 20,
        source: EntrySource.manual,
      ),
      Entry(
        id: '4',
        timestamp: DateTime(2026, 4, 5, 7),
        type: EntryType.move,
        title: 'Run',
        duration: 30,
        calories: 30,
        source: EntrySource.health,
      ),
      Entry(
        id: '5',
        timestamp: DateTime(2026, 4, 6, 18),
        type: EntryType.move,
        title: 'Lift',
        duration: 45,
        calories: 45,
        source: EntrySource.manual,
      ),
      Entry(
        id: '6',
        timestamp: DateTime(2026, 4, 7, 6),
        type: EntryType.rituals,
        title: 'Meditate',
        source: EntrySource.manual,
      ),
    ];
    // Previous month: $60 spent, 50 move kcal over 1 day, 0 rituals.
    final previousEntries = [
      Entry(
        id: 'p1',
        timestamp: DateTime(2026, 3, 10, 9),
        type: EntryType.money,
        title: 'Groceries',
        amount: -60,
        source: EntrySource.manual,
      ),
      Entry(
        id: 'p2',
        timestamp: DateTime(2026, 3, 11, 7),
        type: EntryType.move,
        title: 'Run',
        duration: 50,
        calories: 50,
        source: EntrySource.health,
      ),
    ];

    // The streak is computed upstream (here from the lone Apr 7 ritual entry,
    // with `now` on Apr 7 → a 1-day streak) and passed in, not derived from
    // seeded RitualRoutine.streak values.
    final ritualStreak = ritualStreakDays(entries, now: DateTime(2026, 4, 7, 12));
    final s = buildMonthlyStats(month, entries, previousEntries, ritualStreak);
    expect(s.totalSpent, 36); // 6 + 30 (income excluded)
    expect(s.moveKcal, 75); // 30 + 45
    expect(s.ritualsKept, 1);
    expect(s.longestStreak, 1);

    // Active move days this month: Apr 5 and Apr 6 → 2 distinct days.
    expect(s.current.activeMoveDays, 2);

    // The 4 big rows render in handoff order.
    expect(s.rows.map((r) => r.label).toList(),
        ['Total spent', 'Active energy', 'Routines kept', 'Streak']);

    // Deltas are computed vs the previous month (no fabricated numbers).
    final spentRow = s.rows[0];
    expect(spentRow.sub, '↓ 40% vs March'); // 36 vs 60 → -40%
    final moveRow = s.rows[1];
    expect(moveRow.sub, '↑ 50% vs March · 2 active days'); // 75 vs 50 → +50%
  });

  // ---------------------------------------------------------------------------
  // No prior month → no fabricated delta (sub is null, not a made-up %).
  // ---------------------------------------------------------------------------
  test('buildMonthlyStats omits deltas when the previous month is empty', () {
    final month = DateTime(2026, 4);
    final entries = [
      Entry(
        id: '1',
        timestamp: DateTime(2026, 4, 2, 8),
        type: EntryType.money,
        title: 'Coffee',
        amount: -6,
        source: EntrySource.manual,
      ),
    ];

    final s = buildMonthlyStats(month, entries, const [], 0);
    expect(s.rows[0].sub, isNull); // total spent: no baseline → no delta
    expect(s.rows[1].sub, isNull); // workout: no move kcal, no active days
  });

  // ---------------------------------------------------------------------------
  // Widget — stat rows + mock narrative render; Regenerate swaps the text.
  // ---------------------------------------------------------------------------
  testWidgets(
      'MonthlyReviewScreen renders stats + narrative; Regenerate swaps text',
      (tester) async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final rituals = RitualRepository(db);
    // seeded streak is intentionally a wrong, never-incremented value: the
    // displayed streak must come from persisted ritual entries, not this.
    await rituals.upsertRoutine(const RitualRoutine(
        id: 'morning',
        name: 'Morning',
        time: '7:00 AM',
        tone: RitualTone.morning,
        icon: 'sunrise.fill',
        blurb: '',
        streak: 9));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entries = EntryRepository(db);
    await entries.insert(Entry(
      id: 'e1',
      timestamp: _thisMonthAt(2, 8),
      type: EntryType.money,
      title: 'Coffee',
      amount: -6,
      category: 'Food & Drink',
      source: EntrySource.manual,
    ));
    await entries.insert(Entry(
      id: 'e2',
      timestamp: _thisMonthAt(3, 7),
      type: EntryType.move,
      title: 'Run',
      duration: 40,
      calories: 40,
      source: EntrySource.health,
    ));
    // A real 2-day ritual streak: today + yesterday (ending today).
    await entries.insert(Entry(
      id: 'e3',
      timestamp: today.add(const Duration(hours: 6)),
      type: EntryType.rituals,
      title: 'Meditate',
      source: EntrySource.manual,
    ));
    await entries.insert(Entry(
      id: 'e4',
      timestamp: today.subtract(const Duration(hours: 6)), // yesterday evening
      type: EntryType.rituals,
      title: 'Meditate',
      source: EntrySource.manual,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loopDatabaseProvider.overrideWithValue(db),
          palServiceProvider.overrideWithValue(_SequencedPalService()),
        ],
        child: _wrap(const MonthlyReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // Wait for the async monthlyStats stream to emit before asserting.
    await _pumpUntil(tester, find.text('Total spent'));

    // Section header + "Written by Pal" label render (above the fold).
    expect(find.text('By the numbers'), findsOneWidget);
    expect(find.text('WRITTEN BY PAL'), findsOneWidget);

    // The four stat rows.
    expect(find.text('Total spent'), findsOneWidget);
    expect(find.text('Active energy'), findsOneWidget);
    expect(find.text('Routines kept'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);

    // Computed stat values: spent $6, moved 40 kcal. The streak comes from the
    // persisted ritual entries (a real 2-day run), NOT the seeded streak: 9.
    expect(find.text('\$6'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('9'), findsNothing); // seeded value must not surface
    expect(find.text('Routines, ongoing'), findsOneWidget); // the Streak row
    // The Streak row's value (2) renders; "Routines kept" may also read "2" when
    // both ritual entries land in the current month, so allow ≥1 match.
    expect(find.text('2'), findsWidgets);

    // First narrative from the mock PalService.
    expect(find.text('FIRST_REVIEW — a steady month.'), findsOneWidget);

    // Tapping Regenerate swaps to the next mock review.
    await tester.tap(find.text('Regenerate'));
    await tester.pumpAndSettle();
    await _pumpUntil(
        tester, find.text('SECOND_REVIEW — movement was your anchor.'));
    expect(find.text('FIRST_REVIEW — a steady month.'), findsNothing);
    expect(
        find.text('SECOND_REVIEW — movement was your anchor.'), findsOneWidget);

    // "Patterns Pal found" sits below the fold — scroll it into view.
    await tester.scrollUntilVisible(
      find.text('Patterns Pal found'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Patterns Pal found'), findsOneWidget);
    expect(find.text('Morning rituals lower food spending'), findsOneWidget);
    expect(find.text('On days you journal, food costs drop 32%'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
