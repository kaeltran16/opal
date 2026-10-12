import 'package:flutter/foundation.dart';

import '../controllers/spending_controller.dart';
import '../screens/today/today_logic.dart';
import '../util/format.dart';

/// How an area is going today. Ordered best to worst.
enum AreaState {
  thriving('Ahead'),
  good('On track'),
  watch('Worth watching'),
  care('Needs care');

  const AreaState(this.word);

  final String word;
}

const int _wakeMinute = 7 * 60;
const int _sleepMinute = 22 * 60;

/// How far actual may drift from the day's pace before it is worth watching.
const double _paceSlack = 0.25;

/// From this hour a goal still under [_lateShortfall] will not be met today.
const int _lateHour = 21;
const double _lateShortfall = 0.5;

/// The fraction of the waking day elapsed: 0 at or before 07:00, 1 at or after
/// 22:00, linear between.
double dayShare(DateTime now) {
  final minute = now.hour * 60 + now.minute;
  return ((minute - _wakeMinute) / (_sleepMinute - _wakeMinute)).clamp(0.0, 1.0);
}

/// Spending against a daily budget. Never [AreaState.thriving]: under budget
/// is simply on track until the day ends.
AreaState moneyState({
  required double spent,
  required double budget,
  required DateTime now,
}) {
  if (budget <= 0) return AreaState.good;
  if (spent > budget) return AreaState.care;
  if (spent / budget - dayShare(now) >= _paceSlack) return AreaState.watch;
  return AreaState.good;
}

/// Progress toward a daily goal, for Move and Routines.
AreaState progressState({
  required num done,
  required num goal,
  required DateTime now,
}) {
  if (goal <= 0) return AreaState.good;
  if (done >= goal) return AreaState.thriving;
  final share = done / goal;
  if (now.hour >= _lateHour && share < _lateShortfall) return AreaState.care;
  if (dayShare(now) - share >= _paceSlack) return AreaState.watch;
  return AreaState.good;
}

/// The areas in [AreaState.care], in rule order: Money, Move, Routines.
List<DetailTracker> careAreas(GlanceNumbers n, DateTime now) => [
      if (moneyState(spent: n.spent, budget: n.budget, now: now) == AreaState.care)
        DetailTracker.money,
      if (progressState(done: n.moveKcal, goal: n.moveGoal, now: now) == AreaState.care)
        DetailTracker.move,
      if (progressState(done: n.routinesDone, goal: n.routinesTotal, now: now) ==
          AreaState.care)
        DetailTracker.rituals,
    ];

/// What one ring on Today says. [fraction] is always the fraction [value]
/// states, so ring and number never disagree.
@immutable
class AreaGlance {
  const AreaGlance({
    required this.tracker,
    required this.value,
    required this.fraction,
    required this.state,
    required this.semantics,
  });

  final DetailTracker tracker;
  final String value;
  final double fraction;
  final AreaState state;
  final String semantics;
}

/// The three glances on Today: money, move, routines, in that order.
List<AreaGlance> areaGlances(GlanceNumbers n, Currency currency, DateTime now) =>
    [_money(n, currency, now), _move(n, now), _routines(n, now)];

AreaGlance _money(GlanceNumbers n, Currency currency, DateTime now) {
  final state = moneyState(spent: n.spent, budget: n.budget, now: now);
  if (n.budget <= 0) {
    final spent = formatCurrency(n.spent, currency);
    return AreaGlance(
      tracker: DetailTracker.money,
      value: spent,
      fraction: 0,
      state: state,
      semantics: 'Money: $spent spent. ${state.word}',
    );
  }
  final left = formatCurrency(n.moneyLeft, currency);
  final budget = formatCurrency(n.budget, currency);
  return AreaGlance(
    tracker: DetailTracker.money,
    value: '$left left',
    fraction: (n.moneyLeft / n.budget).clamp(0.0, 1.0),
    state: state,
    semantics: 'Money: $left of $budget left to spend. ${state.word}',
  );
}

AreaGlance _move(GlanceNumbers n, DateTime now) {
  final state = progressState(done: n.moveKcal, goal: n.moveGoal, now: now);
  final hasGoal = n.moveGoal > 0;
  return AreaGlance(
    tracker: DetailTracker.move,
    value: '${n.moveKcal} kcal',
    fraction: hasGoal ? (n.moveKcal / n.moveGoal).clamp(0.0, 1.0) : 0,
    state: state,
    semantics: hasGoal
        ? 'Move: ${n.moveKcal} of ${n.moveGoal} kcal burned. ${state.word}'
        : 'Move: ${n.moveKcal} kcal burned. ${state.word}',
  );
}

AreaGlance _routines(GlanceNumbers n, DateTime now) {
  final state =
      progressState(done: n.routinesDone, goal: n.routinesTotal, now: now);
  if (n.routinesTotal <= 0) {
    return AreaGlance(
      tracker: DetailTracker.rituals,
      value: '0',
      fraction: 0,
      state: state,
      semantics: 'Routines: none today. ${state.word}',
    );
  }
  final value = '${n.routinesDone} of ${n.routinesTotal}';
  return AreaGlance(
    tracker: DetailTracker.rituals,
    value: value,
    fraction: (n.routinesDone / n.routinesTotal).clamp(0.0, 1.0),
    state: state,
    semantics: 'Routines: $value done. ${state.word}',
  );
}
