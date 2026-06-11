import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/move_controller.dart';
import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

const _white = Color(0xFFFFFFFF);

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
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load Workout.\n$e",
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const LargeTitleNavBar(
          title: 'Workout',
          subtitle: 'Workouts, routines & sessions',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: _WeekHero(state: state),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: _StartCta(routineName: state.suggestedRoutineName),
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
        borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // soft radial light blob, top-right.
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
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
                              style: AppFonts.sf(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: _white.withValues(alpha: 0.82),
                                  letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${state.weekWorkouts}',
                                  style: AppFonts.sfr(
                                      size: 48,
                                      weight: FontWeight.w700,
                                      color: _white,
                                      letterSpacing: -1.2,
                                      height: 0.95),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '/ ${state.weekGoal} workouts',
                                  style: AppFonts.sf(
                                      size: 15,
                                      color: _white.withValues(alpha: 0.82),
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
                  const SizedBox(height: 16),
                  _WeekStrip(days: state.weekDays, move: c.move),
                  const SizedBox(height: 14),
                  Container(
                    margin: const EdgeInsets.only(top: 0),
                    padding: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: _white.withValues(alpha: 0.2), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        _HeroStat(
                          value:
                              '${(state.weekVolumeKg / 1000).toStringAsFixed(1)}t',
                          label: 'Volume',
                        ),
                        _heroDivider,
                        _HeroStat(
                          value: '${state.weekMinutes}',
                          unit: 'm',
                          label: 'Time',
                        ),
                        _heroDivider,
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

  Widget get _heroDivider => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: _white.withValues(alpha: 0.2),
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
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(56, 56),
            painter: _RingPainter(progress: progress),
          ),
          Text(
            '$percent%',
            style: AppFonts.sfr(
                size: 14,
                weight: FontWeight.w700,
                color: _white,
                letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = _white.withValues(alpha: 0.22);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = _white;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
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
          if (i != 0) const SizedBox(width: 4),
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
    final bg = day.done
        ? _white
        : day.today
            ? _white.withValues(alpha: 0.25)
            : _white.withValues(alpha: 0.1);
    final dashed = day.today && !day.done;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: dashed
                  ? Border.all(
                      color: _white.withValues(alpha: 0.7), width: 1.5)
                  : null,
            ),
            child: day.done
                ? Center(child: AppIcon('checkmark', size: 13, color: move))
                : null,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          day.letter,
          style: AppFonts.sf(
              size: 10,
              weight: FontWeight.w700,
              color: _white.withValues(alpha: day.today ? 1 : 0.75),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            style: AppFonts.sfr(
                size: 18,
                weight: FontWeight.w700,
                color: _white,
                letterSpacing: -0.3,
                height: 1),
            children: unit == null
                ? null
                : [
                    TextSpan(
                      text: unit,
                      style: AppFonts.sf(
                          size: 11,
                          color: _white.withValues(alpha: 0.75)),
                    ),
                  ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: AppFonts.sf(
              size: 10,
              weight: FontWeight.w600,
              color: _white.withValues(alpha: 0.75),
              letterSpacing: 0.5),
        ),
      ],
    );
  }
}

/// "Start workout" CTA: move-tinted play circle + Pal eyebrow + routine + pill.
class _StartCta extends StatelessWidget {
  const _StartCta({required this.routineName});
  final String? routineName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.startWorkout.name),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.4),
                  radius: 0.9,
                  colors: [c.move, c.move.withValues(alpha: 0.8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.move.withValues(alpha: 0.33),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const AppIcon('play.fill', size: 20, color: _white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "● PAL'S PICK FOR TODAY",
                    style: AppFonts.sf(
                        size: 10,
                        weight: FontWeight.w700,
                        color: c.move,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    routineName ?? 'Freestyle session',
                    style: AppFonts.sfr(
                        size: 18,
                        weight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: c.move, borderRadius: BorderRadius.circular(100)),
              child: Text(
                'Start',
                style: AppFonts.sf(
                    size: 13,
                    weight: FontWeight.w700,
                    color: _white,
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
          chevron: false,
          last: true,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT SESSIONS',
                  style: AppFonts.sf(
                      size: 12,
                      weight: FontWeight.w700,
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
                    'See all',
                    style: AppFonts.sf(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.accent,
                        letterSpacing: -0.08),
                  ),
                ),
              ],
            ),
          ),
          for (final s in sessions) ...[
            _SessionCard(session: s),
            const SizedBox(height: 8),
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
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: c.surface,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: AppIcon(
                                  session.isCardio
                                      ? 'figure.run'
                                      : 'dumbbell.fill',
                                  size: 16,
                                  color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.sf(
                                        size: 15,
                                        weight: FontWeight.w600,
                                        color: c.ink,
                                        letterSpacing: -0.24),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text(
                                      session.relativeDate,
                                      style: AppFonts.sf(
                                          size: 11,
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
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 42),
                          child: Row(
                            children: [
                              _StatChip(
                                  value: '${session.durationMinutes}',
                                  label: 'min'),
                              if (session.volumeTonnes > 0) ...[
                                Container(
                                  width: 1,
                                  height: 14,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  color: c.hair,
                                ),
                                _StatChip(
                                  value:
                                      '${session.volumeTonnes.toStringAsFixed(1)}t',
                                  label: 'volume',
                                ),
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
        const SizedBox(width: 3),
        Text(
          label,
          style: AppFonts.sf(size: 10, color: c.ink3, letterSpacing: -0.08),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.money, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon('star.fill', size: 8, color: _white),
          const SizedBox(width: 3),
          Text(
            '$count PR',
            style: AppFonts.sf(
                size: 10,
                weight: FontWeight.w700,
                color: _white,
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
      padding: const EdgeInsets.only(top: 18),
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
