import '../../models/models.dart';
import 'pal_service.dart' show InsightRange;

/// Formats one timeline entry as the handoff's `HH:MM Title (type, detail)`.
String formatEntryLine(Entry e) {
  final hh = e.timestamp.hour.toString().padLeft(2, '0');
  final mm = e.timestamp.minute.toString().padLeft(2, '0');
  final detail = switch (e.type) {
    EntryType.money => e.amount == null ? '' : '\$${e.amount!.toStringAsFixed(0)}',
    EntryType.move => e.duration == null ? '' : '${e.duration}min',
    EntryType.rituals => '',
  };
  return '$hh:$mm ${e.title} (${e.type.wire}${detail.isEmpty ? '' : ', $detail'})';
}

double _spent(Iterable<Entry> entries) {
  var total = 0.0;
  for (final e in entries) {
    if (e.type == EntryType.money && (e.amount ?? 0) < 0) total += e.amount!.abs();
  }
  return total;
}

int _movedMin(Iterable<Entry> entries) =>
    entries.where((e) => e.type == EntryType.move).fold(0, (a, e) => a + (e.duration ?? 0));

int _rituals(Iterable<Entry> entries) =>
    entries.where((e) => e.type == EntryType.rituals).length;

Map<String, Object?> buildChatContext({
  required String userName,
  required Goals goals,
  required List<Entry> todayEntries,
  required List<Entry> weekEntries,
  required int moveStreakDays,
}) {
  return {
    'userName': userName,
    'todayEntries': todayEntries.map(formatEntryLine).toList(),
    'dailyBudget': goals.dailyBudget,
    'moveGoalMin': goals.dailyMoveMinutes,
    'ritualGoal': goals.dailyRitualTarget,
    'spentToday': _spent(todayEntries),
    'movedTodayMin': _movedMin(todayEntries),
    'ritualsDoneToday': _rituals(todayEntries),
    'weekSpent': _spent(weekEntries),
    'weekBudget': goals.dailyBudget * 7,
    'weekMovedMin': _movedMin(weekEntries),
    'weekRitualsDone': _rituals(weekEntries),
    'weekRitualGoal': goals.dailyRitualTarget * 7,
    'moveStreakDays': moveStreakDays,
  };
}

Map<String, Object?> buildReviewContext({
  required double spent,
  required int spentDeltaPct,
  required int hoursMoved,
  required int movedDeltaPct,
  required int activeDays,
  required int ritualsKept,
  required int ritualsTarget,
  required int streakDays,
  required String topCategory,
  required int topCategoryPct,
  required String discoveredPattern,
}) {
  final pct = ritualsTarget == 0 ? 0 : ((ritualsKept / ritualsTarget) * 100).round();
  return {
    'spent': spent,
    'spentDeltaPct': spentDeltaPct,
    'hoursMoved': hoursMoved,
    'movedDeltaPct': movedDeltaPct,
    'activeDays': activeDays,
    'ritualsKept': ritualsKept,
    'ritualsTarget': ritualsTarget,
    'ritualsPct': pct,
    'streakDays': streakDays,
    'topCategory': topCategory,
    'topCategoryPct': topCategoryPct,
    'discoveredPattern': discoveredPattern,
  };
}

/// Caps the entry texture sent with an insights request so the prompt stays
/// bounded regardless of how busy a window is.
const _maxInsightEntries = 60;

