import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/correlation_card.dart';

// sleep×money correlation WITH breakdown, matching the task spec fixture
const _sleepMoney = Correlation(
  a: Dimension.sleep,
  b: Dimension.money,
  r: 0.5,
  n: 30,
  breakdown: GroupBreakdown(
    binaryDim: Dimension.sleep,
    continuousDim: Dimension.money,
    meanWhenActive: 64,
    meanWhenInactive: 39,
    countActive: 8,
    countInactive: 22,
  ),
);

// move×money correlation used by the pre-existing tests (kept for regression)
const _moveMoney = Correlation(
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

// breakdown-less correlation for fallback tests
const _noBreakdown = Correlation(
  a: Dimension.sleep,
  b: Dimension.mood,
  r: 0.4,
  n: 21,
);

Widget _wrap(Widget child) {
  final colors = AppColors.light(AppAccent.indigo);
  // a minimal GoRouter is needed so context.go in the Ask Pal button resolves
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: 'pal-composer',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('pal-composer')),
            ),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      routerConfig: router,
    ),
  );
}

void main() {
  // ── Card tests ───────────────────────────────────────────────────────────────

  testWidgets('card shows PAL NOTICED eyebrow', (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(correlation: _sleepMoney)));
    expect(find.text('PAL NOTICED'), findsOneWidget);
  });

  testWidgets('card shows the summary line text', (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(correlation: _sleepMoney)));
    // summary contains 'short nights' for binaryDim=sleep
    expect(find.textContaining('short nights'), findsOneWidget);
  });

  testWidgets('card prefers narration over view.line when provided', (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(
        correlation: _sleepMoney,
        narration: 'Custom narration text.')));
    expect(find.text('Custom narration text.'), findsOneWidget);
    // the raw summary should NOT appear because narration wins
    expect(find.textContaining('short nights'), findsNothing);
  });

  testWidgets('card shows Tap to see the numbers subline', (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(correlation: _sleepMoney)));
    expect(find.text('Tap to see the numbers.'), findsOneWidget);
  });

  testWidgets('tapping the card opens the trust sheet', (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(correlation: _sleepMoney)));
    await t.tap(find.byType(CorrelationCard));
    await t.pumpAndSettle();
    // comparison labels from the sleep×money breakdown
    expect(find.textContaining('short nights'), findsWidgets);
    expect(find.textContaining('other nights'), findsWidgets);
  });

  // ── Regression: move×money card ─────────────────────────────────────────────

  testWidgets('move×money card shows summary line and tap subline', (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(correlation: _moveMoney)));
    expect(find.textContaining('workout days'), findsOneWidget);
    expect(find.text('Tap to see the numbers.'), findsOneWidget);
  });

  testWidgets('move×money card narration overrides summary', (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(
        correlation: _moveMoney,
        narration: 'You spend less on workout days.')));
    expect(find.text('You spend less on workout days.'), findsOneWidget);
  });

  testWidgets('tapping move×money card opens trust sheet with dollar values',
      (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(correlation: _moveMoney)));
    await t.tap(find.byType(CorrelationCard));
    await t.pumpAndSettle();
    expect(find.textContaining('\$34'), findsWidgets);
    expect(find.textContaining('\$52'), findsWidgets);
  });

  // ── Trust sheet direct tests (sleep×money) ───────────────────────────────────

  testWidgets('trust sheet shows PairTag pairLabel', (t) async {
    await t.pumpWidget(_wrap(Builder(builder: (ctx) {
      return TextButton(
        onPressed: () => showCorrelationTrustSheet(ctx, _sleepMoney),
        child: const Text('open'),
      );
    })));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    // pairLabel is 'Sleep × Spending' — appears uppercased in PairTag
    expect(find.textContaining('SLEEP'), findsWidgets);
    expect(find.textContaining('SPENDING'), findsWidgets);
  });

  testWidgets('trust sheet shows comparison bar labels and values', (t) async {
    await t.pumpWidget(_wrap(Builder(builder: (ctx) {
      return TextButton(
        onPressed: () => showCorrelationTrustSheet(ctx, _sleepMoney),
        child: const Text('open'),
      );
    })));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('After short nights'), findsOneWidget);
    expect(find.text('After other nights'), findsOneWidget);
    expect(find.text('\$64'), findsOneWidget);
    expect(find.text('\$39'), findsOneWidget);
  });

  testWidgets('trust sheet shows >=3 underlying number rows', (t) async {
    await t.pumpWidget(_wrap(Builder(builder: (ctx) {
      return TextButton(
        onPressed: () => showCorrelationTrustSheet(ctx, _sleepMoney),
        child: const Text('open'),
      );
    })));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    // numbers has: active count, inactive count, Difference row = 3 rows
    expect(find.text('8 short nights'), findsOneWidget);
    expect(find.text('22 other nights'), findsOneWidget);
    expect(find.text('Difference'), findsOneWidget);
  });

  testWidgets('trust sheet shows source row text', (t) async {
    await t.pumpWidget(_wrap(Builder(builder: (ctx) {
      return TextButton(
        onPressed: () => showCorrelationTrustSheet(ctx, _sleepMoney),
        child: const Text('open'),
      );
    })));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.textContaining('last 30 days'), findsOneWidget);
  });

  testWidgets('trust sheet shows Why You\'re Seeing This box', (t) async {
    await t.pumpWidget(_wrap(Builder(builder: (ctx) {
      return TextButton(
        onPressed: () => showCorrelationTrustSheet(ctx, _sleepMoney),
        child: const Text('open'),
      );
    })));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.textContaining("WHY YOU'RE SEEING THIS"), findsOneWidget);
  });

  testWidgets('trust sheet shows Ask Pal button', (t) async {
    await t.pumpWidget(_wrap(Builder(builder: (ctx) {
      return TextButton(
        onPressed: () => showCorrelationTrustSheet(ctx, _sleepMoney),
        child: const Text('open'),
      );
    })));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Ask Pal about this'), findsOneWidget);
  });

  testWidgets('Ask Pal button is tappable (navigates to pal-composer)',
      (t) async {
    await t.pumpWidget(_wrap(Builder(builder: (ctx) {
      return TextButton(
        onPressed: () => showCorrelationTrustSheet(ctx, _sleepMoney),
        child: const Text('open'),
      );
    })));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ask Pal about this'));
    await t.pumpAndSettle();
    // navigation landed on the pal-composer stub route
    expect(find.text('pal-composer'), findsOneWidget);
  });

  // ── Breakdown-less fallback ───────────────────────────────────────────────────

  testWidgets('breakdown-less card shows summary line, no comparison bars',
      (t) async {
    await t.pumpWidget(_wrap(const CorrelationCard(correlation: _noBreakdown)));
    // summary for no-breakdown uses dimensionNoun text
    expect(find.textContaining('sleep'), findsOneWidget);
    // no compare labels
    expect(find.text('After short nights'), findsNothing);
    expect(find.text('SIDE BY SIDE'), findsNothing);
  });

  testWidgets('breakdown-less trust sheet omits comparison section', (t) async {
    await t.pumpWidget(_wrap(Builder(builder: (ctx) {
      return TextButton(
        onPressed: () => showCorrelationTrustSheet(ctx, _noBreakdown),
        child: const Text('open'),
      );
    })));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('SIDE BY SIDE'), findsNothing);
    expect(find.text('After short nights'), findsNothing);
    // why box and ask pal still appear
    expect(find.textContaining("WHY YOU'RE SEEING THIS"), findsOneWidget);
    expect(find.text('Ask Pal about this'), findsOneWidget);
  });
}
