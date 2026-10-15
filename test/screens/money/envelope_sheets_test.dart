import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/analysis/spend_alerts.dart';
import 'package:opal/controllers/budget_advisories_controller.dart';
import 'package:opal/controllers/budget_envelopes_controller.dart';
import 'package:opal/controllers/budgets_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/money/envelope_sheets.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/failure_note.dart';
import 'package:opal/widgets/keypad.dart';

const _groceries = BudgetEnvelope(
  id: 'env-grocer',
  category: 'Groceries',
  cap: 500,
  icon: 'basket.fill',
  colorToken: 'money',
  position: 0,
);

/// Records every write; [fail] makes each one throw instead.
class _FakeEnvelopes extends BudgetEnvelopesController {
  _FakeEnvelopes(this.items);

  List<BudgetEnvelope> items;
  bool fail = false;
  final calls = <String>[];

  @override
  Stream<List<BudgetEnvelope>> build() => Stream.value(items);

  Future<void> _write(String call) async {
    calls.add(call);
    if (fail) throw StateError('disk full');
  }

  @override
  Future<void> setCap(String id, double cap) => _write('setCap $id $cap');

  @override
  Future<void> add({required String category, required String icon, required double cap}) =>
      _write('add $category $icon $cap');

  @override
  Future<void> delete(String id) => _write('delete $id');
}

/// Opens the sheets the way the editor and Budgets do.
class _Host extends ConsumerWidget {
  const _Host(this.envelope);

  final BudgetEnvelope envelope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(budgetEnvelopesControllerProvider);
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => showEnvelopeCapSheet(context, ref, envelope),
            child: const Text('open cap'),
          ),
          TextButton(
            onPressed: () => showNewEnvelopeSheet(context, ref),
            child: const Text('open new'),
          ),
        ],
      ),
    );
  }
}

Future<_FakeEnvelopes> _pump(
  WidgetTester tester, {
  BudgetEnvelope envelope = _groceries,
  Currency currency = Currency.usd,
  List<UnbudgetedCategory> unbudgeted = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'settings.currency': currency.code});
  final prefs = await SharedPreferences.getInstance();
  final fake = _FakeEnvelopes([envelope]);
  final now = clock.now();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        budgetEnvelopesControllerProvider.overrideWith(() => fake),
        budgetsDataProvider.overrideWith((ref) => Stream.value(BudgetsData(
              envelopes: [EnvelopeSpend(envelope: envelope, spent: 286)],
              month: DateTime(now.year, now.month),
              monthlyBudget: 3000,
            ))),
        budgetAdvisoriesProvider.overrideWith((ref) =>
            Stream.value(BudgetAdvisories(unbudgeted: unbudgeted, savings: const []))),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppColors.light()]),
        home: _Host(envelope),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Finder get _sheet => find.byType(BottomSheet);

Finder _inSheet(Finder matching) => find.descendant(of: _sheet, matching: matching);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _label(WidgetTester tester, String label) =>
    _tap(tester, find.bySemanticsLabel(label));

Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await _tap(tester, find.descendant(of: find.byType(Keypad), matching: find.text(d)));
  }
}

Future<void> _delete(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await _label(tester, 'delete');
  }
}

Future<void> _openCap(WidgetTester tester) => _tap(tester, find.text('open cap'));

Future<void> _openNew(WidgetTester tester) => _tap(tester, find.text('open new'));

bool _selected(WidgetTester tester, String label) => isSemantics(isSelected: true)
    .matches(tester.getSemantics(find.bySemanticsLabel(label)), {});

void _expectDisabled(WidgetTester tester, String label) => expect(
    tester.getSemantics(find.bySemanticsLabel(label)),
    isSemantics(hasEnabledState: true, isEnabled: false));

const _iconWords = [
  'Cup', 'Basket', 'Bolt', 'Bag', 'Car', 'TV', //
  'Heart', 'House', 'Fork and knife', 'Card', 'Gift', 'Plane',
];

const _coffee = UnbudgetedCategory(category: 'Coffee', monthSpend: 600, suggestedCap: 650);