/// Current move streak in days: consecutive calendar days, ending today (or
/// yesterday — a streak isn't broken until a full day passes without moving),
/// that have at least one move entry. Pure so it can be unit-tested with a
/// fixed [now]; pass a lookback window of [entries] (e.g. the last 60 days).
int moveStreakDays(List<Entry> entries, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final moveDays = <int>{};
  for (final e in entries) {
    if (e.type != EntryType.move) continue;
    final t = e.timestamp;
    moveDays.add(t.year * 10000 + t.month * 100 + t.day);
  }
  int key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  var cursor = DateTime(today.year, today.month, today.day);
  // allow the streak to anchor on yesterday if today has no move entry yet
  if (!moveDays.contains(key(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!moveDays.contains(key(cursor))) return 0;
  }
  var streak = 0;
  while (moveDays.contains(key(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

String _insightRangeWire(InsightRange range) => switch (range) {
      InsightRange.day => 'day',
      InsightRange.week => 'week',
      InsightRange.month => 'month',
    };

/// Builds the structured aggregate map for an `/insights` request over the
/// window's [entries]. `spendByWeekday` is Monday→Sunday so the model can spot
/// day-of-week patterns; `topCategory`/`topCategoryPct` and the totals give it
/// grounded numbers. [streakDays] is the current move streak (computed upstream).
Map<String, Object?> buildInsightsContext({
  required InsightRange range,
  required List<Entry> entries,
  required Goals goals,
  required int periodDays,
  required int streakDays,
}) {
  final spendByWeekday = List<double>.filled(7, 0);
  final activeMoveDays = <int>{};
  final byCat = <String, double>{};
  for (final e in entries) {
    switch (e.type) {
      case EntryType.money:
        if ((e.amount ?? 0) < 0) {
          final abs = e.amount!.abs();
          spendByWeekday[e.timestamp.weekday - 1] += abs;
          byCat[e.category ?? 'Other'] = (byCat[e.category ?? 'Other'] ?? 0) + abs;
        }
      case EntryType.move:
        final t = e.timestamp;
        activeMoveDays.add(t.year * 10000 + t.month * 100 + t.day);
      case EntryType.rituals:
        break;
    }
  }

  final spent = _spent(entries);
  var topCategory = '—';
  var topVal = 0.0;
  byCat.forEach((k, v) {
    if (v > topVal) {
      topVal = v;
      topCategory = k;
    }
  });

  return {
    'range': _insightRangeWire(range),
    'spent': spent,
    'budget': goals.dailyBudget * periodDays,
    'moveMinutes': _movedMin(entries),
    'moveTarget': goals.dailyMoveMinutes * periodDays,
    'ritualsKept': _rituals(entries),
    'ritualsTarget': goals.dailyRitualTarget * periodDays,
    'activeDays': activeMoveDays.length,
    'streakDays': streakDays,
    'topCategory': topCategory,
    'topCategoryPct': spent == 0 ? 0 : ((topVal / spent) * 100).round(),
    'spendByWeekday': spendByWeekday,
    'entries': entries.take(_maxInsightEntries).map(formatEntryLine).toList(),
  };
}

Map<String, Object?> buildSuggestContext({
  required List<Workout> recentWorkouts,
  required String dayOfWeek,
  required List<Routine> availableRoutines,
}) {
  return {
    'recentWorkouts': recentWorkouts
        .map((w) => {
              'routineName': w.name,
              'date': '${w.startedAt.month}/${w.startedAt.day}',
              'muscles': w.sets.map((s) => s.exerciseId).toSet().join(', '),
            })
        .toList(),
    'dayOfWeek': dayOfWeek,
    'availableRoutines':
        availableRoutines.map((r) => {'id': r.id, 'name': r.name}).toList(),
  };
}

Map<String, Object?> buildPostWorkoutContext({
  required Workout workout,
  required double? lastSessionVolumeKg,
  required int? daysAgoLastSession,
}) {
  final done = workout.sets.where((s) => s.done);
  final prExercises = done.where((s) => s.isPR).map((s) => s.exerciseId).toSet().toList();
  return {
    'routineName': workout.name,
    'setCount': done.length,
    'volumeKg': workout.totalVolumeKg,
    'prCount': workout.prCount,
    'prExercises': prExercises,
    'lastSessionVolumeKg': lastSessionVolumeKg,
    'daysAgoLastSession': daysAgoLastSession,
  };
}
