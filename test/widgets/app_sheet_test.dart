import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_sheet.dart';

/// Opens the sheet from a button and records what it returns.
Future<List<bool?>> _open(WidgetTester tester) async {
  final results = <bool?>[];
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(await showAppSheet<bool>(
            context,
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Finish'),
            ),
          )),
          child: const Text('Open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('shows its grabber and content', (tester) async {
    await _open(tester);

    expect(find.byKey(appSheetGrabberKey), findsOneWidget);
    expect(tester.getSize(find.byKey(appSheetGrabberKey)), const Size(36, 5));
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('a barrier tap dismisses it with null', (tester) async {
    final results = await _open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Finish'), findsNothing);
    expect(results, [null]);
  });

  testWidgets('pop(true) returns true', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });
}
