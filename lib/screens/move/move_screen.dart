import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/move_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/start_workout_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../shell/tab_header.dart';

/// Screen 07 — Move landing, on live data.
///
/// Reads the computed [MoveState] from `moveStateProvider` (today's health
/// summary + recent workouts + non-workout movement) and renders the gradient
/// "This week" hero, the Start-workout CTA, the quick-links section, the recent
/// sessions, and the other-activity list. All derivation lives in the
/// controller; this widget only lays out.
class MoveScreen extends ConsumerWidget {
  const MoveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(moveStateProvider);
    final exerciseCount = ref.watch(exercisesProvider).asData?.value.length;

    return async.when(
      loading: () => Center(
        child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text("Couldn't load Workout.\n$e",
              textAlign: TextAlign.center,
              style: AppType.subhead
                  .copyWith(color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (state) => _MoveBody(state: state, exerciseCount: exerciseCount),
    );
  }
}

class _MoveBody extends StatelessWidget {
  const _MoveBody({required this.state, required this.exerciseCount});
  final MoveState state;
  final int? exerciseCount;

  @override
  Widget build(BuildContext context) {
    return TabHeaderScrollView(
      title: 'Workout',
      subtitle: state.weekGoal == 0
          ? 'No weekly plan yet'
          : '${state.weekWorkouts} of ${state.weekGoal} workouts this week',
      contextualAction: NavIconButton(
        name: 'plus',
        semanticLabel: 'New routine',
        onTap: () => context.pushNamed(AppRoute.routineEditor.name),
      ),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xl),
          child: _WeekHero(state: state),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: const _StartCta(),
        ),
        _QuickLinks(
          routineCount: state.routineCount,
          exerciseCount: exerciseCount,
        ),
        if (state.recentSessions.isNotEmpty)
          _RecentSessions(sessions: state.recentSessions),
        if (state.otherActivity.isNotEmpty)
          _OtherActivity(entries: state.otherActivity),
      ],
    );
  }
}

/// Move-gradient "This week" hero: workouts-vs-goal headline + mini progress
/// ring, a 7-day calendar strip, and a Volume / Time / Records stat row.
class _WeekHero extends StatelessWidget {
  const _WeekHero({required this.state});
  final MoveState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = (state.weekProgress * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(
          // 155° move → move·ee → accent·dd, matching the design hero.
          begin: const Alignment(-0.7, -1),
          end: const Alignment(0.7, 1),
          colors: [
            c.move,
            c.move.withValues(alpha: 0.93),
            c.accent.withValues(alpha: 0.87),
          ],
          stops: const [0, 0.6, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: c.move.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Stack(
          children: [
            // soft radial light blob, top-right.
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 180, // decorative blob
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.onAccent.withValues(alpha: 0.08),
                ),
              ),
            ),
            // diagonal hairline hatch overlay.
            Positioned.fill(
                child: CustomPaint(painter: _HatchPainter(c.onAccent))),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THIS WEEK',
                              style: AppType.caption2.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: c.onAccent.withValues(alpha: 0.82),
                                  letterSpacing: 1.2),
                            ),
                            const SizedBox(height: Spacing.sm),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${state.weekWorkouts}',
                                  style: AppType.amountLg.copyWith(
                                      color: c.onAccent,
                                      letterSpacing: -1.2,
                                      height: 0.95),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Text(
                                  '/ ${state.weekGoal} workouts',
                                  style: AppType.subhead.copyWith(
                                      color: c.onAccent.withValues(alpha: 0.82),
                                      letterSpacing: -0.1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _MiniRing(progress: state.weekProgress, percent: pct),
                    ],
                  ),
                  const SizedBox(height: Spacing.lg),
                  _WeekStrip(days: state.weekDays, move: c.move),
                  const SizedBox(height: Spacing.lg),
                  Container(
                    margin: const EdgeInsets.only(top: 0),
                    padding: const EdgeInsets.only(top: Spacing.lg),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: c.onAccent.withValues(alpha: 0.2),
                            width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        _HeroStat(
                          value:
                              '${(state.weekVolumeKg / 1000).toStringAsFixed(1)}t',
                          label: 'Volume',
                        ),
                        _heroDivider(c.onAccent),
                        _HeroStat(
                          value: '${state.weekMinutes}',
                          unit: 'm',
                          label: 'Time',
                        ),
                        _heroDivider(c.onAccent),
                        _HeroStat(
                          value: '${state.weekPrCount} PR',
                          label: 'Records',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroDivider(Color color) => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        color: color.withValues(alpha: 0.2),
      );
}

/// 56px progress ring with a centered "%" label (private to the hero — the
/// shared ActivityRings widget is intentionally untouched).
class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.progress, required this.percent});
  final double progress;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final onAccent = context.colors.onAccent;
    return SizedBox(
      width: 56, // fixed ring size
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(56, 56),
            painter: _RingPainter(progress: progress, color: onAccent),
          ),
          Text(
            '$percent%',
            style: AppFonts.sfr(
                size: 14,
                weight: FontWeight.w700,
                color: onAccent,
                letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.22);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Diagonal hairline hatch overlay (~125° from horizontal, 25px spacing),
/// matching the design hero's `repeating-linear-gradient` decoration.
class _HatchPainter extends CustomPainter {
  _HatchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const spacing = 25.0;
    final extent = size.width + size.height;
    for (var d = -size.height; d < extent; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height * 1.43, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

/// 7-day Mon→Sun strip: filled white + checkmark when done, dashed border for
/// today (private to the hero).
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days, required this.move});
  final List<WeekDay> days;
  final Color move;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i != 0) const SizedBox(width: Spacing.xs),
          Expanded(child: _DayCell(day: days[i], move: move)),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.move});
  final WeekDay day;
  final Color move;

  @override
  Widget build(BuildContext context) {
    final onAccent = context.colors.onAccent;
    final bg = day.done
        ? onAccent
        : day.today
            ? onAccent.withValues(alpha: 0.25)
            : onAccent.withValues(alpha: 0.1);
    final dashed = day.today && !day.done;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: dashed
                  ? Border.all(
                      color: onAccent.withValues(alpha: 0.7), width: 1.5)
                  : null,
            ),
            child: day.done
                ? Center(child: AppIcon('checkmark', size: 13, color: move))
                : null,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          day.letter,
          style: AppType.caption2.copyWith(
              fontWeight: FontWeight.w700,
              color: onAccent.withValues(alpha: day.today ? 1 : 0.75),
              letterSpacing: 0.3),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, this.unit, required this.label});
  final String value;
  final String? unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onAccent = context.colors.onAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            style: AppFonts.sfr(
                size: 18,
                weight: FontWeight.w700,
                color: onAccent,
                letterSpacing: -0.3,
                height: 1),
            children: unit == null
                ? null
                : [
                    TextSpan(
                      text: unit,
                      style: AppType.caption2
                          .copyWith(color: onAccent.withValues(alpha: 0.75)),
                    ),
                  ],
          ),
        ),
        const SizedBox(height: Spacing.xxs),
        Text(
          label.toUpperCase(),
          style: AppType.caption2.copyWith(
              fontWeight: FontWeight.w600,
              color: onAccent.withValues(alpha: 0.75),
              letterSpacing: 0.5),
        ),
      ],
    );
  }
}

