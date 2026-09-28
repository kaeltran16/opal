import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'press_scale.dart';

/// Dot + label + big value + goal, shown beside the activity rings on Today.
/// Tappable when [onTap] is given (drills into the matching detail screen).
class RingStat extends StatelessWidget {
  const RingStat({
    super.key,
    required this.color,
    required this.label,
    required this.value,
    required this.goal,
    this.onTap,
  });

  final Color color;
  final String label;
  final String value;
  final String goal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6), // kept literal: 6 dot gap is off the spacing grid
            Text(
              label.toUpperCase(),
              style: AppFonts.sf(size: 12, weight: FontWeight.w700, color: color, letterSpacing: 0.5), // kept literal: 12pt w700 tracked eyebrow, caption is w400 untracked
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
                  size: 22, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.3, tabular: true), // kept literal: 22pt w700 tracked tabular, title2 is untracked
            ),
            const SizedBox(width: 3), // kept literal: 3 baseline gap is off the spacing grid
            Text(
              goal,
              style: AppFonts.sf(size: 12, weight: FontWeight.w600, color: c.ink3, letterSpacing: 0.5), // kept literal: 12pt w600 tracked, caption is w400 untracked
            ),
          ],
        ),
      ],
    );
    if (onTap == null) return content;
    return PressScale(semanticLabel: label, onTap: onTap, child: content);
  }
}
