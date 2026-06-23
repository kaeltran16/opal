import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/router.dart';
import 'package:opal/screens/dimensions/dimensions_hub_screen.dart';
import 'package:opal/theme/app_colors.dart';

// Minimal router: the hub at /dimensions plus stub Sleep/Mood destinations
// registered under the same route NAMES the hub pushes (AppRoute.sleep/mood).
// This exercises the hub's navigation wiring without the real screens' provider
// graph (which needs build_runner output + an in-memory db).
Widget _wrap() {
  final colors = AppColors.light(AppAccent.indigo);
  final router = GoRouter(
    initialLocation: '/dimensions',
    routes: [
      GoRoute(
        path: '/dimensions',
        name: AppRoute.dimensionsHub.name,
        builder: (_, __) => const DimensionsHubScreen(),
      ),
      GoRoute(
        path: '/dimensions/sleep',
        name: AppRoute.sleep.name,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('SLEEP STUB'))),
      ),
      GoRoute(
        path: '/dimensions/mood',
        name: AppRoute.mood.name,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('MOOD STUB'))),
      ),
    ],
  );
  return MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, extensions: [colors]),
    routerConfig: router,
  );
}

void main() {
  testWidgets('hub lists Sleep & Mood rows', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Sleep'), findsOneWidget);
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Synced from Health'), findsOneWidget);
  });

  testWidgets('tapping Sleep pushes the Sleep screen', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sleep'));
    await tester.pumpAndSettle();
    expect(find.text('SLEEP STUB'), findsOneWidget);
  });

  testWidgets('tapping Mood pushes the Mood screen', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();
    expect(find.text('MOOD STUB'), findsOneWidget);
  });
}
