import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/weekly_plan_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

const _white = Color(0xFFFFFFFF);

/// Screen 24 — Weekly Plan, the derived 7-day workout schedule.
///
/// Reads the [WeeklyPlan] from `weeklyPlanControllerProvider` (a stream joining
/// the persisted schedule to routines + this week's workouts) and renders the
/// title block, the week strip, the today spotlight, the full schedule list,
/// and a computed weekly-progress note. All derivation lives in the controller;
/// this widget only lays out.
class WeeklyPlanScreen extends ConsumerWidget {
  const WeeklyPlanScreen({super.key});

  /// Maps a [WeekPlanDay.colorKey] to its theme color: the 'rest' pseudo-color
  /// resolves to ink3, everything else through `forType` (accent falls through).
  static Color _colorFor(AppColors c, String key) =>
      key == 'rest' ? c.ink3 : c.forType(key);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Monday of the current week, formatted "WEEK OF MON DD". The plan's day
  /// model only carries day-of-month, so the month comes from the current
  /// week's Monday (the same anchor the controller uses).
  static String _weekOfLabel() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return 'WEEK OF ${_months[monday.month - 1].toUpperCase()} ${monday.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final plan = ref.watch(weeklyPlanControllerProvider).asData?.value ??
        const WeeklyPlan(days: []);
    final today = plan.today;

    // Opaque background so the Cupertino push parallax doesn't show the
    // outgoing page through this one (ghosting). Mirrors the shell's c.bg.
    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
      children: [
        // Nav: back "Move" + trailing ellipsis.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PressScale(
                onTap: () => context.pop(),
                semanticLabel: 'Workout',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon('chevron.left', size: 20, color: c.accent),
                    const SizedBox(width: 2),
                    Text('Workout',
                        style: AppFonts.sf(
                            size: 17, color: c.accent, letterSpacing: -0.43)),
                  ],
                ),
              ),
              const NavIconButton(name: 'ellipsis', semanticLabel: 'More options'),
            ],
          ),
        ),

        // Title block.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _weekOfLabel(),
                style: AppFonts.sf(
                    size: 12,
                    weight: FontWeight.w700,
                    color: c.move,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Your plan.',
                style: AppFonts.sf(
                    size: 34,
                    weight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: 0.37,
                    height: 41 / 34),
              ),
              const SizedBox(height: 2),
              Text(
                '${plan.doneCount} of ${plan.totalCount} done · ${plan.totalMinutes} min planned',
                style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24),
              ),
            ],
          ),
        ),

        // Week strip.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Row(
            children: [
              for (var i = 0; i < plan.days.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _WeekChip(day: plan.days[i])),
              ],
            ],
          ),
        ),

        // Today spotlight.
        if (today != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: _TodaySpotlight(day: today),
          ),

        // Schedule header.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            'Schedule',
            style: AppFonts.sf(
                size: 22,
                weight: FontWeight.w700,
                color: c.ink,
                letterSpacing: 0.35),
          ),
        ),

        // Full schedule inset list.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: c.surface,
              child: Column(
                children: [
                  for (var i = 0; i < plan.days.length; i++)
                    _ScheduleRow(
                        day: plan.days[i], last: i == plan.days.length - 1),
                ],
              ),
            ),
          ),
        ),

        // Weekly progress summary (computed from the plan — no fabricated coach
        // prose; coaching is Pal-territory and has no real source here).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: _WeekProgressNote(plan: plan),
        ),
      ],
      ),
    );
  }
}

/// One day chip in the week strip: letter + 36px circle + completion dot.
class _WeekChip extends StatelessWidget {
  const _WeekChip({required this.day});
  final WeekPlanDay day;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = WeeklyPlanScreen._colorFor(c, day.colorKey);
    final isRest = day.isRest;

    final Color circleBg;
    final Color dateColor;
    final BoxBorder? border;
    // planned = not done, not rest, not today → dashed ring (design spec).
    var dashedRing = false;
    if (day.today) {
      circleBg = c.move;
      dateColor = _white;
      border = null;
    } else if (day.done) {
      circleBg = color.withValues(alpha: 0.13);
      dateColor = color;
      border = null;
    } else if (isRest) {
      circleBg = c.fill;
      dateColor = c.ink3;
      border = null;
    } else {
      circleBg = c.surface;
      dateColor = c.ink;
      border = null;
      dashedRing = true;
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          day.day[0],
          style: AppFonts.sf(
              size: 11,
              weight: FontWeight.w600,
              color: day.today ? c.move : c.ink3,
              letterSpacing: 0.3),
        ),
        const SizedBox(height: 6),
        CustomPaint(
          foregroundPainter: dashedRing
              ? _DashedCirclePainter(color: color.withValues(alpha: 0.33))
              : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: circleBg,
              shape: BoxShape.circle,
              border: border,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.date}',
              style: AppFonts.sfr(
                  size: 14,
                  weight: FontWeight.w700,
                  color: dateColor,
                  letterSpacing: -0.3),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: day.done ? color : const Color(0x00000000),
            border: (day.done || isRest)
                ? null
                : Border.all(color: color, width: 1),
          ),
        ),
      ],
    );
  }
}

