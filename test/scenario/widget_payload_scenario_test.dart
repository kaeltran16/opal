@Tags(['scenario'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/widget_sync_controller.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/util/format.dart';

import 'scenario_harness.dart';

/// One canvas Widget board state, and the copy its rows must read.
class _Fixture {
  const _Fixture(this.state, this.numbers, this.rows);

  final String state;
  final GlanceNumbers numbers;

  /// Expected `(value, first state word)` for move, routines and money.
  final List<(String, String)> rows;
}

GlanceNumbers _numbers({
  double spent = 38,
  int moveKcal = 310,
  int routinesDone = 2,
}) =>
    GlanceNumbers(
      spent: spent,
      budget: 60,
      moveKcal: moveKcal,
      moveGoal: 500,
      routinesDone: routinesDone,
      routinesTotal: 4,
    );

final _fixtures = [
  _Fixture('watch', _numbers(), const [
    ('310 of 500 kcal', 'On track'),
    ('2 of 4 done', 'On track'),
    (r'$22 left of $60', 'Worth watching'),
  ]),
  // canvas delta: the board shows "$4 left", but care needs over budget.
  _Fixture('care', _numbers(spent: 64), const [
    ('310 of 500 kcal', 'On track'),
    ('2 of 4 done', 'On track'),
    (r'$4 over $60', 'Needs care'),
  ]),
  _Fixture('ahead', _numbers(moveKcal: 520, routinesDone: 4, spent: 29), const [
    ('520 of 500 kcal', 'Ahead'),
    ('4 of 4 done', 'Ahead'),
    (r'$31 left of $60', 'On track'),
  ]),
];

void main() {
  final at = DateTime(2026, 10, 13, 11);

  for (final f in _fixtures) {
    test('widget payload: ${f.state}', () {
      final s = buildWidgetSnapshot(f.numbers, Currency.usd, at);
      final rows = [s.move, s.routines, s.money];

      expect(
        [for (final r in rows) (r.value, r.states.first.word)],
        f.rows,
      );

      final file = File('${scenarioOut.path}/widget-${f.state}.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(s.toJson()));
    });
  }
}
