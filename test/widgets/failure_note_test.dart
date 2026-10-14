import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/failure_note.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
      home: Scaffold(body: child),
    ));

void main() {
  testWidgets('the default text is the save failure copy', (tester) async {
    await _pump(tester, const FailureNote());
    expect(saveFailedCopy, "Couldn't save. Try again.");
    expect(find.text(saveFailedCopy), findsOneWidget);
  });

  testWidgets('shows the text it is given', (tester) async {
    await _pump(tester, const FailureNote("Couldn't delete. Try again."));
    expect(find.text("Couldn't delete. Try again."), findsOneWidget);
  });

  testWidgets('the note is a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const FailureNote());
    expect(tester.getSemantics(find.text(saveFailedCopy)),
        isSemantics(isLiveRegion: true, label: saveFailedCopy));
    semantics.dispose();
  });
}
