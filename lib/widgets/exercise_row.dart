import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

const double _minHeight = 52;
const double _icon = 22;
const double _hairline = 1;
const double _rowGap = 14;
const int _nameMaxLines = 2;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// An exercise or routine on a hairline: a line icon, the name over its
/// detail, then a value or the caller's [trailing] controls.
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({
    super.key,
    required this.name,
    required this.detail,
    this.icon = 'dumbbell',
    this.value,
    this.onTap,
    this.trailing,
    this.first = false,
  });

  final String name;
  final String detail;
  final String icon;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = this.value;
    final trailing = this.trailing;
    final row = Container(
      constraints: const BoxConstraints(minHeight: _minHeight),
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      decoration: first
          ? null
          : BoxDecoration(border: Border(top: BorderSide(color: c.hair, width: _hairline))),
      child: Row(
        spacing: _rowGap,
        children: [
          AppIcon(icon, size: _icon, color: c.ink2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Spacing.xxs,
              children: [
                Text(name,
                    maxLines: _nameMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: c.ink)),
                // the detail is what a routine holds; it wraps rather than cut.
                Text(detail, style: AppType.subhead.copyWith(color: c.ink3)),
              ],
            ),
          ),
          if (value != null)
            Text(value,
                maxLines: 1,
                style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular))
          else
            ?trailing,
        ],
      ),
    );
    // with trailing controls the row keeps their own semantics.
    final label = trailing == null ? [name, detail, ?value].join(', ') : null;
    if (onTap == null) {
      if (label == null) return row;
      return Semantics(container: true, label: label, excludeSemantics: true, child: row);
    }
    return PressScale(onTap: onTap, semanticLabel: label, pressedScale: 1, child: row);
  }
}
