import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'analysis/area.dart';
import 'theme/theme.dart';
import 'screens/areas/areas_screen.dart';
import 'screens/detail/detail_screen.dart';
import 'screens/email/email_dashboard_screen.dart';
import 'screens/email/email_intro_screen.dart';
import 'screens/email/email_setup_screen.dart';
import 'screens/entry/new_entry_sheet.dart';
import 'screens/library/exercise_library_screen.dart';
import 'screens/move/move_screen.dart';
import 'screens/move/weekly_plan_screen.dart';
import 'screens/move/workout_history_screen.dart';
import 'screens/nutrition/nutrition_meal_detail_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/pal/pal_composer_screen.dart';
import 'screens/money/budgets_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/recap/recap_screen.dart';
import 'screens/reflect/evening_close_out_screen.dart';
import 'screens/reflect/streak_celebration_screen.dart';
import 'screens/rituals/rituals_builder_screen.dart';
import 'screens/rituals/routine_player_screen.dart';
import 'screens/workout/routine_generator_screen.dart';
import 'screens/settings/about_screen.dart';
import 'screens/settings/budgets_goals_screen.dart';
import 'screens/settings/appearance_screen.dart';
import 'screens/settings/export_data_screen.dart';
import 'screens/settings/notifications_screen.dart';
import 'screens/settings/privacy_screen.dart';
import 'screens/shell/loop_shell.dart';
import 'models/models.dart';
import 'services/pal/pal_service.dart' show InsightRange;
import 'screens/workout/active_session_screen.dart';
import 'screens/workout/post_workout_screen.dart';
import 'screens/workout/routine_editor_screen.dart';
import 'screens/workout/start_workout_screen.dart';
import 'screens/workout/workout_detail_screen.dart';
import 'screens/today/today_screen.dart';

/// Named routes for the whole app. Later units slot their real screens into the
/// already-defined paths so deep links / Live Activity tap-through (U25) stay
/// stable. Each value carries its `name` (for `pushNamed`/`goNamed`) and `path`.
enum AppRoute {
  // Tab roots (branch roots of the StatefulShellRoute).
  today('today', '/today'),
  areas('areas', '/areas'),
  move('move', '/move'),
  you('you', '/you'),

  // Area pages, under the Areas tab.
  areaMoney('areaMoney', 'money'), //               -> /areas/money
  areaMove('areaMove', 'move'), //                  -> /areas/move
  areaRoutines('areaRoutines', 'routines'), //      -> /areas/routines
  areaManageRoutines('areaManageRoutines', 'manage'), // /areas/routines/manage
  areaNutrition('areaNutrition', 'nutrition'), //   -> /areas/nutrition
  areaSleep('areaSleep', 'sleep'), //               -> /areas/sleep
  areaMood('areaMood', 'mood'), //                  -> /areas/mood

  // Nutrition sub-routes.
  nutritionMeal('nutritionMeal', 'meal/:id'), // -> /areas/nutrition/meal/:id
  nutritionPatterns('nutritionPatterns', 'patterns'), // /areas/nutrition/patterns -> /you

  // Old paths, kept as redirects so Siri / Live Activity links resolve.
  nutrition('nutrition', '/nutrition'),
  spendingDetail('spendingDetail', 'spending'), //  -> /today/spending
  moveDetail('moveDetail', 'move-detail'), //       -> /today/move-detail
  ritualsDetail('ritualsDetail', 'rituals-detail'), //  /today/rituals-detail
  todayRituals('todayRituals', 'rituals'), //       -> /today/rituals
  todayManageRituals('todayManageRituals', 'manage'), // /today/rituals/manage
  todaySleep('todaySleep', 'sleep'), //             -> /today/sleep
  todayMood('todayMood', 'mood'), //                -> /today/mood
  rituals('rituals', '/rituals'),
  manageRituals('manageRituals', 'manage'), //      -> /rituals/manage
  sleep('sleep', '/sleep'),
  mood('mood', '/mood'),

  // Move sub-routes.
  startWorkout('startWorkout', 'start'), //   U12 -> /move/start
  workoutDetail('workoutDetail', 'workout/:id'), // U15 -> /move/workout/:id
  workoutHistory('workoutHistory', 'history'), //   -> /move/history
  routineEditor('routineEditor', 'routine-editor'), // U21b -> /move/routine-editor

  // Workout focus routes (full-screen, above the shell — no tab bar).
  activeSession('activeSession', '/session/:routineId'), // U13
  postWorkout('postWorkout', '/post-workout'), //          U14 (stub)

