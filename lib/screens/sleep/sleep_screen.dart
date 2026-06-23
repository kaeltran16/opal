import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/correlations.dart';
import '../../controllers/correlations_controller.dart';
import '../../controllers/sleep_controller.dart';
import '../../theme/theme.dart';
import '../../util/mood_scale.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/correlation_card.dart';
import '../../widgets/press_scale.dart';
import '../shell/tab_header.dart';
import 'widgets/sleep_widgets.dart';

/// Sleep tab root. Renders a full-data hero + trend chart + connections when
/// [SleepState.syncedNights] >= 3; shows a needs-sync onboarding card otherwise.
class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(sleepControllerProvider);

    return async.when(
      loading: () => Center(
        child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text(
            "Couldn't load sleep.\n$e",
            textAlign: TextAlign.center,
            style: AppType.subhead.copyWith(color: c.ink3, letterSpacing: -0.24),
          ),
        ),
      ),
      data: (state) => state.syncedNights >= 3
          ? _SleepBody(state: state)
          : _SleepNeedsSync(syncedNights: state.syncedNights),
    );
  }
}

// ─── Health pill (trailing for both states) ───────────────────────────────────

Widget _healthPill(AppColors c) => Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('heart.fill', size: 13, color: c.red),
          const SizedBox(width: Spacing.xs),
          Text(
            'Health',
            style: AppFonts.sf(
              size: 13,
              weight: FontWeight.w600,
              color: c.ink2,
            ),
          ),
        ],
      ),
    );

// ─── Full body (syncedNights >= 3) ───────────────────────────────────────────

class _SleepBody extends ConsumerWidget {
  const _SleepBody({required this.state});
  final SleepState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final correlationsAsync = ref.watch(surfacedCorrelationsProvider);

    // find first correlation that involves sleep
    final sleepCorr = correlationsAsync.whenOrNull(
      data: (list) {
        for (final corr in list) {
          if (corr.involves(Dimension.sleep)) return corr;
        }
        return null;
      },
    );

    return TabHeaderScrollView(
      title: 'Sleep',
      subtitle: 'synced from Health',
      contextualAction: _healthPill(c),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        _HeroCard(state: state),
        SleepTrendChart(
          week: state.week,
          month: state.month,
          usualMinutes: state.usualMinutes,
        ),
        if (sleepCorr != null) _ConnectionsSection(correlation: sleepCorr),
      ],
    );
  }
}

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state});
  final SleepState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final night = state.lastNight!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          boxShadow: [
            // sleep-tinted glow (prototype: 0 10px 30px sleep33 — alpha 0x33≈0.20)
            BoxShadow(
              color: c.sleep.withValues(alpha: 0.20),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xl),
          child: DecoratedBox(
            // 155° gradient: sleep → sleep@0.90 → sleep@0.70
            decoration: BoxDecoration(
              gradient: LinearGradient(
                // 155° from top → roughly topLeft to bottomRight offset
                transform: const GradientRotation(155 * 3.14159 / 180),
                colors: [
                  c.sleep,
                  c.sleep.withValues(alpha: 0.90),
                  c.sleep.withValues(alpha: 0.70),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // eyebrow
                  Text(
                    'LAST NIGHT',
                    style: AppFonts.sf(
                      size: 11,
                      weight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  // duration + read chip row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DurationBig(
                          minutes: night.asleepMinutes,
                          usualMinutes: state.usualMinutes,
                          light: true,
                          size: 42,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      // read chip: moon.stars.fill + qualitative word
                      if (state.read.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sm, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppIcon('moon.stars.fill',
                                  size: 12, color: Colors.white),
                              const SizedBox(width: Spacing.xs),
                              Text(
                                state.read,
                                style: AppFonts.sf(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  // divider
                  Container(
                      height: 0.5,
                      color: Colors.white.withValues(alpha: 0.22)),
                  const SizedBox(height: Spacing.md),
                  // stage split bar
                  StageSplitBar(
                    deepMinutes: night.deepMinutes,
                    remMinutes: night.remMinutes,
                    coreMinutes: night.coreMinutes,
                    awakeMinutes: night.awakeMinutes,
                    light: true,
                  ),
                  const SizedBox(height: Spacing.md),
                  // in-bed meta line
                  Text(
                    'in bed ${night.bedtime} – ${night.wake}'
                    ' · ${hm(night.inBedMinutes)} in bed'
                    ' · ${night.wakes} brief wakes',
                    style: AppFonts.sf(
                      size: 12.5,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Connections section ──────────────────────────────────────────────────────

class _ConnectionsSection extends StatelessWidget {
  const _ConnectionsSection({required this.correlation});
  final Correlation correlation;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xs, 0, Spacing.xs, Spacing.sm),
            child: Text(
              'Connections',
              style: AppFonts.sf(
                size: 22,
                weight: FontWeight.w700,
                color: c.ink,
                letterSpacing: 0.35,
              ),
            ),
          ),
          CorrelationCard(correlation: correlation),
        ],
      ),
    );
  }
}

// ─── Needs-sync state ─────────────────────────────────────────────────────────

class _SleepNeedsSync extends StatelessWidget {
  const _SleepNeedsSync({required this.syncedNights});
  final int syncedNights;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // clamp so we never render > 3 filled dots
    final filled = syncedNights.clamp(0, 3);

    return TabHeaderScrollView(
      title: 'Sleep',
      subtitle: 'synced from Health',
      contextualAction: _healthPill(c),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Spacing.xxxl),
              // icon disc
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: c.sleepTint,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon('moon.stars.fill', size: 42, color: c.sleep),
                ),
              ),
              const SizedBox(height: Spacing.xxl),
              // title
              Text(
                'A few more nights',
                style: AppType.title2.copyWith(color: c.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.md),
              // copy
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  'Opal needs at least 3 nights of sleep data to build your '
                  'patterns and show insights. Keep your phone nearby while '
                  'you sleep.',
                  style: AppType.subhead.copyWith(
                    color: c.ink2,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Spacing.xxl),
              // progress dots row: 3 dots, fill syncedNights with sleep color
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: Spacing.sm),
                    Container(
                      width: 28,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < filled ? c.sleep : c.fill,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                '$filled of 3 nights synced',
                style: AppFonts.sf(size: 12.5, color: c.ink3),
              ),
              const SizedBox(height: Spacing.xxl),
              // Open Health settings button
              PressScale(
                onTap: null, // no-op visual button; Health settings deep-link wired later
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xxl, vertical: Spacing.md),
                  decoration: BoxDecoration(
                    color: c.sleep,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon('heart.fill',
                          size: 15, color: Colors.white),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        'Open Health settings',
                        style: AppFonts.sf(
                          size: 15,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              // reassurance line
              Text(
                'Already synced? It can take a night to catch up.',
                style: AppFonts.sf(size: 12.5, color: c.ink3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xxxl),
            ],
          ),
        ),
      ],
    );
  }
}
