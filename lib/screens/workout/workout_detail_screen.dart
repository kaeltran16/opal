import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../controllers/workout_detail_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/pal_label.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/stat_row.dart';
import '../../widgets/timed_total.dart';
import '../shell/loop_shell.dart' show shellBottomInset;

const double _leadTop = Spacing.xl;
const double _recordTop = Spacing.md;
const double _statsTop = Spacing.xxl;
const double _sectionTop = Spacing.xxxl;
const double _headingGap = Spacing.xs;
const double _blockGap = Spacing.xl;
const double _iconGap = 6;
const double _recordIcon = 16;
const double _chartHeight = 120;
const double _barWidth = 14;
const double _weekLabels = 18;
const double _rowMinHeight = 48;
const double _setNumberWidth = 28;
const double _hairline = 1;
const double _sheetRowMinHeight = 52;
const double _sheetIcon = 22;
const double _sheetGap = 14;
const String _thousands = ',';
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Screen 12 — Workout Detail (past session).
///
/// Read-only breakdown of one finished [Workout]: the volume as the lead with
/// its best and a stat row (Time / Sets / Records), an 8-week bar chart of
/// volume, or minutes for a timed session (fl_chart), a per-exercise set
/// table, and Pal's post-workout note.
///
/// All derivation lives in [workoutDetailProvider] / [workoutNoteProvider];
/// this widget only lays out.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(workoutDetailProvider(workoutId));

    // Opaque background so the Cupertino push parallax doesn't show the
    // outgoing page through this one (ghosting). Mirrors the shell's c.bg.
    return ColoredBox(
      color: c.bg,
      child: async.when(
        loading: () => Center(
          child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Text("Couldn't load this session.",
                textAlign: TextAlign.center,
                style: AppType.subhead.copyWith(color: c.ink3)),
          ),
        ),
        data: (state) => _Body(workoutId: workoutId, state: state),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.workoutId, required this.state});
  final String workoutId;
  final WorkoutDetailState state;

  String get _dateLabel {
    final d = state.workout.startedAt;
    return '${kMonthsShort[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final w = state.workout;
    return LargeTitleScrollView(
      title: w.name,
      subtitle: _dateLabel,
      leading: NavAction(
        icon: 'chevron.left',
        onTap: () => context.pop(),
        semanticLabel: 'Back',
      ),
      trailing: _MoreButton(workoutId: workoutId, name: w.name),
      padding: EdgeInsets.only(bottom: shellBottomInset(context)),
      children: [
        _Lead(state: state),
        _Section(
          title: w.isTimedSession ? 'Minutes over 8 weeks' : 'Volume over 8 weeks',
          child: _WeeksChart(weeks: state.weeks, timed: w.isTimedSession),
        ),
        _Section(
          title: 'Exercises',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _blockGap,
            children: [
              for (final group in state.exercises) _ExerciseBlock(group: group),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, _sectionTop, Spacing.lg, 0),
          child: _PalNote(workoutId: workoutId),
        ),
      ],
    );
  }
}

/// The session volume, its best when it set one, then Time / Sets / Records.
class _Lead extends StatelessWidget {
  const _Lead({required this.state});
  final WorkoutDetailState state;

  /// `{exercise}, {kg} kg` for the session's first completed PR set.
  String? get _record {
    for (final group in state.exercises) {
      for (final s in group.sets) {
        if (s.done && s.isPR && !s.isTimed) return '${group.name}, ${formatWeight(s.weightKg)} kg';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = state.workout;
    final record = _record;
    final volume = groupThousands('${w.totalVolumeKg.round()}', _thousands);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, _leadTop, Spacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (w.isTimedSession)
            TimedTotal(minutes: w.totalMinutes, km: w.totalKm)
          else ...[
            Text(volume, style: AppType.display.copyWith(color: c.ink)),
            Text('kg lifted', style: AppType.subhead.copyWith(color: c.ink2)),
          ],
          if (record != null) ...[
            const SizedBox(height: _recordTop),
            Row(
              spacing: _iconGap,
              children: [
                AppIcon('checkmark', size: _recordIcon, color: c.thrivingInk),
                Flexible(
                  child: Text('New best · $record',
                      style: AppType.subhead.copyWith(color: c.thrivingInk)),
                ),
              ],
            ),
          ],
          const SizedBox(height: _statsTop),
          StatRow(stats: [
            Stat(value: '${w.duration?.inMinutes ?? 0}', unit: 'min', label: 'Time'),
            Stat(value: '${w.completedSetCount}', unit: 'of ${w.sets.length}', label: 'Sets'),
            Stat(value: '${w.prCount}', label: 'Records'),
          ]),
        ],
      ),
    );
  }
}

/// A `headline` section on the gutter.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, _sectionTop, Spacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _headingGap,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(title, style: AppType.headline.copyWith(color: c.ink)),
          ),
          child,
        ],
      ),
    );
  }
}