/// "Start workout" CTA: move-tinted play circle + Pal eyebrow + routine + pill.
/// Reads the same [palPickControllerProvider] the Start Workout screen uses, so
/// the pick shown here can't diverge from the one on the picker.
class _StartCta extends ConsumerWidget {
  const _StartCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(palPickControllerProvider);
    final suggestion = async.asData?.value;
    final routineName = async.isLoading && suggestion == null
        ? 'Thinking…'
        : suggestion?.title ?? 'Freestyle session';
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.startWorkout.name),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.lg, Spacing.lg, Spacing.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52, // fixed play circle
              height: 52,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.4),
                  radius: 0.9,
                  colors: [c.move, c.move.withValues(alpha: 0.8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  // move-tinted glow, kept inline (not neutral elevation)
                  BoxShadow(
                    color: c.move.withValues(alpha: 0.33),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: AppIcon('play.fill', size: 20, color: c.onAccent),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "● PAL'S PICK FOR TODAY",
                    style: AppType.caption2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.move,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    routineName,
                    style: AppFonts.sfr(
                        size: 18,
                        weight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.md),
              decoration: BoxDecoration(
                  color: c.move, borderRadius: BorderRadius.circular(Radii.pill)),
              child: Text(
                'Start',
                style: AppType.footnote.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.onAccent,
                    letterSpacing: -0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick-links inset section, design order: Weekly plan → My routines →
/// Exercise library → History & trends.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.routineCount, required this.exerciseCount});
  final int routineCount;
  final int? exerciseCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InsetSection(
      children: [
        ListRow(
          icon: 'calendar',
          iconBg: c.move,
          title: 'Weekly plan',
          onTap: () => context.pushNamed(AppRoute.weeklyPlan.name),
        ),
        ListRow(
          icon: 'books.vertical.fill',
          iconBg: c.move,
          title: 'My routines',
          value: '$routineCount',
          onTap: () => context.pushNamed(AppRoute.startWorkout.name),
        ),
        ListRow(
          icon: 'sparkles',
          iconBg: c.rituals,
          title: 'Generate with AI',
          onTap: () => context.pushNamed(AppRoute.routineGenerator.name),
        ),
        ListRow(
          icon: 'dumbbell.fill',
          iconBg: c.accent,
          title: 'Exercise library',
          value: exerciseCount == null ? null : '$exerciseCount',
          onTap: () => context.pushNamed(AppRoute.exerciseLibrary.name),
        ),
        ListRow(
          icon: 'chart.bar.fill',
          iconBg: c.rituals,
          title: 'History & trends',
          value: 'All time',
          last: true,
          // Same destination as the profile "All stats" row.
          onTap: () => context.pushNamed(AppRoute.recap.name,
              queryParameters: const {'range': 'week'}),
        ),
      ],
    );
  }
}

/// "RECENT SESSIONS" header + "See all", then up to 3 decorated session cards.
class _RecentSessions extends StatelessWidget {
  const _RecentSessions({required this.sessions});
  final List<RecentSession> sessions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xs, Spacing.md, Spacing.xs, Spacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT SESSIONS',
                  style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.ink3,
                      letterSpacing: 0.8),
                ),
                GestureDetector(
                  // No history-list screen yet (not a v1 unit); jump to the
                  // most recent session's detail when there is one.
                  onTap: sessions.isEmpty
                      ? null
                      : () => context.pushNamed(AppRoute.workoutDetail.name,
                          pathParameters: {'id': sessions.first.workout.id}),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Latest',
                    style: AppType.footnote.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                        letterSpacing: -0.08),
                  ),
                ),
              ],
            ),
          ),
          for (final s in sessions) ...[
            _SessionCard(session: s),
            const SizedBox(height: Spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final RecentSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = session.isCardio ? c.accent : c.move;
    final w = session.workout;
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.workoutDetail.name,
          pathParameters: {'id': w.id}),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: ColoredBox(
          color: c.surface,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color), // accent rail
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
                              width: 32, // fixed icon tile
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(Radii.sm),
                              ),
                              alignment: Alignment.center,
                              child: AppIcon(
                                  session.isCardio
                                      ? 'figure.run'
                                      : 'dumbbell.fill',
                                  size: 16,
                                  color: color),
                            ),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.subhead.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: c.ink,
                                        letterSpacing: -0.24),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text(
                                      session.relativeDate,
                                      style: AppType.caption2.copyWith(
                                          color: c.ink3,
                                          letterSpacing: -0.08),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (w.prCount > 0) _PrBadge(count: w.prCount),
                          ],
                        ),
                        const SizedBox(height: Spacing.sm),
                        Padding(
                          padding: const EdgeInsets.only(left: 42), // align under title
                          child: Row(
                            children: [
                              _StatChip(
                                  value: '${session.durationMinutes}',
                                  label: 'min'),
                              if (session.volumeTonnes > 0) ...[
                                Container(
                                  width: 1,
                                  height: 14, // fixed divider height
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: Spacing.lg),
                                  color: c.hair,
                                ),
                                _StatChip(
                                  value:
                                      '${session.volumeTonnes.toStringAsFixed(1)}t',
                                  label: 'volume',
                                ),
                              ],
                              const Spacer(),
                              _VolumeSparkline(
                                  bars: _sparkBars(w.sets), color: color),
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
}

/// Derives 6 normalised (0–1) sparkline bars from a session's completed sets by
/// bucketing their per-set volume into 6 equal slices. When there is no volume
/// data (e.g. cardio), falls back to the design's decorative ramp.
List<double> _sparkBars(List<SetLog> sets) {
  const buckets = 6;
  final done = sets.where((s) => s.done).toList();
  final vols = [for (final s in done) s.volumeKg];
  final total = vols.fold<double>(0, (a, b) => a + b);
  if (vols.isEmpty || total <= 0) {
    return const [0.375, 0.625, 0.5, 0.75, 1, 0.875]; // design ramp [3,5,4,6,8,7]/8
  }
  final agg = List<double>.filled(buckets, 0);
  for (var i = 0; i < vols.length; i++) {
    agg[(i * buckets) ~/ vols.length] += vols[i];
  }
  final max = agg.reduce(math.max);
  if (max <= 0) return List<double>.filled(buckets, 0.15);
  return [for (final v in agg) (v / max).clamp(0.15, 1.0)];
}

/// 6-bar mini volume sparkline, right-aligned in the session-card stat row
/// (design tab-landings.jsx L317-324): 3px bars, 2px gap, 18px tall, increasing
/// opacity left→right.
class _VolumeSparkline extends StatelessWidget {
  const _VolumeSparkline({required this.bars, required this.color});
  final List<double> bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18, // sparkline geometry
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i != 0) const SizedBox(width: Spacing.xxs),
            Container(
              width: 3, // bar width (geometry)
              height: 18 * bars[i],
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.4 + i * 0.1),
                borderRadius: BorderRadius.circular(1), // bar corner (geometry)
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: AppFonts.sfr(
              size: 14,
              weight: FontWeight.w700,
              color: c.ink,
              letterSpacing: -0.2),
        ),
        const SizedBox(width: Spacing.xs),
        Text(
          label,
          style: AppType.caption2.copyWith(color: c.ink3, letterSpacing: -0.08),
        ),
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
          Text(
            '$count PR',
            style: AppType.caption2.copyWith(
                fontWeight: FontWeight.w700,
                color: c.onAccent,
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

/// "Other activity" — non-workout movement entries (e.g. a logged run).
class _OtherActivity extends StatelessWidget {
  const _OtherActivity({required this.entries});
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xl),
      child: InsetSection(
        header: 'Other activity',
        children: [
          for (var i = 0; i < entries.length; i++)
            ListRow(
              icon: 'figure.run',
              iconBg: c.move,
              title: entries[i].title,
              subtitle: entries[i].detail,
              chevron: false,
              last: i == entries.length - 1,
            ),
        ],
      ),
    );
  }
}
