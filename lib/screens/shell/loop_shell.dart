import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/areas_controller.dart';
import '../../theme/theme.dart';
import '../../widgets/state_colors.dart';
import '../../widgets/glass_tab_bar.dart';
import '../../widgets/pal_ask_bar.dart';
import '../../router.dart';

/// The space between the tab bar and the ask bar above it.
const double _askGapAbove = 10;

/// What the floating tab bar and ask bar cover at the bottom of a tab, above
/// the safe area.
const double kShellOverlay =
    GlassTabBar.bottomGap + GlassTabBar.expandedHeight + _askGapAbove + PalAskBar.height;

/// The bottom padding every scrolling screen under the shell ends with, so its
/// last row scrolls clear of the floating bars. One value, so no page clips.
double shellBottomInset(BuildContext context) =>
    kShellOverlay + Spacing.xxl + MediaQuery.paddingOf(context).bottom;

/// The persistent app shell: the indexed-stack tab bodies (from go_router's
/// [StatefulNavigationShell]) under a floating [GlassTabBar] and [PalAskBar].
///
/// Scrolling a tab's content down minimizes the bar to a circle and slides
/// the ask bar beside it; scrolling back up, tapping the circle or switching
/// tabs restores it.
class LoopShell extends ConsumerStatefulWidget {
  const LoopShell({super.key, required this.navigationShell});

  /// The branch navigator stack provided by `StatefulShellRoute.indexedStack`.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<LoopShell> createState() => _LoopShellState();
}

class _LoopShellState extends ConsumerState<LoopShell> {
  static const _areasId = 'areas';

  /// Order must match the branches in [createRouter].
  static const _tabs = [
    GlassTab('today', 'Today', 'sun.max.fill'),
    GlassTab(_areasId, 'Areas', 'square.grid.2x2.fill'),
    GlassTab('move', 'Workout', 'dumbbell.fill'),
    GlassTab('you', 'You', 'person.crop.circle.fill'),
  ];

  static const double _askGapBeside = Spacing.sm;
  static const Duration _transition = Duration(milliseconds: 240);

  bool _minimized = false;

  String get _activeId => _tabs[widget.navigationShell.currentIndex].id;

  /// [_tabs], with the Areas tab carrying its state dot and spoken states.
  /// While the summary loads or fails, the tab is plain.
  List<GlassTab> _tabsWith(AreasSummary? areas, AppColors c) {
    if (areas == null) return _tabs;
    final dot = areas.tabDot;
    return [
      for (final t in _tabs)
        t.id == _areasId
            ? GlassTab(
                t.id,
                t.label,
                t.icon,
                dot: dot == null ? null : c.arcFor(dot),
                semanticLabel: areas.tabSemanticLabel,
              )
            : t,
    ];
  }

  @override
  void didUpdateWidget(LoopShell old) {
    super.didUpdateWidget(old);
    if (old.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _minimized = false;
    }
  }

  void _onTab(String id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    // initialLocation:true returns to the branch root if it's the active tab
    // (matches iOS tab double-tap-to-root behaviour).
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  bool _onUserScroll(UserScrollNotification n) {
    // horizontal carousels inside a tab must not toggle the bar.
    if (n.metrics.axis != Axis.vertical) return false;
    final minimized = switch (n.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _minimized,
    };
    if (minimized != _minimized) setState(() => _minimized = minimized);
    return false;
  }

  void _openComposer() => context.pushNamed(AppRoute.palComposer.name,
      queryParameters: {'from': GoRouterState.of(context).uri.path});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final summary = ref.watch(areasSummaryProvider);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final askBottom = safeBottom +
        GlassTabBar.bottomGap +
        (_minimized ? 0 : GlassTabBar.expandedHeight + _askGapAbove);
    final askLeft = GlassTabBar.sideInset +
        (_minimized ? GlassTabBar.minimizedSize + _askGapBeside : 0);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onUserScroll,
              child: widget.navigationShell,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassTabBar(
              tabs: _tabsWith(summary.hasError ? null : summary.value, c),
              activeId: _activeId,
              onTab: _onTab,
              minimized: _minimized,
              onRestore: () => setState(() => _minimized = false),
            ),
          ),
          AnimatedPositioned(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : _transition,
            curve: Curves.easeOutCubic,
            left: askLeft,
            right: GlassTabBar.sideInset,
            bottom: askBottom,
            // the mic opens the composer too until dictation lands.
            child: PalAskBar(onAsk: _openComposer, onMic: _openComposer),
          ),
        ],
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
