import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/analysis/spend_alerts.dart';
import 'package:opal/controllers/budget_advisories_controller.dart';
import 'package:opal/controllers/budget_envelopes_controller.dart';
import 'package:opal/controllers/budget_recommendations_controller.dart';
import 'package:opal/controllers/budgets_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/money/budgets_screen.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _editorMarker = 'envelope editor route';

/// Envelopes held in memory; the add sheet watches this controller.
class _NoEnvelopes extends BudgetEnvelopesController {
  @override
  Stream<List<BudgetEnvelope>> build() => Stream.value(const []);
}

EnvelopeSpend _envelope(String category,
        {required double cap, required double spent, String icon = 'cart.fill'}) =>
    EnvelopeSpend(
      envelope: BudgetEnvelope(
        id: 'env-$category',
        category: category,
        cap: cap,
        icon: icon,
        colorToken: 'money',
        position: 0,
      ),
      spent: spent,
    );

BudgetsData _data(List<EnvelopeSpend> envelopes, {double monthlyBudget = 3000}) {
  final now = clock.now();
  return BudgetsData(
    envelopes: envelopes,
    month: DateTime(now.year, now.month),
    monthlyBudget: monthlyBudget,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Stream<BudgetsData> data, {
  Currency currency = Currency.usd,
  BudgetAdvisories advisories = const BudgetAdvisories(unbudgeted: [], savings: []),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({'settings.currency': currency.code});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        budgetsDataProvider.overrideWith((ref) => data),
        budgetRecommendationsProvider.overrideWith((ref) => Stream.value(const [])),
        budgetAdvisoriesProvider.overrideWith((ref) => Stream.value(advisories)),
        budgetEnvelopesControllerProvider.overrideWith(_NoEnvelopes.new),
      ],
      child: MaterialApp.router(
        theme: ThemeData(extensions: [AppColors.light()]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: GoRouter(routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const BudgetsScreen(),
            routes: [
              GoRoute(
                path: AppRoute.envelopes.path,
                name: AppRoute.envelopes.name,
                builder: (_, _) => const Scaffold(body: Text(_editorMarker)),
              ),
            ],
          ),
        ]),
      ),
    ),
  );
  await tester.pump();
}

/// The 4px bar fills drawn in [color].
Finder _barsIn(Color color) => find.byWidgetPredicate((w) =>
    w is Container &&
    w.constraints?.maxHeight == 4 &&
    (w.decoration as BoxDecoration?)?.color == color);

