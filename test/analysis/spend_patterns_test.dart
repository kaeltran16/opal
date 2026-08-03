import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/spend_patterns.dart';
import 'package:opal/models/models.dart';

// Sunday 28 Jun 2026. A 28-day window ending here starts Monday 1 Jun, so every
// weekday occurs exactly 4 times — the per-weekday averages are then clean
// arithmetic rather than a function of the calendar.
final _now = DateTime(2026, 6, 28, 22);
const _window = 28;

var _seq = 0;
Entry _expense(DateTime ts, double amount, {String category = 'Food & Drink'}) =>
    Entry(
      id: 'e${_seq++}',
      timestamp: ts,
      type: EntryType.money,
      title: category,
      amount: -amount,
      category: category,
      source: EntrySource.manual,
    );

SpendAggregates _aggregate(List<Entry> entries) =>
    aggregateSpend(entries, now: _now, windowDays: _window);

/// The four Mondays / Fridays / Sundays inside the window.
List<DateTime> _everyWeekday(int weekday, {int hour = 12}) => [
      for (var d = DateTime(2026, 6, 1);
          !d.isAfter(DateTime(2026, 6, 28));
          d = d.add(const Duration(days: 1)))
        if (d.weekday == weekday) DateTime(d.year, d.month, d.day, hour),
    ];

