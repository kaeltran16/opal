@Tags(['scenario'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/budget_envelopes_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/money/envelope_editor_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/failure_note.dart';
import 'package:opal/widgets/keypad.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _editorRoute = '/you/budgets/envelopes';
const _writeTurn = Duration(milliseconds: 300);
const _dragStep = Offset(0, 16);
const _dragSteps = 5;

// the scenario's own spend, on the 10th of each month it lands in.
const _spendDay = 10;
const _groceriesMonthly = 900.0; // lifts its suggested cap well past the seed's 500
const _coffeeMonthly = 80.0;
const _coffeeThisMonth = 520.0; // at or above the $500 advisory floor

const _iconWords = [
  'Cup', 'Basket', 'Bolt', 'Bag', 'Car', 'TV', //
  'Heart', 'House', 'Fork and knife', 'Card', 'Gift', 'Plane',
];

const _budgetsRoute = '/you/budgets';
const _budgetsFooter = 'Adjust caps anytime. Pal nudges you before an envelope runs dry.';
const _capStep = 50.0;
const _groceriesSuggested = 1050.0; // $900/mo plus the recommendation's buffer, rounded

String _theme(bool dark) => dark ? 'dark' : 'light';

// Groceries spend this month that the seed already carries; Budgets shows cap less this.
const _groceriesSpent = 38.4;

String _left(double cap) => '${formatCurrency(cap - _groceriesSpent, Currency.usd)} left';

/// Envelope writes that always fail, as a full disk would.
class _FailingEnvelopes extends BudgetEnvelopeRepository {
  _FailingEnvelopes(super.db);

  @override
  Future<void> upsert(BudgetEnvelope envelope) async => throw StateError('disk full');

  @override
  Future<void> deleteById(String id) async => throw StateError('disk full');

  @override
  Future<void> reorder(List<BudgetEnvelope> envelopes) async => throw StateError('disk full');
}

/// A controller whose stream never emits, or only errors.
class _StuckEnvelopes extends BudgetEnvelopesController {
  _StuckEnvelopes({this.error = false});

  final bool error;

  @override
  Stream<List<BudgetEnvelope>> build() => error
      ? Stream.error(StateError('no table'))
      : StreamController<List<BudgetEnvelope>>().stream;
}

Override get _failingWrites => budgetEnvelopeRepositoryProvider
    .overrideWith((ref) => _FailingEnvelopes(ref.watch(loopDatabaseProvider)));

Entry _expense(String category, double amount, DateTime at) => Entry(
      id: 'scenario-${normalizeCategory(category)}-${at.year}-${at.month}',
      timestamp: at,
      type: EntryType.money,
      title: category,
      amount: -amount,
      category: category,
      source: EntrySource.manual,
    );

/// The scenario's spend, relative to [goldenClock]: Groceries in each of the
/// three completed months, so its suggested cap moves off the seed's 500; and
/// Coffee, which has no envelope, in those months (a "No envelope yet"
/// suggestion) and this month above the advisory floor (a pick).
Future<void> _seedSpend(LoopDatabase db) async {
  final entries = EntryRepository(db);
  final now = clock.now();
  for (var back = 1; back <= 3; back++) {
    final at = DateTime(now.year, now.month - back, _spendDay);
    await entries.insert(_expense('Groceries', _groceriesMonthly, at));
    await entries.insert(_expense('Coffee', _coffeeMonthly, at));
  }
  await entries.insert(
      _expense('Coffee', _coffeeThisMonth, DateTime(now.year, now.month, _spendDay)));
}

/// Boots the app over a seeded in-memory database plus the scenario's spend,
/// with [prefs] on top (the currency), and [empty] removing every envelope.
Future<void> _boot(
  WidgetTester tester,
  bool dark, {
  Map<String, Object> prefs = const {},
  bool empty = false,
  List<Override> overrides = const [],
}) async {
  ignoreOverflowErrors();
  SharedPreferences.setMockInitialValues({
    'settings.onboardingComplete': true,
    'settings.brightness': dark ? 'dark' : 'light',
    ...prefs,
  });
  final sp = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  await _seedSpend(db);
  if (empty) {
    final envelopes = BudgetEnvelopeRepository(db);
    for (final e in await envelopes.getEnvelopes()) {
      await envelopes.deleteById(e.id);
    }
  }
  addTearDown(db.close);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(MockPalService(latency: Duration.zero, seed: 0)),
      ...overrides,
    ],
    child: const LoopApp(),
  ));
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, String location) async {
  appRouter(tester).go(location);
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester) => _go(tester, _editorRoute);

