import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/screens/shell/tab_header.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/nav_bar.dart';

void main() {
  Future<GoRouter> pump(WidgetTester tester, {Widget? action}) async {
    final colors = AppColors.light();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (c, s) => TabHeaderScrollView(
            title: 'Demo',
            subtitle: 'a status line',
            contextualAction: action,
            children: const [SizedBox(height: 40)],
          ),
          routes: [
            GoRoute(
              path: 'child',
              builder: (c, s) => const TabHeaderScrollView(
                title: 'Child',
                children: [SizedBox(height: 40)],
              ),
            ),
          ],
        ),
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
    return router;
  }

  testWidgets('a tab root shows only the contextual action', (tester) async {
    await pump(
      tester,
      action: NavIconButton(
          name: 'plus', semanticLabel: 'Add thing', onTap: () {}),
    );

    expect(find.bySemanticsLabel('Add thing'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsNothing);
    expect(find.bySemanticsLabel('You'), findsNothing);
    expect(find.bySemanticsLabel('Open Pal'), findsNothing);
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('a nested screen gets a back button that pops', (tester) async {
    final router = await pump(tester);

    router.go('/home/child');
    await tester.pumpAndSettle();
    expect(find.text('Child'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
    expect(find.bySemanticsLabel('Back'), findsNothing);
  });
}