/// The today=true tinted spotlight card with the radial color wash + CTAs.
class _TodaySpotlight extends StatelessWidget {
  const _TodaySpotlight({required this.day});
  final WeekPlanDay day;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = WeeklyPlanScreen._colorFor(c, day.colorKey);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.27), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-1, -1),
                  radius: 1.1,
                  colors: [color.withValues(alpha: 0.12), const Color(0x00000000)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today pill.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Today · ${day.day}'.toUpperCase(),
                    style: AppFonts.sf(
                        size: 11,
                        weight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(day.icon, size: 24, color: _white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${day.type} · ${day.routine}',
                            style: AppFonts.sfr(
                                size: 22,
                                weight: FontWeight.w700,
                                color: c.ink,
                                letterSpacing: -0.3,
                                height: 1.15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${day.muscles.join(' · ')} · ${day.est} min',
                            style: AppFonts.sf(
                                size: 13,
                                color: c.ink3,
                                letterSpacing: -0.08,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PressScale(
                        onTap: () => context.go('/move/start'),
                        semanticLabel: 'Start workout',
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const AppIcon('play.fill', size: 13, color: _white),
                              const SizedBox(width: 8),
                              Text(
                                'Start workout',
                                style: AppFonts.sf(
                                    size: 15,
                                    weight: FontWeight.w600,
                                    color: _white,
                                    letterSpacing: -0.24),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PressScale(
                      onTap: () => context.go('/move/start'),
                      semanticLabel: 'Swap workout',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.hair, width: 0.5),
                        ),
                        child: Text(
                          'Swap',
                          style: AppFonts.sf(
                              size: 14,
                              weight: FontWeight.w500,
                              color: c.ink2,
                              letterSpacing: -0.15),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the full schedule list.
class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.day, required this.last});
  final WeekPlanDay day;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = WeeklyPlanScreen._colorFor(c, day.colorKey);
    final isRest = day.isRest;

    return Container(
      decoration: BoxDecoration(
        color: day.today ? color.withValues(alpha: 0.06) : const Color(0x00000000),
        border: last
            ? null
            : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      child: Stack(
        children: [
          if (day.today)
            Positioned(
              left: 0,
              top: 8,
              bottom: 8,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(2)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Day chip (abbr + date).
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      Text(
                        day.day.toUpperCase(),
                        style: AppFonts.sf(
                            size: 10,
                            weight: FontWeight.w700,
                            color: c.ink3,
                            letterSpacing: 0.5),
                      ),
                      Text(
                        '${day.date}',
                        style: AppFonts.sfr(
                            size: 20,
                            weight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.3,
                            height: 1.1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Type icon tile.
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isRest ? c.fill : color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(day.icon,
                      size: 15, color: isRest ? c.ink3 : _white),
                ),
                const SizedBox(width: 12),
                // Title + subtitle.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isRest ? 'Rest day' : day.type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.sf(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: isRest ? c.ink2 : c.ink,
                                  letterSpacing: -0.24),
                            ),
                          ),
                          if (day.done) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: c.move,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const AppIcon('checkmark',
                                  size: 8, color: _white),
                            ),
                          ],
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          isRest
                              ? 'Recovery · stretch optional'
                              : '${day.routine} · ${day.est} min',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.sf(
                              size: 12, color: c.ink3, letterSpacing: -0.08),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRest && !day.done)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: AppIcon('chevron.right', size: 14, color: c.ink4),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom weekly-progress gradient note. Renders a factual line computed from
/// the plan (done / total workouts, minutes planned) — not invented coaching.
class _WeekProgressNote extends StatelessWidget {
  const _WeekProgressNote({required this.plan});
  final WeeklyPlan plan;

  /// Factual progress line from the plan's own counts.
  String get _summary {
    final done = plan.doneCount;
    final total = plan.totalCount;
    final remaining = total - done;
    if (total == 0) return 'No workouts scheduled this week yet.';
    if (done >= total) {
      return 'All $total workouts done this week — ${plan.totalMinutes} min planned.';
    }
    final left = remaining == 1 ? '1 workout' : '$remaining workouts';
    return '$done of $total done · $left left this week.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.accent.withValues(alpha: 0.07),
            c.move.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.accent, c.move],
              ),
            ),
            alignment: Alignment.center,
            child: const AppIcon('sparkles', size: 13, color: _white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIS WEEK',
                  style: AppFonts.sf(
                      size: 11,
                      weight: FontWeight.w700,
                      color: c.ink3,
                      letterSpacing: 0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  _summary,
                  style: AppFonts.sf(
                      size: 14,
                      color: c.ink,
                      letterSpacing: -0.15,
                      height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed 1.5px ring for a planned (not-done) week-strip day.
class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 1.5) / 2;
    const dashes = 16;
    final sweep = (2 * math.pi) / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
