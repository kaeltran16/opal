import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/budget_advisories_controller.dart';
import 'package:opal/controllers/budget_envelopes_controller.dart';
import 'package:opal/controllers/budget_recommendations_controller.dart';
import 'package:opal/controllers/budgets_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/money/envelope_editor_screen.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/failure_note.dart';
import 'package:opal/widgets/keypad.dart';

import '../../support/failing_stream.dart';

BudgetEnvelope _env(String id, String category, double cap, String icon, int position) =>
    BudgetEnvelope(
      id: id, category: category, cap: cap, icon: icon,
      colorToken: 'money', position: position,
    );

final _seed = [
  _env('env-grocer', 'Groceries', 500, 'basket.fill', 0),
  _env('env-transit', 'Transport', 200, 'car.fill', 1),
  _env('env-health', 'Health', 150, 'heart.fill', 2),
];

/// Streams [items] and re-emits after each write that lands; records every
/// write, and throws instead while [fail] is set. [stream] replaces the
/// emissions, for loading and load-error.
class _FakeEnvelopes extends BudgetEnvelopesController {
  _FakeEnvelopes(this.items, {this.stream});

  List<BudgetEnvelope> items;
  final Stream<List<BudgetEnvelope>>? stream;
  bool fail = false;
  final calls = <String>[];
  final _changes = StreamController<List<BudgetEnvelope>>.broadcast();

  @override
  Stream<List<BudgetEnvelope>> build() => stream ?? _emit();

  Stream<List<BudgetEnvelope>> _emit() async* {
    yield items;
    yield* _changes.stream;
  }

  Future<void> _write(String call, List<BudgetEnvelope> Function() next) async {
    calls.add(call);
    if (fail) throw StateError('disk full');
    items = next();
    _changes.add(items);
  }

  @override
  Future<void> reorder(int oldIndex, int newIndex) =>
      _write('reorder $oldIndex $newIndex', () {
        final list = List.of(items);
        list.insert(newIndex, list.removeAt(oldIndex));
        return list;
      });

  @override
  Future<void> applyCap(String category, double cap, {String icon = kDefaultEnvelopeIcon}) =>
      _write('applyCap $category $cap', () => [
            for (final e in items) e.category == category ? e.copyWith(cap: cap) : e,
          ]);
}

BudgetRecommendation _rec(String category, double suggested, double? current, double average,
        {SpendTrend trend = SpendTrend.stable}) =>
    BudgetRecommendation(
      category: category,
      suggestedCap: suggested,
      currentCap: current,
      monthlyAverage: average,
      trend: trend,
      percentChange: 0,
      confidence: RecommendationConfidence.high,
      bufferFraction: 0.15,
    );

final _recs = [
  _rec('Groceries', 550, 500, 468),
  _rec('Coffee', 100, null, 74, trend: SpendTrend.increasing),
  _rec('Health', 150, 150, 120),
];

Future<_FakeEnvelopes> _pump(
  WidgetTester tester, {
  List<BudgetEnvelope>? envelopes,
  Stream<List<BudgetEnvelope>>? stream,
  List<BudgetRecommendation>? recs,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fake = _FakeEnvelopes(envelopes ?? _seed, stream: stream);
  final now = clock.now();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        budgetEnvelopesControllerProvider.overrideWith(() => fake),
        budgetRecommendationsProvider.overrideWith((ref) => Stream.value(recs ?? _recs)),
        budgetsDataProvider.overrideWith((ref) => Stream.value(BudgetsData(
              envelopes: const [],
              month: DateTime(now.year, now.month),
              monthlyBudget: 3000,
            ))),
        budgetAdvisoriesProvider.overrideWith(
            (ref) => Stream.value(const BudgetAdvisories(unbudgeted: [], savings: []))),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppColors.light()]),
        home: const EnvelopeEditorScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Drags [name]'s handle down by [rows] rows.
