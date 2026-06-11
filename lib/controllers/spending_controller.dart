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
    recentHeader: "Today's spending",
  ),
  move(
    title: 'Workout',
    entryType: EntryType.move,
    colorToken: 'move',
    askPalPrompt: 'Ask Pal about workouts',
    unbudgetedLabel: 'Other',
    heroSub: 'Minutes logged',
    heroIcon: 'figure.run',
    recentHeader: "Today's workouts",
  ),
  rituals(
    title: 'Routines',
    entryType: EntryType.rituals,
    colorToken: 'rituals',
    askPalPrompt: 'Ask Pal about routines',
    unbudgetedLabel: 'Other',
    heroSub: 'Routines completed',
    heroIcon: 'checkmark',
    recentHeader: "Today's routines",
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

  /// Section header over the recent-entries list (design `Today's …`).
  final String recentHeader;

  /// Magnitude of one entry for totals/breakdown. For money this is the
  /// absolute expense amount; Move/Rituals override to minutes/count.
  double magnitudeOf(Entry e) {
    switch (this) {
      case DetailTracker.money:
        return (e.amount ?? 0) < 0 ? e.amount!.abs() : 0;
      case DetailTracker.move:
        return (e.duration ?? 0).toDouble();
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

  /// Category bucket label for one entry.
  String categoryOf(Entry e) {
    final cat = e.category;
    if (cat != null && cat.trim().isNotEmpty) return cat;
    return unbudgetedLabel;
  }

  /// The budget/target to compare the total against, read off [Goals].
  double targetOf(Goals goals) {
    switch (this) {
      case DetailTracker.money:
        return goals.dailyBudget;
      case DetailTracker.move:
        return goals.dailyMoveMinutes.toDouble();
      case DetailTracker.rituals:
        return goals.dailyRitualTarget.toDouble();
    }
  }
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
DetailData buildDetailData(
  DetailTracker tracker,
  List<Entry> entries,
  Goals goals,
) {
  final included = entries.where(tracker.includes).toList();

  // --- Total -----------------------------------------------------------------
  final total =
      included.fold<double>(0, (s, e) => s + tracker.magnitudeOf(e));

  // --- Category breakdown ----------------------------------------------------
  final byCategory = <String, double>{};
  for (final e in included) {
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

  return DetailData(
    tracker: tracker,
    total: total,
    target: tracker.targetOf(goals),
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

  await for (final entries in entriesRepo.watchAll()) {
    final goals = await goalsRepo.get();
    yield buildDetailData(tracker, entries, goals);
  }
}

/// The money spending detail (handoff screen 06). A thin alias over
/// [detailDataProvider] fixed to [DetailTracker.money] — the named
/// "spending controller / breakdown provider" the unit calls for. Move/Rituals
/// detail just request `detailDataProvider(DetailTracker.move|rituals)`.
@riverpod
Stream<DetailData> spendingDetail(Ref ref) =>
    ref.watch(detailDataProvider(DetailTracker.money).future).asStream();
