import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/correlations.dart';
import '../../controllers/correlations_controller.dart';
import '../../controllers/insights_controller.dart';
import '../../controllers/nutrition_controller.dart';
import '../../router.dart';
import '../../services/pal/pal_service.dart' show InsightRange;
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/correlation_card.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

/// Screen — Connections: all cross-tracker nutrition patterns.
///
/// Reads [nutritionControllerProvider] for [NutritionState.patterns] and lays
/// out a card per pattern. Tapping any card opens the Pal composer.
class NutritionPatternsScreen extends ConsumerWidget {
  const NutritionPatternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(nutritionControllerProvider);
    final surfaced =
        ref.watch(surfacedCorrelationsProvider).asData?.value ?? const [];
    final narration = ref
        .watch(insightsProvider(InsightRange.week))
        .asData
        ?.value
        ?.correlationNarration;

    final patterns = async.asData?.value.patterns ?? const [];
    final nutritionCorrs =
        surfaced.where((corr) => corr.involves(Dimension.nutrition)).toList();

    return ColoredBox(
      color: c.bg,
      child: LargeTitleScrollView(
        title: 'Connections',
        subtitle: 'how eating ties to the rest of your day',
        leading: NavAction(
          icon: 'chevron.left',
          label: 'Nutrition',
          onTap: () => context.pop(),
          semanticLabel: 'Back',
        ),
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          const SizedBox(height: Spacing.lg),
          for (final corr in nutritionCorrs)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, 0, Spacing.lg, Spacing.md),
              child: CorrelationCard(
                correlation: corr,
                // only the globally strongest correlation gets the LLM narration
                narration: (surfaced.isNotEmpty &&
                        corr.a == surfaced.first.a &&
                        corr.b == surfaced.first.b)
                    ? narration
                    : null,
              ),
            ),
          for (final p in patterns)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, 0, Spacing.lg, Spacing.md),
              child: _PatternCard(pattern: p),
            ),
        ],
      ),
    );
  }
}

// ─── Pattern card ────────────────────────────────────────────────────────────

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.pattern});
  final NutritionPattern pattern;

  static String _trackerLabel(String t) => switch (t) {
        'money' => 'Money',
        'move' => 'Workout',
        'rituals' => 'Routines',
        _ => 'Nutrition',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trackerColor = c.forType(pattern.tracker);

    return PressScale(
      onTap: () => context.pushNamed(AppRoute.palComposer.name),
      semanticLabel: pattern.title,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
              color: trackerColor.withValues(alpha: 0.18), width: 0.5),
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Two square dots + eyebrow, with the tracker glyph top-right.
            Row(
              children: [
                _SquareDot(color: c.nutrition),
                const SizedBox(width: Spacing.xs),
                _SquareDot(color: trackerColor),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'NUTRITION × ${_trackerLabel(pattern.tracker)}'.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.ink3,
                        letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                AppIcon(pattern.icon, size: 15, color: trackerColor),
              ],
            ),
            const SizedBox(height: Spacing.md),
            // Title + body, with the sparkline bottom-aligned at the right.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pattern.title,
                        style: AppType.subhead.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                            letterSpacing: -0.24),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        pattern.body,
                        style: AppType.footnote
                            .copyWith(color: c.ink3, letterSpacing: -0.08, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.md),
                _Sparkline(
                  values: pattern.spark,
                  emph: pattern.emph,
                  color: trackerColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Square dot ──────────────────────────────────────────────────────────────

class _SquareDot extends StatelessWidget {
  const _SquareDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─── Sparkline ───────────────────────────────────────────────────────────────

/// Miniature bar chart. Bar height is proportional to v / max(spark); bars
/// whose index is in [emph] use full [color], others use 40% alpha.
class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.values,
    required this.emph,
    required this.color,
  });

  final List<int> values;
  final List<int> emph;
  final Color color;

  static const double _maxH = 40;
  static const double _barW = 5;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    final maxVal =
        values.fold<int>(1, (prev, v) => v > prev ? v : prev).toDouble();

    return SizedBox(
      height: _maxH,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Container(
              width: _barW,
              height: (_maxH * values[i] / maxVal).clamp(2.0, _maxH),
              decoration: BoxDecoration(
                color: emph.contains(i)
                    ? color
                    : color.withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
