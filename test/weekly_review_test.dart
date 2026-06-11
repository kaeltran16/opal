import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/weekly_review_controller.dart';
import 'package:opal/models/models.dart';

Entry _money(DateTime t, double amount) => Entry(
      id: 't',
      timestamp: t,
      type: EntryType.money,
      title: 'x',
      amount: amount,
      source: EntrySource.manual,
    );

Entry _move(DateTime t, int minutes) => Entry(
      id: 't',
      timestamp: t,
      type: EntryType.move,
      title: 'x',
      duration: minutes,
      source: EntrySource.health,
    );

Entry _ritual(DateTime t) => Entry(
      id: 't',
      timestamp: t,
      type: EntryType.rituals,
      title: 'x',
      source: EntrySource.manual,
    );

void main() {
  // ---------------------------------------------------------------------------
  // weekStartFor snaps any day to the Monday 00:00 of its week.
  // ---------------------------------------------------------------------------
  test('weekStartFor returns Monday 00:00 of the containing week', () {
    // Wed Apr 22, 2026 → Mon Apr 20.
    expect(weekStartFor(DateTime(2026, 4, 22, 15, 30)), DateTime(2026, 4, 20));
    // A Monday maps to itself (time zeroed).
    expect(weekStartFor(DateTime(2026, 4, 20, 9)), DateTime(2026, 4, 20));
    // A Sunday maps back to the prior Monday.
    expect(weekStartFor(DateTime(2026, 4, 26, 23)), DateTime(2026, 4, 20));
  });

  // ---------------------------------------------------------------------------
  // Pure math — buildWeeklyStats folds entries against goals into the tiles.
  // ---------------------------------------------------------------------------
  test('buildWeeklyStats sums spend / move / rituals against weekly targets',
      () {
    const goals = Goals(
      dailyBudget: 85,
      dailyMoveMinutes: 60,
      dailyRitualTarget: 5,
    );
    final entries = [
      _money(DateTime(2026, 4, 20, 8), -30),
      _money(DateTime(2026, 4, 21, 9), -12),
      // Income is excluded from spend.
      _money(DateTime(2026, 4, 22, 9), 200),
      _move(DateTime(2026, 4, 20, 7), 40),
      _move(DateTime(2026, 4, 23, 18), 55),
      _ritual(DateTime(2026, 4, 21, 6)),
      _ritual(DateTime(2026, 4, 22, 6)),
      _ritual(DateTime(2026, 4, 24, 6)),
    ];

    final s = buildWeeklyStats(entries, goals, now: DateTime(2026, 4, 22, 12));

    expect(s.weekStart, DateTime(2026, 4, 20));
    expect(s.spent, 42); // 30 + 12 (income excluded)
    expect(s.budget, 595); // 85 * 7
    expect(s.moveMinutes, 95); // 40 + 55
    expect(s.moveTarget, 420); // 60 * 7
    expect(s.ritualsKept, 3);
    expect(s.ritualsTarget, 35); // 5 * 7

    // Tiles render in handoff order with the "of <target>" subs.
    expect(s.tiles.map((t) => t.label).toList(),
        ['Spent', 'Workout', 'Routines']);
    expect(s.tiles[0].value, '\$42');
    expect(s.tiles[0].sub, 'of \$595');
    expect(s.tiles[1].value, '95');
    expect(s.tiles[1].sub, 'of 420 min');
    expect(s.tiles[2].value, '3');
    expect(s.tiles[2].sub, 'of 35');
  });

  // ---------------------------------------------------------------------------
  // Date labels — same-month and month-crossing weeks.
  // ---------------------------------------------------------------------------
  test('WeeklyStats date labels handle same-month and cross-month weeks', () {
    // Mon Apr 20 – Sun Apr 26 (same month).
    final inMonth =
        buildWeeklyStats(const [], const Goals(), now: DateTime(2026, 4, 22));
    expect(inMonth.rangeLabel, 'Apr 20–26');
    expect(inMonth.nextReviewLabel, 'Sunday, Apr 26');

    // Thu Apr 30 → Mon Apr 27 – Sun May 3 (crosses the month boundary).
    final crossMonth =
        buildWeeklyStats(const [], const Goals(), now: DateTime(2026, 4, 30));
    expect(crossMonth.rangeLabel, 'Apr 27–May 3');
    expect(crossMonth.nextReviewLabel, 'Sunday, May 3');
  });
}
