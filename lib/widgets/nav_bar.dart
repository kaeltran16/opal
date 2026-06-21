import 'package:flutter/widgets.dart';
import '../theme/theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

/// iOS large-title navigation header (static, non-collapsing variant used by the
/// prototype). A scroll-collapsing version can wrap this in a SliverPersistentHeader later.
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
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 56, Spacing.lg, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [leading ?? const SizedBox.shrink(), trailing ?? const SizedBox.shrink()],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            title,
            style: AppType.large.copyWith(
              color: c.ink,
              letterSpacing: 0.37,
              height: 41 / 34,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xxs),
              child: Text(
                subtitle!,
                style: AppType.subhead.copyWith(color: c.ink3, letterSpacing: -0.24),
              ),
            ),
        ],
      ),
    );
  }
}

/// Scroll view with an iOS-style large title that collapses to a compact,
/// pinned inline title as the content scrolls up (README "Large-title nav bar":
/// 34/700 large title → 17/600 compact). Drop-in replacement for the common
/// `ListView(children: [LargeTitleNavBar(...), ...body])` pattern: pass the nav
/// fields here and the former body children via [children].
class LargeTitleScrollView extends StatelessWidget {
  const LargeTitleScrollView({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

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
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _CollapsingNavDelegate(
              colors: context.colors,
              title: title,
              subtitle: subtitle,
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

class _CollapsingNavDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingNavDelegate({
    required this.colors,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final AppColors colors;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  // The status inset + a 44pt nav row form the pinned (collapsed) bar; the large
  // title block lives in the extra extent and slides up behind the bar.
  static const double _statusPad = 56;
  static const double _navRow = 44;
  static const double _titleH = 41;
  static const double _subtitleH = 19;
  static const double _bottomPad = 8;

  double get _titleBlock =>
      _titleH + (subtitle != null ? 2 + _subtitleH : 0) + _bottomPad;

  @override
  double get minExtent => _statusPad + _navRow;

  @override
  double get maxExtent => minExtent + _titleBlock;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = colors;
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final largeOpacity = (1 - t * 1.5).clamp(0.0, 1.0);
    final compactOpacity = ((t - 0.4) / 0.6).clamp(0.0, 1.0);

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // large title — drawn first so the opaque pinned bar occludes it as it
          // slides up. Omitted once fully collapsed so the title text exists
          // exactly once in the tree (compact OR large, never both at rest).
          if (largeOpacity > 0)
            Positioned(
              left: Spacing.lg,
              right: Spacing.lg,
              top: minExtent - shrinkOffset,
              child: Opacity(
                opacity: largeOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppType.large.copyWith(
                        color: c.ink,
                        letterSpacing: 0.37,
                        height: _titleH / 34,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.xxs),
                        child: Text(
                          subtitle!,
                          style: AppType.subhead
                              .copyWith(color: c.ink3, letterSpacing: -0.24),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // pinned bar: opaque background, hairline on collapse, then the
          // leading / compact-title / trailing row.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: minExtent,
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(
                  bottom: BorderSide(
                    color: c.hair.withValues(alpha: compactOpacity),
                    width: 0.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(top: _statusPad),
              child: SizedBox(
                height: _navRow,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (compactOpacity > 0)
                      Opacity(
                        opacity: compactOpacity,
                        child: Text(
                          title,
                          style: AppType.headline.copyWith(color: c.ink),
                        ),
                      ),
                    if (leading != null)
                      Positioned(
                          left: Spacing.lg,
                          child: leading!),
                    if (trailing != null)
                      Positioned(
                          right: Spacing.lg,
                          child: trailing!),
                  ],
                ),
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
      old.colors != colors ||
      old.leading != leading ||
      old.trailing != trailing;
}

/// 32×32 circular tinted icon button used in nav trailing slots. The visible
/// circle stays 32; the tap target is padded out to the 44pt iOS minimum.
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
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: c.fill, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: AppIcon(name, size: 17, color: c.accent),
          ),
        ),
      ),
    );
  }
}

/// A single nav-bar action — a text label and/or leading SF-symbol icon shown in
/// a header corner, with a guaranteed 44pt tap target (iOS HIG). The shared
/// replacement for the per-screen Cancel / Add / Save / Done / back buttons; use
/// it in the leading/trailing slots of [LargeTitleNavBar] / [EmailNavBar] and in
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
    final tint = enabled ? (color ?? c.accent) : c.ink4;
    return PressScale(
      onTap: enabled ? onTap : null,
      semanticLabel: semanticLabel ?? label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) AppIcon(icon!, size: 20, color: tint),
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
