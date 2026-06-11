import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../controllers/workout_detail_controller.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

const _white = Color(0xFFFFFFFF);

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

/// Screen 12 — Workout Detail (past session).
///
/// Read-only breakdown of one finished [Workout]: a 2×2 summary grid
/// (Duration / Volume / Sets / PRs), an 8-week volume bar chart (fl_chart), a
/// per-exercise set table with PR badges, and a Pal post-workout note card.
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

    return async.when(
      loading: () => Center(
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load this session.",
              textAlign: TextAlign.center,
              style:
                  AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (state) => _Body(workoutId: workoutId, state: state),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.workoutId, required this.state});
  final String workoutId;
  final WorkoutDetailState state;

  String get _dateLabel {
    final d = state.workout.startedAt;
    return '${_monthAbbr[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = state.workout;
    final minutes = w.duration?.inMinutes ?? 0;
    final reps = w.sets.where((s) => s.done).fold<int>(0, (s, x) => s + x.reps);

    return LargeTitleScrollView(
      title: w.name,
      subtitle: _dateLabel,
      leading: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.pop(),
        child: AppIcon('chevron.left', size: 20, color: c.accent),
      ),
      trailing: const NavIconButton(name: 'ellipsis', semanticLabel: 'More options'),
      padding: const EdgeInsets.only(bottom: 48),
      children: [
        // --- 2×2 summary grid -------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      type: 'move',
                      icon: 'clock.fill',
                      label: 'Duration',
                      value: '$minutes',
                      unit: 'min',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryTile(
                      type: '',
                      icon: 'chart.bar.fill',
                      label: 'Volume',
                      value: (w.totalVolumeKg / 1000).toStringAsFixed(1),
                      unit: 'tonnes',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      type: 'rituals',
                      icon: 'list.number',
                      label: 'Sets',
                      value: '${w.completedSetCount}',
                      unit: '$reps reps',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryTile(
                      type: 'money',
                      icon: 'star.fill',
                      label: 'PRs',
                      value: '${w.prCount}',
                      unit: 'new best',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- 8-week volume bar chart -----------------------------------------
        const _SectionHeader('Volume over 8 weeks'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(14)),
            child: _VolumeChart(weeks: state.weeklyVolume),
          ),
        ),

        // --- Per-exercise set tables -----------------------------------------
        _SectionHeader('Exercises · ${state.exercises.length}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Container(
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < state.exercises.length; i++)
                  _ExerciseBlock(
                    group: state.exercises[i],
                    last: i == state.exercises.length - 1,
                  ),
              ],
            ),
          ),
        ),

        // --- Pal's note ------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _PalNote(workoutId: workoutId),
        ),

        // --- Delete ----------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _DeleteButton(workoutId: workoutId),
        ),
      ],
    );
  }
}

