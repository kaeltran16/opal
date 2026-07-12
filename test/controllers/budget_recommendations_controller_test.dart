import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/budget_recommendations_controller.dart';
import 'package:opal/models/models.dart';

// June 2026: the three completed months in the window are Mar, Apr, May.
final _now = DateTime(2026, 6, 20, 20);
final _mar = DateTime(2026, 3, 10);
final _apr = DateTime(2026, 4, 10);
final _may = DateTime(2026, 5, 10);

// VND-style rounding unit (50 * budgetScale, budgetScale 1000).
const _roundTo = 50000.0;

var _seq = 0;
Entry _expense(String category, double amount, DateTime ts) => Entry(
      id: 'e${_seq++}',
      timestamp: ts,
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

BudgetRecommendation _only(List<BudgetRecommendation> recs) {
  expect(recs, hasLength(1));
  return recs.single;
}

void main() {
  test('suggests the 3-month average plus a 15% buffer for stable spend', () {
    final entries = [
      _expense('Food & Drink', 2000000, _mar),
      _expense('Food & Drink', 2000000, _apr),
      _expense('Food & Drink', 2000000, _may),
    ];

    final rec = _only(buildBudgetRecommendations(
      entries,
      envelopes: const [],
      roundTo: _roundTo,
      now: _now,
    ));

    expect(rec.category, 'Food & Drink');
    expect(rec.monthlyAverage, 2000000);
    expect(rec.trend, SpendTrend.stable);
    expect(rec.bufferFraction, 0.15);
    // 2,000,000 * 1.15 = 2,300,000 (already a multiple of the rounding unit).
    expect(rec.suggestedCap, 2300000);
    expect(rec.percentChange, 0);
    expect(rec.currentCap, isNull);
  });

  test('sizes a larger buffer and rounds the cap up when trending upward', () {
    final entries = [
      _expense('Transport', 600000, _mar),
      _expense('Transport', 700000, _apr),
      _expense('Transport', 900000, _may),
    ];

    final rec = _only(buildBudgetRecommendations(
      entries,
      envelopes: const [],
      roundTo: _roundTo,
      now: _now,
    ));

    expect(rec.trend, SpendTrend.increasing);
    expect(rec.bufferFraction, 0.25);
    expect(rec.percentChange, greaterThan(10));
    // avg ≈ 733,333 → ×1.25 ≈ 916,667 → round up to nearest 50,000 = 950,000.
    expect(rec.suggestedCap, 950000);
  });

  test('flags a downward trend with the smaller buffer', () {
    final entries = [
      _expense('Shopping', 900000, _mar),
      _expense('Shopping', 700000, _apr),
      _expense('Shopping', 600000, _may),
    ];

    final rec = _only(buildBudgetRecommendations(
      entries,
      envelopes: const [],
      roundTo: _roundTo,
      now: _now,
    ));

    expect(rec.trend, SpendTrend.decreasing);
    expect(rec.bufferFraction, 0.10);
    expect(rec.percentChange, lessThan(-10));
  });

  test('attaches the current cap and prefers the envelope display name', () {
    // entry category is lower-cased; it must match the envelope via
    // normalizeCategory and adopt the envelope's canonical name + cap.
    final entries = [
      _expense('food & drink', 1000000, _mar),
      _expense('food & drink', 1000000, _apr),
      _expense('food & drink', 1000000, _may),
    ];

    final rec = _only(buildBudgetRecommendations(
      entries,
      envelopes: [_envelope('Food & Drink', 800000)],
      roundTo: _roundTo,
      now: _now,
    ));

    expect(rec.category, 'Food & Drink');
    expect(rec.currentCap, 800000);
  });

  test('ignores income, uncategorised, and out-of-window entries', () {
    final entries = [
      _expense('Transport', 500000, _may),
      _expense('Transport', 500000, _apr),
      _expense('Transport', 500000, _mar),
      // income (positive) — not an expense
      Entry(
        id: 'inc',
        timestamp: _may,
        type: EntryType.money,
        title: 'Salary',
        amount: 9000000,
        category: 'Transport',
        source: EntrySource.manual,
      ),
      // no category
      _expense('', 400000, _may),
      // current month (June) — outside the completed-month window
      _expense('Transport', 400000, DateTime(2026, 6, 5)),
      // four months back — outside the window
      _expense('Transport', 400000, DateTime(2026, 2, 5)),
    ];

    final rec = _only(buildBudgetRecommendations(
      entries,
      envelopes: const [],
      roundTo: _roundTo,
      now: _now,
    ));

    // only the three in-window expenses count → avg 500,000, income excluded.
    expect(rec.category, 'Transport');
    expect(rec.monthlyAverage, 500000);
  });

  test('sorts recommendations by suggested cap, highest first', () {
    final entries = [
      _expense('Food & Drink', 3000000, _may),
      _expense('Coffee', 200000, _may),
      _expense('Transport', 800000, _may),
    ];

    final recs = buildBudgetRecommendations(
      entries,
      envelopes: const [],
      roundTo: _roundTo,
      now: _now,
    );

    expect(recs.map((r) => r.category).toList(),
        ['Food & Drink', 'Transport', 'Coffee']);
  });

  test('confidence rises with transaction count', () {
    // 9 transactions across the window → high confidence.
    final many = [
      for (final m in [_mar, _apr, _may])
        for (var i = 0; i < 3; i++) _expense('Food & Drink', 300000, m),
    ];
    final high = _only(buildBudgetRecommendations(
      many,
      envelopes: const [],
      roundTo: _roundTo,
      now: _now,
    ));
    expect(high.confidence, RecommendationConfidence.high);

    // 2 transactions → low confidence.
    final few = [
      _expense('Health', 300000, _mar),
      _expense('Health', 300000, _may),
    ];
    final low = _only(buildBudgetRecommendations(
      few,
      envelopes: const [],
      roundTo: _roundTo,
      now: _now,
    ));
    expect(low.confidence, RecommendationConfidence.low);
  });

  test('no rounding when roundTo is zero', () {
    final entries = [
      _expense('Health', 1000000, _mar),
      _expense('Health', 1000000, _apr),
      _expense('Health', 1000000, _may),
    ];
    final rec = _only(buildBudgetRecommendations(
      entries,
      envelopes: const [],
      roundTo: 0,
      now: _now,
    ));
    // 1,000,000 * 1.15, unrounded.
    expect(rec.suggestedCap, 1150000);
  });
}
