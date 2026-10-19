import 'package:flutter/widgets.dart';

import '../analysis/area_state.dart';
import '../theme/theme.dart';
import 'state_colors.dart';

const double _barHeight = 4;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// One thing shaping an area's number: its name, its value, and how far along
/// it is. [off] is the state a contributor that is off track puts its area
/// in, which colours it; null while it is on track.
class ContributorBar extends StatelessWidget {
  const ContributorBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.off,
  });

  final String label;
  final String value;
  final double fraction;
  final AreaState? off;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final off = this.off;
    final radius = BorderRadius.circular(Radii.pill);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(label, style: AppType.subhead.copyWith(color: c.ink2)),
              ),
              const SizedBox(width: Spacing.md),
              Text(
                value,
                // DESIGN.md 9: amounts are never bold; ink against the ink2
                // label is the emphasis.
                style: AppType.subhead.copyWith(
                  color: off == null ? c.ink : c.wordInkFor(off),
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(color: c.track, borderRadius: radius),
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0,
            child: Container(
              height: _barHeight,
              decoration: BoxDecoration(
                  color: off == null ? c.ink : c.arcFor(off), borderRadius: radius),
            ),
          ),
        ),
      ],
    );
  }
}
