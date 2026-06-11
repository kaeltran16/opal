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
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';

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
  Future<String> review(DateTime month) async =>
      _reviews[_i++ % _reviews.length];

  @override
  Future<String> chat(List<PalMessage> history, String message) async => '';

  @override
  Future<ParsedEntryDraft> parse(String text) async =>
      const ParsedEntryDraft(type: EntryType.money);

  @override
  Future<WorkoutSuggestion> suggestWorkout({bool another = false}) async =>
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
        source: EntrySource.health,
      ),
      Entry(
        id: '5',
        timestamp: DateTime(2026, 4, 6, 18),
        type: EntryType.move,
        title: 'Lift',
        duration: 45,
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
    final routines = [
      const RitualRoutine(
          id: 'morning',
          name: 'Morning',
          time: '7:00 AM',
          tone: RitualTone.morning,
          icon: 'sunrise.fill',
          blurb: '',
          streak: 4),
      const RitualRoutine(
          id: 'evening',
          name: 'Evening',
          time: '9:30 PM',
          tone: RitualTone.evening,
          icon: 'moon.stars.fill',
          blurb: '',
          streak: 12),
    ];

    // Previous month: $60 spent, 50 move min over 1 day, 0 rituals.
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
        source: EntrySource.health,
      ),
    ];

    final s = buildMonthlyStats(month, entries, previousEntries, routines);
    expect(s.totalSpent, 36); // 6 + 30 (income excluded)
    expect(s.moveMinutes, 75); // 30 + 45
    expect(s.ritualsKept, 1);
    expect(s.longestStreak, 12);

    // Active move days this month: Apr 5 and Apr 6 → 2 distinct days.
    expect(s.current.activeMoveDays, 2);

    // The 4 big rows render in handoff order.
    expect(s.rows.map((r) => r.label).toList(),
        ['Total spent', 'Workout time', 'Routines kept', 'Streak']);

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

    final s = buildMonthlyStats(month, entries, const [], const []);
    expect(s.rows[0].sub, isNull); // total spent: no baseline → no delta
    expect(s.rows[1].sub, isNull); // workout: no move minutes, no active days
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
    await rituals.upsertRoutine(const RitualRoutine(
        id: 'morning',
        name: 'Morning',
        time: '7:00 AM',
        tone: RitualTone.morning,
        icon: 'sunrise.fill',
        blurb: '',
        streak: 9));

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
      source: EntrySource.health,
    ));
    await entries.insert(Entry(
      id: 'e3',
      timestamp: _thisMonthAt(4, 6),
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

    // Section header + "Written by Pal" label render (above the fold).
    expect(find.text('By the numbers'), findsOneWidget);
    expect(find.text('WRITTEN BY PAL'), findsOneWidget);

    // The four stat rows.
    expect(find.text('Total spent'), findsOneWidget);
    expect(find.text('Workout time'), findsOneWidget);
    expect(find.text('Routines kept'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);

    // Computed stat values: spent $6, moved 40 min, streak 9.
    expect(find.text('\$6'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);

    // First narrative from the mock PalService.
    expect(find.text('FIRST_REVIEW — a steady month.'), findsOneWidget);

    // Tapping Regenerate swaps to the next mock review.
    await tester.tap(find.text('Regenerate'));
    await tester.pumpAndSettle();
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
  });
}
