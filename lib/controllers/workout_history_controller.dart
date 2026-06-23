import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../util/dates.dart';
import 'providers.dart';
import 'workout_detail_controller.dart' show buildWeeklyVolume;

part 'workout_history_controller.g.dart';

/// The period the History & Trends screen is scoped to. Each value rescales the
/// whole page (summary, volume bars, balance, PRs, sessions).
enum WorkoutHistoryRange { eightWeeks, sixMonths, allTime }

/// Group → `AppColors.forType` token + display order for the balance card and
/// PR rows. 'Core' borrows the nutrition hue (no dedicated token); cardio uses
/// the accent. Pull/Legs borrow rituals/money so the four design slices stay
/// visually distinct.
const _groupOrder = ['Push', 'Pull', 'Legs', 'Core', 'Cardio'];
const Map<String, String> _groupToken = {
  'Push': 'move',
  'Pull': 'rituals',
  'Legs': 'money',
  'Core': 'nutrition',
  'Cardio': 'accent',
};

// ─── Sub-view-models ─────────────────────────────────────────────────────────

/// The four headline tiles: total volume (kg), session count, training minutes,
/// and PR count over the range.
@immutable
class HistorySummary {
  const HistorySummary({
    required this.volumeKg,
    required this.sessionCount,
    required this.totalMinutes,
    required this.prCount,
  });

  final double volumeKg;
  final int sessionCount;
  final int totalMinutes;
  final int prCount;
}

/// One bar of the volume trend: its axis label and bucketed volume in kg.
@immutable
class HistoryBar {
  const HistoryBar({required this.label, required this.volumeKg});
  final String label;
  final double volumeKg;
}

/// One slice of the muscle-balance bar: the group, its accent token, and its
/// share of completed sets as a whole percent.
@immutable
class HistoryGroupSlice {
  const HistoryGroupSlice({
    required this.label,
    required this.colorToken,
    required this.pct,
  });

  final String label;
  final String colorToken;
  final int pct;
}

/// One personal-record row: the best logged set for a lift, plus when it was set
/// and the improvement over the previous best (null when there's no baseline).
/// [bodyweight] lifts (zero weight) are ranked and shown by reps.
@immutable
class HistoryPr {
  const HistoryPr({
    required this.exerciseId,
    required this.name,
    required this.group,
    required this.colorToken,
    required this.weightKg,
    required this.reps,
    required this.bodyweight,
    required this.achievedAt,
    this.deltaKg,
    this.deltaReps,
  });

  final String exerciseId;
  final String name;
  final String group;
  final String colorToken;
  final double weightKg;
  final int reps;
  final bool bodyweight;
  final DateTime achievedAt;
  final double? deltaKg;
  final int? deltaReps;
}

/// One row in the full session list. [volumeKg] is 0 for cardio (no weight is
/// logged; per-session distance isn't stored, so cardio rows show duration).
@immutable
class HistorySessionRow {
  const HistorySessionRow({
    required this.workoutId,
    required this.name,
    required this.colorToken,
    required this.isCardio,
    required this.startedAt,
    required this.minutes,
    required this.volumeKg,
    required this.prCount,
  });

  final String workoutId;
  final String name;
  final String colorToken;
  final bool isCardio;
  final DateTime startedAt;
  final int minutes;
  final double volumeKg;
  final int prCount;
}

/// The fully-computed History & Trends view model. All derivation lives in the
/// pure builders below so the screen is dumb and this is unit-testable.
@immutable
class WorkoutHistoryState {
  const WorkoutHistoryState({
    required this.range,
    required this.summary,
    required this.bars,
    required this.trendPct,
    required this.balance,
    required this.balanceNudge,
    required this.prs,
    required this.sessions,
    required this.headline,
  });

  final WorkoutHistoryRange range;
  final HistorySummary summary;
  final List<HistoryBar> bars;

  /// Recent-half vs prior-half volume change, percent. Null without a baseline.
  final int? trendPct;
  final List<HistoryGroupSlice> balance;
  final String balanceNudge;
  final List<HistoryPr> prs;
  final List<HistorySessionRow> sessions;
  final String headline;
}

// ─── Range windowing ─────────────────────────────────────────────────────────

/// 00:00 of the first day the range covers, relative to [now]. For [allTime]
/// this is the epoch (everything is in range).
DateTime _rangeStart(WorkoutHistoryRange range, DateTime now) => switch (range) {
      WorkoutHistoryRange.eightWeeks =>
        startOfWeek(now).subtract(const Duration(days: 7 * 7)),
      WorkoutHistoryRange.sixMonths => DateTime(now.year, now.month - 5, 1),
      WorkoutHistoryRange.allTime => DateTime.fromMillisecondsSinceEpoch(0),
    };

/// The subset of [all] whose start falls inside [range] (relative to [now]).
List<Workout> workoutsInRange(
    List<Workout> all, WorkoutHistoryRange range, DateTime now) {
  final start = _rangeStart(range, now);
  return [for (final w in all) if (!w.startedAt.isBefore(start)) w];
}