void main() {
  group('keypad and steps', () {
    testWidgets('typing 1, 2, 5, 0 shows \$1,250 and delete removes a digit', (tester) async {
      await _pump(tester);
      await _openCap(tester);
      expect(_inSheet(find.text(r'$500')), findsOneWidget);

      await _delete(tester, 1);
      expect(_inSheet(find.text(r'$50')), findsWidgets);
      await _delete(tester, 2);
      expect(_inSheet(find.text(r'$0')), findsOneWidget);

      await _type(tester, '1250');
      expect(_inSheet(find.text(r'$1,250')), findsOneWidget);
      await _delete(tester, 1);
      expect(_inSheet(find.text(r'$125')), findsOneWidget);
    });

    testWidgets('the steps move by \$50, clamp at 0 and stop at the max', (tester) async {
      await _pump(tester);
      await _openCap(tester);

      await _label(tester, r'+ $50');
      await _label(tester, r'+ $50');
      await _label(tester, r'− $50');
      expect(_inSheet(find.text(r'$550')), findsOneWidget);

      await _delete(tester, 3);
      await _type(tester, '20');
      await _label(tester, r'− $50');
      expect(_inSheet(find.text(r'$0')), findsOneWidget);

      await _type(tester, '99999');
      await _label(tester, r'+ $50');
      expect(_inSheet(find.text(r'$100,000')), findsOneWidget);
      await _label(tester, r'+ $50');
      await _type(tester, '1');
      expect(_inSheet(find.text(r'$100,000')), findsOneWidget);
    });

    testWidgets('in VND the steps read 50.000 ₫ and the cap fits at 390 wide', (tester) async {
      await _pump(tester,
          currency: Currency.vnd, envelope: _groceries.copyWith(cap: 1250000));
      await _openCap(tester);

      // the currency's space before ₫ is non-breaking.
      final cap = formatCurrency(1250000, Currency.vnd);
      final step = formatCurrency(50000, Currency.vnd);
      expect(cap, '1.250.000 ₫');
      expect(step, '50.000 ₫');
      expect(_inSheet(find.text(cap)), findsOneWidget);
      expect(find.bySemanticsLabel('− $step'), findsOneWidget);
      expect(find.bySemanticsLabel('+ $step'), findsOneWidget);
      final amount = tester.getRect(_inSheet(find.text(cap)));
      expect(amount.right, lessThanOrEqualTo(390));
      expect(tester.takeException(), isNull);
    });
  });

  group('saving', () {
    testWidgets('Save is off at 0', (tester) async {
      final fake = await _pump(tester);
      await _openCap(tester);
      await _delete(tester, 3);

      _expectDisabled(tester, 'Save');
      await _label(tester, 'Save');
      expect(fake.calls, isEmpty);
      expect(_sheet, findsOneWidget);
    });

    testWidgets('Save writes the whole-unit cap and closes the sheet', (tester) async {
      final fake = await _pump(tester);
      await _openCap(tester);
      await _delete(tester, 3);
      await _type(tester, '1250');
      await _label(tester, 'Save');

      expect(fake.calls, ['setCap env-grocer 1250.0']);
      expect(_sheet, findsNothing);
    });

    testWidgets('a failed save keeps the sheet and draft; the next key clears the note',
        (tester) async {
      final fake = await _pump(tester);
      fake.fail = true;
      await _openCap(tester);
      await _delete(tester, 3);
      await _type(tester, '1250');
      await _label(tester, 'Save');

      expect(find.byType(FailureNote), findsOneWidget);
      expect(find.text(saveFailedCopy), findsOneWidget);
      expect(_inSheet(find.text(r'$1,250')), findsOneWidget);

      await _type(tester, '0');
      expect(find.byType(FailureNote), findsNothing);
      expect(_inSheet(find.text(r'$12,500')), findsOneWidget);
    });

    testWidgets('a digit rejected at the max still clears the note', (tester) async {
      final fake = await _pump(tester);
      fake.fail = true;
      await _openCap(tester);
      await _delete(tester, 3);
      await _type(tester, '100000');
      await _label(tester, 'Save');
      expect(find.byType(FailureNote), findsOneWidget);

      await _type(tester, '1');
      expect(find.byType(FailureNote), findsNothing);
      expect(_inSheet(find.text(r'$100,000')), findsOneWidget);
    });
  });

  group('adding', () {
    testWidgets('Next is off for an empty name and for a duplicate, with the note',
        (tester) async {
      await _pump(tester);
      await _openNew(tester);
      expect(_inSheet(find.text('New envelope')), findsOneWidget);
      _expectDisabled(tester, 'Next');

      await tester.enterText(find.byType(TextField), '  groceries ');
      await tester.pumpAndSettle();
      expect(find.text('You already have a groceries envelope.'), findsOneWidget);
      _expectDisabled(tester, 'Next');

      await tester.enterText(find.byType(TextField), 'Pets');
      await tester.pumpAndSettle();
      expect(find.textContaining('You already have'), findsNothing);
      expect(tester.getSemantics(find.bySemanticsLabel('Next')),
          isSemantics(hasTapAction: true));
    });

    testWidgets('twelve labelled icon cells, one selected, and a tap moves it', (tester) async {
      await _pump(tester);
      await _openNew(tester);

      for (final word in _iconWords) {
        expect(find.bySemanticsLabel(word), findsOneWidget, reason: word);
      }
      expect(_iconWords.where((w) => _selected(tester, w)), ['Card']);

      await _label(tester, 'Gift');
      expect(_iconWords.where((w) => _selected(tester, w)), ['Gift']);
    });

    testWidgets('a pick fills the name and leaves the icon alone', (tester) async {
      await _pump(tester, unbudgeted: [_coffee]);
      await _openNew(tester);
      expect(find.text('You spend on these without a cap'), findsOneWidget);

      await _label(tester, r'Coffee, $600 this month');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Coffee');
      expect(find.bySemanticsLabel(r'Coffee, $600 this month'), findsNothing);
      expect(_iconWords.where((w) => _selected(tester, w)), ['Card']);
    });

    testWidgets('Back from the cap keeps the name and icon', (tester) async {
      await _pump(tester);
      await _openNew(tester);
      await tester.enterText(find.byType(TextField), 'Pets');
      await _label(tester, 'Gift');
      await _label(tester, 'Next');

      expect(_inSheet(find.text('Pets')), findsOneWidget);
      expect(find.text('A month, from the 1st'), findsOneWidget);
      expect(_inSheet(find.text(r'$0')), findsOneWidget);
      _expectDisabled(tester, 'Add');

      await _label(tester, 'Back');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Pets');
      expect(_iconWords.where((w) => _selected(tester, w)), ['Gift']);
    });

    testWidgets('Cancel closes the sheet without adding', (tester) async {
      final fake = await _pump(tester);
      await _openNew(tester);
      await tester.enterText(find.byType(TextField), 'Pets');
      await _label(tester, 'Cancel');

      expect(_sheet, findsNothing);
      expect(fake.calls, isEmpty);
    });

    testWidgets('Add writes the trimmed name, the icon and the cap', (tester) async {
      final fake = await _pump(tester);
      await _openNew(tester);
      await tester.enterText(find.byType(TextField), '  Pets  ');
      await _label(tester, 'Gift');
      await _label(tester, 'Next');
      await _type(tester, '75');
      await _label(tester, 'Add');

      expect(fake.calls, ['add Pets gift 75.0']);
      expect(_sheet, findsNothing);
    });

    testWidgets('a failed add keeps step two with its draft', (tester) async {
      final fake = await _pump(tester);
      fake.fail = true;
      await _openNew(tester);
      await tester.enterText(find.byType(TextField), 'Pets');
      await _label(tester, 'Next');
      await _type(tester, '75');
      await _label(tester, 'Add');

      expect(find.text(saveFailedCopy), findsOneWidget);
      expect(_inSheet(find.text(r'$75')), findsOneWidget);
    });
  });

  testWidgets('the cap sheet is titled with the envelope and notes its spend', (tester) async {
    await _pump(tester);
    await _openCap(tester);

    expect(_inSheet(find.text('Groceries')), findsOneWidget);
    expect(find.text(r'$286 spent so far this month'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete envelope'), findsOneWidget);
  });

  group('deleting', () {
    testWidgets('the confirm deletes and closes the sheet', (tester) async {
      final fake = await _pump(tester);
      await _openCap(tester);
      await _label(tester, 'Delete envelope');

      expect(find.text('Delete Groceries?'), findsOneWidget);
      expect(find.text('Spending logged as Groceries stays. It just has no cap.'),
          findsOneWidget);
      expect(find.byType(Keypad), findsNothing);

      await _label(tester, 'Delete');
      expect(fake.calls, ['delete env-grocer']);
      expect(_sheet, findsNothing);
    });

    testWidgets('a failed delete shows the delete copy and stays', (tester) async {
      final fake = await _pump(tester);
      fake.fail = true;
      await _openCap(tester);
      await _label(tester, 'Delete envelope');
      await _label(tester, 'Delete');

      expect(find.text(deleteFailedCopy), findsOneWidget);
      expect(find.text('Delete Groceries?'), findsOneWidget);
    });

    testWidgets('Cancel on the confirm returns to the cap with the draft', (tester) async {
      final fake = await _pump(tester);
      await _openCap(tester);
      await _delete(tester, 1);
      await _label(tester, 'Delete envelope');
      await _label(tester, 'Cancel');

      expect(find.byType(Keypad), findsOneWidget);
      expect(_inSheet(find.text(r'$50')), findsWidgets);
      expect(fake.calls, isEmpty);
    });
  });

  testWidgets('every control in the sheets is at least 44 by 44', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, unbudgeted: [_coffee]);
    await _openCap(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await _label(tester, 'Cancel');

    await _openNew(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}
