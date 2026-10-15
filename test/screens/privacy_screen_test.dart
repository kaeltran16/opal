import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/router.dart';
import 'package:opal/screens/settings/privacy_screen.dart';
import 'package:opal/theme/app_colors.dart';

Future<void> _pumpPrivacy(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/privacy',
    routes: [
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
      // targets for pushNamed from the rows; bodies only mark arrival.
      GoRoute(
        path: '/export',
        name: AppRoute.exportData.name,
        builder: (_, _) => const Text('export screen'),
      ),
      GoRoute(
        path: '/notifications',
        name: AppRoute.notificationSettings.name,
        builder: (_, _) => const Text('notifications screen'),
      ),
    ],
  );
  final colors = AppColors.light();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: ThemeData(useMaterial3: true, extensions: [colors]),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Privacy screen discloses Pal memory storage', (tester) async {
    await _pumpPrivacy(tester);

    expect(find.text('Pal memory'), findsOneWidget);
    expect(
      find.text(
        'Facts you mention and patterns Pal finds in your timeline, '
        "kept on Pal's server to personalize replies. Clear anytime in Pal.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('says Pal sends the timeline on its own and only email is opt-in',
      (tester) async {
    await _pumpPrivacy(tester);

    expect(find.textContaining('Pal gets your timeline'), findsOneWidget);
    // the closing note sits below the fold of the lazily built list.
    await tester.scrollUntilVisible(find.textContaining('Email sync is opt-in'), 100);
    expect(find.textContaining('Email sync is opt-in. Pal is part of the app'), findsOneWidget);
    expect(find.textContaining('Both are opt-in'), findsNothing);
    expect(find.textContaining('Text you send to Pal is processed'), findsNothing);
  });

  testWidgets('title reads Data and privacy', (tester) async {
    await _pumpPrivacy(tester);

    expect(find.text('Data and privacy'), findsOneWidget);
  });

  testWidgets('renders Export data and Notifications rows', (tester) async {
    await _pumpPrivacy(tester);

    // the rows sit below the fold of the lazily built list.
    await tester.scrollUntilVisible(find.text('Notifications'), 100);

    expect(find.text('Export data'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('Export data opens the export screen', (tester) async {
    await _pumpPrivacy(tester);

    await tester.scrollUntilVisible(
      find.text('Export data').hitTestable(),
      100,
    );
    await tester.tap(find.text('Export data'));
    await tester.pumpAndSettle();

    expect(find.text('export screen'), findsOneWidget);
  });

  testWidgets('Notifications opens the notification settings screen', (
    tester,
  ) async {
    await _pumpPrivacy(tester);

    await tester.scrollUntilVisible(
      find.text('Notifications').hitTestable(),
      100,
    );
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('notifications screen'), findsOneWidget);
  });
}
