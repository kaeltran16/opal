import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/profile_controller.dart';
import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../services/pal/pal_context_builder.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';

/// Live timeline entries for the move-streak math. The repository already
/// scopes the heavy lifting; the seed/live history is short enough that the
/// whole stream is a fine lookback for [moveStreakDays] (it counts back from
/// today on its own). A manual provider (not codegen) since no controller
/// exposes the raw entry stream and this screen is its only consumer.
final _moveEntriesProvider = StreamProvider.autoDispose<List<Entry>>(
  (ref) => ref.watch(entryRepositoryProvider).watchAll(),
);

/// Screen 15 — Streak Celebration.
///
/// A milestone moment. A radial green glow + faint radiating rays behind a giant
/// streak number, two-line copy, three pill stats, a rotated shareable card
/// preview, and Share / Keep going CTAs. Respects light/dark theme (the glow and
/// surfaces read from [AppColors]). This is the *workout* streak celebration
/// ("days moving"), so the number is the live move streak — the same value the
/// rest of the app uses — computed from the entry stream via [moveStreakDays].
/// The stat pills still draw from [profileStatsProvider] (kcal totals/best day).
class StreakCelebrationScreen extends ConsumerWidget {
  const StreakCelebrationScreen({super.key});

  static const _milestoneDots = 16;

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
    if (stats.moveKcal > 0) {
      pills.add(('Total', '${stats.moveKcal} kcal'));
    }
    final bestDay = stats.bestMoveDay;
    if (bestDay != null && stats.bestMoveDayKcal > 0) {
      final wd = _weekdayAbbrev[bestDay.weekday - 1];
      pills.add(('Best day', '$wd · ${stats.bestMoveDayKcal} kcal'));
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
    // the workout streak the rest of the app reports: consecutive move days,
    // counted from the live entry stream (the same helper the Pal context uses).
    // profileStats.longestStreak is the *ritual* streak — wrong source for this
    // "days moving" screen — so we derive the move streak from entries directly.
    final entries = ref.watch(_moveEntriesProvider).asData?.value;
    final streak = entries == null ? 0 : moveStreakDays(entries);
    final filledDots = streak.clamp(0, _milestoneDots);
    final pills = _statsFor(stats, streak);
    // only frame it as an unlocked milestone once there's an actual streak.
    final unlocked = streak >= 1;
    final start = streakStartDate(streak, DateTime.now());
    final sinceLine = !unlocked
        ? 'Move on any day to start a streak.'
        : start == null
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
                padding: const EdgeInsets.fromLTRB(Spacing.lg, 56, Spacing.lg, 0),
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
                padding: const EdgeInsets.fromLTRB(Spacing.xxl, 44, Spacing.xxl, Spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(unlocked ? 'STREAK UNLOCKED' : 'WORKOUT STREAK',
                        textAlign: TextAlign.center,
                        style: AppType.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.move,
                            letterSpacing: 0.5)),
                    const SizedBox(height: Spacing.lg),
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
                    const SizedBox(height: Spacing.xs),
                    Text(streak == 1 ? 'day moving' : 'days moving',
                        textAlign: TextAlign.center,
                        style: AppFonts.sfr(
                            size: 28,
                            weight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.5)),
                    const SizedBox(height: Spacing.lg),
                    Text(
                      sinceLine,
                      textAlign: TextAlign.center,
                      style: AppType.subhead
                          .copyWith(color: c.ink2, height: 1.5),
                    ),
                    if (pills.isNotEmpty) const SizedBox(height: Spacing.xxl),

                    // --- Stat pills ------------------------------------------
                    if (pills.isNotEmpty)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Spacing.sm,
                        runSpacing: Spacing.sm,
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
                padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xl, Spacing.xxl, 0),
                child: Transform.rotate(
                  angle: -1.5 * math.pi / 180,
                  child: _ShareCard(streak: streak, filledDots: filledDots),
                ),
              ),

              // --- CTAs -----------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.xl, 28, Spacing.xl, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: PressScale(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: Spacing.lg, horizontal: Spacing.lg),
                          decoration: BoxDecoration(
                            color: c.move,
                            borderRadius: BorderRadius.circular(Radii.card),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppIcon('square.and.arrow.up',
                                  size: 16, color: c.onAccent),
                              const SizedBox(width: Spacing.sm),
                              Text('Share',
                                  style: AppType.callout.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: c.onAccent,
                                      letterSpacing: -0.24)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: PressScale(
                        onTap: () => Navigator.of(context).canPop()
                            ? Navigator.of(context).pop()
                            : context.go('/today'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: Spacing.lg, horizontal: Spacing.lg),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(Radii.card),
                            border: Border.all(color: c.hair, width: 0.5),
                          ),
                          alignment: Alignment.center,
                          child: Text('Keep going',
                              style: AppType.callout.copyWith(
                                  fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.hair, width: 0.5),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label · ',
              style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: c.ink4,
                  letterSpacing: -0.08),
            ),
            TextSpan(
              text: value,
              style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                  letterSpacing: -0.08),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCard extends ConsumerWidget {
  const _ShareCard({required this.streak, required this.filledDots});
  final int streak;
  final int filledDots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final who = ref.watch(settingsRepositoryProvider).displayNameOrDefault;
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.hair, width: 0.5),
        // oversized soft share-card shadow; no Elevation preset fits (spec: record inline)
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 40, offset: const Offset(0, 12))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WORKOUT STREAK',
                    style: AppType.caption2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.move,
                        letterSpacing: 0.3)),
                const SizedBox(height: Spacing.xxs),
                Text('$streak ${streak == 1 ? 'day' : 'days'}',
                    style: AppFonts.sfr(
                        size: 44,
                        weight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.8,
                        height: 1.0)),
                const SizedBox(height: Spacing.xs),
                Text('$who · Opal',
                    style: AppType.caption
                        .copyWith(color: c.ink3, letterSpacing: -0.08)),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
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
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: [
        for (var i = 0; i < StreakCelebrationScreen._milestoneDots; i++)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: i < filled ? moveColor : emptyColor,
              borderRadius: BorderRadius.circular(Radii.xs),
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
