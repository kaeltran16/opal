import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/screens/shell/loop_shell.dart';
import 'package:opal/screens/workout/active_session_screen.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show bootApp;

/// Every path that resolved before the Areas tab still resolves: moved routes
/// land on their new location under /areas, everything else stays put.
const _cases = {
  '/today': '/today', '/areas': '/areas', '/move': '/move',
  '/areas/money': '/areas/money', '/areas/move': '/areas/move',
  '/areas/routines': '/areas/routines', '/areas/routines/manage': '/areas/routines/manage',
  '/areas/nutrition': '/areas/nutrition', '/areas/nutrition/patterns': '/areas/nutrition/patterns',
  '/areas/nutrition/meal/m1': '/areas/nutrition/meal/m1',
  '/areas/sleep': '/areas/sleep', '/areas/mood': '/areas/mood',
  '/nutrition': '/areas/nutrition', '/nutrition/patterns': '/areas/nutrition/patterns',
  '/nutrition/meal/m1': '/areas/nutrition/meal/m1',
  '/rituals': '/areas/routines', '/rituals/manage': '/areas/routines/manage',
  '/sleep': '/areas/sleep', '/mood': '/areas/mood',
  '/today/spending': '/areas/money', '/today/move-detail': '/areas/move',
  '/today/rituals-detail': '/areas/routines', '/today/rituals': '/areas/routines',
  '/today/rituals/manage': '/areas/routines/manage',
  '/today/sleep': '/areas/sleep', '/today/mood': '/areas/mood',
  '/move/start': '/move/start', '/move/history': '/move/history',
  '/move/routine-editor': '/move/routine-editor', '/move/weekly-plan': '/move/weekly-plan',
  '/move/routine-generator': '/move/routine-generator',
  '/you': '/you', '/you/budgets': '/you/budgets', '/you/insights': '/you/insights',
  '/you/budgets-goals': '/you/budgets-goals', '/you/notifications': '/you/notifications',
  '/you/appearance': '/you/appearance', '/you/privacy': '/you/privacy',
  '/you/export': '/you/export', '/you/about': '/you/about',
  '/entry/new': '/entry/new', '/library': '/library', '/recap': '/recap',
  '/monthly-review': '/recap', '/weekly-review': '/recap',
  '/email': '/email', '/email/setup': '/email/setup', '/email/dashboard': '/email/dashboard',
  '/pal-composer': '/pal-composer', '/pal': '/you', '/pal-home': '/you', '/pal-inbox': '/you',
  '/close-out': '/close-out', '/streak': '/streak',
  '/post-workout': '/post-workout',
  '/onboarding': '/today', // onboarding is complete in the test, so the gate bounces to Today
};

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(LoopShell)));

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

/// Reads a provider nothing on screen watches yet. The drift query behind it
/// only completes once fake time advances, so pump before awaiting.
Future<T> _read<T>(WidgetTester tester, ProviderListenable<Future<T>> p) async {
  final container =
      ProviderScope.containerOf(tester.element(find.byType(LoopApp)));
  final sub = container.listen(p, (_, _) {});
  addTearDown(sub.close);
  await tester.pumpAndSettle();
  return sub.read();
}

void main() {
  test('every root AppRoute path has a compat case', () {
    final roots = AppRoute.values
        .map((r) => r.path)
        .where((p) => p.startsWith('/') && !p.contains(':'));
    for (final path in roots) {
      expect(_cases.containsKey(path), isTrue, reason: '$path has no case');
    }
  });

  testWidgets('old and current paths resolve to their location',
      (tester) async {
    await bootApp(tester);
    final router = _router(tester);

    for (final MapEntry(key: from, value: to) in _cases.entries) {
      router.go(from);
      await tester.pumpAndSettle();
      expect(_path(router), to, reason: 'go($from)');
    }

    await flushProviderTimers(tester);
  });

  testWidgets('moved-route redirects keep the query string', (tester) async {
    await bootApp(tester);
    final router = _router(tester);
    const cases = {
      '/nutrition?x=1': '/areas/nutrition?x=1',
      '/nutrition/patterns?x=1': '/areas/nutrition/patterns?x=1',
      '/today/spending?x=1': '/areas/money?x=1',
      '/today/rituals/manage?from=widget': '/areas/routines/manage?from=widget',
      '/rituals?from=widget': '/areas/routines?from=widget',
      '/rituals/manage?from=widget': '/areas/routines/manage?from=widget',
      '/sleep?from=siri': '/areas/sleep?from=siri',
      '/mood?from=siri': '/areas/mood?from=siri',
      '/sleep': '/areas/sleep',
    };
    for (final MapEntry(key: from, value: to) in cases.entries) {
      router.go(from);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), to,
          reason: 'go($from)');
    }
    await flushProviderTimers(tester);
  });

  testWidgets('a moved route opened from another tab shows Areas with Back',
      (tester) async {
    await bootApp(tester);
    final router = _router(tester);

    router.go('/move');
    await tester.pumpAndSettle();
    router.go('/sleep');
    await tester.pumpAndSettle();

    expect(_path(router), '/areas/sleep');
    expect(
      tester.getSemantics(find.descendant(
          of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^Areas')))),
      isSemantics(isButton: true, isSelected: true),
    );

    await tester.tap(find.bySemanticsLabel('Back to Areas'));
    await tester.pumpAndSettle();
    expect(_path(router), '/areas');

    await flushProviderTimers(tester);
  });

  testWidgets('the rituals player still opens at its root path',
      (tester) async {
    await bootApp(tester);
    final routines = await _read(tester, ritualRoutinesStreamProvider.future);

    _router(tester).go('/rituals/player/${routines.first.id}');
    await tester.pumpAndSettle();

    expect(find.byType(RoutinePlayerScreen), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('an active session still opens at its root path',
      (tester) async {
    await bootApp(tester);
    final routines = await _read(tester, workoutRoutinesStreamProvider.future);

    _router(tester).go('/session/${routines.first.id}');
    // the session clock ticks every second, so the tree never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ActiveSessionScreen), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
