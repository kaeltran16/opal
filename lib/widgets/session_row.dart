import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'press_scale.dart';

const double _minHeight = 48;
const double _whenWidth = 44;
const double _hairline = 1;
const double _rowGap = Spacing.md;
const int _titleMaxLines = 2;
// the detail and New best take at most this share, so the title keeps the rest.
const double _trailingShare = 0.5;
const String _newBest = 'New best';
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// A logged session on a hairline: when, what, how much, and `New best`
/// when it set a record.
class SessionRow extends StatelessWidget {
  const SessionRow({
    super.key,
    required this.when,
    required this.title,
    required this.detail,
    this.newBest = false,
    this.onTap,
    this.first = false,
  });

  final String when;
  final String title;
  final String detail;
  final bool newBest;
  final VoidCallback? onTap;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = [title, when, detail, if (newBest) 'new best'].join(', ');
    final row = Container(
      constraints: const BoxConstraints(minHeight: _minHeight),
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      decoration: first
          ? null
          : BoxDecoration(border: Border(top: BorderSide(color: c.hair, width: _hairline))),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          spacing: _rowGap,
          children: [
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(_whenWidth),
              // "Yesterday" is wider than the column; shrink it rather than cut it.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(when, maxLines: 1, style: AppType.caption.copyWith(color: c.ink3)),
              ),
            ),
            Expanded(
              child: Text(title,
                  maxLines: _titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.callout.copyWith(color: c.ink)),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * _trailingShare),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: _rowGap,
                children: [
                  Flexible(
                    child: Text(detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular)),
                  ),
                  if (newBest)
                    Text(_newBest, maxLines: 1, style: AppType.subhead.copyWith(color: c.thrivingInk)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) {
      return Semantics(container: true, label: label, excludeSemantics: true, child: row);
    }
    return PressScale(onTap: onTap, semanticLabel: label, pressedScale: 1, child: row);
  }
}