  // You / Settings sub-routes (push within the You branch).
  youBudgets('youBudgets', 'budgets'), //           -> /you/budgets
  youInsights('youInsights', 'insights'), //        /you/insights -> /you
  budgetsGoals('budgetsGoals', 'budgets-goals'), // -> /you/budgets-goals
  notificationSettings('notificationSettings', 'notifications'), // /you/notifications
  appearance('appearance', 'appearance'), //        -> /you/appearance
  privacy('privacy', 'privacy'), //                 -> /you/privacy
  exportData('exportData', 'export'), //            -> /you/export
  about('about', 'about'), //                       -> /you/about

  // Modal sheets / focus routes (stubbed; built in later units).
  newEntry('newEntry', '/entry/new'), //            U07
  exerciseLibrary('exerciseLibrary', '/library'), // U11
  recap('recap', '/recap'), //                      consolidated Day/Week/Month
  monthlyReview('monthlyReview', '/monthly-review'), // U18 → redirects to recap
  emailSync('emailSync', '/email'), //              U20 Intro
  emailSetup('emailSetup', 'setup'), //             U20 -> /email/setup
  emailDashboard('emailDashboard', 'dashboard'), //  U20 -> /email/dashboard

  // --- Handoff #2 (Wave 6) ---
  // Pal composer — the unified FAB input surface (replaces Quick Actions menu).
  palComposer('palComposer', '/pal-composer'),
  // the old Pal hub paths, kept for stable deep links; all redirect to /you.
  palInbox('palInbox', '/pal-inbox'),
  palHome('palHome', '/pal-home'),
  pal('pal', '/pal'),
  eveningCloseOut('eveningCloseOut', '/close-out'),
  streakCelebration('streakCelebration', '/streak'),
  weeklyReview('weeklyReview', '/weekly-review'),
  // Move sub-routes (nest under /move so back returns to the Move tab).
  weeklyPlan('weeklyPlan', 'weekly-plan'), //          -> /move/weekly-plan
  routineGenerator('routineGenerator', 'routine-generator'), // /move/routine-generator
  // Rituals guided player — full-screen above the shell (no tab bar).
  routinePlayer('routinePlayer', '/rituals/player/:routineId'),

  // First-run onboarding (U17), full-screen above the shell.
  onboarding('onboarding', '/onboarding');

  const AppRoute(this.name, this.path);

