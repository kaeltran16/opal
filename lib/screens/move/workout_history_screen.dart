import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/workout_history_controller.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart' show relativeDateLabel;
import '../../widgets/contributor_bar.dart';
import '../../widgets/controls.dart';
import '../../widgets/exercise_row.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/pal_label.dart';
import '../../widgets/session_row.dart';
import '../../widgets/stat_row.dart';
import '../shell/loop_shell.dart' show shellBottomInset;

const double _sectionGap = Spacing.xl;
const double _chartHeight = 116;
const double _barValueSlot = 16;
const double _barGap = Spacing.xs;
// the floor keeps an empty period visible as a stub on the axis.
const double _minBarShare = 0.04;
const String _emptyRange = 'No sessions in this range.';
const String _newBest = 'New best';
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Workout — History and trends. The all-time, all-sessions view of training
/// progress, opened from the Workout tab. A range control (8 weeks / 6 months
/// / All time) rescales the whole page; everything is derived in
/// [workoutHistoryProvider], so this widget only lays out.
class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  WorkoutHistoryRange _range = WorkoutHistoryRange.eightWeeks;

  static const _options = [
    (WorkoutHistoryRange.eightWeeks, '8 weeks'),
    (WorkoutHistoryRange.sixMonths, '6 months'),
    (WorkoutHistoryRange.allTime, 'All time'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(workoutHistoryProvider(_range));

    return LargeTitleScrollView(
      title: 'History and trends',
      subtitle: _subtitle(_range),
      leading: NavAction(
        icon: 'chevron.left',
        label: 'Workout',
        onTap: () => context.pop(),
        semanticLabel: 'Back',
      ),
      trailing: const NavIconButton(
        name: 'square.and.arrow.up',
        semanticLabel: 'Share',
      ),
      padding: EdgeInsets.only(bottom: shellBottomInset(context)),
      children: [
        // Range control — always available, even while the data loads.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.xs, Spacing.lg, Spacing.lg),
          child: Segmented<WorkoutHistoryRange>(
            options: _options,
            value: _range,
            onChanged: (v) => setState(() => _range = v),
          ),
        ),
        ...async.when(
          loading: () => [
            Padding(
              padding: const EdgeInsets.all(Spacing.xxl),
              child: Center(
                child: Text('…',
                    style: AppType.body.copyWith(color: c.ink3)),
              ),
            ),
          ],
          error: (e, _) => [
            Padding(
              padding: const EdgeInsets.all(Spacing.xxl),
              child: Text("Couldn't load your history.",
                  textAlign: TextAlign.center,
                  style: AppType.subhead.copyWith(color: c.ink3)),
            ),
          ],
          data: (s) => _sections(context, s),
        ),
      ],
    );
  }

  List<Widget> _sections(BuildContext context, WorkoutHistoryState s) {
    final c = context.colors;
    if (s.sessions.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Text(_emptyRange,
              style: AppType.subhead.copyWith(color: c.ink3)),
        ),
      ];
    }
    final now = clock.now();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, 0, Spacing.lg, _sectionGap),
        child: Text(s.headline,
            style: AppType.subhead.copyWith(color: c.ink2)),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, 0, Spacing.lg, _sectionGap),
        child: _Summary(summary: s.summary),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, 0, Spacing.lg, _sectionGap),
        child: _VolumeTrend(state: s),
      ),

      if (s.balance.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, 0, Spacing.lg, _sectionGap),
          child: _Balance(slices: s.balance, nudge: s.balanceNudge),
        ),

      if (s.prs.isNotEmpty)
        InsetSection(
          header: 'Personal records · ${s.prs.length}',
          children: [
            for (final (i, pr) in s.prs.indexed)
              ExerciseRow(
                first: i == 0,
                icon: pr.bodyweight ? 'figure.run' : 'dumbbell',
                name: pr.name,
                detail: _prDetail(pr, now),
                trailing: _beaten(pr)
                    ? Text(_newBest,
                        maxLines: 1,
                        style:
                            AppType.subhead.copyWith(color: c.thrivingInk))
                    : null,
              ),
          ],
        ),

      InsetSection(
        header: 'All sessions · ${s.sessions.length}',
        children: [
          for (final (i, row) in s.sessions.indexed)
            SessionRow(
              first: i == 0,
              when: relativeDateLabel(row.startedAt, now),
              title: row.name,
              detail: _sessionDetail(row),
              newBest: row.prCount > 0,
              onTap: () => context.pushNamed(AppRoute.workoutDetail.name,
                  pathParameters: {'id': row.workoutId}),
            ),
        ],
      ),
    ];
  }
}

// ─── Summary ─────────────────────────────────────────────────────────────────

/// The four headline numbers, two to a row so they hold at large text sizes.
class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final HistorySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.lg,
      children: [
        StatRow(stats: [
          Stat(
              value: (summary.volumeKg / 1000).toStringAsFixed(1),
              unit: 't',
              label: 'Volume'),
          Stat(value: '${summary.sessionCount}', label: 'Sessions'),
        ]),
        StatRow(stats: [
          Stat(value: _hm(summary.totalMinutes), unit: 'h:m', label: 'Time'),
          Stat(value: '${summary.prCount}', label: 'PRs'),
        ]),
      ],
    );
  }
}