/// Red destructive "Delete routine" text button. Removes this session via the
/// repository the screen already consumes, then pops back.
class _DeleteButton extends ConsumerWidget {
  const _DeleteButton({required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return PressScale(
      onTap: () async {
        await ref.read(workoutRepositoryProvider).deleteById(workoutId);
        if (context.mounted) context.pop();
      },
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Text('Delete routine',
            style: AppFonts.sf(
                size: 15,
                weight: FontWeight.w500,
                color: c.red,
                letterSpacing: -0.24)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(text.toUpperCase(),
          style: AppFonts.sf(
              size: 13, color: c.ink3, letterSpacing: -0.08)),
    );
  }
}

/// One summary tile: tinted icon chip + label / big value + unit.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.type,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String type; // 'move' | 'rituals' | 'money' | '' (accent)
  final String icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(type);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: AppIcon(icon, size: 10, color: color),
              ),
              const SizedBox(width: 6),
              Text(label.toUpperCase(),
                  style: AppFonts.sf(
                      size: 10,
                      weight: FontWeight.w700,
                      color: c.ink3,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: AppFonts.sfr(
                      size: 26, weight: FontWeight.w700, color: color, letterSpacing: -0.5)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sf(
                        size: 11, color: c.ink3, letterSpacing: -0.08)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 8-week weekly-volume bars (fl_chart), with a "total" headline. The latest
/// week is the accent-strong bar; earlier weeks are tinted.
class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.weeks});
  final List<WeekVolume> weeks;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final totalT =
        weeks.fold<double>(0, (s, w) => s + w.volumeKg) / 1000;
    final maxKg = weeks.fold<double>(0, (m, w) => w.volumeKg > m ? w.volumeKg : m);
    final maxY = maxKg <= 0 ? 1.0 : maxKg;
    final latestT = weeks.isEmpty ? 0.0 : weeks.last.volumeKg / 1000;
    final trend = _trendPct(weeks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(totalT.toStringAsFixed(1),
                style: AppFonts.sfr(
                    size: 26, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.5)),
            const SizedBox(width: 4),
            Text('t total',
                style: AppFonts.sf(
                    size: 13,
                    weight: FontWeight.w500,
                    color: c.ink3,
                    letterSpacing: -0.08)),
            const Spacer(),
            if (trend != null) _TrendPill(pct: trend),
          ],
        ),
        const SizedBox(height: 14),
        // value label sits above the latest (highlighted) bar, which spaceBetween
        // pins to the right edge.
        if (weeks.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: c.move.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${latestT.toStringAsFixed(1)}t',
                    style: AppFonts.sfr(
                        size: 10,
                        weight: FontWeight.w700,
                        color: c.move,
                        letterSpacing: -0.08)),
              ),
            ),
          ),
        SizedBox(
          height: 120,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceBetween,
              barTouchData: BarTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      final isLast = i == weeks.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('W${i + 1}',
                            style: AppFonts.sf(
                                size: 9,
                                weight:
                                    isLast ? FontWeight.w700 : FontWeight.w500,
                                color: isLast ? c.move : c.ink3,
                                letterSpacing: 0.3)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < weeks.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: weeks[i].volumeKg,
                        width: 14,
                        color: i == weeks.length - 1
                            ? c.move
                            : c.move.withValues(alpha: 0.27),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                          bottom: Radius.circular(3),
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

/// Percent change of the recent half vs the prior half of the 8-week window.
/// Null when there's no prior baseline to compare against (avoids /0 and a
/// meaningless "+0%").
int? _trendPct(List<WeekVolume> weeks) {
  if (weeks.length < 2) return null;
  final half = weeks.length ~/ 2;
  final prior = weeks.take(half).fold<double>(0, (s, w) => s + w.volumeKg);
  final recent = weeks.skip(half).fold<double>(0, (s, w) => s + w.volumeKg);
  if (prior <= 0) return null;
  return (((recent - prior) / prior) * 100).round();
}

/// The "+15% in 4 wks" volume-trend pill next to the chart headline. Green for
/// gains (or flat), red for a drop, with a matching directional arrow.
class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.pct});
  final int pct;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final up = pct >= 0;
    final color = up ? c.move : c.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // only arrow.up.right is mapped in app_icon; rotate it for the drop case.
          Transform.rotate(
            angle: up ? 0 : 1.5707963267948966,
            child: AppIcon('arrow.up.right', size: 10, color: color),
          ),
          const SizedBox(width: 4),
          Text('${up ? '+' : ''}$pct% in 4 wks',
              style: AppFonts.sf(
                  size: 11,
                  weight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.08)),
        ],
      ),
    );
  }
}

/// One exercise's header (name + set count × volume) and its set table.
class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({required this.group, required this.last});
  final ExerciseSets group;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vol = group.sets
        .fold<double>(0, (s, x) => s + x.weightKg * x.reps)
        .round();
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(group.name,
                    style: AppFonts.sf(
                        size: 16,
                        weight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.3)),
              ),
              Text('${group.sets.length} × ${vol}kg',
                  style: AppFonts.sfr(
                      size: 12,
                      weight: FontWeight.w400,
                      color: c.ink3,
                      letterSpacing: -0.08)),
            ],
          ),
          const SizedBox(height: 10),
          _SetVolumeSparkline(sets: group.sets),
          const SizedBox(height: 10),
          _SetTableHeader(),
          for (var i = 0; i < group.sets.length; i++)
            _SetRow(
              index: i,
              set: group.sets[i],
              last: i == group.sets.length - 1,
            ),
        ],
      ),
    );
  }
}

