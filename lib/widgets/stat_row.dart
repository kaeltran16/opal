import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

const double _hairline = 1;
const double _labelGap = Spacing.xxs;
const int _labelMaxLines = 2;

// the canvas's stat number: score's light tabular face at 28/32.
final TextStyle _statValue = AppType.score.copyWith(fontSize: 28, height: 32 / 28, letterSpacing: -0.6);

/// One number in a [StatRow].
class Stat {
  const Stat({required this.value, this.unit, required this.label});

  final String value;
  final String? unit;
  final String label;
}

/// Equal columns of light numbers, split by a hairline.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.stats});

  final List<Stat> stats;

  @override
  Widget build(BuildContext context) {
    // intrinsic height so every divider runs the full row when a label wraps.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, stat) in stats.indexed)
            Expanded(child: _StatColumn(stat: stat, divided: i > 0)),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.stat, required this.divided});

  final Stat stat;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unit = stat.unit;
    return Container(
      padding: divided ? const EdgeInsets.only(left: Spacing.lg) : EdgeInsets.zero,
      decoration: divided
          ? BoxDecoration(border: Border(left: BorderSide(color: c.hair, width: _hairline)))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _labelGap,
        children: [
          // scale a long value down rather than overflow the column.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: stat.value),
                if (unit != null)
                  TextSpan(text: ' $unit', style: AppType.subhead.copyWith(color: c.ink3)),
              ]),
              maxLines: 1,
              style: _statValue.copyWith(color: c.ink),
            ),
          ),
          Text(stat.label,
              maxLines: _labelMaxLines,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(color: c.ink3)),
        ],
      ),
    );
  }
}
