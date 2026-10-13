import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

import '../models/models.dart';

/// Which tracker a [DetailScreen] is rendering: one widget and one provider
/// serve the Money, Move and Routines area pages, switching only this value.
///
/// Each case carries its title, the underlying [EntryType], and how a single
/// entry's magnitude and category are read.
enum DetailTracker {
  money(
    title: 'Spending',
    entryType: EntryType.money,
    unbudgetedLabel: 'Uncategorized',
  ),
  move(
    title: 'Workout',
    entryType: EntryType.move,
    unbudgetedLabel: 'Other',
  ),
  rituals(
    title: 'Routines',
    entryType: EntryType.rituals,
    unbudgetedLabel: 'Other',
  );

  const DetailTracker({
    required this.title,
    required this.entryType,
    required this.unbudgetedLabel,
  });

  /// What the tracker is called in the page's load-failure copy.
  final String title;

  /// The [EntryType] whose entries feed this detail screen.
  final EntryType entryType;

  /// Category bucket label for entries with no category set.
  final String unbudgetedLabel;

  /// Magnitude of one entry for totals/breakdown. For money this is the
  /// absolute expense amount; Move is active energy in kcal (same source as
  /// Today), Rituals counts one per entry.
  double magnitudeOf(Entry e) {
    switch (this) {
      case DetailTracker.money:
        return (e.amount ?? 0) < 0 ? e.amount!.abs() : 0;
      case DetailTracker.move:
        return (e.calories ?? 0).toDouble();
      case DetailTracker.rituals:
        return 1;
    }
  }

  /// Whether an entry counts toward this tracker's total (e.g. expenses only,
  /// not income, for money).
  bool includes(Entry e) {
    if (e.type != entryType) return false;
    switch (this) {
      case DetailTracker.money:
        return (e.amount ?? 0) < 0;
      case DetailTracker.move:
      case DetailTracker.rituals:
        return true;
    }
  }

  /// Category bucket label for one entry. Money uses the entry's own category;
  /// move/rituals carry none, so the bucket is read from the lead segment of the
  /// `bucket · detail` convention — move groups by activity (Run/Walk/Strength),
  /// rituals by routine (Morning/Evening) — falling back to [unbudgetedLabel]
  /// when the convention isn't present.
  String categoryOf(Entry e) {
    final cat = e.category;
    if (cat != null && cat.trim().isNotEmpty) return cat;
    switch (this) {
      case DetailTracker.money:
        return unbudgetedLabel;
      case DetailTracker.move:
        return _leadSegment(e.title) ?? unbudgetedLabel;
      case DetailTracker.rituals:
        return _leadSegment(e.detail) ?? _leadSegment(e.title) ?? unbudgetedLabel;
    }
  }

  /// The budget/target to compare the total against, read off [Goals].
  double targetOf(Goals goals) {
    switch (this) {
      case DetailTracker.money:
        return goals.dailyBudget;
      case DetailTracker.move:
        return goals.dailyMoveKcal.toDouble();
      case DetailTracker.rituals:
        return goals.dailyRitualTarget.toDouble();
    }
  }
}

/// The lead segment of a `bucket · detail` string ("Run · Mission loop" ->
/// "Run"), or null when [s] is null/blank. Recovers an implicit category from
/// move/rituals entries, which carry no explicit one.
String? _leadSegment(String? s) {
  if (s == null) return null;
  final i = s.indexOf('·');
  final head = (i >= 0 ? s.substring(0, i) : s).trim();
  return head.isEmpty ? null : head;
}

/// One category row in the breakdown (amount + share of the total).
@immutable
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.label,
    required this.amount,
    required this.fraction,
  });

  /// Category label (e.g. "Food & Drink", "Groceries").
  final String label;

  /// Summed magnitude for this category.
  final double amount;

  /// `amount / total` (0..1), for the row's bar. 0 when total is 0.
  final double fraction;
}

/// A day's worth of entries for the "recent transactions" list.
@immutable
class DayGroup {
  const DayGroup({required this.day, required this.entries});