// ─── Summary ─────────────────────────────────────────────────────────────────

/// Folds the range's workouts into the four headline tiles.
HistorySummary buildHistorySummary(List<Workout> inRange) {
  var volume = 0.0;
  var minutes = 0;
  var prs = 0;
  for (final w in inRange) {
    volume += w.totalVolumeKg;
    minutes += w.duration?.inMinutes ?? 0;
    prs += w.prCount;
  }
  return HistorySummary(
    volumeKg: volume,
    sessionCount: inRange.length,
    totalMinutes: minutes,
    prCount: prs,
  );
}

// ─── Muscle balance ──────────────────────────────────────────────────────────

/// Splits completed sets by their exercise's [Exercise.group] into whole-percent
/// slices, in [_groupOrder]. Counts sets (not volume) so cardio — which logs no
/// weight — is still represented. Groups with no sets are omitted.
List<HistoryGroupSlice> buildGroupBalance(
    List<Workout> inRange, List<Exercise> catalog) {
  final groupOf = {for (final e in catalog) e.id: e.group};
  final counts = <String, int>{};
  var total = 0;
  for (final w in inRange) {
    for (final s in w.sets) {
      if (!s.done) continue;
      final g = groupOf[s.exerciseId];
      if (g == null) continue;
      counts[g] = (counts[g] ?? 0) + 1;
      total++;
    }
  }
  if (total == 0) return const [];
  return [
    for (final g in _groupOrder)
      if ((counts[g] ?? 0) > 0)
        HistoryGroupSlice(
          label: g,
          colorToken: _groupToken[g] ?? 'accent',
          pct: ((counts[g]! / total) * 100).round(),
        ),
  ];
}

/// Pal's one-line read on the balance: flags a neglected pull, else encourages.
String _balanceNudge(List<HistoryGroupSlice> balance) {
  if (balance.isEmpty) {
    return 'Log a few sessions and Pal will read your training balance here.';
  }
  final pulls = balance.where((b) => b.label == 'Pull').toList();
  final pull = pulls.isEmpty ? null : pulls.first;
  if (pull != null && pull.pct < 20) {
    return "Pull is only ${pull.pct}% of your sets — you've been skipping it. "
        'Prioritize a pull day to even things out.';
  }
  return 'Nicely balanced across push, pull and legs. Keep the cardio coming.';
}

// ─── Personal records ────────────────────────────────────────────────────────

/// The best logged set per lift over the range, newest achievement first.
/// Weighted lifts rank by volume (weight × reps); bodyweight lifts (zero weight)
/// rank by reps. [HistoryPr.deltaKg]/[HistoryPr.deltaReps] capture the gain over
/// the previous best when an earlier set exists.
List<HistoryPr> buildHistoryPrs(List<Workout> inRange, List<Exercise> catalog) {
  final cat = {for (final e in catalog) e.id: e};
  final byExercise = <String, List<({SetLog set, DateTime at})>>{};
  for (final w in inRange) {
    for (final s in w.sets) {
      if (!s.done) continue;
      (byExercise[s.exerciseId] ??= []).add((set: s, at: w.startedAt));
    }
  }

  final prs = <HistoryPr>[];
  byExercise.forEach((id, entries) {
    final hasWeight = entries.any((e) => e.set.weightKg > 0);
    double metric(SetLog s) => hasWeight ? s.volumeKg : s.reps.toDouble();

    var best = entries.first;
    for (final e in entries.skip(1)) {
      final cmp = metric(e.set).compareTo(metric(best.set));
      if (cmp > 0 || (cmp == 0 && e.at.isAfter(best.at))) best = e;
    }

    double? deltaKg;
    int? deltaReps;
    final earlier = [for (final e in entries) if (e.at.isBefore(best.at)) e];
    if (earlier.isNotEmpty) {
      if (hasWeight) {
        final prevMax =
            earlier.map((e) => e.set.weightKg).reduce((a, b) => a > b ? a : b);
        final d = best.set.weightKg - prevMax;
        if (d > 0) deltaKg = d;
      } else {
        final prevMax =
            earlier.map((e) => e.set.reps).reduce((a, b) => a > b ? a : b);
        final d = best.set.reps - prevMax;
        if (d > 0) deltaReps = d;
      }
    }

    final ex = cat[id];
    prs.add(HistoryPr(
      exerciseId: id,
      name: ex?.name ?? id,
      group: ex?.group ?? '',
      colorToken: _groupToken[ex?.group] ?? 'accent',
      weightKg: best.set.weightKg,
      reps: best.set.reps,
      bodyweight: !hasWeight,
      achievedAt: best.at,
      deltaKg: deltaKg,
      deltaReps: deltaReps,
    ));
  });

  prs.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
  return prs;
}

// ─── Sessions ────────────────────────────────────────────────────────────────

