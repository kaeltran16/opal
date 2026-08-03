import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/budget_forecast.dart';
import 'package:opal/models/models.dart';

// June 2026 has 30 days. Anchoring on the 10th leaves 20 days after today, so a
// month-to-date figure projects to exactly 3x itself.
final _now = DateTime(2026, 6, 10, 21);

var _seq = 0;
Entry _expense(String category, double amount, {int day = 5}) => Entry(
      id: 'e${_seq++}',
      timestamp: DateTime(2026, 6, day, 12),
      type: EntryType.money,
      title: category,
      amount: -amount,
      category: category,
      source: EntrySource.manual,
    );

BudgetEnvelope _envelope(String category, double cap) => BudgetEnvelope(
      id: 'env-$category',
      category: category,
      cap: cap,
      icon: 'tray.fill',
      colorToken: 'money',
      position: 0,
    );

EnvelopeForecast _only(List<EnvelopeForecast> fs) {
  expect(fs, hasLength(1));
  return fs.single;
}

void main() {
  group('projection', () {
    test('projects month-to-date spend at the current daily pace', () {
      // 300 over 10 elapsed days = 30/day; 30 days in June -> 900 projected.
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 300)],
        now: _now,
      ));

      expect(f.spent, 300);
      expect(f.dailyAverage, 30);
      expect(f.projectedSpend, 900);
      expect(f.daysRemaining, 20);
    });

    test('overage is the projected excess over the cap, never negative', () {
      final under = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 300)],
        now: _now,
      ));
      expect(under.projectedOverage, 0);

      // 500 MTD -> 50/day -> 1500 projected against a 1200 cap.
      final over = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 500)],
        now: _now,
      ));
      expect(over.projectedOverage, 300);
    });

    test('income and other trackers never count toward spend', () {
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [
          _expense('Food & Drink', 300),
          Entry(
            id: 'income',
            timestamp: DateTime(2026, 6, 5),
            type: EntryType.money,
            title: 'Refund',
            amount: 500, // positive = income
            category: 'Food & Drink',
            source: EntrySource.manual,
          ),
          Entry(
            id: 'run',
            timestamp: DateTime(2026, 6, 5),
            type: EntryType.move,
            title: 'Run',
            calories: 400,
            source: EntrySource.manual,
          ),
        ],
        now: _now,
      ));

      expect(f.spent, 300);
    });

    test('categories match case-insensitively, like the budgets screen', () {
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('food & drink', 300)],
        now: _now,
      ));

      expect(f.spent, 300);
    });
  });

  group('status ladder', () {
    test('safe while both spend and projection sit under the cap', () {
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 200)], // 20/day -> 600 projected
        now: _now,
      ));
      expect(f.status, ForecastStatus.safe);
    });

    test('warning past 80% of the cap while the pace still lands under it', () {
      // Late in the month the two can diverge: 960 of a 1200 cap is 80% used,
      // but 960 over 25 elapsed days projects to 1152 — still inside the cap.
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 960)],
        now: DateTime(2026, 6, 25, 21),
      ));

      expect(f.progress, closeTo(0.8, 1e-9));
      expect(f.projectedSpend, lessThan(f.cap));
      expect(f.status, ForecastStatus.warning);
    });

    test('danger when the pace projects past the cap but spend has not', () {
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 500)], // 1500 projected
        now: _now,
      ));
      expect(f.status, ForecastStatus.danger);
      expect(f.spent, lessThan(f.cap));
    });

    test('exceeded once spend reaches the cap, regardless of pace', () {
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 1200)],
        now: _now,
      ));
      expect(f.status, ForecastStatus.exceeded);
    });

    test('sorts most severe first', () {
      final fs = forecastEnvelopes(
        [
          _envelope('Food & Drink', 1200),
          _envelope('Transport', 1200),
          _envelope('Shopping', 1200),
        ],
        [
          _expense('Food & Drink', 100), // safe
          _expense('Transport', 1300), // exceeded
          _expense('Shopping', 500), // danger
        ],
        now: _now,
      );

      expect(fs.map((f) => f.status).toList(), [
        ForecastStatus.exceeded,
        ForecastStatus.danger,
        ForecastStatus.safe,
      ]);
    });
  });

  group('recommended daily limit', () {
    test('spreads what is left over the days after today', () {
      // 1200 cap - 300 spent = 900 left over 20 remaining days.
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 300)],
        now: _now,
      ));
      expect(f.recommendedDailyLimit, 45);
    });

    test('is zero, not negative, once the cap is blown', () {
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 1500)],
        now: _now,
      ));
      expect(f.recommendedDailyLimit, 0);
    });

    test('is null on the last day of the month — no days left to pace over', () {
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [_expense('Food & Drink', 300)],
        now: DateTime(2026, 6, 30, 21),
      ));
      expect(f.daysRemaining, 0);
      expect(f.recommendedDailyLimit, isNull);
    });
  });

  group('guards', () {
    test('envelopes without a real cap are not forecast', () {
      // The budgets screen's "Uncategorized" tally row carries cap 0; it is a
      // tally, not a budget, and must never read as exceeded.
      final fs = forecastEnvelopes(
        [_envelope('Uncategorized', 0)],
        [_expense('Uncategorized', 500)],
        now: _now,
      );
      expect(fs, isEmpty);
    });

    test('an envelope with no spend yet is safe with a full allowance', () {
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        const [],
        now: _now,
      ));

      expect(f.spent, 0);
      expect(f.projectedSpend, 0);
      expect(f.status, ForecastStatus.safe);
      expect(f.recommendedDailyLimit, 60); // 1200 / 20
    });

    test('only the anchor month counts', () {
      final f = _only(forecastEnvelopes(
        [_envelope('Food & Drink', 1200)],
        [
          _expense('Food & Drink', 300),
          Entry(
            id: 'last-month',
            timestamp: DateTime(2026, 5, 20),
            type: EntryType.money,
            title: 'Food & Drink',
            amount: -900,
            category: 'Food & Drink',
            source: EntrySource.manual,
          ),
        ],
        now: _now,
      ));

      expect(f.spent, 300);
    });
  });
}