// ─── Volume trend ────────────────────────────────────────────────────────────

class _VolumeTrend extends StatelessWidget {
  const _VolumeTrend({required this.state});
  final WorkoutHistoryState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bars = state.bars;
    final totalT = bars.fold<double>(0, (s, b) => s + b.volumeKg) / 1000;
    final maxKg = bars.fold<double>(0, (m, b) => b.volumeKg > m ? b.volumeKg : m);
    final maxY = maxKg <= 0 ? 1.0 : maxKg;
    final pct = state.trendPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Volume trend', c),
        const SizedBox(height: Spacing.xxs),
        // the total and the trend speak for the chart, as one stop
        Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${totalT.toStringAsFixed(1)} t total',
                  style: AppType.subhead
                      .copyWith(color: c.ink2, fontFeatures: _tabular)),
              if (pct != null)
                Text(_trendSentence(pct, state.range, bars.length),
                    style: AppType.subhead.copyWith(color: c.ink3)),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),
        ExcludeSemantics(
          child: SizedBox(
            height: MediaQuery.textScalerOf(context).scale(_chartHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: _barGap,
              children: [
                for (final (i, bar) in bars.indexed)
                  Expanded(
                      child: _Bar(
                          bar: bar, maxY: maxY, current: i == bars.length - 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One period's bar: the current period is `ink`, the rest `track`.
class _Bar extends StatelessWidget {
  const _Bar({required this.bar, required this.maxY, required this.current});
  final HistoryBar bar;
  final double maxY;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = AppType.caption.copyWith(
        color: current ? c.ink : c.ink3,
        fontWeight: current ? FontWeight.w600 : FontWeight.w400,
        fontFeatures: _tabular);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // every bar reserves the value slot so heights stay comparable; only
        // the current period shows its figure.
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(_barValueSlot),
          child: current
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${(bar.volumeKg / 1000).toStringAsFixed(1)}t',
                      maxLines: 1, style: label),
                )
              : null,
        ),
        const SizedBox(height: Spacing.xs),
        Expanded(
          child: FractionallySizedBox(
            heightFactor: (bar.volumeKg / maxY).clamp(_minBarShare, 1.0),
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: current ? c.ink : c.track,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Radii.xs)),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(bar.label, maxLines: 1, style: label),
        ),
      ],
    );
  }
}

// ─── Weekly balance ──────────────────────────────────────────────────────────

class _Balance extends StatelessWidget {
  const _Balance({required this.slices, required this.nudge});
  final List<HistoryGroupSlice> slices;
  final String? nudge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final line = nudge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.md,
      children: [
        _heading('Weekly balance', c),
        for (final s in slices)
          ContributorBar(
            label: s.label,
            value: '${s.pct}%',
            fraction: s.pct / 100,
          ),
        if (line != null) ...[
          const SizedBox(height: Spacing.xs),
          Semantics(
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Spacing.xs,
              children: [
                const PalLabel(),
                Text(line, style: AppType.subhead.copyWith(color: c.ink)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Formatting helpers ──────────────────────────────────────────────────────

/// A section heading as its own node: loose text folds into the nearest node
/// above, which carries the section's chart or rows with it.
Widget _heading(String text, AppColors c) => Semantics(
      container: true,
      header: true,
      child: Text(text, style: AppType.headline.copyWith(color: c.ink)),
    );

String _subtitle(WorkoutHistoryRange range) => switch (range) {
      WorkoutHistoryRange.eightWeeks => 'Sessions in the last 8 weeks',
      WorkoutHistoryRange.sixMonths => 'Sessions in the last 6 months',
      WorkoutHistoryRange.allTime => 'All sessions, all time',
    };

/// "Up 12% on the previous 4 weeks": the recent half of the bars against the
/// half before it, which is what [historyTrendPct] compares.
String _trendSentence(int pct, WorkoutHistoryRange range, int barCount) {
  final half = barCount ~/ 2;
  final unit = range == WorkoutHistoryRange.eightWeeks ? 'weeks' : 'months';
  final window = 'the previous $half $unit';
  if (pct > 0) return 'Up $pct% on $window';
  if (pct < 0) return 'Down ${-pct}% on $window';
  return 'Level with $window';
}

/// "92.5 kg × 5 · 3d ago", or "12 reps · 3d ago" for a bodyweight lift.
String _prDetail(HistoryPr pr, DateTime now) {
  final when = relativeDateLabel(pr.achievedAt, now);
  if (pr.bodyweight) return '${pr.reps} reps · $when';
  return '${_kg(pr.weightKg)} kg × ${pr.reps} · $when';
}

/// A record that beat an earlier best inside the range.
bool _beaten(HistoryPr pr) => pr.deltaKg != null || pr.deltaReps != null;

/// "45 min · 4.2 t" for a lift session, "30 min" for cardio.
String _sessionDetail(HistorySessionRow row) {
  final minutes = '${row.minutes} min';
  if (row.isCardio || row.volumeKg <= 0) return minutes;
  return '$minutes · ${(row.volumeKg / 1000).toStringAsFixed(1)} t';
}

/// Whole-hour:minute label for a duration in minutes, e.g. 1120 → "18:40".
String _hm(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}

/// Trims a trailing ".0" off a kg figure (90.0 → "90", 92.5 → "92.5").
String _kg(double kg) {
  final s = kg.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
