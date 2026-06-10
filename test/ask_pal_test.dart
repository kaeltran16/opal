import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:loop/controllers/providers.dart';
import 'package:loop/screens/pal/ask_pal_screen.dart';
import 'package:loop/services/services.dart';
import 'package:loop/theme/app_colors.dart';

/// Pumps [AskPalScreen] inside a ProviderScope + GoRouter (so `context.pop()`
/// resolves) with a fast, seeded [MockPalService] so the reply is deterministic.
Future<void> _pumpChat(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        routes: [
          GoRoute(
            path: 'pal',
            builder: (context, state) => const AskPalScreen(),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        palServiceProvider.overrideWithValue(
          MockPalService(latency: const Duration(milliseconds: 20), seed: 1),
        ),
      ],
      child: MaterialApp.router(
        theme: ThemeData.light().copyWith(
          extensions: [AppColors.light(AppAccent.blue)],
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  router.go('/host/pal');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'empty state shows suggestion chips; sending a message shows the typing '
      'indicator then a mock reply', (WidgetTester tester) async {
    await _pumpChat(tester);

    // Empty state: the suggestion chips are present.
    expect(find.text('Why was Friday expensive?'), findsOneWidget);
    expect(find.text('How am I doing this week?'), findsOneWidget);
    expect(find.text('Suggest an evening ritual'), findsOneWidget);

    // Type a message and send it.
    await tester.enterText(find.byType(TextField), 'How am I doing?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(); // process the send

    // The user bubble appears and the typing indicator is shown (still loading,
    // reply not yet arrived).
    expect(find.text('How am I doing?'), findsOneWidget);
    // Chips are gone now that the conversation has started.
    expect(find.text('Why was Friday expensive?'), findsNothing);

    // Let the fake latency elapse; the canned reply arrives.
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    // Seed 1 → Random.nextInt(4) == 0 → the first canned reply is on screen.
    expect(
      find.text("Nice — logged it. You're tracking a calm week so far."),
      findsOneWidget,
    );
  });
}
