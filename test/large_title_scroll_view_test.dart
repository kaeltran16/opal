import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/nav_bar.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    final colors = AppColors.light(AppAccent.blue);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [colors]),
        home: LargeTitleScrollView(
          title: 'Profile',
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 60, child: Text('row $i')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('large title shows at rest and pins (stays on screen) on scroll',
      (tester) async {
    await pump(tester);

    // At rest the (large) title renders exactly once.
    expect(find.text('Profile'), findsOneWidget);

    // Scroll the body well past the header's collapse range.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The title is still on screen (pinned compact title) — the whole point of
    // the collapsing header vs. a plain ListView, where it would scroll away.
    expect(find.text('Profile'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Profile')).dy, lessThan(120));
  });
}
