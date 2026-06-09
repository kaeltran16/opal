import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';

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
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: AppFonts.sf(size: 12, weight: FontWeight.w700, color: color, letterSpacing: 0.5),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppFonts.sf(
                  size: 22, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.3, tabular: true),
            ),
            const SizedBox(width: 3),
            Text(
              goal,
              style: AppFonts.sf(size: 12, weight: FontWeight.w600, color: c.ink3, letterSpacing: 0.5),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppFonts.sf(size: 14, weight: FontWeight.w600, color: color, letterSpacing: -0.15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  big,
                  style: AppFonts.sfr(size: 28, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.3),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: AppFonts.sf(size: 13, weight: FontWeight.w600, color: c.ink3, letterSpacing: 0.3),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Text(
              sub,
              style: AppFonts.sf(size: 13, color: c.ink3, letterSpacing: -0.08),
            ),
          ],
        ),
      ),
    );
  }
}
