import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/screens/you/sub_screen.dart';
import 'package:opal/theme/app_colors.dart';

/// Pushes a [SubScreen] from a launcher page, as You does.
Future<void> _open(WidgetTester tester, {String? backLabel}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => backLabel == null
                      ? const SubScreen(
                          eyebrow: 'Settings',
                          title: 'About',
                          children: [],
                        )
                      : SubScreen(
                          eyebrow: 'Lunch · 12:30',
                          title: 'Poke bowl',
                          backLabel: backLabel,
                          children: const [],
                        ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('backs to You by default', (tester) async {
    await _open(tester);

    expect(find.text('You'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to You'), findsOneWidget);
  });

  testWidgets('shows the given back label', (tester) async {
    await _open(tester, backLabel: 'Nutrition');

    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.text('You'), findsNothing);
    expect(find.bySemanticsLabel('Back to Nutrition'), findsOneWidget);
  });

  testWidgets('tapping back pops', (tester) async {
    await _open(tester, backLabel: 'Nutrition');

    await tester.tap(find.text('Nutrition'));
    await tester.pumpAndSettle();

    expect(find.byType(SubScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
