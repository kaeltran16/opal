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

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show bootApp;

/// Every path that resolved before the four-tab shell still resolves: moved
/// routes land on their new location, everything else stays put.
const _cases = {
  '/today': '/today', '/move': '/move', '/nutrition': '/nutrition',
  '/rituals': '/today/rituals', '/rituals/manage': '/today/rituals/manage',
  '/sleep': '/today/sleep', '/mood': '/today/mood',
  '/today/spending': '/today/spending', '/today/move-detail': '/today/move-detail',
  '/today/rituals-detail': '/today/rituals-detail',
  '/move/start': '/move/start', '/move/history': '/move/history',
  '/move/routine-editor': '/move/routine-editor', '/move/weekly-plan': '/move/weekly-plan',
  '/move/routine-generator': '/move/routine-generator',
  '/nutrition/patterns': '/nutrition/patterns',
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

  testWidgets('a moved route opened from another tab shows Today with Back',
      (tester) async {
    await bootApp(tester);
    final router = _router(tester);

    router.go('/nutrition');
    await tester.pumpAndSettle();
    router.go('/sleep');
    await tester.pumpAndSettle();

    expect(_path(router), '/today/sleep');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Today')),
      isSemantics(label: 'Today', isButton: true, isSelected: true),
    );

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(_path(router), '/today');

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
