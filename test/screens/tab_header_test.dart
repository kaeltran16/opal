import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/screens/shell/tab_header.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/nav_bar.dart';

void main() {
  testWidgets('TabHeaderScrollView renders profile, Pal, and the contextual action',
      (tester) async {
    final colors = AppColors.light(AppAccent.blue);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (c, s) => TabHeaderScrollView(
            title: 'Demo',
            subtitle: 'a status line',
            contextualAction: NavIconButton(
                name: 'plus', semanticLabel: 'Add thing', onTap: () {}),
            children: const [SizedBox(height: 40)],
          ),
        ),
        // Names must match AppRoute.you.name / AppRoute.pal.name.
        GoRoute(path: '/you', name: 'you', builder: (c, s) => const SizedBox()),
        GoRoute(path: '/pal', name: 'pal', builder: (c, s) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('You'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Pal'), findsOneWidget);
    expect(find.bySemanticsLabel('Add thing'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('TabHeaderScrollView omits the contextual slot when null',
      (tester) async {
    final colors = AppColors.light(AppAccent.blue);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (c, s) => const TabHeaderScrollView(
            title: 'Demo',
            children: [SizedBox(height: 40)],
          ),
        ),
        GoRoute(path: '/you', name: 'you', builder: (c, s) => const SizedBox()),
        GoRoute(path: '/pal', name: 'pal', builder: (c, s) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('You'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Pal'), findsOneWidget);
  });
}
