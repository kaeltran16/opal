import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/move_controller.dart' show relativeDateLabel;
import '../../controllers/workout_history_controller.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/nav_bar.dart';

/// Workout — History & Trends. The all-time, all-sessions view of training
/// progress, opened from the Move screen's "History & trends" row. A range
/// control (8 weeks / 6 months / All time) rescales the whole page; everything
/// is derived in [workoutHistoryProvider], so this widget only lays out.
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
      title: 'History & trends',
      subtitle: 'All sessions, all time',
      leading: NavAction(
        icon: 'chevron.left',
        label: 'Move',
        onTap: () => context.pop(),
        semanticLabel: 'Back',
      ),
      trailing: const NavIconButton(
        name: 'square.and.arrow.up',
        semanticLabel: 'Share',
      ),
      padding: const EdgeInsets.only(bottom: 48),
      children: [
        // Range control — always available, even while the data loads.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.xs, Spacing.lg, Spacing.md),
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
    return [
      // Headline.
      Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, 0, Spacing.lg, Spacing.lg),
        child: Text(s.headline,
            style: AppType.subhead
                .copyWith(color: c.ink2, letterSpacing: -0.1, height: 1.45)),
      ),

      // Summary tiles (2×2).
      Padding(
        padding:
            const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
        child: _SummaryGrid(summary: s.summary),
      ),

      // Volume trend.
      _Card(child: _VolumeTrend(state: s)),

      // Weekly balance.
      if (s.balance.isNotEmpty)
        _Card(child: _Balance(slices: s.balance, nudge: s.balanceNudge)),

      // Personal records.
      if (s.prs.isNotEmpty) ...[
        _Header('Personal records · ${s.prs.length}', icon: 'star.fill'),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
          child: Container(
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < s.prs.length; i++)
                  _PrRow(pr: s.prs[i], last: i == s.prs.length - 1),
              ],
            ),
          ),
        ),
      ],

      // All sessions.
      if (s.sessions.isNotEmpty) ...[
        _Header('All sessions · ${s.sessions.length}'),
        for (final row in s.sessions)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, 0, Spacing.lg, Spacing.sm),
            child: _SessionCard(row: row),
          ),
      ],
    ];
  }
}

// ─── Section scaffolding ─────────────────────────────────────────────────────

/// A surface-card wrapper with the page's standard horizontal inset.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.icon});
  final String text;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.xs, Spacing.xl, Spacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 11, color: c.money),
            const SizedBox(width: Spacing.xs),
          ],
          Text(text.toUpperCase(),
              style: AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.08)),
        ],
      ),
    );
  }
}

// ─── Summary tiles ───────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final HistorySummary summary;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _TileData('Volume', (summary.volumeKg / 1000).toStringAsFixed(1), 't',
          'move', 'chart.bar.fill'),
      _TileData('Sessions', '${summary.sessionCount}', 'workouts', 'accent',
          'figure.run'),
      _TileData('Time', _hm(summary.totalMinutes), 'h:m', 'rituals', 'timer'),
      _TileData('PRs', '${summary.prCount}', 'new bests', 'money', 'star.fill'),
    ];
    return Column(
      children: [
        Row(children: [
          Expanded(child: _SummaryTile(data: tiles[0])),
          const SizedBox(width: Spacing.sm),
          Expanded(child: _SummaryTile(data: tiles[1])),
        ]),
        const SizedBox(height: Spacing.sm),
        Row(children: [
          Expanded(child: _SummaryTile(data: tiles[2])),
          const SizedBox(width: Spacing.sm),
          Expanded(child: _SummaryTile(data: tiles[3])),
        ]),
      ],
    );
  }
}

