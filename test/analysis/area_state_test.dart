import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/spending_controller.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/util/format.dart';

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 10, 3, hour, minute);

GlanceNumbers _numbers({
  double spent = 38,
  double budget = 60,
  int moveKcal = 310,
  int moveGoal = 500,
  int routinesDone = 2,
  int routinesTotal = 4,
}) =>
    GlanceNumbers(
      spent: spent,
      budget: budget,
      moveKcal: moveKcal,
      moveGoal: moveGoal,
      routinesDone: routinesDone,
      routinesTotal: routinesTotal,
    );

void main() {
  test('state words are the fixed four', () {
    expect(AreaState.values.map((s) => s.word),
        ['Ahead', 'On track', 'Worth watching', 'Needs care']);
  });

  group('dayShare', () {
    test('is 0 before and at 07:00', () {
      expect(dayShare(_at(6)), 0);
      expect(dayShare(_at(7)), 0);
    });

    test('is linear through the waking day', () {
      expect(dayShare(_at(14, 30)), 0.5);
    });

    test('is 1 at and after 22:00', () {
      expect(dayShare(_at(22)), 1);
      expect(dayShare(_at(23, 30)), 1);
    });
  });

  group('moneyState', () {
    test('on pace is good', () {
      expect(moneyState(spent: 30, budget: 60, now: _at(14, 30)), AreaState.good);
    });

    test('63% spent at 09:00 is watch', () {
      expect(moneyState(spent: 63, budget: 100, now: _at(9)), AreaState.watch);
    });

    test('63% spent at 20:00 is good', () {
      expect(moneyState(spent: 63, budget: 100, now: _at(20)), AreaState.good);
    });

    test('one cent over budget is care', () {
      expect(moneyState(spent: 60.01, budget: 60, now: _at(21)), AreaState.care);
    });

    test('exactly at budget late in the day is good', () {
      expect(moneyState(spent: 60, budget: 60, now: _at(21)), AreaState.good);
    });

    test('zero budget is good', () {
      expect(moneyState(spent: 38, budget: 0, now: _at(9)), AreaState.good);
    });
  });

  group('progressState', () {
    test('goal met is thriving at any hour', () {
      for (final hour in [6, 9, 14, 21, 23]) {
        expect(progressState(done: 500, goal: 500, now: _at(hour)),
            AreaState.thriving);
      }
      expect(progressState(done: 5, goal: 4, now: _at(9)), AreaState.thriving);
    });

    test('0 done at 09:00 is good', () {
      expect(progressState(done: 0, goal: 4, now: _at(9)), AreaState.good);
    });

    test('0 done at 14:00 is watch', () {
      expect(progressState(done: 0, goal: 4, now: _at(14)), AreaState.watch);
    });

    test('40% done at 21:00 is care', () {
      expect(progressState(done: 200, goal: 500, now: _at(21)), AreaState.care);
    });

    test('60% done at 21:30 is watch', () {
      expect(
          progressState(done: 300, goal: 500, now: _at(21, 30)), AreaState.watch);
    });

    test('zero goal is good', () {
      expect(progressState(done: 0, goal: 0, now: _at(21)), AreaState.good);
      expect(progressState(done: 120, goal: 0, now: _at(21)), AreaState.good);
    });
  });

  group('careAreas', () {
    test('is empty when every area is on track', () {
      expect(careAreas(_numbers(), _at(14)), isEmpty);
    });

    test('is money when spent is over budget', () {
      expect(careAreas(_numbers(spent: 75), _at(14)), [DetailTracker.money]);
    });

    test('is move then routines at 21:30 with under half of both goals', () {
      expect(
        careAreas(_numbers(moveKcal: 200, routinesDone: 1), _at(21, 30)),
        [DetailTracker.move, DetailTracker.rituals],
      );
    });

    test('lists every area in rule order', () {
      expect(
        careAreas(_numbers(spent: 75, moveKcal: 200, routinesDone: 1), _at(21, 30)),
        [DetailTracker.money, DetailTracker.move, DetailTracker.rituals],
      );
    });

    test('ignores an area with no goal', () {
      expect(
        careAreas(
          _numbers(budget: 0, moveKcal: 0, moveGoal: 0, routinesDone: 0, routinesTotal: 0),
          _at(21, 30),
        ),
        isEmpty,
      );
    });
  });

  group('areaGlances', () {
    test('returns money, move, routines in order', () {
      final glances = areaGlances(_numbers(), Currency.usd, _at(9));
      expect(glances.map((g) => g.tracker),
          [DetailTracker.money, DetailTracker.move, DetailTracker.rituals]);
    });

    test('money states what is left of the budget', () {
      final money = areaGlances(_numbers(), Currency.usd, _at(9)).first;
      expect(money.value, r'$22 left');
      expect(money.fraction, closeTo(22 / 60, 1e-9));
      expect(money.state, AreaState.watch);
      expect(money.semantics,
          r'Money: $22 of $60 left to spend. Worth watching');
    });

    test('over budget shows nothing left, never a negative', () {
      final money =
          areaGlances(_numbers(spent: 75), Currency.usd, _at(15)).first;
      expect(money.value, r'$0 left');
      expect(money.fraction, 0);
      expect(money.state, AreaState.care);
      expect(money.semantics, r'Money: $0 of $60 left to spend. Needs care');
    });

    test('no budget shows the amount spent with an empty ring', () {
      final money =
          areaGlances(_numbers(budget: 0), Currency.usd, _at(15)).first;
      expect(money.value, r'$38');
      expect(money.fraction, 0);
      expect(money.state, AreaState.good);
      expect(money.semantics, r'Money: $38 spent. On track');
    });

    test('money follows the currency format', () {
      final money = areaGlances(
        _numbers(spent: 380000, budget: 600000),
        Currency.vnd,
        _at(20),
      ).first;
      // formatCurrency owns the spacing around a trailing symbol
      final left = formatCurrency(220000, Currency.vnd);
      final budget = formatCurrency(600000, Currency.vnd);
      expect(left, contains('220.000'));
      expect(money.value, '$left left');
      expect(money.semantics, 'Money: $left of $budget left to spend. On track');
    });

    test('move states kcal burned against the goal', () {
      final move = areaGlances(_numbers(), Currency.usd, _at(14))[1];
      expect(move.value, '310 kcal');
      expect(move.fraction, closeTo(0.62, 1e-9));
      expect(move.state, AreaState.good);
      expect(move.semantics, 'Move: 310 of 500 kcal burned. On track');
    });

    test('move past its goal clamps the ring and is ahead', () {
      final move =
          areaGlances(_numbers(moveKcal: 640), Currency.usd, _at(14))[1];
      expect(move.value, '640 kcal');
      expect(move.fraction, 1);
      expect(move.state, AreaState.thriving);
      expect(move.semantics, 'Move: 640 of 500 kcal burned. Ahead');
    });

    test('no move goal is a plain amount with an empty ring', () {
      final move = areaGlances(_numbers(moveGoal: 0), Currency.usd, _at(21))[1];
      expect(move.value, '310 kcal');
      expect(move.fraction, 0);
      expect(move.state, AreaState.good);
      expect(move.semantics, 'Move: 310 kcal burned. On track');
    });

    test('routines state done of total', () {
      final routines = areaGlances(_numbers(), Currency.usd, _at(14)).last;
      expect(routines.value, '2 of 4');
      expect(routines.fraction, 0.5);
      expect(routines.state, AreaState.good);
      expect(routines.semantics, 'Routines: 2 of 4 done. On track');
    });

    test('no routines is 0 with an empty ring', () {
      final routines = areaGlances(
        _numbers(routinesDone: 0, routinesTotal: 0),
        Currency.usd,
        _at(21),
      ).last;
      expect(routines.value, '0');
      expect(routines.fraction, 0);
      expect(routines.state, AreaState.good);
      expect(routines.semantics, 'Routines: none today. On track');
    });

    test('zero goals never produce NaN or infinite fractions', () {
      final glances = areaGlances(
        _numbers(budget: 0, moveGoal: 0, routinesDone: 0, routinesTotal: 0),
        Currency.usd,
        _at(12),
      );
      for (final g in glances) {
        expect(g.fraction.isFinite, isTrue);
        expect(g.fraction, 0);
      }
    });
  });
}