void main() {
  testWidgets('the hero shows what is left in the user currency', (tester) async {
    final data = _data([_envelope('Groceries', cap: 1000000, spent: 250000)],
        monthlyBudget: 3000000);
    await _pump(tester, Stream.value(data), currency: Currency.vnd);

    expect(find.text(formatCurrency(2750000, Currency.vnd)), findsOneWidget);
    expect(find.textContaining(Currency.vnd.symbol), findsWidgets);
    expect(find.textContaining('\$'), findsNothing);
    expect(find.text('left this month'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
  });

  testWidgets('an overspent envelope reads over and Needs care in care ink', (tester) async {
    final data = _data([_envelope('Dining', cap: 100, spent: 120)]);
    await _pump(tester, Stream.value(data));

    expect(find.text('${formatCurrency(20, Currency.usd)} over'), findsOneWidget);
    final word = tester.widget<Text>(find.text('Needs care'));
    expect(word.style!.color, AppColors.light().careInk);
    expect(_barsIn(AppColors.light().care), findsOneWidget);
  });

  testWidgets('a zero-cap envelope shows no state word and an ink bar', (tester) async {
    final data = _data([_envelope('Gifts', cap: 0, spent: 30)]);
    await _pump(tester, Stream.value(data));

    expect(find.text('Gifts'), findsOneWidget);
    expect(find.text('${formatCurrency(0, Currency.usd)} left'), findsOneWidget);
    for (final word in ['On track', 'Worth watching', 'Needs care']) {
      expect(find.text(word), findsNothing, reason: word);
    }
    expect(_barsIn(AppColors.light().ink), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the spend ring is gone', (tester) async {
    await _pump(tester, Stream.value(_data([_envelope('Dining', cap: 100, spent: 40)])));

    expect(File('lib/widgets/spend_ring.dart').existsSync(), isFalse);
  });

  testWidgets('advisories stay as hairline rows', (tester) async {
    // tall enough that the lazy list builds the advisories below the envelopes.
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      Stream.value(_data([_envelope('Dining', cap: 100, spent: 40)])),
      advisories: const BudgetAdvisories(
        unbudgeted: [UnbudgetedCategory(category: 'Pets', monthSpend: 45, suggestedCap: 60)],
        savings: [],
      ),
    );
    // the advisories stream is first watched once the body has built.
    await tester.pump();

    expect(find.text('No envelope yet'), findsOneWidget);
    expect(find.text('Pets'), findsOneWidget);
    expect(find.text(formatCurrency(60, Currency.usd)), findsOneWidget);
  });

  testWidgets('the loading text renders', (tester) async {
    final pending = StreamController<BudgetsData>();
    addTearDown(pending.close);
    await _pump(tester, pending.stream);

    expect(find.text('…'), findsOneWidget);
  });

  testWidgets('the error text renders', (tester) async {
    await _pump(tester, Stream.error(StateError('boom')));
    await tester.pump();

    expect(find.text("Couldn't load your budgets."), findsOneWidget);
  });

  testWidgets('rows wrap instead of overflowing at large text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final data = _data([
      _envelope('Health and personal care', cap: 100, spent: 120),
      _envelope('Transport and commuting', cap: 400, spent: 380),
    ], monthlyBudget: 300);
    await _pump(tester, Stream.value(data), textScale: 1.5);

    expect(find.text('Needs care'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Budget options pushes the envelope editor', (tester) async {
    await _pump(tester, Stream.value(_data([_envelope('Dining', cap: 100, spent: 40)])));

    await tester.tap(find.bySemanticsLabel('Budget options'));
    await tester.pumpAndSettle();

    expect(find.text(_editorMarker), findsOneWidget);
  });

  testWidgets('New envelope opens the add sheet', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, Stream.value(_data([_envelope('Dining', cap: 100, spent: 40)])));

    await tester.tap(find.bySemanticsLabel('New envelope'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('envelope rows draw the line glyph for a fill name', (tester) async {
    await _pump(
      tester,
      Stream.value(_data([_envelope('Groceries', cap: 500, spent: 40, icon: 'basket.fill')])),
    );

    expect(find.byIcon(lineIconForSf('basket.fill')), findsOneWidget);
    expect(find.byIcon(iconForSf('basket.fill')), findsNothing);
  });

  testWidgets('with no envelopes a quiet row sits under the heading', (tester) async {
    await _pump(tester, Stream.value(_data(const [])));

    expect(find.text('No envelopes yet.'), findsOneWidget);
  });

  testWidgets('the uncategorized tally alone still reads as no envelopes', (tester) async {
    await _pump(
      tester,
      Stream.value(_data([EnvelopeSpend(envelope: kUncategorizedEnvelope, spent: 30)])),
    );

    expect(find.text('No envelopes yet.'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);
  });

  testWidgets('real envelopes hide the empty row', (tester) async {
    await _pump(tester, Stream.value(_data([_envelope('Dining', cap: 100, spent: 40)])));

    expect(find.text('No envelopes yet.'), findsNothing);
  });

  testWidgets('the footer reads the new copy', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, Stream.value(_data([_envelope('Dining', cap: 100, spent: 40)])));

    expect(find.text('Adjust caps anytime. Pal nudges you before an envelope runs dry.'),
        findsOneWidget);
  });
}
