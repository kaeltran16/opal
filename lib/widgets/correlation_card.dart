import 'package:flutter/material.dart';

import '../analysis/correlations.dart';
import '../theme/theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

/// A surfaced cross-dimension correlation: eyebrow, narrated (or templated)
/// body, and a sample-size + strength chip. Tappable to reveal the breakdown.
class CorrelationCard extends StatelessWidget {
  const CorrelationCard({super.key, required this.correlation, this.narration});

  final Correlation correlation;
  final String? narration;

  static String _label(Dimension d) => switch (d) {
        Dimension.money => 'Money',
        Dimension.move => 'Move',
        Dimension.rituals => 'Rituals',
        Dimension.nutrition => 'Nutrition',
      };

  static String _token(Dimension d) => _label(d).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final aColor = c.forType(_token(correlation.a));
    final bColor = c.forType(_token(correlation.b));
    final body = narration ?? correlation.summary;
    final eyebrow =
        '${_label(correlation.a)} x ${_label(correlation.b)}'.toUpperCase();

    return PressScale(
      onTap: () => showCorrelationTrustSheet(context, correlation),
      semanticLabel: body,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: aColor.withValues(alpha: 0.18), width: 0.5),
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Dot(color: aColor),
                const SizedBox(width: Spacing.xs),
                _Dot(color: bColor),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption2.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.ink3,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(width: Spacing.sm),
                // 'chart.line.uptrend.xyaxis' is not in the SF symbol map;
                // 'sparkles' is the designated fallback for unmapped glyphs.
                AppIcon('sparkles', size: 15, color: aColor),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(body,
                style: AppType.subhead.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -0.24,
                    height: 1.35)),
            const SizedBox(height: Spacing.sm),
            Text(
                'Based on ${correlation.n} days · ${correlation.strengthWord} link',
                style: AppType.caption2.copyWith(color: c.ink3)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
      width: 8,
      height: 8,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)));
}

/// Modal "why" sheet: two-group means (when one side is binary) or a template
/// summary, plus the sample size — the underlying-data view the trust layer
/// requires.
Future<void> showCorrelationTrustSheet(
    BuildContext context, Correlation correlation) {
  final b = correlation.breakdown;
  // backgroundColor is resolved immediately at call-site, not inside the builder.
  final surface = context.colors.surface;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: surface,
    showDragHandle: true,
    builder: (ctx) {
      final c = ctx.colors;
      return Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why you\'re seeing this',
              style: AppType.title3
                  .copyWith(fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: Spacing.md),
          if (b != null) ...[
            _Row(
                label: '${b.countActive} ${activeDayLabel(b.binaryDim)}',
                value: formatValue(b.continuousDim, b.meanWhenActive),
                colors: c),
            const SizedBox(height: Spacing.sm),
            _Row(
                label: '${b.countInactive} ${inactiveDayLabel(b.binaryDim)}',
                value: formatValue(b.continuousDim, b.meanWhenInactive),
                colors: c),
          ] else
            Text(correlation.summary,
                style: AppType.body.copyWith(color: c.ink)),
          const SizedBox(height: Spacing.lg),
          Text(
              'Computed from your own data over ${correlation.n} days. '
              'A ${correlation.strengthWord} link, not a certainty.',
              style: AppType.footnote.copyWith(color: c.ink3, height: 1.4)),
        ],
      ),
    );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.colors});
  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: AppType.subhead.copyWith(color: colors.ink2))),
          Text(value,
              style: AppType.subhead
                  .copyWith(fontWeight: FontWeight.w700, color: colors.ink)),
        ],
      );
}