  final String name;
  final String path;
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _todayNavigatorKey = GlobalKey<NavigatorState>();
final _areasNavigatorKey = GlobalKey<NavigatorState>();
final _moveNavigatorKey = GlobalKey<NavigatorState>();
final _youNavigatorKey = GlobalKey<NavigatorState>();

/// The page route of [area], under the Areas tab.
AppRoute areaRoute(Area area) => switch (area) {
      Area.money => AppRoute.areaMoney,
      Area.move => AppRoute.areaMove,
      Area.routines => AppRoute.areaRoutines,
      Area.nutrition => AppRoute.areaNutrition,
      Area.sleep => AppRoute.areaSleep,
      Area.mood => AppRoute.areaMood,
    };

/// The old Today children and where each moved under the Areas tab. The
/// rituals pair has a child of its own, so it is wired by hand.
const _movedFromToday = [
  (AppRoute.spendingDetail, AppRoute.areaMoney),
  (AppRoute.moveDetail, AppRoute.areaMove),
  (AppRoute.ritualsDetail, AppRoute.areaRoutines),
  (AppRoute.todaySleep, AppRoute.areaSleep),
  (AppRoute.todayMood, AppRoute.areaMood),
];

const _lightSheetScrim = 0.12;
const _darkSheetScrim = 0.35;

/// Builds the app router. Kept as a function so tests can supply their own
/// `initialLocation` if needed.
///
/// [isOnboardingComplete] is read on every navigation by the first-run gate
/// (see the `redirect` below). It defaults to `() => true` so existing call
/// sites / tests that don't care about onboarding are unaffected; `app.dart`
/// passes the live `SettingsRepository.onboardingComplete` getter.
GoRouter createRouter({
  String initialLocation = '/today',
  bool Function() isOnboardingComplete = _alwaysComplete,
}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    // --- U17 first-run gate (isolated; merge-safe) -------------------------
    // While onboarding is incomplete, force every route to /onboarding; once
    // complete, bounce away from /onboarding to Today. Returns null (no
    // redirect) in all other cases so unrelated navigation is untouched.
    redirect: (context, state) {
      final complete = isOnboardingComplete();
      final atOnboarding = state.matchedLocation == AppRoute.onboarding.path;
      if (!complete) return atOnboarding ? null : AppRoute.onboarding.path;
      if (atOnboarding) return AppRoute.today.path;
      return null;
    },
    // -----------------------------------------------------------------------
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
                // the area pages moved under the Areas tab; these old paths
                // redirect there.
                routes: [
                  for (final (from, to) in _movedFromToday)
                    GoRoute(
                      path: from.path,
                      name: from.name,
                      redirect: (context, state) =>
                          _childOf(AppRoute.areas, to, state),
                    ),
                  // a route-level redirect runs for every route in the match,
                  // so the parent only redirects its own path.
                  GoRoute(
                    path: AppRoute.todayRituals.path,
                    name: AppRoute.todayRituals.name,
                    redirect: (context, state) => state.uri.path ==
                            '${AppRoute.today.path}/${AppRoute.todayRituals.path}'
                        ? _childOf(AppRoute.areas, AppRoute.areaRoutines, state)
                        : null,
                    routes: [
                      GoRoute(
                        path: AppRoute.todayManageRituals.path,
                        name: AppRoute.todayManageRituals.name,
                        redirect: (context, state) =>
                            _childOf(AppRoute.areas, AppRoute.areaRoutines, state,
                                '/${AppRoute.areaManageRoutines.path}'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // --- Areas branch ---
          StatefulShellBranch(
            navigatorKey: _areasNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.areas.path,
                name: AppRoute.areas.name,
                builder: (context, state) => const AreasScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.areaMoney.path,
                    name: AppRoute.areaMoney.name,
                    builder: (context, state) =>
                        const DetailScreen(area: Area.money),
                  ),
                  GoRoute(
                    path: AppRoute.areaMove.path,
                    name: AppRoute.areaMove.name,
                    builder: (context, state) =>
                        const DetailScreen(area: Area.move),
                  ),
                  GoRoute(
                    path: AppRoute.areaRoutines.path,
                    name: AppRoute.areaRoutines.name,
                    builder: (context, state) =>
                        const DetailScreen(area: Area.routines),
                    routes: [
                      GoRoute(
                        path: AppRoute.areaManageRoutines.path,
                        name: AppRoute.areaManageRoutines.name,
                        builder: (context, state) =>
                            const RitualsBuilderScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: AppRoute.areaNutrition.path,
                    name: AppRoute.areaNutrition.name,
                    builder: (context, state) =>
                        const DetailScreen(area: Area.nutrition),
                    routes: [
                      GoRoute(
                        path: AppRoute.nutritionMeal.path,
                        name: AppRoute.nutritionMeal.name,
                        builder: (context, state) => NutritionMealDetailScreen(
                            mealId: state.pathParameters['id']!),
                      ),
                      // patterns live in Pal's findings on the You tab now.
                      GoRoute(
                        path: AppRoute.nutritionPatterns.path,
                        name: AppRoute.nutritionPatterns.name,
                        redirect: (context, state) => AppRoute.you.path,
                      ),
                    ],
                  ),
                  GoRoute(
                    path: AppRoute.areaSleep.path,
                    name: AppRoute.areaSleep.name,
                    builder: (context, state) =>
                        const DetailScreen(area: Area.sleep),
                  ),
                  GoRoute(
                    path: AppRoute.areaMood.path,
                    name: AppRoute.areaMood.name,
                    builder: (context, state) =>
                        const DetailScreen(area: Area.mood),
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
                builder: (context, state) => const MoveScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.startWorkout.path,
                    name: AppRoute.startWorkout.name,
                    builder: (context, state) => const StartWorkoutScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.workoutDetail.path,
                    name: AppRoute.workoutDetail.name,
                    builder: (context, state) => WorkoutDetailScreen(
                        workoutId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: AppRoute.workoutHistory.path,
                    name: AppRoute.workoutHistory.name,
                    builder: (context, state) => const WorkoutHistoryScreen(),
                  ),
                  // U21b — Routine Editor. `routineId` query param absent =
                  // create new; present = edit that routine.
                  GoRoute(
                    path: AppRoute.routineEditor.path,
                    name: AppRoute.routineEditor.name,
                    builder: (context, state) => RoutineEditorScreen(
                        routineId: state.uri.queryParameters['routineId']),
                  ),
                  // Handoff #2 — Weekly Plan (24) + AI Routine Generator.
                  GoRoute(
                    path: AppRoute.weeklyPlan.path,
                    name: AppRoute.weeklyPlan.name,
                    builder: (context, state) => const WeeklyPlanScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.routineGenerator.path,
                    name: AppRoute.routineGenerator.name,
                    builder: (context, state) => const RoutineGeneratorScreen(),
                  ),
                ],
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
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.youBudgets.path,
                    name: AppRoute.youBudgets.name,
                    builder: (context, state) => const BudgetsScreen(),
                  ),
                  // insights live in Pal's findings on this tab now.
                  GoRoute(
                    path: AppRoute.youInsights.path,
                    name: AppRoute.youInsights.name,
                    redirect: (context, state) => AppRoute.you.path,
                  ),
                  GoRoute(
                    path: AppRoute.budgetsGoals.path,
                    name: AppRoute.budgetsGoals.name,
                    builder: (context, state) => const BudgetsGoalsScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.notificationSettings.path,
                    name: AppRoute.notificationSettings.name,
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.appearance.path,
                    name: AppRoute.appearance.name,
                    builder: (context, state) => const AppearanceScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.privacy.path,
                    name: AppRoute.privacy.name,
                    builder: (context, state) => const PrivacyScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.exportData.path,
                    name: AppRoute.exportData.name,
                    builder: (context, state) => const ExportDataScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.about.path,
                    name: AppRoute.about.name,
                    builder: (context, state) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // --- Old tab paths, now area pages under the Areas tab ---
      // a route-level redirect runs for every route in the match, so the
      // parent only redirects its own path and leaves /rituals/manage to the
      // child. /rituals/player/:routineId doesn't match here and falls through.
      GoRoute(
        path: AppRoute.rituals.path,
        name: AppRoute.rituals.name,
        redirect: (context, state) => state.uri.path == AppRoute.rituals.path
            ? _childOf(AppRoute.areas, AppRoute.areaRoutines, state)
            : null,
        routes: [
          GoRoute(
            path: AppRoute.manageRituals.path,
            name: AppRoute.manageRituals.name,
            redirect: (context, state) => _childOf(AppRoute.areas,
                AppRoute.areaRoutines, state, '/${AppRoute.areaManageRoutines.path}'),
          ),
        ],
      ),
      for (final (from, to) in [
        (AppRoute.sleep, AppRoute.areaSleep),
        (AppRoute.mood, AppRoute.areaMood),
      ])
        GoRoute(
          path: from.path,
          name: from.name,
          redirect: (context, state) => _childOf(AppRoute.areas, to, state),
        ),
      // the parent runs first in the match and carries the rest of the path,
      // so the meal and patterns children redirect through it.
      GoRoute(
        path: AppRoute.nutrition.path,
        name: AppRoute.nutrition.name,
        redirect: _toAreaNutrition,
        routes: [
          for (final child in [AppRoute.nutritionMeal, AppRoute.nutritionPatterns])
            GoRoute(path: child.path, redirect: _toAreaNutrition),
        ],
      ),

      // --- Modal / focus routes above the shell (full-screen for now) ---
      GoRoute(
        path: AppRoute.newEntry.path,
        name: AppRoute.newEntry.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _sheetPage(
            state.pageKey,
            NewEntrySheet(
              initialKind: state.uri.queryParameters['kind'],
              notice: state.uri.queryParameters['notice'],
            )),
      ),
      GoRoute(
        path: AppRoute.exerciseLibrary.path,
        name: AppRoute.exerciseLibrary.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ExerciseLibraryScreen(),
      ),
      // U13 — Active workout session (focus route, no tab bar).
      GoRoute(
        path: AppRoute.activeSession.path,
        name: AppRoute.activeSession.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _sheetPage(state.pageKey,
            ActiveSessionScreen(routineId: state.pathParameters['routineId']!)),
      ),
      // U14 — Post-workout summary (focus route). The active session pushes
      // here on Finish, handing the finished Workout via `extra`.
      GoRoute(
        path: AppRoute.postWorkout.path,
        name: AppRoute.postWorkout.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _sheetPage(
            state.pageKey, PostWorkoutScreen(workout: state.extra as Workout?)),
      ),
      // Consolidated Recap (Day / Week / Month). `?range=` opens the matching
      // segment; absent/unknown defaults to Day.
      GoRoute(
        path: AppRoute.recap.path,
        name: AppRoute.recap.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state.pageKey,
          RecapScreen(initialRange: _rangeFrom(state.uri.queryParameters['range'])),
        ),
      ),
      // U18 — Monthly Review deep link kept stable; redirects into the Recap.
      GoRoute(
        path: AppRoute.monthlyReview.path,
        name: AppRoute.monthlyReview.name,
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/recap?range=month',
      ),
      // Email sync intro — real screens land in U20; stub for now so the
      // profile Integrations row has a stable deep-link target.
      // U20 — Email sync: Intro → Setup → Dashboard. Profile Integrations row
      // deep-links to the Intro; Setup/Dashboard nest so the /email prefix and
      // back-stack stay natural.
      GoRoute(
        path: AppRoute.emailSync.path,
        name: AppRoute.emailSync.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EmailIntroScreen(),
        routes: [
          GoRoute(
            path: AppRoute.emailSetup.path,
            name: AppRoute.emailSetup.name,
            builder: (context, state) => const EmailSetupScreen(),
          ),
          GoRoute(
            path: AppRoute.emailDashboard.path,
            name: AppRoute.emailDashboard.name,
            builder: (context, state) => const EmailDashboardScreen(),
          ),
        ],
      ),

      // --- Handoff #2 (Wave 6) routes, all above the shell ---
      // Pal composer: the unified input surface. Presented over a dim,
      // tap-to-dismiss backdrop; optional `?seed=` pre-fills + expands it.
      GoRoute(
        path: AppRoute.palComposer.path,
        name: AppRoute.palComposer.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final seed = state.uri.queryParameters['seed'];
          final c = context.colors;
          // a light scrim keeps the page readable through the glass sheet.
          final scrimAlpha =
              c.brightness == Brightness.dark ? _darkSheetScrim : _lightSheetScrim;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierDismissible: true,
            barrierColor: c.scrim.withValues(alpha: scrimAlpha),
            fullscreenDialog: true,
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder: (context, animation, secondary, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: const Cubic(0.22, 1, 0.36, 1),
                reverseCurve: Curves.easeInCubic,
              );
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              );
            },
            child: Material(
              type: MaterialType.transparency,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: PalComposerSheet(seed: seed),
              ),
            ),
          );
        },
      ),
      // Rituals guided player — full-screen overlay (no tab bar).
      GoRoute(
        path: AppRoute.routinePlayer.path,
        name: AppRoute.routinePlayer.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state.pageKey,
          RoutinePlayerScreen(routineId: state.pathParameters['routineId']!),
        ),
      ),
      // the Pal hub's memory, autopilot and noticed feed live on the You tab
      // now; its old paths stay as stable redirects there.
      for (final route in [AppRoute.pal, AppRoute.palInbox, AppRoute.palHome])
        GoRoute(
          path: route.path,
          name: route.name,
          redirect: (context, state) => AppRoute.you.path,
        ),
      GoRoute(
        path: AppRoute.eveningCloseOut.path,
        name: AppRoute.eveningCloseOut.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _sheetPage(state.pageKey, const EveningCloseOutScreen()),
      ),
      GoRoute(
        path: AppRoute.streakCelebration.path,
        name: AppRoute.streakCelebration.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const StreakCelebrationScreen()),
      ),
      // Weekly Review deep link kept stable; redirects into the Recap.
      GoRoute(
        path: AppRoute.weeklyReview.path,
        name: AppRoute.weeklyReview.name,
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/recap?range=week',
      ),
      // --- U17 first-run onboarding (full-screen, above the shell) ---
      GoRoute(
        path: AppRoute.onboarding.path,
        name: AppRoute.onboarding.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const OnboardingScreen()),
      ),
    ],
  );
}

