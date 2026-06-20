import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/screens/settings/privacy_screen.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  testWidgets('Privacy screen discloses Pal memory storage', (tester) async {
    final colors = AppColors.light(AppAccent.blue);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: const PrivacyScreen(),
    ));

    expect(find.text('Pal memory'), findsOneWidget);
    expect(
      find.text('Facts you mention and patterns Pal learns, '
          'stored to personalize replies. Clear anytime in Pal.'),
      findsOneWidget,
    );
  });
}
