import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart';

String _path(WidgetTester tester) =>
    appRouter(tester).routerDelegate.currentConfiguration.uri.path;

/// Route changes as the platform delivers them: a web hash change, a Siri or
/// Live Activity link. Several can land before the next frame.
Future<void> _platformPush(WidgetTester tester, String location) =>
    tester.binding.handlePushRoute(location);

void main() {
  for (final path in ['/areas/money', '/you/budgets', '/move/history']) {
    testWidgets('a cold start on $path opens there, not on Today', (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = path;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      await withClock(goldenClock, () async {
        pinSurface(tester);
        await bootApp(tester);

        expect(_path(tester), path);
        await flushProviderTimers(tester);
      });
    });
  }

  for (final hops in [
    ['/you', '/move'],
    ['/areas/money', '/you/budgets'],
    ['/today', '/areas/nutrition', '/move/history', '/you'],
    ['/close-out', '/areas'],
    ['/move/start', '/session/push-a', '/today'],
    ['/session/push-a', '/move'],
    ['/pal-composer', '/areas/mood'],
  ]) {
    testWidgets('platform route changes ${hops.join(' then ')} in one frame land on the last',
        (tester) async {
      await withClock(goldenClock, () async {
        pinSurface(tester);
        await bootApp(tester);
        // none awaited: each lands before the router has handled the last.
        final pushes = [for (final h in hops) _platformPush(tester, h)];
        await tester.pumpAndSettle();
        await Future.wait(pushes);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_path(tester), hops.last);
        expect(find.byType(Navigator), findsWidgets);
        await flushProviderTimers(tester);
      });
    });
  }
}
