import 'package:flutter/widgets.dart';
import '../theme/theme.dart';
import 'app_icon.dart';

/// iOS inset-grouped section: optional uppercase header, rounded surface card,
/// optional footer. Children are typically [ListRow]s.
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
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
              child: Text(
                header!.toUpperCase(),
                style: AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.08),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: ColoredBox(
              color: c.surface,
              child: Column(children: children),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
              child: Text(
                footer!,
                style: AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.08),
              ),
            ),
        ],
      ),
    );
  }
}

/// Default iOS list row: tinted icon tile + title/subtitle + value + chevron,
/// with a hairline separator (inset to the title when an icon is present).
class ListRow extends StatefulWidget {
  const ListRow({
    super.key,
    this.icon,
    this.iconBg,
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.chevron = true,
    this.last = false,
    this.onTap,
  });

  final String? icon;
  final Color? iconBg;
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
    final tappable = widget.onTap != null;
    return Semantics(
      button: tappable,
      label: tappable ? widget.title : null,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: tappable ? (_) => _set(true) : null,
        onTapUp: tappable ? (_) => _set(false) : null,
        onTapCancel: tappable ? () => _set(false) : null,
        behavior: HitTestBehavior.opaque,
        // brief highlight (theme.fill) that fades over 180ms on release
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: _down ? c.fill : const Color(0x00000000),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Container(
                          width: 29,
                          height: 29,
                          decoration: BoxDecoration(
                            color: widget.iconBg ?? c.accent,
                            borderRadius: BorderRadius.circular(Radii.sm),
                          ),
                          alignment: Alignment.center,
                          child: AppIcon(icon, size: 17, color: c.onAccent),
                        ),
                        const SizedBox(width: Spacing.md),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.body.copyWith(color: c.ink, height: 22 / 17),
                            ),
                            if (widget.subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  widget.subtitle!,
                                  style: AppType.footnote
                                      .copyWith(color: c.ink3, letterSpacing: -0.08),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.value != null)
                        Padding(
                          padding: const EdgeInsets.only(left: Spacing.sm),
                          child: Text(
                            widget.value!,
                            style: AppType.body.copyWith(
                                color: widget.valueColor ?? c.ink3,
                                fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                        ),
                      if (widget.chevron)
                        Padding(
                          padding: const EdgeInsets.only(left: Spacing.sm),
                          child: AppIcon('chevron.right', size: 14, color: c.ink4),
                        ),
                    ],
                  ),
                ),
              ),
              if (!widget.last)
                Positioned(
                  left: icon != null ? 57 : Spacing.lg,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 0.5, color: c.hair),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
