import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/insights_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/recap_controller.dart';
import 'package:opal/screens/recap/recap_screen.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/theme.dart';

final _recap = RecapData(
  range: InsightRange.day,
  periodStart: DateTime(2026, 10, 14),
  spent: 42,
  budget: 60,
  moveKcal: 310,
  moveTarget: 500,
  ritualsKept: 2,
  ritualsTarget: 3,
);

const _insights = PalInsights(
  wins: [
    InsightWin(colorToken: 'move', title: 'Moved three days running', sub: '310 kcal today'),
  ],
  patterns: [
    InsightPattern(colorToken: 'money', title: 'Coffee runs on Mondays', detail: 'Every week'),
  ],
  suggestion: 'Try a short walk after lunch.',
);

/// Pumps the Recap behind a router with stand-ins for You and the composer,
/// so a tap's destination reads as text.
Future<void> _pump(
  WidgetTester tester, {
  Future<PalInsights?> Function()? insights,
  Map<String, Object> prefs = const {},
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final router = GoRouter(initialLocation: '/recap', routes: [
    GoRoute(path: '/recap', builder: (_, _) => const RecapScreen()),
    GoRoute(path: '/you', builder: (_, _) => const Text('YOU PAGE')),
    GoRoute(
      path: '/pal-composer',
      builder: (_, state) => Text('COMPOSER ${state.uri.queryParameters['seed']}'),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      recapMemoryRefreshProvider.overrideWith((_) async {}),
      recapDataProvider(InsightRange.day).overrideWith((_) => Stream.value(_recap)),
      insightsProvider(InsightRange.day)
          .overrideWith((_) => (insights ?? () async => _insights)()),
    ],
    child: MaterialApp.router(
      theme: ThemeData(extensions: [AppColors.light()]),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
    finder, 120, scrollable: find.byType(Scrollable).first);

void main() {
  testWidgets('stats render as light numbers with their labels', (tester) async {
    await _pump(tester);

    final spent = tester.widget<Text>(find.text('\$42'));
    expect(spent.style?.fontSize, AppType.score.fontSize);
    expect(spent.style?.fontWeight, AppType.score.fontWeight);
    expect(find.text('310'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('Moved'), findsOneWidget);
    expect(find.text('Rituals'), findsOneWidget);
    expect(find.text('of \$60'), findsOneWidget);
  });

  testWidgets('the spent stat follows the user currency', (tester) async {
    await _pump(tester, prefs: {'settings.currency': 'VND'});

    expect(find.textContaining('₫'), findsWidgets);
    expect(find.textContaining('\$'), findsNothing);
  });

  testWidgets('wins render, and neither Patterns nor PAL NOTICED does', (tester) async {
    await _pump(tester);

    await _scrollTo(tester, find.text('Moved three days running'));
    expect(find.text('Wins'), findsOneWidget);
    expect(find.text('310 kcal today'), findsOneWidget);
    expect(find.text('Patterns'), findsNothing);
    expect(find.textContaining('Coffee runs on Mondays'), findsNothing);
    expect(find.text('PAL NOTICED'), findsNothing);
    expect(find.text('Connections'), findsNothing);
  });

  testWidgets('Patterns are on You opens You', (tester) async {
    await _pump(tester);

    await _scrollTo(tester, find.text('Patterns are on You'));
    await tester.tap(find.text('Patterns are on You'));
    await tester.pumpAndSettle();

    expect(find.text('YOU PAGE'), findsOneWidget);
  });

  testWidgets('Ask Pal more opens the composer with the recap seed', (tester) async {
    await _pump(tester);

    await _scrollTo(tester, find.text('Ask Pal more'));
    expect(find.text('Try a short walk after lunch.'), findsOneWidget);
    await tester.tap(find.text('Ask Pal more'));
    await tester.pumpAndSettle();

    expect(find.text('COMPOSER Tell me more about this recap'), findsOneWidget);
  });

  testWidgets('shows the reviewing notice while Pal loads', (tester) async {
    final pending = Completer<PalInsights?>();
    await _pump(tester, insights: () => pending.future);

    expect(find.text('Pal is reviewing your recap…'), findsOneWidget);
  });

  testWidgets('shows the empty notice when Pal has nothing yet', (tester) async {
    await _pump(tester, insights: () async => null);

    expect(
      find.text('Keep logging and Pal will gather your wins and patterns here.'),
      findsOneWidget,
    );
    expect(find.text('Patterns are on You'), findsOneWidget);
  });

  testWidgets('wraps at large text without overflowing', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, textScale: 1.5);

    await _scrollTo(tester, find.text('Patterns are on You'));
    expect(tester.takeException(), isNull);
  });
}
