import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../theme/theme.dart';
import 'app_icon.dart';
import 'glass_surface.dart';
import 'press_scale.dart';

// clears the status bar above the first header row.
const double _statusPad = 56;
// every header row is one 44pt touch target tall.
const double _row = 44;
// line heights of the text the header reserves room for.
const double _eyebrowLine = 18;
const double _titleLine = 27;
const double _subtitleLine = 20;
const double _compactGap = Spacing.sm;
const double _bottomPad = Spacing.sm;
const double _hairline = 1;
const double _navGlyph = 20;

TextStyle _titleStyle(AppColors c) => AppType.title.copyWith(color: c.ink);

TextStyle _subtitleStyle(AppColors c) => AppType.subhead
    .copyWith(color: c.ink3, height: _subtitleLine / AppType.subhead.fontSize!);

/// Static large-title navigation header. [leading] (back) sits on its own row;
/// the title shares the next row with [trailing].
class LargeTitleNavBar extends StatelessWidget {
  const LargeTitleNavBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bg,
      padding:
          const EdgeInsets.fromLTRB(Spacing.lg, _statusPad, Spacing.lg, _bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null)
            SizedBox(
              height: _row,
              child: Align(alignment: Alignment.centerLeft, child: leading),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _row),
            child: Row(
              children: [
                Expanded(child: Text(title, style: _titleStyle(c))),
                if (trailing != null) ...[
                  const SizedBox(width: _compactGap),
                  trailing!,
                ],
              ],
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xxs),
              child: Text(subtitle!, style: _subtitleStyle(c)),
            ),
        ],
      ),
    );
  }
}

/// Scroll view with a large title that collapses to a compact, pinned inline
/// title as the content scrolls up. Drop-in replacement for the common
/// `ListView(children: [LargeTitleNavBar(...), ...body])` pattern: pass the nav
/// fields here and the former body children via [children].
class LargeTitleScrollView extends StatelessWidget {
  const LargeTitleScrollView({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.largeTitle,
    this.leading,
    this.trailing,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.physics,
  });

  final String title;
  final String? subtitle;

  /// A small line above the large title (Today's date).
  final String? eyebrow;

  /// The expanded title when it differs from the compact [title] (Today's
  /// greeting collapses to "Today").
  final String? largeTitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    // Paint the page background ourselves so the view doesn't depend on an
    // ancestor Scaffold. Routes pushed above the shell (e.g. /you, the Pal hub)
    // have no Scaffold, so without this the platform default shows through —
    // black on iOS — behind the list, hiding the dark large title in light mode.
    return ColoredBox(
      color: context.colors.bg,
      child: CustomScrollView(
        controller: controller,
        physics: physics,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _CollapsingNavDelegate(
              colors: context.colors,
              textScaler: MediaQuery.textScalerOf(context),
              title: title,
              subtitle: subtitle,
              eyebrow: eyebrow,
              largeTitle: largeTitle,
              leading: leading,
              trailing: trailing,
            ),
          ),
          SliverPadding(
            padding: padding,
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      ),
    );
  }
}

enum _Slot { leading, trailing, compact, eyebrow, title, subtitle }

