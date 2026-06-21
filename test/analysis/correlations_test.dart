import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';

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
}
