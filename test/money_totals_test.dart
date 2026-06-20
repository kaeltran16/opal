import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/budgets_controller.dart';
import 'package:opal/controllers/insights_money_controller.dart';
import 'package:opal/controllers/recap_controller.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart' show InsightRange;

Entry _expense(double amount, String? category, DateTime at) => Entry(
      id: 'e-$category-${at.day}',
      timestamp: at,
      type: EntryType.money,
      title: category ?? 'Spend',
      amount: -amount,
      category: category,
      source: EntrySource.manual,
    );

void main() {
  final envelopes = SeedData.budgetEnvelopes();
  final monthCap = envelopes.fold<double>(0, (s, e) => s + e.cap);

  // Coffee + lunch + groceries = 60.35 this month, all canonical categories.
  final now = DateTime(2026, 6, 20, 20);
  final entries = [
    _expense(5.75, 'Food & Drink', DateTime(2026, 6, 20, 8)),
    _expense(16.20, 'Food & Drink', DateTime(2026, 6, 20, 12)),
    _expense(38.40, 'Groceries', DateTime(2026, 6, 20, 19)),
  ];

  test('Budgets, Insights and Recap agree on the month total', () {
    final budgets = buildBudgetsData(envelopes, entries, now: now);
    final insights = buildInsightsData(entries, envelopes, now: now);
    final recap = buildRecapData(InsightRange.month, entries, const Goals(),
        monthlyBudget: monthCap, now: now);

    expect(budgets.totalSpent, closeTo(60.35, 1e-9));
    expect(insights.currentTotal, closeTo(60.35, 1e-9));
    expect(recap.spent, closeTo(60.35, 1e-9));
  });

  test('an expense matching no envelope still counts toward the total', () {
    // "Dining" is not an envelope category (Food & Drink is) — it must land in
    // Uncategorized, never be dropped.
    final withStray = [...entries, _expense(10, 'Dining', DateTime(2026, 6, 20, 13))];
    final budgets = buildBudgetsData(envelopes, withStray, now: now);

    expect(budgets.totalSpent, closeTo(70.35, 1e-9)); // 60.35 + 10
    final uncategorized =
        budgets.envelopes.where((e) => e.envelope.category == 'Uncategorized');
    expect(uncategorized.single.spent, closeTo(10, 1e-9));
    // the catch-all carries no cap, so the budget total is unchanged.
    expect(budgets.totalCap, monthCap);
  });

  test('the canonical monthly budget is the envelope-cap sum', () {
    final budgets = buildBudgetsData(envelopes, entries, now: now);
    final recap = buildRecapData(InsightRange.month, entries, const Goals(),
        monthlyBudget: monthCap, now: now);

    expect(monthCap, 2600);
    expect(budgets.totalCap, 2600);
    expect(recap.budget, 2600);
  });

  test('seed money categories all match a canonical envelope category', () {
    final envelopeKeys = envelopes.map((e) => normalizeCategory(e.category)).toSet();
    final moneyCategories = SeedData.entries()
        .where((e) => e.type == EntryType.money && (e.amount ?? 0) < 0)
        .map((e) => e.category)
        .whereType<String>();

    for (final category in moneyCategories) {
      expect(envelopeKeys, contains(normalizeCategory(category)),
          reason: '"$category" should be a canonical envelope category');
    }
  });

  test('envelope categories are exactly the canonical list', () {
    expect(envelopes.map((e) => e.category).toList(), kSpendCategories);
  });
}
