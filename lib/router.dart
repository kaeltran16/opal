import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'controllers/spending_controller.dart';
import 'theme/theme.dart';
import 'screens/detail/detail_screen.dart';
import 'screens/email/email_dashboard_screen.dart';
import 'screens/email/email_intro_screen.dart';
import 'screens/email/email_setup_screen.dart';
import 'screens/entry/new_entry_sheet.dart';
import 'screens/library/exercise_library_screen.dart';
import 'screens/move/move_screen.dart';
import 'screens/move/weekly_plan_screen.dart';
import 'screens/nutrition/nutrition_meal_detail_screen.dart';
import 'screens/nutrition/nutrition_patterns_screen.dart';
import 'screens/nutrition/nutrition_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/pal/pal_composer_screen.dart';
import 'screens/pal/pal_screen.dart';
import 'screens/money/budgets_screen.dart';
import 'screens/money/insights_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/recap/recap_screen.dart';
import 'screens/reflect/evening_close_out_screen.dart';
import 'screens/reflect/streak_celebration_screen.dart';
import 'screens/rituals/rituals_builder_screen.dart';
import 'screens/rituals/routine_player_screen.dart';
import 'screens/rituals/rituals_screen.dart';
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
  move('move', '/move'),
  nutrition('nutrition', '/nutrition'),
  rituals('rituals', '/rituals'),
  you('you', '/you'),

  // Nutrition sub-routes.
  nutritionMeal('nutritionMeal', 'meal/:id'), //   -> /nutrition/meal/:id
  nutritionPatterns('nutritionPatterns', 'patterns'), // /nutrition/patterns

  // Today sub-routes / detail (stubbed until their units).
  spendingDetail('spendingDetail', 'spending'), // U09 -> /today/spending
  moveDetail('moveDetail', 'move-detail'), //       -> /today/move-detail
  ritualsDetail('ritualsDetail', 'rituals-detail'), //  /today/rituals-detail

  // Move sub-routes.
  startWorkout('startWorkout', 'start'), //   U12 -> /move/start
  workoutDetail('workoutDetail', 'workout/:id'), // U15 -> /move/workout/:id
  routineEditor('routineEditor', 'routine-editor'), // U21b -> /move/routine-editor

  // Workout focus routes (full-screen, above the shell — no tab bar).
  activeSession('activeSession', '/session/:routineId'), // U13
  postWorkout('postWorkout', '/post-workout'), //          U14 (stub)

  // Rituals sub-routes.
  manageRituals('manageRituals', 'manage'), //   U21b -> /rituals/manage

  // You / Settings sub-routes (push within the pushed /you route).
  youBudgets('youBudgets', 'budgets'), //           -> /you/budgets
  youInsights('youInsights', 'insights'), //        -> /you/insights
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
  palInbox('palInbox', '/pal-inbox'),
  // palHome kept for stable deep links; redirects to /pal.
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
final _moveNavigatorKey = GlobalKey<NavigatorState>();
final _nutritionNavigatorKey = GlobalKey<NavigatorState>();
final _ritualsNavigatorKey = GlobalKey<NavigatorState>();

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
                        const DetailScreen(tracker: DetailTracker.move),
                  ),
                  GoRoute(
                    path: AppRoute.ritualsDetail.path,
                    name: AppRoute.ritualsDetail.name,
                    builder: (context, state) =>
                        const DetailScreen(tracker: DetailTracker.rituals),
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
          // --- Nutrition branch ---
          StatefulShellBranch(
            navigatorKey: _nutritionNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.nutrition.path,
                name: AppRoute.nutrition.name,
                builder: (context, state) => const NutritionScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.nutritionMeal.path,
                    name: AppRoute.nutritionMeal.name,
                    builder: (context, state) =>
                        NutritionMealDetailScreen(mealId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: AppRoute.nutritionPatterns.path,
                    name: AppRoute.nutritionPatterns.name,
                    builder: (context, state) => const NutritionPatternsScreen(),
                  ),
                ],
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
                builder: (context, state) => const RitualsScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.manageRituals.path,
                    name: AppRoute.manageRituals.name,
                    builder: (context, state) => const RitualsBuilderScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // --- You / profile (pushed above the shell; lifted off the tab bar) ---
      // Reached from the Today-header avatar via `pushNamed`, not a tab. Its
      // existing sub-routes are preserved verbatim so /you/* deep links stay
      // stable; the profile screen carries its own back/Done leading action.
      GoRoute(
        path: AppRoute.you.path,
        name: AppRoute.you.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: AppRoute.youBudgets.path,
            name: AppRoute.youBudgets.name,
            builder: (context, state) => const BudgetsScreen(),
          ),
          GoRoute(
            path: AppRoute.youInsights.path,
            name: AppRoute.youInsights.name,
            builder: (context, state) => const InsightsScreen(),
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
          return CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierDismissible: true,
            barrierColor: context.colors.scrim,
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
      // Pal hub — the merged Home + Inbox destination.
      GoRoute(
        path: AppRoute.pal.path,
        name: AppRoute.pal.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _sheetPage(state.pageKey, const PalScreen()),
      ),
      // Old Pal routes kept as stable redirects into the hub.
      GoRoute(
        path: AppRoute.palInbox.path,
        name: AppRoute.palInbox.name,
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/pal',
      ),
      GoRoute(
        path: AppRoute.palHome.path,
        name: AppRoute.palHome.name,
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/pal',
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
