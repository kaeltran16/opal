import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/nav_bar.dart';

void main() {
  const trailingKey = Key('trailing');
  const leadingKey = Key('leading');
  const longTitle = 'A very long workout title that cannot fit the bar';

  Future<void> pump(
    WidgetTester tester, {
    String title = 'Profile',
    Widget? leading,
    Widget? trailing,
  }) async {
    final colors = AppColors.light();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          home: LargeTitleScrollView(
            title: title,
            leading: leading,
            trailing: trailing,
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 60, child: Text('row $i')),
            ],
          ),
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

  testWidgets('the pinned bar turns to glass only once it collapses',
      (tester) async {
    await pump(tester);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('the expanded title is the oura title style', (tester) async {
    await pump(tester);

    final style = tester.widget<Text>(find.text('Profile')).style!;
    expect(style.fontSize, 22);
    expect(style.fontWeight, FontWeight.w500);
  });

  testWidgets('the trailing action shares a row with the expanded title',
      (tester) async {
    await pump(
      tester,
      title: 'Workout',
      trailing: NavIconButton(
          key: trailingKey, name: 'plus', semanticLabel: 'Add', onTap: () {}),
    );

    final title = tester.getCenter(find.text('Workout')).dy;
    final action = tester.getCenter(find.byKey(trailingKey)).dy;
    expect((title - action).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('the collapsed title stays clear of leading and trailing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      title: longTitle,
      leading: NavAction(
          key: leadingKey, icon: 'chevron.left', label: 'Back', onTap: () {}),
      trailing: NavIconButton(
          key: trailingKey, name: 'plus', semanticLabel: 'Add', onTap: () {}),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final compact = tester.getRect(find.text(longTitle));
    expect(compact.overlaps(tester.getRect(find.byKey(trailingKey))), isFalse);
    expect(compact.overlaps(tester.getRect(find.byKey(leadingKey))), isFalse);
  });
}