class _CollapsingNavDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingNavDelegate({
    required this.colors,
    required this.textScaler,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.largeTitle,
    this.leading,
    this.trailing,
  });

  final AppColors colors;
  final TextScaler textScaler;
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? largeTitle;
  final Widget? leading;
  final Widget? trailing;

  // the status inset + one 44pt row form the pinned (collapsed) bar. at rest
  // the leading gets that row and the title row follows it; without a leading
  // the title row is the bar row itself, as on the canvas.
  double get _eyebrowBlock =>
      eyebrow != null ? textScaler.scale(_eyebrowLine) + Spacing.xxs : 0;
  double get _titleRow => math.max(_row, textScaler.scale(_titleLine));
  double get _subtitleBlock =>
      subtitle != null ? Spacing.xxs + textScaler.scale(_subtitleLine) : 0;

  /// The title row's top at rest, measured from the bottom of the status inset.
  double get _titleTop => (leading != null ? _row : 0) + _eyebrowBlock;

  @override
  double get minExtent => _statusPad + _row;

  @override
  double get maxExtent =>
      _statusPad + _titleTop + _titleRow + _subtitleBlock + _bottomPad;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = colors;
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final largeOpacity = (1 - t * 1.5).clamp(0.0, 1.0);
    final compactOpacity = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
    // glass only once content slides under the bar; at rest it's plain page.
    final atRest = t == 0;
    final bar = Container(
      height: minExtent,
      decoration: BoxDecoration(
        color: atRest ? c.bg : null,
        border: Border(
          bottom: BorderSide(
            color: c.hair.withValues(alpha: compactOpacity),
            width: _hairline,
          ),
        ),
      ),
    );

    // the large title, eyebrow and subtitle exist only while visible, and the
    // compact title only once collapsing, so the title text is in the tree
    // exactly once at rest and once collapsed.
    Widget large(_Slot slot, Widget child) => LayoutId(
          id: slot,
          child: Opacity(opacity: largeOpacity, child: child),
        );

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: atRest
                ? bar
                : GlassSurface(borderRadius: BorderRadius.zero, child: bar),
          ),
          Positioned.fill(
            top: _statusPad,
            child: ClipRect(
              child: CustomMultiChildLayout(
                delegate: _NavLayout(
                  titleTop: _titleTop - shrinkOffset,
                  titleRow: _titleRow,
                  eyebrowBlock: _eyebrowBlock,
                ),
                children: [
                  if (largeOpacity > 0) ...[
                    if (eyebrow != null)
                      large(
                        _Slot.eyebrow,
                        Text(
                          eyebrow!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.label.copyWith(color: c.ink3),
                        ),
                      ),
                    large(
                      _Slot.title,
                      Semantics(
                        header: true,
                        child: largeTitle == null
                            ? Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _titleStyle(c),
                              )
                            // a long greeting scales down to one line rather
                            // than being cut.
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(largeTitle!,
                                    maxLines: 1, style: _titleStyle(c)),
                              ),
                      ),
                    ),
                    if (subtitle != null)
                      large(
                        _Slot.subtitle,
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _subtitleStyle(c),
                        ),
                      ),
                  ],
                  if (compactOpacity > 0)
                    LayoutId(
                      id: _Slot.compact,
                      child: Opacity(
                        opacity: compactOpacity,
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.headline.copyWith(color: c.ink),
                          ),
                        ),
                      ),
                    ),
                  if (leading != null)
                    LayoutId(id: _Slot.leading, child: leading!),
                  if (trailing != null)
                    LayoutId(id: _Slot.trailing, child: trailing!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsingNavDelegate old) =>
      old.title != title ||
      old.subtitle != subtitle ||
      old.eyebrow != eyebrow ||
      old.largeTitle != largeTitle ||
      old.colors != colors ||
      old.textScaler != textScaler ||
      old.leading != leading ||
      old.trailing != trailing;
}

/// Lays the header out below the status inset. The bar row is at the top;
/// [titleTop] is where the title row currently sits, so it already includes
/// the scroll offset.
class _NavLayout extends MultiChildLayoutDelegate {
  _NavLayout({
    required this.titleTop,
    required this.titleRow,
    required this.eyebrowBlock,
  });

  final double titleTop;
  final double titleRow;
  final double eyebrowBlock;

