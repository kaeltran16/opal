import '../../models/models.dart';
import '../../util/dates.dart' show startOfWeek;
import '../../util/format.dart';
import 'pal_service.dart' show InsightRange, ReviewRange;

/// Formats one timeline entry as the handoff's `HH:MM Title (type, detail)`.
String formatEntryLine(Entry e, Currency currency) {
  final hh = e.timestamp.hour.toString().padLeft(2, '0');
  final mm = e.timestamp.minute.toString().padLeft(2, '0');
  final detail = switch (e.type) {
    EntryType.money =>
      e.amount == null ? '' : formatCurrency(e.amount!, currency, withSign: true),
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

int _movedKcal(Iterable<Entry> entries) =>
    entries.where((e) => e.type == EntryType.move).fold(0, (a, e) => a + (e.calories ?? 0));

int _rituals(Iterable<Entry> entries) =>
    entries.where((e) => e.type == EntryType.rituals).length;

Map<String, Object?> buildChatContext({
  required String userName,
  required Goals goals,
  required List<Entry> todayEntries,
  required List<Entry> weekEntries,
  required int moveStreakDays,
  List<RitualRoutine> routines = const [],
  Currency currency = Currency.usd,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final ritualTarget = effectiveDailyRitualTarget(routines.length, goals);
  return {
    'userName': userName,
    'todayEntries': todayEntries.map((e) => formatEntryLine(e, currency)).toList(),
    'dailyBudget': goals.dailyBudget,
    'moveGoalKcal': goals.dailyMoveKcal,
    'ritualGoal': ritualTarget,
    'spentToday': _spent(todayEntries),
    'movedTodayKcal': _movedKcal(todayEntries),
    'ritualsDoneToday': completedRoutines(todayEntries, routines, day: clock),
    'weekSpent': _spent(weekEntries),
    'weekBudget': goals.dailyBudget * 7,
    'weekMovedKcal': _movedKcal(weekEntries),
    'weekRitualsDone': completedRoutinesInPeriod(weekEntries, routines,
        start: startOfWeek(clock), days: 7),
    'weekRitualGoal': ritualTarget * 7,
    'moveStreakDays': moveStreakDays,
    'hourOfDay': clock.hour,
    'weekday': clock.weekday,
    'currency': currency.toWire(),
  };
}

Map<String, Object?> buildReviewContext({
  required ReviewRange range,
  required double spent,
  required int? spentDeltaPct,
  required int kcalMoved,
  required int? movedDeltaPct,
  required int activeDays,
  required int ritualsKept,
  required int ritualsTarget,
  required int streakDays,
  required String topCategory,
  required int topCategoryPct,
  Currency currency = Currency.usd,
}) {
  final pct = ritualsTarget == 0 ? 0 : ((ritualsKept / ritualsTarget) * 100).round();
  return {
    'range': switch (range) {
      ReviewRange.week => 'week',
      ReviewRange.month => 'month',
    },
    'spent': spent,
    'spentDeltaPct': spentDeltaPct,
    'kcalMoved': kcalMoved,
    'movedDeltaPct': movedDeltaPct,
    'activeDays': activeDays,
    'ritualsKept': ritualsKept,
    'ritualsTarget': ritualsTarget,
    'ritualsPct': pct,
    'streakDays': streakDays,
    'topCategory': topCategory,
    'topCategoryPct': topCategoryPct,
    'currency': currency.toWire(),
  };
}

/// Caps the entry texture sent with an insights request so the prompt stays
/// bounded regardless of how busy a window is.
const _maxInsightEntries = 60;

/// Current move streak in days: consecutive calendar days, ending today (or
/// yesterday — a streak isn't broken until a full day passes without moving),
/// that have at least one move entry. Pure so it can be unit-tested with a
/// fixed [now]; pass a lookback window of [entries] (e.g. the last 60 days).
int moveStreakDays(List<Entry> entries, {DateTime? now}) =>
    _streakDays(entries, EntryType.move, now: now);

/// Current ritual streak in days: consecutive calendar days, ending today (or
/// yesterday), on which at least one ritual step was completed. Mirrors
/// [moveStreakDays] but over ritual-type entries — the persisted completion
/// records written by `RitualsController` (the single source of truth shared
/// with the Today rings). Pure; pass a lookback window of [entries].
int ritualStreakDays(List<Entry> entries, {DateTime? now}) =>
    _streakDays(entries, EntryType.rituals, now: now);

/// Consecutive-day streak ending today (or yesterday if today has no qualifying
/// entry yet) over entries of [type]. Shared by [moveStreakDays] and
/// [ritualStreakDays].
int _streakDays(List<Entry> entries, EntryType type, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = <int>{};
  for (final e in entries) {
    if (e.type != type) continue;
    final t = e.timestamp;
    days.add(t.year * 10000 + t.month * 100 + t.day);
  }
  int key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  var cursor = DateTime(today.year, today.month, today.day);
  // allow the streak to anchor on yesterday if today has no qualifying entry yet
  if (!days.contains(key(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(key(cursor))) return 0;
  }
  var streak = 0;
  while (days.contains(key(cursor))) {
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
  List<RitualRoutine> routines = const [],
  DateTime? periodStart,
  String? correlationSummary,
  Currency currency = Currency.usd,
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
    'moveKcal': _movedKcal(entries),
    'moveTargetKcal': goals.dailyMoveKcal * periodDays,
    'ritualsKept': periodStart == null
        ? _rituals(entries)
        : completedRoutinesInPeriod(entries, routines,
            start: periodStart, days: periodDays),
    'ritualsTarget': effectiveDailyRitualTarget(routines.length, goals) * periodDays,
    'activeDays': activeMoveDays.length,
    'streakDays': streakDays,
    'topCategory': topCategory,
    'topCategoryPct': spent == 0 ? 0 : ((topVal / spent) * 100).round(),
    'spendByWeekday': spendByWeekday,
    'entries': entries.take(_maxInsightEntries).map((e) => formatEntryLine(e, currency)).toList(),
    if (correlationSummary != null) 'correlation': {'summary': correlationSummary},
    'currency': currency.toWire(),
  };
}

Map<String, Object?> buildSuggestContext({
  required List<Workout> recentWorkouts,
  required String dayOfWeek,
  required List<Routine> availableRoutines,
  required Map<String, Exercise> exercisesById,
}) {
  return {
    'recentWorkouts': recentWorkouts
        .map((w) => {
              'routineName': w.name,
              'date': '${w.startedAt.month}/${w.startedAt.day}',
              'muscles': w.sets
                  .map((s) => _muscleLabel(exercisesById[s.exerciseId], s.exerciseId))
                  .toSet()
                  .join(', '),
            })
        .toList(),
    'dayOfWeek': dayOfWeek,
    'availableRoutines':
        availableRoutines.map((r) => {'id': r.id, 'name': r.name}).toList(),
  };
}

/// Best label for an exercise: its primary muscle, falling back to its group,
/// then to the raw id when the exercise is unknown to the catalog.
String _muscleLabel(Exercise? exercise, String exerciseId) {
  if (exercise == null) return exerciseId;
  if (exercise.muscle.isNotEmpty) return exercise.muscle;
  if (exercise.group.isNotEmpty) return exercise.group;
  return exerciseId;
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