Future<void> _drag(WidgetTester tester, String name, int rows) async {
  final handle = find.bySemanticsLabel('Reorder $name');
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump();
  for (var i = 0; i < rows * 4; i++) {
    await gesture.moveBy(const Offset(0, 18));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Row names from top to bottom, by their handles.
List<String> _order(WidgetTester tester) {
  double top(String name) => tester.getTopLeft(find.bySemanticsLabel('Reorder $name')).dy;
  return _seed.map((e) => e.category).toList()..sort((a, b) => top(a).compareTo(top(b)));
}

void main() {
  testWidgets('rows draw their line glyph, name and cap under the summary', (tester) async {
    await _pump(tester);

    expect(find.text('Envelopes'), findsOneWidget);
    expect(find.text(r'3 envelopes · $850 a month'), findsOneWidget);
    for (final e in _seed) {
      expect(find.byIcon(lineIconForSf(e.icon)), findsOneWidget, reason: e.icon);
    }
    expect(find.text(r'$500'), findsOneWidget);
    expect(find.text('Tap an envelope to change its cap. Drag to reorder.'), findsOneWidget);
  });

  testWidgets('one envelope reads singular', (tester) async {
    await _pump(tester, envelopes: [_seed.first]);

    expect(find.text(r'1 envelope · $500 a month'), findsOneWidget);
  });

  testWidgets('rows and handles carry their labels, and tapping a row opens its cap',
      (tester) async {
    await _pump(tester);

    for (final (name, cap) in [('Groceries', r'$500'), ('Transport', r'$200'), ('Health', r'$150')]) {
      expect(find.bySemanticsLabel('$name, $cap a month. Edit cap'), findsOneWidget);
      expect(find.bySemanticsLabel('Reorder $name'), findsOneWidget);
    }

    await _tap(tester, find.bySemanticsLabel(r'Groceries, $500 a month. Edit cap'));
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Groceries')),
        findsOneWidget);
  });

  testWidgets('New envelope opens the add sheet', (tester) async {
    await _pump(tester);
    await _tap(tester, find.bySemanticsLabel('New envelope'));

    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('New envelope')),
        findsOneWidget);
  });

  group('reordering', () {
    testWidgets('dragging a handle reorders', (tester) async {
      final fake = await _pump(tester);
      await _drag(tester, 'Groceries', 1);

      expect(fake.calls, ['reorder 0 1']);
      expect(_order(tester), ['Transport', 'Groceries', 'Health']);
      expect(find.byType(FailureNote), findsNothing);
    });

    testWidgets('a failed reorder shows the note and keeps the order', (tester) async {
      final fake = await _pump(tester);
      fake.fail = true;
      await _drag(tester, 'Groceries', 1);

      expect(fake.calls, ['reorder 0 1']);
      expect(find.byType(FailureNote), findsOneWidget);
      expect(find.text(saveFailedCopy), findsOneWidget);
      expect(_order(tester), ['Groceries', 'Transport', 'Health']);

      fake.fail = false;
      await _tap(tester, find.bySemanticsLabel(r'Use $550 for Groceries'));
      expect(find.byType(FailureNote), findsNothing);
    });
  });

  group('suggestions', () {
    testWidgets('rows show with their heading and footer; an equal cap is hidden',
        (tester) async {
      await _pump(tester);

      expect(find.text('Suggested caps'), findsOneWidget);
      expect(find.text('From your spending over the last 3 months.'), findsOneWidget);
      expect(find.text(r'$468/mo · steady · now $500'), findsOneWidget);
      expect(find.text(r'No envelope yet · $74/mo'), findsOneWidget);
      expect(find.bySemanticsLabel(r'Use $100 for Coffee'), findsOneWidget);
      expect(find.bySemanticsLabel(r'Use $150 for Health'), findsNothing);
    });

    testWidgets('Use applies the suggested cap', (tester) async {
      final fake = await _pump(tester);
      await _tap(tester, find.bySemanticsLabel(r'Use $550 for Groceries'));

      expect(fake.calls, ['applyCap Groceries 550.0']);
    });

    testWidgets('a failed Use shows the list note', (tester) async {
      final fake = await _pump(tester);
      fake.fail = true;
      await _tap(tester, find.bySemanticsLabel(r'Use $100 for Coffee'));

      expect(find.byType(FailureNote), findsOneWidget);
    });

    testWidgets('a key on a cap sheet clears the list note', (tester) async {
      final fake = await _pump(tester);
      fake.fail = true;
      await _tap(tester, find.bySemanticsLabel(r'Use $100 for Coffee'));
      await _tap(tester, find.bySemanticsLabel(r'Groceries, $500 a month. Edit cap'));
      expect(find.byType(FailureNote), findsOneWidget);

      await _tap(tester, find.descendant(of: find.byType(Keypad), matching: find.text('5')));
      expect(find.byType(FailureNote), findsNothing);
    });

    testWidgets('naming a new envelope clears the list note', (tester) async {
      final fake = await _pump(tester);
      fake.fail = true;
      await _tap(tester, find.bySemanticsLabel(r'Use $100 for Coffee'));
      await _tap(tester, find.bySemanticsLabel('New envelope'));
      expect(find.byType(FailureNote), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Pets');
      await tester.pumpAndSettle();
      expect(find.byType(FailureNote), findsNothing);
    });

    testWidgets('the section is left out when no row remains', (tester) async {
      await _pump(tester, recs: [_rec('Health', 150, 150, 120)]);

      expect(find.text('Suggested caps'), findsNothing);
      expect(find.text('From your spending over the last 3 months.'), findsNothing);
    });
  });

  group('states', () {
    testWidgets('loading shows the ellipsis', (tester) async {
      await _pump(tester, stream: StreamController<List<BudgetEnvelope>>().stream);

      expect(find.text('…'), findsOneWidget);
      expect(find.text('New envelope'), findsNothing);
    });

    testWidgets('a load error says so', (tester) async {
      await _pump(tester, stream: failingStream(StateError('no table')));

      expect(find.text("Couldn't load your envelopes."), findsOneWidget);
    });

    testWidgets('empty: the summary and list copy, New envelope and suggestions stay',
        (tester) async {
      await _pump(tester, envelopes: const []);

      expect(find.text('Caps you set here pace this month’s spending.'), findsOneWidget);
      expect(find.text('No envelopes yet. Add one, or use a suggested cap below.'),
          findsOneWidget);
      expect(find.bySemanticsLabel('New envelope'), findsOneWidget);
      expect(find.text('Suggested caps'), findsOneWidget);
      expect(find.text('Tap an envelope to change its cap. Drag to reorder.'), findsNothing);
    });
  });

  testWidgets('every control is at least 44 by 44', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}
