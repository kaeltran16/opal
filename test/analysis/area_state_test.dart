import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/spending_controller.dart';
import 'package:opal/screens/today/today_logic.dart';

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 10, 3, hour, minute);

GlanceNumbers _numbers({
  double spent = 38,
  double budget = 60,
  int moveKcal = 310,
  int moveGoal = 500,
  int routinesDone = 2,
  int routinesTotal = 4,
}) => GlanceNumbers(
  spent: spent,
  budget: budget,
  moveKcal: moveKcal,
  moveGoal: moveGoal,
  routinesDone: routinesDone,
  routinesTotal: routinesTotal,
);

void main() {
  test('state words are the fixed four', () {
    expect(AreaState.values.map((s) => s.word), [
      'Ahead',
      'On track',
      'Worth watching',
      'Needs care',
    ]);
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
      expect(
        moneyState(spent: 30, budget: 60, now: _at(14, 30)),
        AreaState.good,
      );
    });

    test('63% spent at 09:00 is watch', () {
      expect(moneyState(spent: 63, budget: 100, now: _at(9)), AreaState.watch);
    });

    test('63% spent at 20:00 is good', () {
      expect(moneyState(spent: 63, budget: 100, now: _at(20)), AreaState.good);
    });

    test('one cent over budget is care', () {
      expect(
        moneyState(spent: 60.01, budget: 60, now: _at(21)),
        AreaState.care,
      );
    });

    test('nothing left before the day ends is watch; at its end, good', () {
      expect(moneyState(spent: 60, budget: 60, now: _at(21)), AreaState.watch);
      expect(moneyState(spent: 60, budget: 60, now: _at(22)), AreaState.good);
    });

    test('97.6% spent at 20:15 is watch, though on pace', () {
      expect(moneyState(spent: 117.15, budget: 120, now: _at(20, 15)), AreaState.watch);
    });

    test('zero budget is good', () {
      expect(moneyState(spent: 38, budget: 0, now: _at(9)), AreaState.good);
    });
  });

  group('budgetState', () {
    test('no budget is good', () {
      expect(budgetState(spent: 38, budget: 0, elapsed: 0.5), AreaState.good);
    });

    test('over budget is care', () {
      expect(
        budgetState(spent: 101, budget: 100, elapsed: 0.9),
        AreaState.care,
      );
    });

    test('a spent share at elapsed plus slack is watch', () {
      expect(
        budgetState(spent: 60, budget: 100, elapsed: 0.3),
        AreaState.watch,
      );
    });

    test('a spent share under elapsed plus slack is good', () {
      expect(budgetState(spent: 54, budget: 100, elapsed: 0.3), AreaState.good);
    });

    test('under a tenth left before the period ends is watch', () {
      expect(budgetState(spent: 91, budget: 100, elapsed: 0.95), AreaState.watch);
      expect(budgetState(spent: 90, budget: 100, elapsed: 0.95), AreaState.good);
      expect(budgetState(spent: 91, budget: 100, elapsed: 1), AreaState.good);
    });
  });

  group('progressState', () {
    test('goal met is thriving at any hour', () {
      for (final hour in [6, 9, 14, 21, 23]) {
        expect(
          progressState(done: 500, goal: 500, now: _at(hour)),
          AreaState.thriving,
        );
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
        progressState(done: 300, goal: 500, now: _at(21, 30)),
        AreaState.watch,
      );
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
      expect(careAreas(_numbers(moveKcal: 200, routinesDone: 1), _at(21, 30)), [
        DetailTracker.move,
        DetailTracker.rituals,
      ]);
    });

    test('lists every area in rule order', () {
      expect(
        careAreas(
          _numbers(spent: 75, moveKcal: 200, routinesDone: 1),
          _at(21, 30),
        ),
        [DetailTracker.money, DetailTracker.move, DetailTracker.rituals],
      );
    });

    test('ignores an area with no goal', () {
      expect(
        careAreas(
          _numbers(
            budget: 0,
            moveKcal: 0,
            moveGoal: 0,
            routinesDone: 0,
            routinesTotal: 0,
          ),
          _at(21, 30),
        ),
        isEmpty,
      );
    });
  });
}
