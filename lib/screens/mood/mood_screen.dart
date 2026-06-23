import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/correlations.dart';
import '../../controllers/correlations_controller.dart';
import '../../controllers/mood_controller.dart';
import '../../models/mood_checkin.dart';
import '../../theme/theme.dart';
import '../../util/mood_scale.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/correlation_card.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';
import '../shell/tab_header.dart';
import 'mood_logger_sheet.dart';
import 'widgets/mood_widgets.dart';

/// Mood landing screen. Mirrors NutritionScreen's ConsumerWidget + .when pattern.
class MoodScreen extends ConsumerWidget {
  const MoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(moodControllerProvider);

    return async.when(
      loading: () => Center(
        child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text(
            "Couldn't load mood.\n$e",
            textAlign: TextAlign.center,
            style: AppType.subhead.copyWith(color: c.ink3, letterSpacing: -0.24),
          ),
        ),
      ),
      data: (state) => _MoodBody(state: state),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _MoodBody extends StatelessWidget {
  const _MoodBody({required this.state});
  final MoodState state;

  @override
  Widget build(BuildContext context) {
    return TabHeaderScrollView(
      title: 'Mood',
      subtitle: "how you've been feeling",
      contextualAction: NavIconButton(
        name: 'plus',
        semanticLabel: 'Check in',
        onTap: () => showMoodLogger(context),
      ),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        _HeroCard(state: state),
        _CheckInAgainRow(state: state),
        _CheckInsSection(state: state),
        _WeekSection(state: state),
        const _ConnectionsSection(),
      ],
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state});
  final MoodState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = c.brightness == Brightness.dark;
    final tone = c.mood;
    final last = state.lastCheckin;
    final hasCheckins = state.todayCheckins.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          boxShadow: [
            BoxShadow(
              color: tone.withValues(alpha: 0.28),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xl),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tone,
                  tone.withValues(alpha: 0.90),
                  tone.withValues(alpha: 0.70),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY LEANS',
                    style: AppType.caption2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xD9FFFFFF),
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    moodWord(state.todayLean),
                    style: AppFonts.sf(
                      size: 28,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    'averaged from ${state.todayCheckins.length} check-in${state.todayCheckins.length == 1 ? '' : 's'}',
                    style: AppType.subhead.copyWith(
                      color: const Color(0xCCFFFFFF),
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (last?.tag != null) ...[
                    const SizedBox(height: Spacing.md),
                    _TagChip(tag: last!.tag!),
                  ],
                  const SizedBox(height: Spacing.md),
                  Container(height: 0.5, color: const Color(0x4DFFFFFF)),
                  const SizedBox(height: Spacing.md),
                  MoodMiniScale(t: state.todayLean, dark: dark, light: true),
                  if (hasCheckins) ...[
                    const SizedBox(height: Spacing.md),
                    Text(
                      _metaLine(state),
                      style: AppType.subhead.copyWith(
                        color: const Color(0xCCFFFFFF),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _metaLine(MoodState state) {
    final tag = state.mostTag ?? state.lastCheckin?.tag;
    final last = state.lastCheckin;
    final parts = <String>[];
    if (tag != null) parts.add('most often $tag');
    if (last != null) {
      final t = last.timestamp;
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      parts.add('last logged $h:$m');
    }
    return parts.join(' · ');
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon('heart.fill', size: 11, color: Colors.white),
          const SizedBox(width: Spacing.xs),
          Text(
            tag,
            style: AppFonts.sf(
              size: 12,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Check in again row ────────────────────────────────────────────────────────

class _CheckInAgainRow extends StatelessWidget {
  const _CheckInAgainRow({required this.state});
  final MoodState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = c.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: PressScale(
        onTap: () => showMoodLogger(context),
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
          ),
          child: Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: moodColor(state.todayLean, dark),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                alignment: Alignment.center,
                child: const AppIcon('plus', size: 16, color: Colors.white),
              ),
              const SizedBox(width: Spacing.md),
              Text(
                'Check in again',
                style: AppType.body.copyWith(color: c.ink),
              ),
              const Spacer(),
              AppIcon('chevron.right', size: 14, color: c.ink4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Check-ins section ────────────────────────────────────────────────────────

class _CheckInsSection extends StatelessWidget {
  const _CheckInsSection({required this.state});
  final MoodState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = c.brightness == Brightness.dark;
    final checkins = state.todayCheckins.reversed.toList();

    if (checkins.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xs, 0, Spacing.xs, Spacing.sm),
            child: Text(
              'Check-ins',
              style: AppFonts.sf(
                size: 22,
                weight: FontWeight.w700,
                color: c.ink,
                letterSpacing: 0.35,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
            ),
            child: Column(
              children: [
                for (var i = 0; i < checkins.length; i++)
                  _CheckInRow(
                    checkin: checkins[i],
                    dark: dark,
                    last: i == checkins.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInRow extends StatelessWidget {
  const _CheckInRow({
    required this.checkin,
    required this.dark,
    required this.last,
  });
  final MoodCheckin checkin;
  final bool dark;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = checkin.timestamp;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final dotColor = moodColor(checkin.pleasantness, dark);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.sm,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Text(
                  timeStr,
                  style: AppType.footnote.copyWith(color: c.ink3),
                ),
                const SizedBox(width: Spacing.md),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  moodWord(checkin.pleasantness),
                  style: AppType.body.copyWith(color: c.ink),
                ),
                if (checkin.tag != null) ...[
                  const SizedBox(width: Spacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      checkin.tag!,
                      style: AppType.caption.copyWith(
                        color: dotColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!last)
          Positioned(
            left: Spacing.lg,
            right: 0,
            bottom: 0,
            child: Container(height: 0.5, color: c.hair),
          ),
      ],
    );
  }
}

// ─── Week section ─────────────────────────────────────────────────────────────

class _WeekSection extends StatelessWidget {
  const _WeekSection({required this.state});
  final MoodState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = c.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week',
              style: AppFonts.sf(
                size: 15,
                weight: FontWeight.w700,
                color: c.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            MoodWeekChart(week: state.week, dark: dark),
          ],
        ),
      ),
    );
  }
}

// ─── Connections section ──────────────────────────────────────────────────────

class _ConnectionsSection extends ConsumerWidget {
  const _ConnectionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(surfacedCorrelationsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (correlations) {
        final moodCorrs = correlations.where(
          (corr) => corr.a == Dimension.mood || corr.b == Dimension.mood,
        ).toList();
        if (moodCorrs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.xs, 0, Spacing.xs, Spacing.sm),
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
              CorrelationCard(correlation: moodCorrs.first),
            ],
          ),
        );
      },
    );
  }
}