class _TileData {
  const _TileData(this.label, this.value, this.unit, this.token, this.icon);
  final String label, value, unit, token, icon;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.data});
  final _TileData data;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(data.token);
    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 13, Spacing.lg, 13),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
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
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                alignment: Alignment.center,
                child: AppIcon(data.icon, size: 10, color: color),
              ),
              const SizedBox(width: Spacing.sm),
              Text(data.label.toUpperCase(),
                  style: AppType.caption2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.ink3,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(data.value,
                  style: AppFonts.sfr(
                      size: 26,
                      weight: FontWeight.w700,
                      color: color,
                      letterSpacing: -0.5)),
              const SizedBox(width: Spacing.xs),
              Flexible(
                child: Text(data.unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption2
                        .copyWith(color: c.ink3, letterSpacing: -0.08)),
              ),
            ],
          ),
        ],
      ),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Volume trend',
                    style: AppType.subhead.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.2)),
                const SizedBox(height: Spacing.xxs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(totalT.toStringAsFixed(1),
                        style: AppFonts.sfr(
                            size: 22,
                            weight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.4)),
                    const SizedBox(width: Spacing.xs),
                    Text('t total',
                        style: AppType.footnote.copyWith(
                            fontWeight: FontWeight.w500, color: c.ink3)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            if (pct != null) _TrendPill(pct: pct),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        SizedBox(
          height: 116,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) const SizedBox(width: Spacing.xs),
                Expanded(child: _Bar(bar: bars[i], maxY: maxY, last: i == bars.length - 1)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.bar, required this.maxY, required this.last});
  final HistoryBar bar;
  final double maxY;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Reserve the value-label slot on every bar so heights stay comparable;
        // only the latest (highlighted) bar shows its figure.
        SizedBox(
          height: 16,
          child: last
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xs, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.move.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.xs),
                  ),
                  child: Text('${(bar.volumeKg / 1000).toStringAsFixed(1)}t',
                      style: AppFonts.sfr(
                          size: 9,
                          weight: FontWeight.w700,
                          color: c.move,
                          letterSpacing: -0.08)),
                )
              : null,
        ),
        const SizedBox(height: Spacing.xs),
        Expanded(
          child: FractionallySizedBox(
            heightFactor: (bar.volumeKg / maxY).clamp(0.04, 1.0),
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: last ? c.move : c.move.withValues(alpha: 0.27),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                  bottom: Radius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(bar.label,
            style: AppType.caption2.copyWith(
                fontWeight: last ? FontWeight.w700 : FontWeight.w500,
                color: last ? c.move : c.ink3,
                letterSpacing: 0.3)),
      ],
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.pct});
  final int pct;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final up = pct >= 0;
    final color = up ? c.move : c.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: up ? 0 : 1.5707963267948966,
            child: AppIcon('arrow.up.right', size: 10, color: color),
          ),
          const SizedBox(width: Spacing.xs),
          Text('${up ? '+' : ''}$pct%',
              style: AppType.caption2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.08)),
        ],
      ),
    );
  }
}

// ─── Weekly balance ──────────────────────────────────────────────────────────

