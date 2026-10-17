import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'spend_patterns.dart';

/// An expense title must recur at least this many times in the current daypart
/// before it is offered as a pick. One-offs are not habits.
const int kMinHabitOccurrences = 2;

/// How many habit picks to surface at most.
const int kMaxHabitPicks = 3;

/// Extra weight a past expense carries when its day matched today's kind
/// (weekend vs weekday). Ranking only — it never lets a single expense clear
/// [kMinHabitOccurrences], which counts real occurrences.
const int kSameDayTypeWeight = 2;

/// The SF-symbol shown on a habit pick. One icon for every money pick, matching
/// what the server derives for a `log_money` suggestion.
const String kHabitPickIcon = 'dollarsign.circle.fill';

bool _isWeekendDay(DateTime d) => d.weekday >= DateTime.saturday;

/// A recurring expense mined from the user's own history: what they log at this
/// time of day, and what it usually costs.
///
/// Pure data — no formatted amounts, so the UI owns currency rendering.
@immutable
class HabitPick {
  const HabitPick({
    required this.title,
    required this.averageAmount,
    required this.occurrences,
    this.category,
  });

  /// The title as most recently spelled, so the pick reads the way the user
  /// writes it.
  final String title;

  /// Mean spend on this title within the daypart, as a positive magnitude
  /// rounded to cents. The sign is applied on save, as everywhere else.
  final double averageAmount;

  /// How many times it was actually logged in the daypart (unweighted).
  final int occurrences;

  /// The category it most often carried, or null when it never had one.
  final String? category;
}

/// Accumulator for one title while folding the window.
class _Habit {
  _Habit(this.title, this.latest);

  String title;
  DateTime latest;
  double total = 0;
  int count = 0;
  int weighted = 0;
  final Map<String, int> categories = {};

  /// The category seen most often for this title. Ties break toward the first
  /// one reached, which is stable for a given entry list.
  String? get modalCategory {
    String? best;
    var bestCount = 0;
    categories.forEach((category, n) {
      if (n > bestCount) {
        bestCount = n;
        best = category;
      }
    });
    return best;
  }
}

/// The user's recurring expenses for the daypart [now] falls in, best first.
///
/// Mirrors how [aggregateSpend] reads the same window, but groups by title
/// instead of by day: only expenses logged in this daypart count, an expense
/// from a day of the same kind (weekend vs weekday) ranks higher, and a title
/// must clear [kMinHabitOccurrences] real logs to appear at all.
///
/// Returns an empty list for a thin history — the honest answer, leaving the
/// caller to show its own defaults rather than inventing a habit from one
/// coffee.
List<HabitPick> habitPicksForNow(
  List<Entry> entries, {
  required DateTime now,
  int windowDays = kSpendWindowDays,
  int maxPicks = kMaxHabitPicks,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final windowStart = today.subtract(Duration(days: windowDays - 1));
  final windowEnd = today.add(const Duration(days: 1));
  final daypart = daypartFor(now.hour);
  final weekend = _isWeekendDay(now);

  final habits = <String, _Habit>{};
  for (final e in entries) {
    if (!e.isExpense) continue;
    if (e.timestamp.isBefore(windowStart) || !e.timestamp.isBefore(windowEnd)) {
      continue;
    }
    if (daypartFor(e.timestamp.hour) != daypart) continue;

    final key = e.title.trim().toLowerCase();
    if (key.isEmpty) continue;

    final h = habits.putIfAbsent(key, () => _Habit(e.title.trim(), e.timestamp));
    h.total += e.amount!.abs();
    h.count++;
    h.weighted += _isWeekendDay(e.timestamp) == weekend ? kSameDayTypeWeight : 1;
    if (e.timestamp.isAfter(h.latest)) {
      h.latest = e.timestamp;
      h.title = e.title.trim();
    }
    final category = e.category?.trim();
    if (category != null && category.isNotEmpty) {
      h.categories[category] = (h.categories[category] ?? 0) + 1;
    }
  }

  final qualifying = habits.values
      .where((h) => h.count >= kMinHabitOccurrences)
      .toList()
    // weighted frequency first; real count then spend break ties so the order
    // is stable rather than map-insertion dependent.
    ..sort((a, b) {
      final byWeighted = b.weighted.compareTo(a.weighted);
      if (byWeighted != 0) return byWeighted;
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return b.total.compareTo(a.total);
    });

  return [
    for (final h in qualifying.take(maxPicks))
      HabitPick(
        title: h.title,
        averageAmount: ((h.total / h.count) * 100).round() / 100,
        occurrences: h.count,
        category: h.modalCategory,
      ),
  ];
}

/// Titles (trimmed, lowercased) of entries of any kind logged today in the
/// daypart [now] falls in: what is already done for now, so a prediction of it
/// would be a second log.
Set<String> titlesLoggedThisDaypart(List<Entry> entries, {required DateTime now}) {
  final daypart = daypartFor(now.hour);
  return {
    for (final e in entries)
      if (e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day &&
          daypartFor(e.timestamp.hour) == daypart)
        e.title.trim().toLowerCase(),
  };
}
