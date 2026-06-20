import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/weekly_review_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/services.dart';

/// Builds a minimal [Entry] of [type]; only the fields read by
/// `buildWeeklyStats` (amount for money, calories for move) matter.
Entry _entry(EntryType type, {double? amount, int? calories, String? ritualId}) =>
    Entry(
  id: 'e-${type.wire}-${amount ?? calories ?? ritualId ?? 0}',
  timestamp: DateTime(2026, 4, 22),
  type: type,
  title: 'x',
  amount: amount,
  calories: calories,
  ritualId: ritualId,
  source: EntrySource.manual,
);

/// A routine whose steps are [stepIds]; completing all of them on one day
/// counts as one completed routine.
RitualRoutine _routine(String id, List<String> stepIds) => RitualRoutine(
      id: id, name: id, time: '7:00 AM', tone: RitualTone.morning,
      icon: 'x', blurb: '',
      steps: [
        for (final s in stepIds) RitualStep(id: s, title: s, note: '', icon: 'x'),
      ],
    );

/// A PalService whose `review` returns a different canned string per call (so a
/// regenerate is guaranteed to swap text) and records the range it was asked
/// for. Other seams are unused no-ops.
class _SequencedPal implements PalService {
  @override
  Future<PalAgenda> agenda() async => const PalAgenda();

  int _i = 0;
  final List<ReviewRange> reviewRanges = [];
  static const _reviews = ['FIRST week review.', 'SECOND week review.'];

  @override
  Future<String> review(DateTime anchor, ReviewRange range) async {
    reviewRanges.add(range);
    return _reviews[_i++ % _reviews.length];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('build resolves the week narrative from PalService.review', () async {
    final pal = _SequencedPal();
    final container = ProviderContainer(
      overrides: [palServiceProvider.overrideWithValue(pal)],
    );
    addTearDown(container.dispose);

    final text = await container.read(weeklyReviewControllerProvider.future);

    expect(text, 'FIRST week review.');
    // the controller asks for the week range, not the month.
    expect(pal.reviewRanges, [ReviewRange.week]);
  });

  test('regenerate swaps to the next narrative', () async {
    final pal = _SequencedPal();
    final container = ProviderContainer(
      overrides: [palServiceProvider.overrideWithValue(pal)],
    );
    addTearDown(container.dispose);

    await container.read(weeklyReviewControllerProvider.future);
    await container.read(weeklyReviewControllerProvider.notifier).regenerate();

    final state = container.read(weeklyReviewControllerProvider);
    expect(state.value, 'SECOND week review.');
    expect(pal.reviewRanges, [ReviewRange.week, ReviewRange.week]);
  });

  group('weekStartFor', () {
    test('snaps a mid-week day to that week\'s Monday at 00:00', () {
      // 2026-04-22 is a Wednesday; its Monday is 2026-04-20.
      final start = weekStartFor(DateTime(2026, 4, 22, 14, 30));
      expect(start, DateTime(2026, 4, 20));
    });

    test('returns the same Monday when given a Monday', () {
      expect(weekStartFor(DateTime(2026, 4, 20, 9)), DateTime(2026, 4, 20));
    });
  });

  group('rangeLabel', () {
    WeeklyStats statsForWeekOf(DateTime now) =>
        buildWeeklyStats(const [], const Goals(), now: now);

    test('within a month omits the end month', () {
      // Week of Wed 2026-04-22 → Mon 20 … Sun 26.
      expect(statsForWeekOf(DateTime(2026, 4, 22)).rangeLabel, 'Apr 20–26');
    });

    test('crossing a month boundary shows both month abbreviations', () {
      // Week of Wed 2026-04-29 → Mon Apr 27 … Sun May 3.
      final label = statsForWeekOf(DateTime(2026, 4, 29)).rangeLabel;
      expect(label, 'Apr 27–May 3');
      expect(label, contains('Apr'));
      expect(label, contains('May'));
    });
  });

  group('nextReviewLabel', () {
    test('is the closing Sunday formatted "Weekday, Mon D"', () {
      // Week of Wed 2026-04-22 closes on Sun 2026-04-26.
      final stats = buildWeeklyStats(
        const [],
        const Goals(),
        now: DateTime(2026, 4, 22),
      );
      expect(stats.nextReviewLabel, 'Sunday, Apr 26');
    });
  });

  group('buildWeeklyStats', () {
    final now = DateTime(2026, 4, 22);
    final entries = [
      _entry(EntryType.money, amount: -30), // expense
      _entry(EntryType.money, amount: -12.5), // expense
      _entry(EntryType.money, amount: 100), // income, ignored by spent
      _entry(EntryType.move, calories: 200),
      _entry(EntryType.move, calories: 96),
      _entry(EntryType.rituals, ritualId: 's1'),
      _entry(EntryType.rituals, ritualId: 's2'),
      _entry(EntryType.rituals, ritualId: 's3'),
    ];

    test('folds entries into spent / moveKcal / completed routines', () {
      // one routine of 3 steps, all done on the day → one completed routine.
      final stats = buildWeeklyStats(entries, const Goals(),
          routines: [_routine('r', ['s1', 's2', 's3'])], now: now);
      expect(stats.spent, 42.5); // only the two expenses, income excluded
      expect(stats.moveKcal, 296);
      expect(stats.ritualsKept, 1);
    });

    test('budget and moveTarget are the daily goals × 7', () {
      final goals = const Goals(dailyBudget: 85, dailyMoveKcal: 500);
      final stats = buildWeeklyStats(entries, goals, now: now);
      expect(stats.budget, 595);
      expect(stats.moveTarget, 3500);
    });

    test('ritualsTarget uses the routine count × 7 when there are routines', () {
      final stats = buildWeeklyStats(
        entries,
        const Goals(dailyRitualTarget: 5),
        routines: [_routine('a', ['a0']), _routine('b', ['b0']), _routine('c', ['c0'])],
        now: now,
      );
      // effectiveDailyRitualTarget(3, goals) == 3 → 3 * 7.
      expect(stats.ritualsTarget, 21);
    });

    test('ritualsTarget falls back to goals.dailyRitualTarget × 7 when '
        'there are no routines', () {
      final stats = buildWeeklyStats(
        entries,
        const Goals(dailyRitualTarget: 5),
        routines: const [],
        now: now,
      );
      expect(stats.ritualsTarget, 35);
    });
  });
}