class _Balance extends StatelessWidget {
  const _Balance({required this.slices, required this.nudge});
  final List<HistoryGroupSlice> slices;
  final String nudge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly balance',
            style: AppType.subhead.copyWith(
                fontWeight: FontWeight.w700, color: c.ink, letterSpacing: -0.2)),
        const SizedBox(height: Spacing.md),
        // Stacked bar.
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (var i = 0; i < slices.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: slices[i].pct,
                    child: ColoredBox(color: c.forType(slices[i].colorToken)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        // Legend (2 columns).
        Wrap(
          runSpacing: Spacing.sm,
          children: [
            for (final s in slices)
              SizedBox(
                width: (MediaQuery.of(context).size.width - 2 * Spacing.lg - 2 * Spacing.lg) / 2,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.forType(s.colorToken),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(s.label,
                        style: AppType.footnote
                            .copyWith(color: c.ink2, letterSpacing: -0.08)),
                    const Spacer(),
                    Text('${s.pct}%',
                        style: AppFonts.sfr(
                            size: 13,
                            weight: FontWeight.w600,
                            color: c.ink,
                            letterSpacing: -0.08)),
                    const SizedBox(width: Spacing.md),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        // Pal nudge.
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: c.accentTint,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.accent.withValues(alpha: 0.13), width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: AppIcon('sparkles', size: 11, color: c.onAccent),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PAL',
                        style: AppType.caption2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.accent,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(nudge,
                        style: AppType.footnote.copyWith(
                            color: c.ink, letterSpacing: -0.1, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Personal record row ─────────────────────────────────────────────────────

class _PrRow extends StatelessWidget {
  const _PrRow({required this.pr, required this.last});
  final HistoryPr pr;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(pr.colorToken);
    final delta = _deltaLabel(pr);
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            alignment: Alignment.center,
            child: AppIcon(pr.bodyweight ? 'figure.run' : 'dumbbell.fill',
                size: 16, color: color),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pr.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead.copyWith(
                        fontWeight: FontWeight.w600, color: c.ink)),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Text(pr.group, style: _meta(c)),
                    if (delta != null) ...[
                      _dot(c),
                      Text(delta,
                          style: _meta(c).copyWith(
                              color: c.move, fontWeight: FontWeight.w600)),
                    ],
                    _dot(c),
                    Flexible(
                      child: Text(relativeDateLabel(pr.achievedAt, DateTime.now()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _meta(c)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text.rich(
            TextSpan(
              text: pr.bodyweight ? '${pr.reps}' : _kg(pr.weightKg),
              style: AppFonts.sfr(
                  size: 17,
                  weight: FontWeight.w700,
                  color: c.ink,
                  letterSpacing: -0.2),
              children: [
                TextSpan(
                  text: pr.bodyweight ? ' reps' : 'kg',
                  style: AppType.caption2
                      .copyWith(color: c.ink3, letterSpacing: -0.08),
                ),
                if (!pr.bodyweight)
                  TextSpan(
                    text: ' × ${pr.reps}',
                    style: AppType.caption2
                        .copyWith(color: c.ink4, letterSpacing: -0.08),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _meta(AppColors c) =>
      AppType.caption2.copyWith(color: c.ink3, letterSpacing: -0.08);

  Widget _dot(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        child: Text('·', style: AppType.caption2.copyWith(color: c.ink4)),
      );
}

// ─── Session card ────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.row});
  final HistorySessionRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(row.colorToken);
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.workoutDetail.name,
          pathParameters: {'id': row.workoutId}),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: ColoredBox(
          color: c.surface,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(Radii.sm),
                              ),
                              alignment: Alignment.center,
                              child: AppIcon(
                                  row.isCardio ? 'figure.run' : 'dumbbell.fill',
                                  size: 16,
                                  color: color),
                            ),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.subhead.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: c.ink,
                                          letterSpacing: -0.24)),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text(
                                        relativeDateLabel(
                                            row.startedAt, DateTime.now()),
                                        style: AppType.caption2.copyWith(
                                            color: c.ink3, letterSpacing: -0.08)),
                                  ),
                                ],
                              ),
                            ),
                            if (row.prCount > 0) _PrBadge(count: row.prCount),
                          ],
                        ),
                        const SizedBox(height: Spacing.sm),
                        Padding(
                          padding: const EdgeInsets.only(left: 42),
                          child: Row(
                            children: [
                              _Stat(value: '${row.minutes}', label: 'min'),
                              if (!row.isCardio && row.volumeKg > 0) ...[
                                _divider(c),
                                _Stat(
                                    value:
                                        '${(row.volumeKg / 1000).toStringAsFixed(1)}t',
                                    label: 'volume'),
                              ] else if (row.isCardio) ...[
                                _divider(c),
                                _Stat(value: 'Cardio', label: ''),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(AppColors c) => Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        color: c.hair,
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value,
            style: AppFonts.sfr(
                size: 14,
                weight: FontWeight.w700,
                color: c.ink,
                letterSpacing: -0.2)),
        if (label.isNotEmpty) ...[
          const SizedBox(width: Spacing.xs),
          Text(label,
              style:
                  AppType.caption2.copyWith(color: c.ink3, letterSpacing: -0.08)),
        ],
      ],
    );
  }
}

class _PrBadge extends StatelessWidget {
  const _PrBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 3),
      decoration: BoxDecoration(
          color: c.money, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('star.fill', size: 8, color: c.onAccent),
          const SizedBox(width: Spacing.xs),
          Text('$count PR',
              style: AppType.caption2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.onAccent,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

// ─── Formatting helpers ──────────────────────────────────────────────────────

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

/// "+5 kg" / "+1 rep" gain over the previous best, or null when there's none.
String? _deltaLabel(HistoryPr pr) {
  if (pr.bodyweight) {
    final d = pr.deltaReps;
    return d == null ? null : '+$d ${d == 1 ? 'rep' : 'reps'}';
  }
  final d = pr.deltaKg;
  return d == null ? null : '+${_kg(d)} kg';
}
