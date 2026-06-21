import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/correlation_card.dart';

const _correlation = Correlation(
  a: Dimension.move,
  b: Dimension.money,
  r: -0.52,
  n: 28,
  breakdown: GroupBreakdown(
    binaryDim: Dimension.move,
    continuousDim: Dimension.money,
    meanWhenActive: 34,
    meanWhenInactive: 52,
    countActive: 12,
    countInactive: 16,
  ),
);

Widget _wrap(Widget child) {
  final colors = AppColors.light(AppAccent.indigo);
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('shows the sample size and falls back to the summary', (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(correlation: _correlation)));
    expect(find.textContaining('28 days'), findsOneWidget);
    expect(find.textContaining('workout days'), findsOneWidget);
  });

  testWidgets('prefers the narration when provided', (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(
        correlation: _correlation,
        narration: 'You spend less on workout days.')));
    expect(find.text('You spend less on workout days.'), findsOneWidget);
  });

  testWidgets('tapping opens the trust sheet with the two-group breakdown',
      (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(correlation: _correlation)));
    await t.tap(find.byType(CorrelationCard));
    await t.pumpAndSettle();
    expect(find.textContaining('\$34'), findsWidgets);
    expect(find.textContaining('\$52'), findsWidgets);
  });
}
