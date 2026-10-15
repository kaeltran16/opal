import '../controllers/spending_controller.dart';
import '../screens/today/today_logic.dart';

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

/// Under this share of a budget left before the period ends is worth watching,
/// however close to pace the spending is.
const double _lowHeadroom = 0.1;

/// From this hour a goal still under [_lateShortfall] will not be met today.
const int _lateHour = 21;
const double _lateShortfall = 0.5;

/// The fraction of the waking day elapsed: 0 at or before 07:00, 1 at or after
/// 22:00, linear between.
double dayShare(DateTime now) {
  final minute = now.hour * 60 + now.minute;
  return ((minute - _wakeMinute) / (_sleepMinute - _wakeMinute)).clamp(
    0.0,
    1.0,
  );
}

/// Spending against a daily budget. Never [AreaState.thriving]: under budget
/// is simply on track until the day ends.
AreaState moneyState({
  required double spent,
  required double budget,
  required DateTime now,
}) => budgetState(spent: spent, budget: budget, elapsed: dayShare(now));

/// Spending against a budget over any period, with [elapsed] the fraction of
/// that period gone (0 to 1). Never [AreaState.thriving], as [moneyState].
AreaState budgetState({
  required double spent,
  required double budget,
  required double elapsed,
}) {
  if (budget <= 0) return AreaState.good;
  if (spent > budget) return AreaState.care;
  if (spent / budget - elapsed >= _paceSlack) return AreaState.watch;
  if (elapsed < 1 && budgetNearlySpent(spent: spent, budget: budget)) {
    return AreaState.watch;
  }
  return AreaState.good;
}

/// Whether under a tenth of [budget] is left, without going over.
bool budgetNearlySpent({required double spent, required double budget}) =>
    budget > 0 && spent <= budget && (budget - spent) / budget < _lowHeadroom;

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
  if (progressState(done: n.moveKcal, goal: n.moveGoal, now: now) ==
      AreaState.care)
    DetailTracker.move,
  if (progressState(done: n.routinesDone, goal: n.routinesTotal, now: now) ==
      AreaState.care)
    DetailTracker.rituals,
];
