import '../../models/models.dart';

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