Finder _onEditor(Finder matching) =>
    find.descendant(of: find.byType(EnvelopeEditorScreen), matching: matching);

Finder get _sheet => find.byType(BottomSheet);

Finder _inSheet(Finder matching) => find.descendant(of: _sheet, matching: matching);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapLabel(WidgetTester tester, String label) =>
    _tap(tester, find.bySemanticsLabel(label));

/// Lets a database write finish: the full app's drift future completes only on
/// a real async turn, which the test's fake-async zone never takes.
Future<void> _settleWrite(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(_writeTurn));
  await tester.pumpAndSettle();
}

/// Taps [label] for a write, then lets it land.
Future<void> _write(WidgetTester tester, String label) async {
  final finder = find.bySemanticsLabel(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settleWrite(tester);
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await _tap(tester, find.descendant(of: find.byType(Keypad), matching: find.text(d)));
  }
}

/// Empties the keypad's draft, one delete per digit of [cap].
Future<void> _clear(WidgetTester tester, int cap) async {
  for (var i = 0; i < '$cap'.length; i++) {
    await _tapLabel(tester, 'delete');
  }
}

String _rowLabel(BudgetEnvelope e, Currency currency) =>
    '${e.category}, ${formatCurrency(e.cap, currency)} a month. Edit cap';

BudgetEnvelope get _groceries =>
    SeedData.budgetEnvelopes().firstWhere((e) => e.category == 'Groceries');

/// Opens Groceries' cap sheet from its row.
Future<void> _openGroceries(WidgetTester tester, {Currency currency = Currency.usd}) =>
    _tapLabel(tester, _rowLabel(_groceries, currency));

Future<void> _openNew(WidgetTester tester) => _tapLabel(tester, 'New envelope');

String _field(WidgetTester tester) =>
    tester.widget<TextField>(_inSheet(find.byType(TextField))).controller!.text;

List<String> _selectedIcons(WidgetTester tester) => [
      for (final word in _iconWords)
        if (isSemantics(isSelected: true)
            .matches(tester.getSemantics(find.bySemanticsLabel(word)), {}))
          word,
    ];

final _coffeePick = find.bySemanticsLabel(
    RegExp('^Coffee, ${RegExp.escape(formatCurrency(_coffeeThisMonth, Currency.usd))} this month\$'));

Finder _use(String category) => find.bySemanticsLabel(RegExp('^Use .* for $category\$'));

/// Taps `Use` on [category]'s suggestion and lets the write land.
Future<void> _writeUse(WidgetTester tester, String category) async {
  await tester.ensureVisible(_use(category));
  await tester.pumpAndSettle();
  await tester.tap(_use(category));
  await _settleWrite(tester);
}

/// The fixture's rows: Groceries and Coffee under Suggested caps, and Coffee
/// as a pick in the new-envelope sheet. Leaves the editor with no sheet open.
Future<void> _expectFixture(WidgetTester tester) async {
  await tester.ensureVisible(_use('Coffee'));
  await tester.pumpAndSettle();
  expect(_onEditor(find.text('Suggested caps')), findsOneWidget);
  expect(_use('Groceries'), findsOneWidget);
  expect(_use('Coffee'), findsOneWidget);
  expect(_onEditor(find.textContaining('No envelope yet · ')), findsOneWidget);

  await _openNew(tester);
  expect(_coffeePick, findsOneWidget);
  await _tapLabel(tester, 'Cancel');
  expect(_sheet, findsNothing);
  await tester.drag(_onEditor(find.byType(Scrollable)).first, const Offset(0, 2000));
  await tester.pumpAndSettle();
}

