import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/models/models.dart';

void main() {
  group('pearson', () {
    test('perfect positive is 1.0', () {
      expect(pearson([1, 2, 3, 4], [2, 4, 6, 8]), closeTo(1.0, 1e-9));
    });
    test('perfect negative is -1.0', () {
      expect(pearson([1, 2, 3, 4], [8, 6, 4, 2]), closeTo(-1.0, 1e-9));
    });
    test('a constant series yields 0 (undefined guarded)', () {
      expect(pearson([5, 5, 5, 5], [1, 2, 3, 4]), 0.0);
    });
    test('fewer than two points yields 0', () {
      expect(pearson([1], [2]), 0.0);
    });
  });

  group('correlationPValue', () {
    test('strong r over a large n is significant', () {
      expect(correlationPValue(0.7, 40), lessThan(0.001));
    });
    test('weak r over a small n is not significant', () {
      expect(correlationPValue(0.1, 22), greaterThan(0.05));
    });
    test('too few points is non-significant (p = 1)', () {
      expect(correlationPValue(0.9, 3), 1.0);
    });
    test('a perfect correlation is maximally significant', () {
      expect(correlationPValue(-1.0, 24), lessThan(kAlpha));
    });
  });

  group('Correlation presentation', () {
    final c = Correlation(
      a: Dimension.move,
      b: Dimension.money,
      r: -0.52,
      n: 28,
      breakdown: const GroupBreakdown(
        binaryDim: Dimension.move,
        continuousDim: Dimension.money,
        meanWhenActive: 34,
        meanWhenInactive: 52,
        countActive: 12,
        countInactive: 16,
      ),
    );
    test('involves reports membership', () {
      expect(c.involves(Dimension.money), isTrue);
      expect(c.involves(Dimension.rituals), isFalse);
    });
    test('strengthWord buckets |r|', () {
      expect(c.strengthWord, 'moderate');
      expect(
          Correlation(a: Dimension.move, b: Dimension.money, r: 0.75, n: 28)
              .strengthWord,
          'strong');
    });
    test('summary states the two-group comparison factually', () {
      expect(c.summary, contains('workout days'));
      expect(c.summary, contains('\$34'));
      expect(c.summary, contains('\$52'));
    });
  });

  group('surfacedCorrelations', () {
    DailySeries series(Dimension d, List<double> values) {
      // map onto consecutive day ordinals starting 2026-01-01
      final byDay = <int, double>{};
      for (var i = 0; i < values.length; i++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: i));
        byDay[date.year * 10000 + date.month * 100 + date.day] = values[i];
      }
      return DailySeries(dim: d, byDay: byDay);
    }

    test('surfaces a strong, well-sampled pair', () {
      // 24 days, money mirrors move strongly (negative).
      final move = List<double>.generate(24, (i) => (i % 4 == 0) ? 0 : 300);
      final money = move.map((m) => m == 0 ? 60.0 : 30.0).toList();
      final out = surfacedCorrelations({
        Dimension.move: series(Dimension.move, move),
        Dimension.money: series(Dimension.money, money),
      });
      expect(out, isNotEmpty);
      expect(out.first.involves(Dimension.move), isTrue);
      expect(out.first.involves(Dimension.money), isTrue);
      expect(out.first.r.abs(), greaterThanOrEqualTo(kMinAbsR));
      expect(out.first.breakdown, isNotNull); // move is binary -> two-group
    });

    test('rejects an under-sampled pair (n < 21)', () {
      final move = List<double>.generate(10, (i) => (i % 2 == 0) ? 0 : 300);
      final money = move.map((m) => m == 0 ? 60.0 : 30.0).toList();
      final out = surfacedCorrelations({
        Dimension.move: series(Dimension.move, move),
        Dimension.money: series(Dimension.money, money),
      });
      expect(out, isEmpty);
    });

    test('rejects a weak pair (|r| < 0.4)', () {
      final move = List<double>.generate(30, (i) => (i % 2).toDouble() * 300);
      final money = List<double>.generate(30, (i) => 50 + (i % 7)); // unrelated
      final out = surfacedCorrelations({
        Dimension.move: series(Dimension.move, move),
        Dimension.money: series(Dimension.money, money),
      });
      expect(out, isEmpty);
    });

    test('a constant (fabricated-looking) series surfaces nothing', () {
      final flat = List<double>.filled(30, 100);
      final money = List<double>.generate(30, (i) => 40.0 + i);
      final out = surfacedCorrelations({
        Dimension.nutrition: series(Dimension.nutrition, flat),
        Dimension.money: series(Dimension.money, money),
      });
      expect(out, isEmpty); // guards against re-introducing fiction
    });
  });

  group('buildDailyVectors', () {
    final now = DateTime(2026, 3, 1, 12);
    Entry money(int daysAgo, double amount) => Entry(
        id: 'm$daysAgo',
        timestamp: now.subtract(Duration(days: daysAgo)),
        type: EntryType.money,
        title: 'x',
        amount: amount,
        source: EntrySource.manual);
    Entry move(int daysAgo, int cal) => Entry(
        id: 'w$daysAgo',
        timestamp: now.subtract(Duration(days: daysAgo)),
        type: EntryType.move,
        title: 'x',
        calories: cal,
        source: EntrySource.manual);

    test('money sums expense magnitude per day; income ignored', () {
      final v = buildDailyVectors(
          [money(1, -10), money(1, -5), money(1, 100)], const [], const [], const [],
          now: now);
      final key = _ord(now.subtract(const Duration(days: 1)));
      expect(v[Dimension.money]!.byDay[key], 15.0);
    });

    test('move days are 0-filled within the active span', () {
      // a move 3 days ago and one today -> day between is a real 0.
      final v = buildDailyVectors([move(3, 200), move(0, 200)], const [], const [], const [],
          now: now);
      expect(v[Dimension.move]!.byDay[_ord(now.subtract(const Duration(days: 1)))],
          0.0);
    });

    test('nutrition only has days with a logged meal (no 0-fill)', () {
      final meal = NutritionMeal(
        id: 'n1',
        timestamp: now.subtract(const Duration(days: 2)),
        slot: 'Lunch',
        name: 'x',
        source: NutritionSource.manual,
        icon: 'fork.knife',
        confidence: NutritionConfidence.med,
        cal: const IntRange(400, 600),
        macros: const Macros(
          protein: IntRange(0, 0),
          carbs: IntRange(0, 0),
          fat: IntRange(0, 0),
        ),
      );
      final v = buildDailyVectors([move(0, 200)], [meal], const [], const [], now: now);
      expect(v[Dimension.nutrition]!.byDay.length, 1);
      expect(v[Dimension.nutrition]!.byDay[_ord(now.subtract(const Duration(days: 2)))],
          500.0); // cal.mid
    });

    test('label/format switches cover sleep & mood', () {
      expect(dimensionNoun(Dimension.sleep), 'sleep');
      expect(dimensionNoun(Dimension.mood), 'mood');
      expect(activeDayLabel(Dimension.sleep), 'short nights');
      expect(inactiveDayLabel(Dimension.sleep), 'other nights');
      expect(formatValue(Dimension.sleep, 414), '6h 54m');
      expect(formatValue(Dimension.mood, 0.64), 'Slightly pleasant (0.64)');
    });

    test('sleep attributed to the next day; short-night split + means', () {
      final nights = [
        SleepNight(id: '1', night: DateTime(2026, 6, 1), asleepMinutes: 360,
          inBedMinutes: 380, bedtime: '1:00', wake: '7:00', deepMinutes: 40,
          remMinutes: 80, coreMinutes: 240, awakeMinutes: 20, wakes: 2,
          source: EntrySource.health),
        SleepNight(id: '2', night: DateTime(2026, 6, 2), asleepMinutes: 450,
          inBedMinutes: 470, bedtime: '23:00', wake: '7:00', deepMinutes: 70,
          remMinutes: 100, coreMinutes: 280, awakeMinutes: 20, wakes: 1,
          source: EntrySource.health),
      ];
      final entries = [
        Entry(id: 'm1', timestamp: DateTime(2026, 6, 2, 9), type: EntryType.money,
          title: 'x', amount: -80, source: EntrySource.manual),
        Entry(id: 'm2', timestamp: DateTime(2026, 6, 3, 9), type: EntryType.money,
          title: 'y', amount: -20, source: EntrySource.manual),
      ];
      final vectors = buildDailyVectors(entries, const [], nights, const [],
          now: DateTime(2026, 6, 3));
      final sleep = vectors[Dimension.sleep]!.byDay;
      expect(sleep[20260602], 360);
      expect(sleep[20260603], 450);
    });

    test('mood daily mean is sparse (only days with a check-in)', () {
      final moods = [
        MoodCheckin(id: 'a', timestamp: DateTime(2026, 6, 2, 8), pleasantness: 0.4, source: EntrySource.manual),
        MoodCheckin(id: 'b', timestamp: DateTime(2026, 6, 2, 20), pleasantness: 0.6, source: EntrySource.manual),
      ];
      final v = buildDailyVectors(const [], const [], const [], moods,
          now: DateTime(2026, 6, 3));
      expect(v[Dimension.mood]!.byDay[20260602], closeTo(0.5, 1e-9));
      expect(v[Dimension.mood]!.byDay.containsKey(20260603), isFalse);
    });
  });
}

int _ord(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
