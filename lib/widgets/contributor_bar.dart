import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

const double _barHeight = 4;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// One thing shaping an area's number: its name, its value, and how far along
/// it is. [off] marks a contributor that is off track.
class ContributorBar extends StatelessWidget {
  const ContributorBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.off = false,
  });

  final String label;
  final String value;
  final double fraction;
  final bool off;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                  color: off ? c.watchInk : c.ink,
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
              decoration: BoxDecoration(color: off ? c.watch : c.ink, borderRadius: radius),
            ),
          ),
        ),
      ],
    );
  }
}
