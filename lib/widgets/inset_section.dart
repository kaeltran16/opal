import 'package:flutter/widgets.dart';
import '../theme/theme.dart';
import 'app_icon.dart';

const double _headerGap = Spacing.xs;
const double _rowMinHeight = 52;
const double _icon = 22;
const double _gap = 14;
const double _chevron = 16;
const double _hairline = 1;
const int _titleMaxLines = 2;
const double _valueShare = 0.5;
const Duration _highlightFade = Duration(milliseconds: 180);
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// An open list section: an optional heading, its rows on the screen gutter,
/// and an optional footer. No card, fill or clip. Children are typically
/// [ListRow]s.
class InsetSection extends StatelessWidget {
  const InsetSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin = const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // the heading and footer are their own nodes: loose text folds into
          // the nearest node above, which carries the rows with it.
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(bottom: _headerGap),
              child: Semantics(
                container: true,
                header: true,
                child: Text(header!, style: AppType.headline.copyWith(color: c.ink)),
              ),
            ),
          ...children,
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Semantics(
                container: true,
                child: Text(footer!, style: AppType.subhead.copyWith(color: c.ink3)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A tool row: optional line icon, title and subtitle, trailing value and a
/// chevron when it navigates, with a hairline between rows (inset to the text
/// when there is an icon).
class ListRow extends StatefulWidget {
  const ListRow({
    super.key,
    this.icon,
    this.iconBg,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.chevron = true,
    this.last = false,
    this.onTap,
  });

  final String? icon;

  /// Ignored. Kept only so existing call sites compile until the legacy
  /// tokens retire; the icon has no tile.
  final Color? iconBg;

  /// Ignored. Kept only so existing call sites compile until the legacy
  /// tokens retire; the icon is always ink2.
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final bool chevron;
  final bool last;
  final VoidCallback? onTap;

  @override
  State<ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<ListRow> {
  bool _down = false;

  void _set(bool down) => setState(() => _down = down);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icon = widget.icon;
    final value = widget.value;
    final tappable = widget.onTap != null;
    return Semantics(
      container: true,
      button: tappable,
      label: tappable ? (value == null ? widget.title : '${widget.title}, $value') : null,
      excludeSemantics: tappable,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: tappable ? (_) => _set(true) : null,
        onTapUp: tappable ? (_) => _set(false) : null,
        onTapCancel: tappable ? () => _set(false) : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // the highlight is a layer behind the row so nothing paints under the icon
            Positioned.fill(
              child: AnimatedContainer(duration: _highlightFade, color: _down ? c.fill : AppColors.clear),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _rowMinHeight),
              // the padding only keeps wrapped text off the hairline; a single line stays at the minimum
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: LayoutBuilder(
                  builder: (context, box) => Row(
                    children: [
                      if (icon != null) ...[
                        AppIcon(icon, size: _icon, color: c.ink2),
                        const SizedBox(width: _gap),
                      ],
                      Expanded(child: _texts(c)),
                      if (value != null) ...[
                        const SizedBox(width: _gap),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: box.maxWidth * _valueShare),
                          child: Text(
                            value,
                            textAlign: TextAlign.end,
                            style: AppType.subhead.copyWith(
                                color: widget.valueColor ?? c.ink3, fontFeatures: _tabular),
                          ),
                        ),
                      ],
                      // chevron only when the row actually navigates: an
                      // affordance either works or isn't shown
                      if (widget.chevron && tappable) ...[
                        const SizedBox(width: _gap),
                        AppIcon('chevron.right', size: _chevron, color: c.ink3),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.last)
              Positioned(
                left: icon != null ? _icon + _gap : 0,
                right: 0,
                bottom: 0,
                child: Container(height: _hairline, color: c.hair),
              ),
          ],
        ),
      ),
    );
  }

  Widget _texts(AppColors c) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            maxLines: _titleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: AppType.body.copyWith(color: c.ink),
          ),
          if (widget.subtitle != null)
            Text(widget.subtitle!, style: AppType.subhead.copyWith(color: c.ink3)),
        ],
      );
}
