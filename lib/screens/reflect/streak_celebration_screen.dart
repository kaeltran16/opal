import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/profile_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';

/// Screen 15 — Streak Celebration.
///
/// A milestone moment. A radial green glow + faint radiating rays behind a giant
/// streak number, two-line copy, three pill stats, a rotated shareable card
/// preview, and Share / Keep going CTAs. Respects light/dark theme (the glow and
/// surfaces read from [AppColors]). The streak number reads
/// [profileStatsProvider]'s `longestStreak`, falling back to 11.
class StreakCelebrationScreen extends ConsumerWidget {
  const StreakCelebrationScreen({super.key});

  static const _fallbackStreak = 11;
  static const _milestoneDots = 16;

  static const _white = Color(0xFFFFFFFF);

  static const _weekdayAbbrev = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthAbbrev = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Stat pills derived from real profile data; only includes a pill when its
  /// value can actually be computed (no fabricated stats).
  static List<(String, String)> _statsFor(ProfileStats? stats, int streak) {
    if (stats == null) return const [];
    final pills = <(String, String)>[];
    if (stats.moveMinutes > 0) {
      pills.add(('Total', '${stats.moveMinutes} min'));
    }
    final bestDay = stats.bestMoveDay;
    if (bestDay != null && stats.bestMoveDayMinutes > 0) {
      final wd = _weekdayAbbrev[bestDay.weekday - 1];
      pills.add(('Best day', '$wd · ${stats.bestMoveDayMinutes}m'));
    }
    final next = nextStreakMilestone(streak);
    if (next != null) {
      pills.add(('Next milestone', '${next - streak} days'));
    }
    return pills;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final stats = ref.watch(profileStatsProvider).asData?.value;
    final streak = stats?.longestStreak ?? _fallbackStreak;
    final filledDots = streak.clamp(0, _milestoneDots);
    final pills = _statsFor(stats, streak);
    final start = streakStartDate(streak, DateTime.now());
    final sinceLine = start == null
        ? 'Your longest streak this year.'
        : "You haven't missed a day since "
            '${_monthAbbrev[start.month - 1]} ${start.day}.\n'
            'Your longest streak this year.';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.24),
          radius: 0.9,
          colors: [c.move.withValues(alpha: 0.20), c.bg],
          stops: const [0.0, 0.6],
        ),
      ),
      child: Stack(
        children: [
          // Faint radiating rays.
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            height: 500,
            child: CustomPaint(painter: _RaysPainter(color: c.move)),
          ),
          ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // --- Close ----------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
                child: PressScale(
                  onTap: () => Navigator.of(context).canPop()
                      ? Navigator.of(context).pop()
                      : context.go('/today'),
                  semanticLabel: 'Close',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration:
                            BoxDecoration(color: c.fill, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: AppIcon('xmark', size: 13, color: c.ink3),
                      ),
                    ),
                  ),
                ),
              ),

              // --- Hero -----------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 44, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('STREAK UNLOCKED',
                        textAlign: TextAlign.center,
                        style: AppFonts.sf(
                            size: 12,
                            weight: FontWeight.w700,
                            color: c.move,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 16),
                    Text('$streak',
                        textAlign: TextAlign.center,
                        style: AppFonts.sfr(
                          size: 140,
                          weight: FontWeight.w800,
                          color: c.move,
                          letterSpacing: -4,
                          height: 1.0,
                        ).copyWith(
                          shadows: [
                            Shadow(
                              color: c.move.withValues(alpha: 0.27),
                              blurRadius: 24,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        )),
                    const SizedBox(height: 4),
                    Text('days moving',
                        textAlign: TextAlign.center,
                        style: AppFonts.sfr(
                            size: 28,
                            weight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 14),
                    Text(
                      sinceLine,
                      textAlign: TextAlign.center,
                      style: AppFonts.sf(
                          size: 15,
                          color: c.ink2,
                          letterSpacing: -0.24,
                          height: 1.5),
                    ),
                    if (pills.isNotEmpty) const SizedBox(height: 22),

                    // --- Stat pills ------------------------------------------
                    if (pills.isNotEmpty)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (label, value) in pills)
                            _StatPill(label: label, value: value),
                        ],
                      ),
                  ],
                ),
              ),

              // --- Shareable card preview -----------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Transform.rotate(
                  angle: -1.5 * math.pi / 180,
                  child: _ShareCard(streak: streak, filledDots: filledDots),
                ),
              ),

              // --- CTAs -----------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: PressScale(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: c.move,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const AppIcon('square.and.arrow.up',
                                  size: 16, color: _white),
                              const SizedBox(width: 8),
                              Text('Share',
                                  style: AppFonts.sf(
                                      size: 16,
                                      weight: FontWeight.w600,
                                      color: _white,
                                      letterSpacing: -0.24)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PressScale(
                        onTap: () => Navigator.of(context).canPop()
                            ? Navigator.of(context).pop()
                            : context.go('/today'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.hair, width: 0.5),
                          ),
                          alignment: Alignment.center,
                          child: Text('Keep going',
                              style: AppFonts.sf(
                                  size: 16,
                                  weight: FontWeight.w600,
                                  color: c.ink,
                                  letterSpacing: -0.24)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.hair, width: 0.5),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label · ',
              style: AppFonts.sf(
                  size: 12,
                  weight: FontWeight.w500,
                  color: c.ink4,
                  letterSpacing: -0.08),
            ),
            TextSpan(
              text: value,
              style: AppFonts.sf(
                  size: 12,
                  weight: FontWeight.w700,
                  color: c.ink,
                  letterSpacing: -0.08),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.streak, required this.filledDots});
  final int streak;
  final int filledDots;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.hair, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WORKOUT STREAK',
                    style: AppFonts.sf(
                        size: 11,
                        weight: FontWeight.w700,
                        color: c.move,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text('$streak days',
                    style: AppFonts.sfr(
                        size: 44,
                        weight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.8,
                        height: 1.0)),
                const SizedBox(height: 4),
                Text('@mira · Opal',
                    style: AppFonts.sf(
                        size: 12, color: c.ink3, letterSpacing: -0.08)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _DotGrid(filled: filledDots, moveColor: c.move, emptyColor: c.fill),
        ],
      ),
    );
  }
}

/// 4×4 grid of 8px dots; the first [filled] are move-green, the rest fill-grey.
class _DotGrid extends StatelessWidget {
  const _DotGrid({
    required this.filled,
    required this.moveColor,
    required this.emptyColor,
  });

  final int filled;
  final Color moveColor;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < StreakCelebrationScreen._milestoneDots; i++)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: i < filled ? moveColor : emptyColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// 12 faint rays radiating from the hero point, matching the prototype's SVG.
class _RaysPainter extends CustomPainter {
  _RaysPainter({required this.color});
  final Color color;

  static const _count = 12;
  static const _length = 280.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Origin mirrors the prototype viewBox (195, 250) within a 390-wide frame.
    final origin = Offset(size.width / 2, 250);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _count; i++) {
      final angle = (i * 30) * math.pi / 180 - math.pi / 2;
      final end = origin +
          Offset(math.cos(angle) * _length, math.sin(angle) * _length);
      canvas.drawLine(origin, end, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.color != color;
}
