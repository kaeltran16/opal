import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'controllers/spending_controller.dart';
import 'screens/detail/detail_screen.dart';
import 'screens/shell/loop_shell.dart';
import 'screens/today/today_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';

/// Named routes for the whole app. Later units slot their real screens into the
/// already-defined paths so deep links / Live Activity tap-through (U25) stay
/// stable. Each value carries its `name` (for `pushNamed`/`goNamed`) and `path`.
enum AppRoute {
  // Tab roots (branch roots of the StatefulShellRoute).
  today('today', '/today'),
  move('move', '/move'),
  rituals('rituals', '/rituals'),
  you('you', '/you'),

  // Today sub-routes / detail (stubbed until their units).
  spendingDetail('spendingDetail', 'spending'), // U09 -> /today/spending
  moveDetail('moveDetail', 'move-detail'), //       -> /today/move-detail
  ritualsDetail('ritualsDetail', 'rituals-detail'), //  /today/rituals-detail

  // Modal sheets / focus routes (stubbed; built in later units).
  quickActions('quickActions', '/quick-actions'), // U06
  newEntry('newEntry', '/entry/new'), //            U07
  askPal('askPal', '/pal'); //                      U16

  const AppRoute(this.name, this.path);

  final String name;
  final String path;
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _todayNavigatorKey = GlobalKey<NavigatorState>();
final _moveNavigatorKey = GlobalKey<NavigatorState>();
final _ritualsNavigatorKey = GlobalKey<NavigatorState>();
final _youNavigatorKey = GlobalKey<NavigatorState>();

/// Builds the app router. Kept as a function so tests can supply their own
/// `initialLocation` if needed.
GoRouter createRouter({String initialLocation = '/today'}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            LoopShell(navigationShell: navigationShell),
        branches: [
          // --- Today branch ---
          StatefulShellBranch(
            navigatorKey: _todayNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.today.path,
                name: AppRoute.today.name,
                builder: (context, state) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.spendingDetail.path,
                    name: AppRoute.spendingDetail.name,
                    builder: (context, state) =>
                        const DetailScreen(tracker: DetailTracker.money),
                  ),
                  GoRoute(
                    path: AppRoute.moveDetail.path,
                    name: AppRoute.moveDetail.name,
                    builder: (context, state) =>
                        const _DetailStub(title: 'Movement'),
                  ),
                  GoRoute(
                    path: AppRoute.ritualsDetail.path,
                    name: AppRoute.ritualsDetail.name,
                    builder: (context, state) =>
                        const _DetailStub(title: 'Rituals'),
                  ),
                ],
              ),
            ],
          ),
          // --- Move branch ---
          StatefulShellBranch(
            navigatorKey: _moveNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.move.path,
                name: AppRoute.move.name,
                builder: (context, state) =>
                    const PlaceholderScreen(label: 'Move'),
              ),
            ],
          ),
          // --- Rituals branch ---
          StatefulShellBranch(
            navigatorKey: _ritualsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.rituals.path,
                name: AppRoute.rituals.name,
                builder: (context, state) =>
                    const PlaceholderScreen(label: 'Rituals'),
              ),
            ],
          ),
          // --- You branch ---
          StatefulShellBranch(
            navigatorKey: _youNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.you.path,
                name: AppRoute.you.name,
                builder: (context, state) =>
                    const PlaceholderScreen(label: 'You'),
              ),
            ],
          ),
        ],
      ),

      // --- Modal / focus routes above the shell (full-screen for now) ---
      GoRoute(
        path: AppRoute.quickActions.path,
        name: AppRoute.quickActions.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const _DetailStub(title: 'Quick Actions'),
      ),
      GoRoute(
        path: AppRoute.newEntry.path,
        name: AppRoute.newEntry.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const _DetailStub(title: 'New Entry'),
      ),
      GoRoute(
        path: AppRoute.askPal.path,
        name: AppRoute.askPal.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const _DetailStub(title: 'Ask Pal'),
      ),
    ],
  );
}

/// Temporary full-screen stub for routes whose screens arrive in later units.
/// Provides a back affordance so navigation is testable now.
class _DetailStub extends StatelessWidget {
  const _DetailStub({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new,
                        size: 18, color: c.accent),
                    onPressed: () => context.pop(),
                  ),
                  Text(title,
                      style: AppFonts.sf(
                          size: 17,
                          weight: FontWeight.w600,
                          color: c.ink,
                          letterSpacing: -0.43)),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text('$title — coming soon',
                    style: AppFonts.sf(
                        size: 17, color: c.ink3, letterSpacing: -0.43)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