void main() {
  group('aggregateSpend', () {
    test('buckets by weekday Monday-first and divides by weekday occurrences',
        () {
      final entries = [
        for (final d in _everyWeekday(DateTime.friday)) _expense(d, 100),
      ];

      final a = _aggregate(entries);

      expect(a.dayOccurrences, List.filled(7, 4));
      expect(a.dayTotals[4], 400); // Friday is index 4, Monday-first
      expect(a.dayAverages[4], 100); // 400 over 4 Fridays
      expect(a.dayAverages[0], 0); // no Monday spend
    });

    test('averages per weekday occurrence, not per transaction', () {
      // Three small Monday expenses on one day plus a single large Friday one.
      // Per-transaction averaging would call Monday the cheaper day; per-day
      // averaging correctly reports the same 90 on both.
      final monday = DateTime(2026, 6, 1, 12);
      final entries = [
        _expense(monday, 120),
        _expense(monday.add(const Duration(hours: 2)), 120),
        _expense(monday.add(const Duration(hours: 4)), 120),
        _expense(DateTime(2026, 6, 5, 12), 360),
      ];

      final a = _aggregate(entries);

      expect(a.dayAverages[0], 90); // 360 over 4 Mondays
      expect(a.dayAverages[4], 90); // 360 over 4 Fridays
    });

    test('buckets by daypart on the meal-slot hour boundaries', () {
      final day = DateTime(2026, 6, 1);
      final a = _aggregate([
        _expense(DateTime(day.year, day.month, day.day, 8), 10),
        _expense(DateTime(day.year, day.month, day.day, 13), 20),
        _expense(DateTime(day.year, day.month, day.day, 19), 40),
        _expense(DateTime(day.year, day.month, day.day, 22), 80),
      ]);

      expect(a.daypartTotals[SpendDaypart.morning.index], 10);
      expect(a.daypartTotals[SpendDaypart.midday.index], 20);
      expect(a.daypartTotals[SpendDaypart.evening.index], 40);
      expect(a.daypartTotals[SpendDaypart.night.index], 80);
    });

    test('sums categories and the window total over expenses only', () {
      final a = _aggregate([
        _expense(DateTime(2026, 6, 2, 12), 100),
        _expense(DateTime(2026, 6, 3, 12), 50, category: 'Transport'),
        Entry(
          id: 'income',
          timestamp: DateTime(2026, 6, 3, 12),
          type: EntryType.money,
          title: 'Payday',
          amount: 5000,
          category: 'Food & Drink',
          source: EntrySource.manual,
        ),
        Entry(
          id: 'run',
          timestamp: DateTime(2026, 6, 3, 7),
          type: EntryType.move,
          title: 'Run',
          calories: 300,
          source: EntrySource.manual,
        ),
      ]);

      expect(a.windowTotal, 150);
      expect(a.expenseCount, 2);
      expect(a.categoryTotals['food & drink'], 100);
      expect(a.categoryTotals['transport'], 50);
    });

    test('drops entries outside the window', () {
      final a = _aggregate([
        _expense(DateTime(2026, 5, 20, 12), 900), // before windowStart
        _expense(DateTime(2026, 6, 2, 12), 100),
      ]);

      expect(a.windowTotal, 100);
      expect(a.expenseCount, 1);
    });

    test('uncategorized spend gets its own bucket, never dropped', () {
      final a = _aggregate([
        Entry(
          id: 'blank',
          timestamp: DateTime(2026, 6, 2, 12),
          type: EntryType.money,
          title: 'Something',
          amount: -75,
          source: EntrySource.manual,
        ),
      ]);

      expect(a.categoryTotals[kUncategorizedKey], 75);
      expect(a.windowTotal, 75);
    });
  });

  group('biggest spending day', () {
    test('surfaces the peak vs quiet weekday once the gap clears the bar', () {
      final entries = [
        for (final d in _everyWeekday(DateTime.friday)) _expense(d, 200),
        for (final d in _everyWeekday(DateTime.tuesday)) _expense(d, 50),
      ];

      final p = detectSpendPatterns(_aggregate(entries)).biggestDay!;

      expect(p.peakWeekday, DateTime.friday);
      expect(p.quietWeekday, DateTime.tuesday);
      expect(p.peakAverage, 200);
      expect(p.quietAverage, 50);
      expect(p.multiplier, 4);
    });

    test('stays silent when every day looks alike', () {
      final entries = [
        for (var d = DateTime(2026, 6, 1);
            !d.isAfter(DateTime(2026, 6, 28));
            d = d.add(const Duration(days: 1)))
          _expense(DateTime(d.year, d.month, d.day, 12), 100),
      ];

      expect(detectSpendPatterns(_aggregate(entries)).biggestDay, isNull);
    });

    test('quiet day is the cheapest day with spend, not an unspent one', () {
      // Only Fridays and Tuesdays have any spend; the five silent weekdays are
      // not "your quietest day" — there is nothing to compare.
      final entries = [
        for (final d in _everyWeekday(DateTime.friday)) _expense(d, 200),
        for (final d in _everyWeekday(DateTime.tuesday)) _expense(d, 50),
      ];

      final p = detectSpendPatterns(_aggregate(entries)).biggestDay!;

      expect(p.quietAverage, 50);
    });
  });

  group('weekend split', () {
    test('reports the signed gap between weekend and weekday days', () {
      final entries = [
        for (final d in _everyWeekday(DateTime.saturday)) _expense(d, 300),
        for (final d in _everyWeekday(DateTime.sunday)) _expense(d, 300),
        for (final d in _everyWeekday(DateTime.wednesday)) _expense(d, 100),
      ];

      final s = detectSpendPatterns(_aggregate(entries)).weekendSplit!;

      // weekend: 2400 over 8 weekend days = 300/day.
      // weekday: 400 over 20 weekday days = 20/day.
      expect(s.weekendAverage, 300);
      expect(s.weekdayAverage, 20);
      expect(s.heavierOnWeekend, isTrue);
    });

    test('stays silent when the two sides are close', () {
      final entries = [
        for (var d = DateTime(2026, 6, 1);
            !d.isAfter(DateTime(2026, 6, 28));
            d = d.add(const Duration(days: 1)))
          _expense(DateTime(d.year, d.month, d.day, 12), 100),
      ];

      expect(detectSpendPatterns(_aggregate(entries)).weekendSplit, isNull);
    });
  });

  group('daypart peak', () {
    test('names the heaviest daypart and its share of the window', () {
      final entries = [
        for (final d in _everyWeekday(DateTime.friday, hour: 19))
          _expense(d, 200),
        for (final d in _everyWeekday(DateTime.tuesday, hour: 8))
          _expense(d, 50),
      ];

      final p = detectSpendPatterns(_aggregate(entries)).daypartPeak!;

      expect(p.daypart, SpendDaypart.evening);
      expect(p.total, 800);
      expect(p.share, closeTo(800 / 1000, 1e-9));
    });

    test('stays silent when no daypart dominates', () {
      final day = DateTime(2026, 6, 1);
      final a = _aggregate([
        _expense(DateTime(day.year, day.month, day.day, 8), 100),
        _expense(DateTime(day.year, day.month, day.day, 13), 100),
        _expense(DateTime(day.year, day.month, day.day, 19), 100),
        _expense(DateTime(day.year, day.month, day.day, 22), 100),
      ]);

      expect(detectSpendPatterns(a).daypartPeak, isNull);
    });
  });

  group('no-spend streak', () {
    test('counts consecutive silent days back from yesterday', () {
      // Last spend 10 days before today -> a 9-day streak (yesterday back to
      // the day after that expense).
      final a = _aggregate([
        _expense(DateTime(2026, 6, 18, 12), 100),
      ]);

      expect(detectSpendPatterns(a).noSpendStreakDays, 9);
    });

    test('today being quiet does not start a streak — the day is still open',
        () {
      final a = _aggregate([
        _expense(DateTime(2026, 6, 27, 12), 100), // yesterday
      ]);

      expect(detectSpendPatterns(a).noSpendStreakDays, 0);
    });

    test('a streak shorter than the reporting bar is not surfaced', () {
      final a = _aggregate([
        _expense(DateTime(2026, 6, 25, 12), 100),
      ]);

      // 2 silent days (26th, 27th) is under kMinNoSpendStreakDays.
      expect(detectSpendPatterns(a).noSpendStreakDays, 0);
    });
  });

  group('unusual expenses', () {
    test('flags expenses well above the window mean, largest first', () {
      final entries = [
        for (var i = 0; i < 10; i++) _expense(DateTime(2026, 6, 2 + i, 12), 100),
        _expense(DateTime(2026, 6, 20, 12), 900),
        _expense(DateTime(2026, 6, 21, 12), 500),
      ];

      final unusual = detectSpendPatterns(_aggregate(entries)).unusual;

      expect(unusual.map((u) => u.entry.amount!.abs()).toList(), [900, 500]);
      expect(unusual.first.multipleOfMean, greaterThan(kUnusualMultiplier));
    });

    test('caps how many it reports', () {
      final entries = [
        for (var i = 0; i < 10; i++) _expense(DateTime(2026, 6, 2 + i, 12), 10),
        for (var i = 0; i < 6; i++) _expense(DateTime(2026, 6, 14 + i, 12), 500),
      ];

      expect(detectSpendPatterns(_aggregate(entries)).unusual,
          hasLength(kMaxUnusual));
    });

    test('an even spread has nothing unusual in it', () {
      final entries = [
        for (var i = 0; i < 10; i++) _expense(DateTime(2026, 6, 2 + i, 12), 100),
      ];

      expect(detectSpendPatterns(_aggregate(entries)).unusual, isEmpty);
    });
  });

  test('no spend at all yields an empty, silent result', () {
    final p = detectSpendPatterns(_aggregate(const []));

    expect(p.biggestDay, isNull);
    expect(p.weekendSplit, isNull);
    expect(p.daypartPeak, isNull);
    expect(p.noSpendStreakDays, 0);
    expect(p.unusual, isEmpty);
    expect(p.isEmpty, isTrue);
  });
}
