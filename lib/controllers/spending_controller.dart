import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'spending_controller.g.dart';

/// Which tracker a [DetailScreen] is rendering. This is the real
/// type-parametrization for handoff screen 06: the Spending detail is built as
/// a reusable template so the Move and Rituals detail screens (later units)
/// reuse the exact same widget + provider, only switching this value.
///
/// Each case carries the presentation knobs the template needs (title, the
/// underlying [EntryType], the tracker color token, and how a single entry's
/// magnitude and label are read). Money is the only case wired into the UI now;
/// the others are defined so Move/Rituals detail can drop in without touching
/// the template.
enum DetailTracker {
  money(
    title: 'Spending',
    entryType: EntryType.money,
    colorToken: 'money',
    askPalPrompt: 'Ask Pal about spending',
    unbudgetedLabel: 'Uncategorized',
    heroSub: 'Spent today',
    heroIcon: 'creditcard.fill',
    recentHeader: 'Recent spending',
  ),
  move(
    title: 'Workout',
    entryType: EntryType.move,
    colorToken: 'move',
    askPalPrompt: 'Ask Pal about workouts',
    unbudgetedLabel: 'Other',
    heroSub: 'Active energy',
    heroIcon: 'figure.run',
    recentHeader: 'Recent workouts',
  ),
  rituals(
    title: 'Routines',
    entryType: EntryType.rituals,
    colorToken: 'rituals',
    askPalPrompt: 'Ask Pal about routines',
    unbudgetedLabel: 'Other',
    heroSub: 'Routines completed',
    heroIcon: 'checkmark',
    recentHeader: 'Recent routines',
  );

  const DetailTracker({
    required this.title,
    required this.entryType,
    required this.colorToken,
    required this.askPalPrompt,
    required this.unbudgetedLabel,
    required this.heroSub,
    required this.heroIcon,
    required this.recentHeader,
  });

  /// Large-title nav text for this detail screen.
  final String title;

  /// The [EntryType] whose entries feed this detail screen.
  final EntryType entryType;

  /// `context.colors.forType(colorToken)` — the tracker accent color.
  final String colorToken;

  /// Copy for the bottom "Ask Pal about …" pill.
  final String askPalPrompt;

  /// Category bucket label for entries with no category set.
  final String unbudgetedLabel;

  /// Colored hero sub-line under the big number (design `cfg.sub`).
  final String heroSub;

  /// SF symbol for the hero icon tile and entry rows (design `cfg.icon`/`e.sf`).
  final String heroIcon;

  /// Section header over the recent-entries list. "Recent", not the design's
  /// "Today's …": the list groups by day (Today/Yesterday/date), so it spans
  /// history while the hero above stays scoped to today.
  final String recentHeader;

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
  final n = now ?? DateTime.now();
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

  // Rituals denominator is the routine count when known (matches Today); money
  // and move use the goal off [Goals], as does the rituals legacy fallback.
  final target = tracker == DetailTracker.rituals && routines.isNotEmpty
      ? routines.length.toDouble()
      : tracker.targetOf(goals);

  return DetailData(
    tracker: tracker,
    total: total,
    target: target,
    categories: categories,
    days: days,
  );
}

/// Streams the [DetailData] for a [tracker]. Reactive: re-emits whenever the
/// entries or goals change. Reads all entries (the detail shows recent history
/// across days, not just today) and folds them via [buildDetailData].
@riverpod
Stream<DetailData> detailData(Ref ref, DetailTracker tracker) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final goalsRepo = ref.watch(goalsRepositoryProvider);
  final ritualRepo = ref.watch(ritualRepositoryProvider);

  await for (final entries in entriesRepo.watchAll()) {
    final goals = await goalsRepo.get();
    // Rituals hero counts completed routines ÷ routine count (matches Today);
    // other trackers don't need routine structure.
    final routines = tracker == DetailTracker.rituals
        ? await ritualRepo.getAll()
        : const <RitualRoutine>[];
    yield buildDetailData(tracker, entries, goals, routines: routines);
  }
}

/// The money spending detail (handoff screen 06). A thin alias over
/// [detailDataProvider] fixed to [DetailTracker.money] — the named
/// "spending controller / breakdown provider" the unit calls for. Move/Rituals
/// detail just request `detailDataProvider(DetailTracker.move|rituals)`.
@riverpod
Stream<DetailData> spendingDetail(Ref ref) =>
    ref.watch(detailDataProvider(DetailTracker.money).future).asStream();
