import 'package:flutter/widgets.dart';
import '../theme/theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

/// Dot + label + big value + goal, shown beside the activity rings on Today.
class RingStat extends StatelessWidget {
  const RingStat({
    super.key,
    required this.color,
    required this.label,
    required this.value,
    required this.goal,
  });

  final Color color;
  final String label;
  final String value;
  final String goal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: Spacing.sm),
            Text(
              label.toUpperCase(),
              style: AppType.caption
                  .copyWith(fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppType.title2.copyWith(
                  color: c.ink,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              goal,
              style: AppType.caption
                  .copyWith(fontWeight: FontWeight.w600, color: c.ink3, letterSpacing: 0.5),
            ),
          ],
        ),
      ],
    );
  }
}

/// 3-up summary tile: icon + label / big number + unit / sub-line.
class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.type,
    required this.icon,
    required this.label,
    required this.big,
    this.unit,
    required this.sub,
    this.onTap,
  });

  final String type; // money | move | rituals
  final String icon;
  final String label;
  final String big;
  final String? unit;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(type);
    return PressScale(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        // kept literal: the Today 3-up grid caps this tile at ~100px, so snapping
        // 14→Spacing.lg(16) overflows the height-constrained content.
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(icon, size: 16, color: color),
                const SizedBox(width: Spacing.sm),
                Text(
                  label,
                  style: AppType.footnote
                      .copyWith(fontWeight: FontWeight.w600, color: color, letterSpacing: -0.15),
                ),
              ],
            ),
            // height-capped tile: snap the label→number gap DOWN to xs so the
            // token doesn't push content past the ~100px grid cap.
            const SizedBox(height: Spacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  big,
                  style: AppFonts.sfr(size: 28, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.3),
                ),
                if (unit != null) ...[
                  const SizedBox(width: Spacing.xs),
                  Text(
                    unit!,
                    style: AppType.footnote
                        .copyWith(fontWeight: FontWeight.w600, color: c.ink3, letterSpacing: 0.3),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Text(
              sub,
              style: AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.08),
            ),
          ],
        ),
      ),
    );
  }
}
