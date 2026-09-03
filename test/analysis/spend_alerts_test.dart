import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/spend_alerts.dart';
import 'package:opal/models/models.dart';

// June 2026. Anchoring on the 10th puts the recent 7-day window at Jun 4-10 and
// the prior one at May 28 - Jun 3; the three completed months are Mar/Apr/May.
final _now = DateTime(2026, 6, 10, 21);

var _seq = 0;
Entry _expense(
  String category,
  double amount, {
  required DateTime on,
}) =>
    Entry(
      id: 'e${_seq++}',
      timestamp: on,
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

void main() {
  group('detectVelocityChange', () {
    test('reports acceleration past the threshold', () {
      final entries = [
        _expense('Food', 200, on: DateTime(2026, 6, 8)),
        _expense('Food', 100, on: DateTime(2026, 5, 30)),
      ];
      final v = detectVelocityChange(entries, now: _now);
      expect(v, isNotNull);
      expect(v!.recent, 200);
      expect(v.previous, 100);
      expect(v.changeFraction, closeTo(1.0, 1e-9));
      expect(v.isAccelerating, isTrue);
    });

    test('stays quiet inside the threshold', () {
      final entries = [
        _expense('Food', 110, on: DateTime(2026, 6, 8)),
        _expense('Food', 100, on: DateTime(2026, 5, 30)),
      ];
      expect(detectVelocityChange(entries, now: _now), isNull);
    });

    test('is null without a prior week to compare against', () {
      final entries = [_expense('Food', 200, on: DateTime(2026, 6, 8))];
      expect(detectVelocityChange(entries, now: _now), isNull);
    });
  });

  group('detectCategorySpikes', () {
    test('reports a category well above last month', () {
      final entries = [
        _expense('Food', 300, on: DateTime(2026, 6, 5)),
        _expense('Food', 100, on: DateTime(2026, 5, 5)),
      ];
      final spikes = detectCategorySpikes(entries, now: _now);
      expect(spikes, hasLength(1));
      expect(spikes.single.category, 'Food');
      expect(spikes.single.changeFraction, closeTo(2.0, 1e-9));
    });

    test('ignores a category with no last-month baseline', () {
      final entries = [_expense('Food', 300, on: DateTime(2026, 6, 5))];
      expect(detectCategorySpikes(entries, now: _now), isEmpty);
    });
  });

  group('detectUnbudgetedCategories', () {
    test('surfaces significant spend with no envelope', () {
      final entries = [
        _expense('Shopping', 600, on: DateTime(2026, 6, 5)),
        _expense('Food', 900, on: DateTime(2026, 6, 5)),
      ];
      final out = detectUnbudgetedCategories(
        entries,
        envelopes: [_envelope('Food', 1000)],
        minSpend: 500,
        roundTo: 50,
        now: _now,
      );
      expect(out.map((u) => u.category), ['Shopping']);
      expect(out.single.monthSpend, 600);
      // 600 + 10% buffer, rounded up to the nearest 50.
      expect(out.single.suggestedCap, 700);
    });

    test('ignores spend below the significance floor', () {
      final entries = [_expense('Shopping', 100, on: DateTime(2026, 6, 5))];
      final out = detectUnbudgetedCategories(
        entries,
        envelopes: const [],
        minSpend: 500,
        roundTo: 50,
        now: _now,
      );
      expect(out, isEmpty);
    });
  });

  group('detectSavingsOpportunities', () {
    test('suggests a lower cap for a consistently underspent envelope', () {
      // 300/mo against a 1000 cap across the three completed months.
      final entries = [
        for (final m in [3, 4, 5]) _expense('Food', 300, on: DateTime(2026, m, 12)),
      ];
      final out = detectSavingsOpportunities(
        entries,
        envelopes: [_envelope('Food', 1000)],
        roundTo: 50,
        now: _now,
      );
      expect(out, hasLength(1));
      expect(out.single.monthlyAverage, closeTo(300, 1e-9));
      // 300 + 10% buffer, rounded up to the nearest 50.
      expect(out.single.suggestedCap, 350);
    });

    test('leaves an envelope spent close to its cap alone', () {
      final entries = [
        for (final m in [3, 4, 5]) _expense('Food', 900, on: DateTime(2026, m, 12)),
      ];
      final out = detectSavingsOpportunities(
        entries,
        envelopes: [_envelope('Food', 1000)],
        roundTo: 50,
        now: _now,
      );
      expect(out, isEmpty);
    });

    test('ignores the still-open current month', () {
      // A quiet Mar/Apr/May with a heavy June must still read as underspent.
      final entries = [
        for (final m in [3, 4, 5]) _expense('Food', 200, on: DateTime(2026, m, 12)),
        _expense('Food', 5000, on: DateTime(2026, 6, 2)),
      ];
      final out = detectSavingsOpportunities(
        entries,
        envelopes: [_envelope('Food', 1000)],
        roundTo: 50,
        now: _now,
      );
      expect(out, hasLength(1));
      expect(out.single.monthlyAverage, closeTo(200, 1e-9));
    });
  });
}
