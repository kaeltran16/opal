import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/budgets_controller.dart';
import 'package:opal/controllers/recap_controller.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart' show InsightRange;

// the fix (MONEY_FINDINGS #1–#3): the monthly budget is dailyBudget *
// daysInMonth everywhere, not the seed-frozen envelope-cap sum. these tests
// pin that editing the daily budget moves both the monthly Recap and the
// Budgets-screen target, and that every period shares one daily basis.
void main() {
  final envelopes = SeedData.budgetEnvelopes();
  // june 2026 has 30 days.
  final now = DateTime(2026, 6, 20, 20);
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

  test('editing dailyBudget moves the monthly Recap target', () {
    final lower = const Goals().copyWith(dailyBudget: 50);
    final higher = const Goals().copyWith(dailyBudget: 85);

    final lowerRecap =
        buildRecapData(InsightRange.month, const [], lower, now: now);
    final higherRecap =
        buildRecapData(InsightRange.month, const [], higher, now: now);

    expect(lowerRecap.budget, 50 * daysInMonth);
    expect(higherRecap.budget, 85 * daysInMonth);
    // the budget tracks the editable daily budget, not the frozen cap sum.
    expect(lowerRecap.budget, isNot(higherRecap.budget));
  });

  test('editing dailyBudget moves the Budgets-screen target', () {
    final lower = buildBudgetsData(
      envelopes,
      const [],
      goals: const Goals().copyWith(dailyBudget: 50),
      now: now,
    );
    final higher = buildBudgetsData(
      envelopes,
      const [],
      goals: const Goals().copyWith(dailyBudget: 85),
      now: now,
    );

    expect(lower.totalCap, 50 * daysInMonth);
    expect(higher.totalCap, 85 * daysInMonth);
    // totalLeft / progress follow the editable basis, not the cap sum.
    expect(lower.totalLeft, 50 * daysInMonth);
    expect(higher.totalLeft, 85 * daysInMonth);
  });

  test('day, week and month share one daily budget basis', () {
    final goals = const Goals().copyWith(dailyBudget: 70);
    final day = buildRecapData(InsightRange.day, const [], goals, now: now);
    final week = buildRecapData(InsightRange.week, const [], goals, now: now);
    final month = buildRecapData(InsightRange.month, const [], goals, now: now);

    expect(day.budget, 70);
    expect(week.budget, 70 * 7);
    expect(month.budget, 70 * daysInMonth);
  });

  test('Budgets and monthly Recap agree on the same monthly target', () {
    final goals = const Goals().copyWith(dailyBudget: 60);
    final budgets =
        buildBudgetsData(envelopes, const [], goals: goals, now: now);
    final recap =
        buildRecapData(InsightRange.month, const [], goals, now: now);

    expect(budgets.totalCap, recap.budget);
  });
}
