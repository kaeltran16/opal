import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/loop_tab_bar.dart';
import '../../widgets/press_scale.dart';
import '../../router.dart';

/// The persistent app shell: the indexed-stack tab bodies (from go_router's
/// [StatefulNavigationShell]) plus the visual [LoopTabBar] and center FAB.
///
/// The bar shows four primary destinations (Today, Workout, Nutrition) plus a
/// "More" button. Tapping More opens a blurred overflow popover above the bar
/// (Sleep, Mood, Routines) — those are tab-style branches hidden behind it, so
/// the More tab stays lit and the popover marks the active one.
class LoopShell extends StatefulWidget {
  const LoopShell({super.key, required this.navigationShell});

  /// The branch navigator stack provided by `StatefulShellRoute.indexedStack`.
  final StatefulNavigationShell navigationShell;

  @override
  State<LoopShell> createState() => _LoopShellState();
}

class _LoopShellState extends State<LoopShell> {
  bool _moreOpen = false;

  /// Maps a branch index to its tab/destination id. Order must match the
  /// branches in [createRouter].
  static const _branchIds = [
    'today',
    'move',
    'nutrition',
    'rituals',
    'sleep',
    'mood',
  ];

  /// Destinations hidden behind the More overflow popover, in display order.
  static const _overflow = [
    _OverflowDest('sleep', 'Sleep', 'moon.stars.fill'),
    _OverflowDest('mood', 'Mood', 'heart.fill'),
    _OverflowDest('rituals', 'Routines', 'sparkles'),
  ];

  static const _overflowIds = {'sleep', 'mood', 'rituals'};

  /// The id of the visible tab to highlight: a primary tab, or 'more' whenever
  /// an overflow destination is active or the popover is open.
  String get _activeId {
    if (_moreOpen) return 'more';
    final id = _branchIds[widget.navigationShell.currentIndex];
    return _overflowIds.contains(id) ? 'more' : id;
  }

  /// The active overflow destination (for the popover checkmark), or null.
  String? get _activeOverflowId {
    final id = _branchIds[widget.navigationShell.currentIndex];
    return _overflowIds.contains(id) ? id : null;
  }

  void _onTab(String id) {
    if (id == 'more') {
      setState(() => _moreOpen = !_moreOpen);
      return;
    }
    setState(() => _moreOpen = false);
    _goBranch(_branchIds.indexOf(id));
  }

  void _pickOverflow(String id) {
    setState(() => _moreOpen = false);
    _goBranch(_branchIds.indexOf(id));
  }

  void _goBranch(int index) {
    // initialLocation:true returns to the branch root if it's the active tab
    // (matches iOS tab double-tap-to-root behaviour).
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(child: widget.navigationShell),
          // Dim backdrop — tap anywhere outside the popover to dismiss.
          if (_moreOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _moreOpen = false),
                child: const ColoredBox(color: Color(0x0D000000)),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_moreOpen)
                  _MoreOverflowMenu(
                    destinations: _overflow,
                    activeId: _activeOverflowId,
                    onPick: _pickOverflow,
                  ),
                LoopTabBar(
                  active: _activeId,
                  onTab: _onTab,
                  // Handoff #2: the FAB now opens the unified Pal composer (the
                  // single input surface) instead of the old Quick-Actions menu.
                  onFab: () => context.pushNamed(AppRoute.palComposer.name),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One destination in the More overflow popover.
class _OverflowDest {
  const _OverflowDest(this.id, this.label, this.icon);
  final String id;
  final String label;
  final String icon;
}

/// The blurred floating popover that lists the overflow destinations. Mirrors
/// the design's tab-bar overflow: a translucent card inset above the bar, with
/// the active destination marked by a checkmark.
class _MoreOverflowMenu extends StatelessWidget {
  const _MoreOverflowMenu({
    required this.destinations,
    required this.activeId,
    required this.onPick,
  });

  final List<_OverflowDest> destinations;
  final String? activeId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.sm),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 220),
        curve: const Cubic(0.22, 1, 0.36, 1),
        tween: Tween(begin: 0, end: 1),
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.xl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 44,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.blur,
                  borderRadius: BorderRadius.circular(Radii.xl),
                  border: Border.all(color: c.hair, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final d in destinations)
                      _OverflowRow(
                        dest: d,
                        active: d.id == activeId,
                        onTap: () => onPick(d.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverflowRow extends StatelessWidget {
  const _OverflowRow({
    required this.dest,
    required this.active,
    required this.onTap,
  });

  final _OverflowDest dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.accent : c.ink;
    return PressScale(
      onTap: onTap,
      semanticLabel: dest.label,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.md - 1),
        decoration: BoxDecoration(
          color: active ? c.fill : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          children: [
            AppIcon(dest.icon, size: 21, color: color),
            const SizedBox(width: Spacing.md + 1),
            Text(
              dest.label,
              style: AppFonts.sf(
                size: 16,
                weight: FontWeight.w500,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            if (active) AppIcon('checkmark', size: 15, color: c.accent),
          ],
        ),
      ),
    );
  }
}

/// Simple centred placeholder body for tabs/screens not yet built.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.bg,
      child: Center(
        child: Text('$label — coming soon',
            style: AppType.body.copyWith(color: c.ink3)),
      ),
    );
  }
}