  /// Midnight of the day these entries fall on.
  final DateTime day;

  /// Entries for the day, newest-first.
  final List<Entry> entries;
}

/// The fully-computed detail view model for one [DetailTracker]: hero total vs
/// budget, the category breakdown rows, and recent entries grouped by day. All
/// math lives here so the screen is dumb and this is unit-testable.
@immutable
class DetailData {
  const DetailData({
    required this.tracker,
    required this.total,
    required this.target,
    required this.categories,
    required this.days,
  });

  final DetailTracker tracker;

  /// Summed magnitude across all included entries (e.g. total spent).
  final double total;

  /// Budget/target for the period (e.g. daily budget).
  final double target;

  /// Category breakdown rows, largest-first.
  final List<CategoryBreakdown> categories;

  /// Recent entries grouped by day, newest day first.
  final List<DayGroup> days;

  /// total / target, clamped at 0 when no target. Can exceed 1 (over budget).
  double get progress => target == 0 ? 0 : total / target;

  /// Remaining toward target (never negative).
  double get remaining => (target - total).clamp(0, target);
}

/// Builds a [DetailData] from a list of [Entry]s for the given [tracker].
/// Extracted from the provider so it can be tested directly with fixtures.
///
/// [routines] supplies the Rituals tracker its hero numerator/denominator:
/// completed routines (every step done today) ÷ total routine count — the same
/// semantics as the Today screen. When empty (money/move, or tests/pre-load)
/// the rituals hero falls back to the legacy per-step count vs
/// [Goals.dailyRitualTarget].
DetailData buildDetailData(
  DetailTracker tracker,
  List<Entry> entries,
  Goals goals, {
  List<RitualRoutine> routines = const [],
  DateTime? now,
}) {
  final included = entries.where(tracker.includes).toList();

  // The hero + breakdown describe *today* vs the daily goal; the recent list
  // below keeps full history. Without scoping, the fold summed every day — e.g.
  // the move tracker showed ~2 weeks of active energy against the daily kcal
  // goal (3012 / 500), reading as 100% off a monthly number on a daily label.
  final n = now ?? clock.now();
  bool isToday(DateTime t) =>
      t.year == n.year && t.month == n.month && t.day == n.day;
  final todayIncluded = included.where((e) => isToday(e.timestamp)).toList();

  // --- Total -----------------------------------------------------------------
  // Rituals counts completed *routines* (every step done) when routine data is
  // known; otherwise the per-entry magnitude fold below. Money/move always fold.
  final total = tracker == DetailTracker.rituals && routines.isNotEmpty
      ? completedRoutines(entries, routines, day: n).toDouble()
      : todayIncluded.fold<double>(0, (s, e) => s + tracker.magnitudeOf(e));

  // --- Category breakdown (today, to share the hero's base) ------------------
  final byCategory = <String, double>{};
  for (final e in todayIncluded) {
    final label = tracker.categoryOf(e);
    byCategory[label] = (byCategory[label] ?? 0) + tracker.magnitudeOf(e);
  }
  final categories = byCategory.entries
      .map((e) => CategoryBreakdown(
            label: e.key,
            amount: e.value,
            fraction: total == 0 ? 0 : e.value / total,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  // --- Recent entries grouped by day -----------------------------------------
  final byDay = <DateTime, List<Entry>>{};
  for (final e in included) {
    final d = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
    (byDay[d] ??= []).add(e);
  }
  final days = byDay.entries
      .map((e) => DayGroup(
            day: e.key,
            entries: e.value
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
          ))
      .toList()
    ..sort((a, b) => b.day.compareTo(a.day));

  // Rituals denominator matches Today: the routines with steps, else the
  // legacy goal off [Goals] when there are no routines. Money and move always
  // use the goal off [Goals].
  final target = tracker == DetailTracker.rituals
      ? effectiveDailyRitualTarget(routines, goals).toDouble()
      : tracker.targetOf(goals);

  return DetailData(
    tracker: tracker,
    total: total,
    target: target,
    categories: categories,
    days: days,
  );
}
