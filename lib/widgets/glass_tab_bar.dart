import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'app_icon.dart';
import 'glass_surface.dart';
import 'press_scale.dart';

class GlassTab {
  const GlassTab(this.id, this.label, this.icon);
  final String id, label, icon;
}

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

  static const double _height = 62;
  static const double _inset = Spacing.xs;
  static const double _gap = Spacing.xxs;
  static const double _iconSize = 22;
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
      height: _height,
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
    return Semantics(
      key: const ValueKey('minimized'),
      container: true,
      selected: true,
      button: true,
      label: '${active.label} tab, expand tab bar',
      child: PressScale(
        onTap: onRestore,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: minimizedSize,
            child: Center(
              child: AppIcon(active.icon, size: _iconSize, color: c.accent),
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
    final color = active ? c.accent : c.ink;
    return Semantics(
      container: true,
      selected: active,
      button: true,
      label: tab.label,
      child: PressScale(
        onTap: onTap,
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? c.fill : null,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: Spacing.xxs,
              children: [
                AppIcon(tab.icon, size: GlassTabBar._iconSize, color: color),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption2.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