/// Maps each workout to a session row (newest first), tagging cardio via its
/// routine's [RoutineTag.cardio]. Color mirrors the Move screen: cardio →
/// accent, strength → move.
List<HistorySessionRow> buildHistorySessions(
    List<Workout> inRange, List<Routine> routines) {
  final cardioIds = {
    for (final r in routines)
      if (r.tag == RoutineTag.cardio) r.id,
  };
  final rows = [
    for (final w in inRange)
      HistorySessionRow(
        workoutId: w.id,
        name: w.name,
        startedAt: w.startedAt,
        minutes: w.duration?.inMinutes ?? 0,
        volumeKg: w.totalVolumeKg,
        prCount: w.prCount,
        isCardio: w.routineId != null && cardioIds.contains(w.routineId),
        colorToken: w.routineId != null && cardioIds.contains(w.routineId)
            ? 'accent'
            : 'move',
      ),
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return rows;
}

// ─── Volume bars + trend ─────────────────────────────────────────────────────

/// The volume trend bars for [range]: 8 weekly buckets (8w), 6 monthly buckets
/// (6m), or the trailing 12 monthly buckets (all time).
List<HistoryBar> buildVolumeBars(
    WorkoutHistoryRange range, List<Workout> workouts, DateTime now) {
  switch (range) {
    case WorkoutHistoryRange.eightWeeks:
      final weeks = buildWeeklyVolume(workouts, now);
      return [
        for (var i = 0; i < weeks.length; i++)
          HistoryBar(label: 'W${i + 1}', volumeKg: weeks[i].volumeKg),
      ];
    case WorkoutHistoryRange.sixMonths:
      return _monthlyBars(workouts, now, 6);
    case WorkoutHistoryRange.allTime:
      return _monthlyBars(workouts, now, 12);
  }
}

/// [count] monthly volume buckets ending at the month of [now], oldest first.
List<HistoryBar> _monthlyBars(
    List<Workout> workouts, DateTime now, int count) {
  final months = [
    for (var i = count - 1; i >= 0; i--) DateTime(now.year, now.month - i, 1),
  ];
  final volume = {for (final m in months) m: 0.0};
  for (final w in workouts) {
    final key = DateTime(w.startedAt.year, w.startedAt.month, 1);
    if (volume.containsKey(key)) {
      volume[key] = volume[key]! + w.totalVolumeKg;
    }
  }
  return [
    for (final m in months)
      HistoryBar(label: kMonthsShort[m.month - 1], volumeKg: volume[m]!),
  ];
}

/// Recent-half vs prior-half volume change as a whole percent. Null when there
/// are fewer than two bars or no prior-half baseline (avoids /0 and "+0%").
int? historyTrendPct(List<HistoryBar> bars) {
  if (bars.length < 2) return null;
  final half = bars.length ~/ 2;
  final prior = bars.take(half).fold<double>(0, (s, b) => s + b.volumeKg);
  final recent = bars.skip(half).fold<double>(0, (s, b) => s + b.volumeKg);
  if (prior <= 0) return null;
  return (((recent - prior) / prior) * 100).round();
}

// ─── Composition + headline ──────────────────────────────────────────────────

String _headline(WorkoutHistoryRange range, HistorySummary s) {
  final period = switch (range) {
    WorkoutHistoryRange.eightWeeks => 'the last 8 weeks',
    WorkoutHistoryRange.sixMonths => 'the last 6 months',
    WorkoutHistoryRange.allTime => 'all time',
  };
  final tonnes = (s.volumeKg / 1000).toStringAsFixed(1);
  return 'You trained ${s.sessionCount} '
      '${s.sessionCount == 1 ? 'time' : 'times'} and moved $tonnes tonnes over '
      '$period.';
}

/// Composes the full [WorkoutHistoryState] for [range] from the pure builders.
WorkoutHistoryState buildWorkoutHistory(
  WorkoutHistoryRange range,
  List<Workout> all,
  List<Exercise> catalog,
  List<Routine> routines,
  DateTime now,
) {
  final inRange = workoutsInRange(all, range, now);
  final summary = buildHistorySummary(inRange);
  final bars = buildVolumeBars(range, inRange, now);
  final balance = buildGroupBalance(inRange, catalog);
  return WorkoutHistoryState(
    range: range,
    summary: summary,
    bars: bars,
    trendPct: historyTrendPct(bars),
    balance: balance,
    balanceNudge: _balanceNudge(balance),
    prs: buildHistoryPrs(inRange, catalog),
    sessions: buildHistorySessions(inRange, routines),
    headline: _headline(range, summary),
  );
}

// ─── Provider ────────────────────────────────────────────────────────────────

/// Streams the [WorkoutHistoryState] for [range]: re-emits when the workout
/// store changes. The catalog and routines are awaited once via `.future`.
@riverpod
Stream<WorkoutHistoryState> workoutHistory(
    Ref ref, WorkoutHistoryRange range) async* {
  final repo = ref.watch(workoutRepositoryProvider);
  final catalog = await ref.watch(exercisesProvider.future);
  final routines = await ref.watch(workoutRoutinesStreamProvider.future);

  await for (final all in repo.watchWorkouts()) {
    yield buildWorkoutHistory(range, all, catalog, routines, DateTime.now());
  }
}