/// Per-set volume sparkline: one bar per set sized by its volume (weightKg ×
/// reps), with the top set's volume labeled. The highlighted bar is the
/// heaviest set; bodyweight-only sets (zero weight) fall back to rep count so
/// the bar isn't invisible.
class _SetVolumeSparkline extends StatelessWidget {
  const _SetVolumeSparkline({required this.sets});
  final List<SetLog> sets;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vols = [
      for (final s in sets)
        s.weightKg > 0 ? s.weightKg * s.reps : s.reps.toDouble(),
    ];
    final maxVol = vols.fold<double>(0, (m, v) => v > m ? v : m);
    if (maxVol <= 0) return const SizedBox.shrink();
    final topIdx = vols.indexOf(maxVol);
    final topSet = sets[topIdx];
    final topLabel = topSet.weightKg > 0
        ? '${(topSet.weightKg * topSet.reps).round()}kg'
        : '${topSet.reps} reps';

    return SizedBox(
      height: 46,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 14,
            child: Align(
              alignment: Alignment(_labelX(topIdx, sets.length), 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: c.move.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(topLabel,
                    style: AppFonts.sfr(
                        size: 9,
                        weight: FontWeight.w700,
                        color: c.move,
                        letterSpacing: -0.08)),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < vols.length; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: (vols[i] / maxVol).clamp(0.08, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: i == topIdx
                              ? c.move
                              : c.move.withValues(alpha: 0.27),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                            bottom: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // aligns the value label horizontally over the i-th of n equal-width bars,
  // mapping the bar's center to Alignment's [-1, 1] x axis.
  double _labelX(int i, int n) {
    if (n <= 1) return 0;
    return (i + 0.5) / n * 2 - 1;
  }
}

class _SetTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget cell(String t, {int flex = 1, double width = 0}) {
      final style = AppFonts.sf(
          size: 10, weight: FontWeight.w700, color: c.ink3, letterSpacing: 0.5);
      final text = Text(t, style: style);
      return width > 0
          ? SizedBox(width: width, child: text)
          : Expanded(flex: flex, child: text);
    }

    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.hair, width: 0.5))),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          cell('SET', width: 32),
          cell('KG'),
          cell('REPS'),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.index, required this.set, required this.last});
  final int index;
  final SetLog set;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final weight = set.weightKg;
    final reps = set.reps;
    final isPR = set.isPR;
    final weightLabel =
        weight == weight.roundToDouble() ? '${weight.round()}' : '$weight';
    final num = AppFonts.sfr(
        size: 15, weight: FontWeight.w600, color: c.ink, letterSpacing: -0.1);
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                    color: c.hair.withValues(alpha: 0.5), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('${index + 1}',
                style: AppFonts.sfr(
                    size: 13, weight: FontWeight.w600, color: c.ink3)),
          ),
          Expanded(child: Text(weightLabel, style: num)),
          Expanded(child: Text('$reps', style: num)),
          SizedBox(
            width: 40,
            child: isPR ? const _PrTag() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PrTag extends StatelessWidget {
  const _PrTag();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration:
            BoxDecoration(color: c.money, borderRadius: BorderRadius.circular(5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon('star.fill', size: 8, color: _white),
            const SizedBox(width: 3),
            Text('PR',
                style: AppFonts.sf(
                    size: 9,
                    weight: FontWeight.w700,
                    color: _white,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

/// Pal post-workout note card with a loading→text state.
class _PalNote extends ConsumerWidget {
  const _PalNote({required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final note = ref.watch(workoutNoteProvider(workoutId));
    final loading = note.isLoading;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.accentTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.accent.withValues(alpha: 0.13), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon('sparkles', size: 12, color: c.accent),
              const SizedBox(width: 6),
              Text("PAL'S NOTE",
                  style: AppFonts.sf(
                      size: 11,
                      weight: FontWeight.w700,
                      color: c.accent,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note.when(
              loading: () => 'Pal is reading your session…',
              error: (_, _) => "Pal couldn't write a note just now.",
              data: (text) => text,
            ),
            style: AppFonts.sf(
                size: 14,
                color: loading ? c.ink3 : c.ink,
                letterSpacing: -0.2,
                height: 1.45),
          ),
        ],
      ),
    );
  }
}