/// 8-week bars (fl_chart) in `ink` on `track`, under a sentence with the
/// total and the trend: weekly volume, or the minutes of timed sets when
/// [timed], as a timed session counts time, not weight.
class _WeeksChart extends StatelessWidget {
  const _WeeksChart({required this.weeks, required this.timed});
  final List<WeekTotals> weeks;
  final bool timed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final values = [for (final w in weeks) timed ? w.minutes.toDouble() : w.volumeKg];
    final most = values.fold<double>(0, math.max);
    final maxY = most <= 0 ? 1.0 : most;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.lg,
      children: [
        Semantics(
          container: true,
          child: Text(_weeksSentence(weeks, timed: timed),
              style: AppType.subhead.copyWith(color: c.ink3)),
        ),
        SizedBox(
          height: _chartHeight,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceBetween,
              barTouchData: BarTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: _weekLabels,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      final latest = i == weeks.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: Spacing.xs),
                        child: Text('W${i + 1}',
                            style: AppType.caption.copyWith(
                                fontWeight: latest ? FontWeight.w600 : null,
                                color: latest ? c.ink : c.ink3)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (final (i, value) in values.indexed)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        width: _barWidth,
                        color: c.ink,
                        borderRadius: const BorderRadius.all(Radius.circular(Radii.xs)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: c.track,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "12.4 t over 8 weeks, up 15% in the last 4 weeks.", or for a timed session
/// "95 min · 12.4 km over 8 weeks, ...".
String _weeksSentence(List<WeekTotals> weeks, {required bool timed}) {
  final String amount;
  if (timed) {
    final minutes = weeks.fold<int>(0, (s, w) => s + w.minutes);
    amount = formatTimed(minutes, weeks.fold<double>(0, (s, w) => s + w.km));
  } else {
    final tonnes = weeks.fold<double>(0, (s, w) => s + w.volumeKg) / 1000;
    amount = '${tonnes.toStringAsFixed(1)} t';
  }
  final total = '$amount over 8 weeks';
  final trend = _trendPct([for (final w in weeks) timed ? w.minutes.toDouble() : w.volumeKg]);
  if (trend == null) return '$total.';
  if (trend == 0) return '$total, level over the last 4 weeks.';
  final direction = trend > 0 ? 'up' : 'down';
  return '$total, $direction ${trend.abs()}% in the last 4 weeks.';
}

/// Percent change of the recent half vs the prior half of the 8-week window.
/// Null when there's no prior baseline to compare against (avoids /0 and a
/// meaningless "+0%").
int? _trendPct(List<double> weeks) {
  if (weeks.length < 2) return null;
  final half = weeks.length ~/ 2;
  final prior = weeks.take(half).fold<double>(0, (s, w) => s + w);
  final recent = weeks.skip(half).fold<double>(0, (s, w) => s + w);
  if (prior <= 0) return null;
  return (((recent - prior) / prior) * 100).round();
}

/// One exercise's name over its hairline set table.
class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({required this.group});
  final ExerciseSets group;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _headingGap),
          child: Semantics(
            container: true,
            header: true,
            child: Text(group.name, style: AppType.headline.copyWith(color: c.ink)),
          ),
        ),
        for (final (i, set) in group.sets.indexed) _SetRow(index: i, set: set),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.index, required this.set});
  final int index;
  final SetLog set;

  String get _load => set.isTimed
      ? formatTimed(set.minutes!, set.distanceKm ?? 0)
      : set.weightKg == 0
          ? '${set.reps} reps'
          : '${formatWeight(set.weightKg)} kg × ${set.reps}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: _rowMinHeight),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hair, width: _hairline)),
        ),
        child: Row(
          spacing: Spacing.sm,
          children: [
            SizedBox(
              width: _setNumberWidth,
              child: Text('${index + 1}',
                  style: AppType.caption.copyWith(color: c.ink3, fontFeatures: _tabular)),
            ),
            Expanded(
              child: Text(_load,
                  style: AppType.subhead.copyWith(color: c.ink, fontFeatures: _tabular)),
            ),
            if (set.isPR && !set.isTimed)
              Text('New best', style: AppType.subhead.copyWith(color: c.thrivingInk)),
          ],
        ),
      ),
    );
  }
}

/// Pal's post-workout note: the label over a `body` line.
class _PalNote extends ConsumerWidget {
  const _PalNote({required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final note = ref.watch(workoutNoteProvider(workoutId));
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spacing.sm,
        children: [
          const PalLabel(),
          Text(
            note.when(
              loading: () => 'Pal is reading your session…',
              error: (_, _) => "Pal couldn't write a note just now.",
              data: (text) => text,
            ),
            style: AppType.body.copyWith(color: note.hasValue ? c.ink : c.ink3),
          ),
        ],
      ),
    );
  }
}

/// Trailing "…" button for the detail header. Opens the More options sheet;
/// its one action, Delete workout, removes this session after a confirm and
/// pops back. (A past session is read-only, so there's no Edit/Share.)
class _MoreButton extends ConsumerWidget {
  const _MoreButton({required this.workoutId, required this.name});
  final String workoutId;
  final String name;

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final delete = await showAppSheet<bool>(
      context,
      builder: (sheetContext) => _DeleteRow(onTap: () => Navigator.of(sheetContext).pop(true)),
    );
    if (delete != true || !context.mounted) return;
    if (!await _confirmDelete(context, name)) return;
    await ref.read(workoutRepositoryProvider).deleteById(workoutId);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavIconButton(
      name: 'ellipsis',
      semanticLabel: 'More options',
      onTap: () => _openMenu(context, ref),
    );
  }
}

/// Cupertino confirm before a workout is deleted. True only on Delete.
Future<bool> _confirmDelete(BuildContext context, String name) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('Delete workout?'),
      content: Text('"$name" will be removed. This can’t be undone.'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// The sheet's destructive row: a `trash` line icon and the word in `careInk`.
class _DeleteRow extends StatelessWidget {
  const _DeleteRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Delete workout',
      pressedScale: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _sheetRowMinHeight),
        child: Row(
          spacing: _sheetGap,
          children: [
            AppIcon('trash', size: _sheetIcon, color: c.careInk),
            Expanded(
              child: Text('Delete workout', style: AppType.body.copyWith(color: c.careInk)),
            ),
          ],
        ),
      ),
    );
  }
}
