import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'app_icon.dart';
import 'glass_surface.dart';
import 'press_scale.dart';

class GlassTab {
  const GlassTab(
    this.id,
    this.label,
    this.icon, {
    this.dot,
    this.semanticLabel,
  });
  final String id, label, icon;

  /// State ink for a dot at the icon's top right; null hides it.
  final Color? dot;

  /// Replaces [label] as the accessible label; the visible text stays [label].
  final String? semanticLabel;

  String get _a11yLabel => semanticLabel ?? label;
}

/// Key of a tab's dot, so the shell's tests can find it by tab.
ValueKey<String> glassTabDotKey(String id) => ValueKey('glassTabDot:$id');

/// Floating Liquid Glass tab bar. On scroll-down the shell sets [minimized],
/// which morphs the capsule into a circle showing the active tab so the ask
/// bar can sit beside it; tapping the circle calls [onRestore].
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onTab,
    required this.minimized,
    required this.onRestore,
  });

  /// Layout the shell reuses to place the ask bar beside the minimized circle.
  static const double sideInset = Spacing.lg;
  static const double bottomGap = Spacing.sm;
  static const double minimizedSize = 52;
  static const double expandedHeight = 62;

  static const double _inset = Spacing.xs;
  static const double _gap = Spacing.xxs;
  static const double _iconSize = 22;
  static const double _dotSize = 8;
  static const double _dotRing = 2;
  static const double _dotTop = -1;
  // the bar's height is fixed, so the label grows only as far as the room
  // under the icon, as an iOS tab bar's does.
  static final double _maxLabelScale =
      (expandedHeight - 2 * _inset - _iconSize - _gap) /
          (AppType.caption.fontSize! * AppType.caption.height!);
  static const double _dotRight = -4;
  static const Duration _transition = Duration(milliseconds: 240);

  final List<GlassTab> tabs;
  final String activeId;
  final ValueChanged<String> onTab;
  final bool minimized;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final state = minimized ? _minimized(context.colors) : _expanded();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(sideInset, 0, sideInset, bottomGap),
        child: Align(
          alignment: Alignment.bottomLeft,
          heightFactor: 1,
          // one glass instance morphs, so the blur never doubles mid-swap.
          child: GlassSurface(
            // reduce motion is a plain swap. AnimatedSize can't take
            // Duration.zero: it re-dirties itself during layout and asserts.
            child: MediaQuery.disableAnimationsOf(context)
                ? state
                : AnimatedSize(
                    duration: _transition,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: _transition,
                      // only the incoming child sizes the box, so AnimatedSize
                      // morphs in one step instead of waiting for the fade-out.
                      layoutBuilder: (current, _) =>
                          current ?? const SizedBox.shrink(),
                      child: state,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _expanded() {
    return SizedBox(
      key: const ValueKey('expanded'),
      width: double.infinity,
      height: expandedHeight,
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: Row(
          spacing: _gap,
          children: [
            for (final t in tabs)
              Expanded(
                child: _TabButton(
                  tab: t,
                  active: t.id == activeId,
                  onTap: () => onTab(t.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _minimized(AppColors c) {
    final active = tabs.firstWhere((t) => t.id == activeId);
    return MergeSemantics(
      key: const ValueKey('minimized'),
      child: Semantics(
        container: true,
        selected: true,
        button: true,
        label: '${active._a11yLabel} tab, expand tab bar',
        child: PressScale(
          onTap: onRestore,
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: minimizedSize,
              child: Center(
                child: _DottedIcon(tab: active, color: c.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final GlassTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.ink : c.ink3;
    // one stop per tab: PressScale's own tap node would otherwise sit beside
    // this label as a blank button.
    return MergeSemantics(
      child: Semantics(
        container: true,
        selected: active,
        button: true,
        label: tab._a11yLabel,
        child: PressScale(
          onTap: onTap,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: active ? c.surface2 : null,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: Spacing.xxs,
                children: [
                  _DottedIcon(tab: tab, color: color),
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: GlassTabBar._maxLabelScale,
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tab's icon with its state dot, ringed in the bar surface so it reads
/// against the icon stroke.
class _DottedIcon extends StatelessWidget {
  const _DottedIcon({required this.tab, required this.color});

  final GlassTab tab;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = AppIcon(tab.icon, size: GlassTabBar._iconSize, color: color);
    final dot = tab.dot;
    if (dot == null) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: GlassTabBar._dotTop,
          right: GlassTabBar._dotRight,
          // both callers already exclude semantics, so the dot stays silent.
          child: DecoratedBox(
            key: glassTabDotKey(tab.id),
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.colors.surface,
                width: GlassTabBar._dotRing,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: const SizedBox.square(dimension: GlassTabBar._dotSize),
          ),
        ),
      ],
    );
  }
}