/// Row names from top to bottom, by their handles.
List<String> _order(WidgetTester tester) {
  double top(String name) => tester.getTopLeft(find.bySemanticsLabel('Reorder $name')).dy;
  return SeedData.budgetEnvelopes().map((e) => e.category).toList()
    ..sort((a, b) => top(a).compareTo(top(b)));
}

/// Drags [name]'s handle down one row and lets the write land.
Future<void> _dragDown(WidgetTester tester, String name) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.bySemanticsLabel('Reorder $name')));
  await tester.pump();
  for (var i = 0; i < _dragSteps; i++) {
    await gesture.moveBy(_dragStep);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
  await _settleWrite(tester);
}

/// The add sheet's first step with Coffee picked and Gift chosen.
Future<void> _pickCoffee(WidgetTester tester) async {
  await _openNew(tester);
  await _tap(tester, _coffeePick);
  await _tapLabel(tester, 'Gift');
}

/// The add sheet's second step: Coffee, Gift, a cap of 120.
Future<void> _coffeeCap(WidgetTester tester) async {
  await _pickCoffee(tester);
  await _tapLabel(tester, 'Next');
  await _type(tester, '120');
}

void main() {
  final seed = SeedData.budgetEnvelopes();

  scenarioTest('envelopes_list', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _expectFixture(tester);

    final total = seed.fold<double>(0, (sum, e) => sum + e.cap);
    expect(
        _onEditor(find.text(
            '${seed.length} envelopes · ${formatCurrency(total, Currency.usd)} a month')),
        findsOneWidget);
    for (final e in seed) {
      expect(find.bySemanticsLabel(_rowLabel(e, Currency.usd)), findsOneWidget,
          reason: e.category);
      expect(_onEditor(find.byIcon(lineIconForSf(e.icon))), findsOneWidget, reason: e.icon);
    }
    await shot(tester, 'envelopes_list_${_theme(dark)}');
  });

  scenarioTest('envelopes_loading', (tester, dark) async {
    await _boot(tester, dark, overrides: [
      budgetEnvelopesControllerProvider.overrideWith(_StuckEnvelopes.new),
    ]);
    await _openEditor(tester);

    expect(_onEditor(find.text('…')), findsOneWidget);
    expect(_onEditor(find.text('New envelope')), findsNothing);
    await shot(tester, 'envelopes_loading_${_theme(dark)}');
  });

  scenarioTest('envelopes_cap_keypad', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _openGroceries(tester);
    expect(_inSheet(find.text('Groceries')), findsOneWidget);

    await _clear(tester, _groceries.cap.round());
    await _type(tester, '1250');
    expect(_inSheet(find.text(r'$1,250')), findsOneWidget);
    await shot(tester, 'envelopes_cap_keypad_${_theme(dark)}');
  });

  scenarioTest('envelopes_cap_stepped', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _openGroceries(tester);
    expect(_inSheet(find.text(r'$500')), findsOneWidget);

    await _tapLabel(tester, r'+ $50');
    await _tapLabel(tester, r'+ $50');
    await _tapLabel(tester, r'− $50');
    expect(_inSheet(find.text(r'$550')), findsOneWidget);
    await shot(tester, 'envelopes_cap_stepped_${_theme(dark)}');
  });

  scenarioTest('envelopes_cap_vnd', (tester, dark) async {
    await _boot(tester, dark, prefs: {'settings.currency': 'VND'});
    await _openEditor(tester);
    await _openGroceries(tester, currency: Currency.vnd);

    await _clear(tester, _groceries.cap.round());
    await _type(tester, '1250000');
    final cap = formatCurrency(1250000, Currency.vnd);
    final step = formatCurrency(50000, Currency.vnd);
    expect(cap, '1.250.000 ₫');
    expect(_inSheet(find.text(cap)), findsOneWidget);
    expect(tester.getRect(_inSheet(find.text(cap))).right, lessThanOrEqualTo(390));
    expect(find.bySemanticsLabel('− $step'), findsOneWidget);
    expect(find.bySemanticsLabel('+ $step'), findsOneWidget);
    await shot(tester, 'envelopes_cap_vnd_${_theme(dark)}');
  });

  scenarioTest('envelopes_cap_save_failed', (tester, dark) async {
    await _boot(tester, dark, overrides: [_failingWrites]);
    await _openEditor(tester);
    await _openGroceries(tester);
    await _tapLabel(tester, r'+ $50');
    await _write(tester, 'Save');

    expect(find.byType(FailureNote), findsOneWidget);
    expect(_inSheet(find.text(saveFailedCopy)), findsOneWidget);
    expect(_inSheet(find.text(r'$550')), findsOneWidget);
    await shot(tester, 'envelopes_cap_save_failed_${_theme(dark)}');
  });

  scenarioTest('envelopes_add_name', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _openNew(tester);

    expect(_coffeePick, findsOneWidget);
    await tester.enterText(_inSheet(find.byType(TextField)), 'groceries');
    await tester.pumpAndSettle();
    expect(_inSheet(find.text('You already have a groceries envelope.')), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Next')),
        isSemantics(hasEnabledState: true, isEnabled: false));
    for (final word in _iconWords) {
      expect(find.bySemanticsLabel(word), findsOneWidget, reason: word);
    }
    expect(_selectedIcons(tester), ['Card']);
    await shot(tester, 'envelopes_add_name_${_theme(dark)}');
  });

  scenarioTest('envelopes_add_picked', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _pickCoffee(tester);

    expect(_field(tester), 'Coffee');
    expect(_selectedIcons(tester), ['Gift']);
    await shot(tester, 'envelopes_add_picked_${_theme(dark)}');
  });

  scenarioTest('envelopes_add_cap', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _coffeeCap(tester);

    expect(_inSheet(find.text('Coffee')), findsOneWidget);
    expect(_inSheet(find.text('A month, from the 1st')), findsOneWidget);
    expect(_inSheet(find.text(r'$120')), findsOneWidget);
    await shot(tester, 'envelopes_add_cap_${_theme(dark)}');
  });

  scenarioTest('envelopes_add_back', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _coffeeCap(tester);
    await _tapLabel(tester, 'Back');

    expect(_inSheet(find.text('New envelope')), findsOneWidget);
    expect(_field(tester), 'Coffee');
    expect(_selectedIcons(tester), ['Gift']);
    await shot(tester, 'envelopes_add_back_${_theme(dark)}');
  });

  scenarioTest('envelopes_added', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _coffeeCap(tester);
    await _write(tester, 'Add');

    expect(_sheet, findsNothing);
    final row = find.bySemanticsLabel(r'Coffee, $120 a month. Edit cap');
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(_onEditor(find.byIcon(lineIconForSf('gift'))), findsOneWidget);
    await shot(tester, 'envelopes_added_${_theme(dark)}');
  });

  scenarioTest('envelopes_delete_confirm', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _openGroceries(tester);
    await _tapLabel(tester, 'Delete envelope');

    expect(_inSheet(find.text('Delete Groceries?')), findsOneWidget);
    expect(_inSheet(find.text('Spending logged as Groceries stays. It just has no cap.')),
        findsOneWidget);
    expect(find.byType(Keypad), findsNothing);
    await shot(tester, 'envelopes_delete_confirm_${_theme(dark)}');
  });

  scenarioTest('envelopes_delete_cancelled', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _openGroceries(tester);
    await _tapLabel(tester, r'+ $50');
    await _tapLabel(tester, 'Delete envelope');
    await _tapLabel(tester, 'Cancel');

    expect(find.byType(Keypad), findsOneWidget);
    expect(_inSheet(find.text('Groceries')), findsOneWidget);
    expect(_inSheet(find.text(r'$550')), findsOneWidget);
    await shot(tester, 'envelopes_delete_cancelled_${_theme(dark)}');
  });

  scenarioTest('envelopes_delete_failed', (tester, dark) async {
    await _boot(tester, dark, overrides: [_failingWrites]);
    await _openEditor(tester);
    await _openGroceries(tester);
    await _tapLabel(tester, 'Delete envelope');
    await _write(tester, 'Delete');

    expect(_inSheet(find.text(deleteFailedCopy)), findsOneWidget);
    expect(_inSheet(find.text('Delete Groceries?')), findsOneWidget);
    await shot(tester, 'envelopes_delete_failed_${_theme(dark)}');
  });

  scenarioTest('envelopes_deleted', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _openGroceries(tester);
    await _tapLabel(tester, 'Delete envelope');
    await _write(tester, 'Delete');

    expect(_sheet, findsNothing);
    expect(find.bySemanticsLabel('Reorder Groceries'), findsNothing);
    expect(_onEditor(find.textContaining('${seed.length - 1} envelopes · ')), findsOneWidget);
    await shot(tester, 'envelopes_deleted_${_theme(dark)}');
  });

  scenarioTest('envelopes_reordered', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    final before = seed.map((e) => e.category).toList();
    await _dragDown(tester, before[0]);

    expect(_order(tester), [before[1], before[0], ...before.skip(2)]);
    expect(find.byType(FailureNote), findsNothing);
    await shot(tester, 'envelopes_reordered_${_theme(dark)}');
  });

  scenarioTest('envelopes_reorder_failed', (tester, dark) async {
    await _boot(tester, dark, overrides: [_failingWrites]);
    await _openEditor(tester);
    final before = seed.map((e) => e.category).toList();
    await _dragDown(tester, before[0]);

    expect(_onEditor(find.text(saveFailedCopy)), findsOneWidget);
    expect(_order(tester), before);
    await shot(tester, 'envelopes_reorder_failed_${_theme(dark)}');
  });

  scenarioTest('envelopes_suggestion_failed', (tester, dark) async {
    await _boot(tester, dark, overrides: [_failingWrites]);
    await _openEditor(tester);
    await _tap(tester, _use('Groceries'));

    await tester.drag(_onEditor(find.byType(Scrollable)).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(_onEditor(find.text(saveFailedCopy)), findsOneWidget);
    expect(_use('Groceries'), findsOneWidget);
    await shot(tester, 'envelopes_suggestion_failed_${_theme(dark)}');
  });

  scenarioTest('envelopes_empty', (tester, dark) async {
    await _boot(tester, dark, empty: true);
    await _openEditor(tester);

    expect(_onEditor(find.text('Caps you set here pace this month’s spending.')),
        findsOneWidget);
    expect(_onEditor(find.text('No envelopes yet. Add one, or use a suggested cap below.')),
        findsOneWidget);
    expect(find.bySemanticsLabel('New envelope'), findsOneWidget);
    expect(_onEditor(find.text('Suggested caps')), findsOneWidget);
    expect(_onEditor(find.text('Tap an envelope to change its cap. Drag to reorder.')),
        findsNothing);
    await shot(tester, 'envelopes_empty_${_theme(dark)}');
  });

  scenarioTest('envelopes_load_error', (tester, dark) async {
    await _boot(tester, dark, overrides: [
      budgetEnvelopesControllerProvider.overrideWith(() => _StuckEnvelopes(error: true)),
    ]);
    await _openEditor(tester);

    expect(_onEditor(find.text("Couldn't load your envelopes.")), findsOneWidget);
    await shot(tester, 'envelopes_load_error_${_theme(dark)}');
  });

  scenarioTest('budgets_options_opens_editor', (tester, dark) async {
    await _boot(tester, dark);
    await _go(tester, _budgetsRoute);
    await _tapLabel(tester, 'Budget options');

    expect(find.byType(EnvelopeEditorScreen), findsOneWidget);
    expect(_onEditor(find.text('Envelopes')), findsWidgets);
    await shot(tester, 'budgets_options_opens_editor_${_theme(dark)}');
  });

  scenarioTest('budgets_after_cap_edit', (tester, dark) async {
    await _boot(tester, dark);
    await _go(tester, _budgetsRoute);
    final before = find.text(_left(_groceries.cap));
    expect(before, findsOneWidget);

    await _tapLabel(tester, 'Budget options');
    await _openGroceries(tester);
    await _tapLabel(tester, r'+ $50');
    await _write(tester, 'Save');
    expect(_sheet, findsNothing);
    // the sheet's scroll-into-view left the list scrolled; the back control is at its top.
    await tester.drag(_onEditor(find.byType(Scrollable)).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    // the control's semantics span the row; only its chevron and label take taps.
    await _tap(tester, _onEditor(find.byIcon(iconForSf('chevron.left'))));

    expect(find.byType(EnvelopeEditorScreen), findsNothing);
    expect(find.text(_left(_groceries.cap + _capStep)), findsOneWidget);
    expect(before, findsNothing);
    await shot(tester, 'budgets_after_cap_edit_${_theme(dark)}');
  });

  scenarioTest('budgets_new_envelope', (tester, dark) async {
    await _boot(tester, dark);
    await _go(tester, _budgetsRoute);
    await _openNew(tester);

    expect(_sheet, findsOneWidget);
    expect(_inSheet(find.text('New envelope')), findsOneWidget);
    expect(_coffeePick, findsOneWidget);
    await shot(tester, 'budgets_new_envelope_${_theme(dark)}');
  });

  scenarioTest('budgets_empty', (tester, dark) async {
    await _boot(tester, dark, empty: true);
    await _go(tester, _budgetsRoute);

    expect(find.text('No envelopes yet.'), findsOneWidget);
    await shot(tester, 'budgets_empty_${_theme(dark)}');
  });

  scenarioTest('envelopes_suggestion_applied', (tester, dark) async {
    await _boot(tester, dark);
    await _openEditor(tester);
    await _expectFixture(tester);

    await _writeUse(tester, 'Groceries');
    expect(
        find.bySemanticsLabel(
            _rowLabel(_groceries.copyWith(cap: _groceriesSuggested), Currency.usd)),
        findsOneWidget);
    expect(_use('Groceries'), findsNothing);

    await _writeUse(tester, 'Coffee');
    final row = find.bySemanticsLabel(RegExp(r'^Coffee, .* a month\. Edit cap$'));
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(_onEditor(find.byIcon(lineIconForSf(kDefaultEnvelopeIcon))), findsWidgets);
    expect(_use('Coffee'), findsNothing);
    await shot(tester, 'envelopes_suggestion_applied_${_theme(dark)}');
  });

  scenarioTest('budgets_line_glyphs', (tester, dark) async {
    await _boot(tester, dark);
    await _go(tester, _budgetsRoute);

    // envelope rows come before the suggestions, so the first match is the row.
    final groceries = find
        .ancestor(of: find.text('Groceries').first, matching: find.byType(MergeSemantics))
        .first;
    expect(find.descendant(of: groceries, matching: find.byIcon(lineIconForSf('basket.fill'))),
        findsOneWidget);
    expect(find.descendant(of: groceries, matching: find.byIcon(iconForSf('basket.fill'))),
        findsNothing);
    await tester.ensureVisible(find.text(_budgetsFooter));
    await tester.pumpAndSettle();
    expect(find.text(_budgetsFooter), findsOneWidget);
    await shot(tester, 'budgets_line_glyphs_${_theme(dark)}');
  });
}
