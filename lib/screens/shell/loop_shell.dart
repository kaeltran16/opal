import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/loop_tab_bar.dart';
import '../../router.dart';

/// The persistent app shell: the indexed-stack tab bodies (from go_router's
/// [StatefulNavigationShell]) plus the visual [LoopTabBar] and center FAB.
/// Replaces the old string-switch `HomeShell`.
class LoopShell extends StatelessWidget {
  const LoopShell({super.key, required this.navigationShell});

  /// The branch navigator stack provided by `StatefulShellRoute.indexedStack`.
  final StatefulNavigationShell navigationShell;

  /// Maps a branch index to the [LoopTabBar] string id and back.
  static const _tabIds = ['today', 'move', 'rituals', 'you'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeId = _tabIds[navigationShell.currentIndex];
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LoopTabBar(
              active: activeId,
              onTab: (id) => _goBranch(_tabIds.indexOf(id)),
              // Handoff #2: the FAB now opens the unified Pal composer (the
              // single input surface) instead of the old Quick-Actions menu.
              onFab: () => context.pushNamed(AppRoute.palComposer.name),
            ),
          ),
        ],
      ),
    );
  }

  void _goBranch(int index) {
    // initialLocation:true returns to the branch root if it's the active tab
    // (matches iOS tab double-tap-to-root behaviour).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
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
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
    );
  }
}