/// Default gate predicate: when no `SettingsRepository` is supplied (tests,
/// stand-alone use) the app behaves as if onboarding is already done.
bool _alwaysComplete() => true;

/// The redirect target for a moved route: [child] (plus [suffix]) under
/// [parent], keeping [state]'s query string.
String _childOf(AppRoute parent, AppRoute child, GoRouterState state,
    [String suffix = '']) {
  final query = state.uri.query;
  final path = '${parent.path}/${child.path}$suffix';
  return query.isEmpty ? path : '$path?$query';
}

String _toAreaNutrition(BuildContext context, GoRouterState state) => _childOf(
    AppRoute.areas,
    AppRoute.areaNutrition,
    state,
    state.uri.path.substring(AppRoute.nutrition.path.length));

/// Maps the Recap `?range=` query value to an [InsightRange]; anything other
/// than `week`/`month` (including absent) opens on Day.
InsightRange _rangeFrom(String? raw) => switch (raw) {
      'week' => InsightRange.week,
      'month' => InsightRange.month,
      _ => InsightRange.day,
    };

/// Slide-up + ease cover transition for modal / focus routes (the New Entry
/// sheet, Ask Pal, and the full-screen workout flow). Shares the Quick Actions
/// easing so presentations feel consistent across the app.
CustomTransitionPage<void> _sheetPage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(curved),
        child: child,
      );
    },
    child: child,
  );
}

/// Gentle cross-fade for full-screen routes that read better without a slide
/// (first-run onboarding, monthly review).
CustomTransitionPage<void> _fadePage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
    child: child,
  );
}