  @override
  void performLayout(Size size) {
    final inner = size.width - 2 * Spacing.lg;
    var leadW = 0.0;
    var trailW = 0.0;

    if (hasChild(_Slot.leading)) {
      final s = layoutChild(_Slot.leading, BoxConstraints.loose(Size(inner, _row)));
      positionChild(_Slot.leading, Offset(Spacing.lg, (_row - s.height) / 2));
      leadW = s.width;
    }
    if (hasChild(_Slot.trailing)) {
      final s = layoutChild(_Slot.trailing, BoxConstraints.loose(Size(inner, _row)));
      // rides up with the title row, then pins in the bar row.
      final riding = titleTop + (titleRow - s.height) / 2;
      final pinned = (_row - s.height) / 2;
      positionChild(
        _Slot.trailing,
        Offset(size.width - Spacing.lg - s.width, math.max(pinned, riding)),
      );
      trailW = s.width;
    }
    if (hasChild(_Slot.compact)) {
      // equal insets keep the compact title centred and clear of both sides.
      final side = Spacing.lg + math.max(leadW, trailW) + _compactGap;
      final s = layoutChild(
        _Slot.compact,
        BoxConstraints.loose(Size(math.max(0.0, size.width - 2 * side), _row)),
      );
      positionChild(
        _Slot.compact,
        Offset((size.width - s.width) / 2, (_row - s.height) / 2),
      );
    }
    if (hasChild(_Slot.eyebrow)) {
      layoutChild(_Slot.eyebrow, BoxConstraints.loose(Size(inner, eyebrowBlock)));
      positionChild(_Slot.eyebrow, Offset(Spacing.lg, titleTop - eyebrowBlock));
    }
    if (hasChild(_Slot.title)) {
      final width = trailW > 0 ? inner - trailW - _compactGap : inner;
      final s = layoutChild(
        _Slot.title,
        BoxConstraints.loose(Size(math.max(0.0, width), titleRow)),
      );
      positionChild(
        _Slot.title,
        Offset(Spacing.lg, titleTop + (titleRow - s.height) / 2),
      );
    }
    if (hasChild(_Slot.subtitle)) {
      layoutChild(_Slot.subtitle, BoxConstraints.loose(Size(inner, size.height)));
      positionChild(
        _Slot.subtitle,
        Offset(Spacing.lg, titleTop + titleRow + Spacing.xxs),
      );
    }
  }

  @override
  bool shouldRelayout(_NavLayout old) =>
      old.titleTop != titleTop ||
      old.titleRow != titleRow ||
      old.eyebrowBlock != eyebrowBlock;
}

/// The 44pt `surface2` circle with an `ink` glyph used in nav trailing slots.
class NavIconButton extends StatelessWidget {
  const NavIconButton({super.key, required this.name, this.onTap, this.semanticLabel});

  final String name;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: _row,
        height: _row,
        decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: AppIcon(name, size: _navGlyph, color: c.ink),
      ),
    );
  }
}

/// A single nav-bar action — a text label and/or leading SF-symbol icon shown in
/// a header corner, with a guaranteed 44pt tap target (iOS HIG). The shared
/// replacement for the per-screen Cancel / Add / Save / Done / back buttons; use
/// it in the leading/trailing slots of [LargeTitleNavBar] and in
/// modal-sheet headers so every screen gets the same comfortable hit area.
class NavAction extends StatelessWidget {
  const NavAction({
    super.key,
    this.label,
    this.icon,
    this.onTap,
    this.bold = false,
    this.enabled = true,
    this.color,
    this.semanticLabel,
  }) : assert(label != null || icon != null, 'NavAction needs a label or icon');

  final String? label;
  final String? icon;
  final VoidCallback? onTap;
  final bool bold;
  final bool enabled;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = enabled ? (color ?? c.ink) : c.ink4;
    return PressScale(
      onTap: enabled ? onTap : null,
      semanticLabel: semanticLabel ?? label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        child: SizedBox(
          height: _row,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) AppIcon(icon!, size: _navGlyph, color: tint),
              if (icon != null && label != null) const SizedBox(width: Spacing.xxs),
              if (label != null)
                Text(
                  label!,
                  style: (bold ? AppType.headline : AppType.body).copyWith(color: tint),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
