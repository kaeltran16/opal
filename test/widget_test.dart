import 'package:flutter_test/flutter_test.dart';

import 'package:loop/main.dart';

void main() {
  testWidgets('Today screen renders core content', (WidgetTester tester) async {
    await tester.pumpWidget(const LoopApp());

    // Above-the-fold content (ListView builds lazily, so off-screen rows
    // like the timeline aren't in the tree at the default test viewport).
    expect(find.text('Today'), findsWidgets); // nav title + tab label
    expect(find.text('Thursday, April 23'), findsOneWidget);
    expect(find.text('PAL NOTICED'), findsOneWidget);
  });
}
