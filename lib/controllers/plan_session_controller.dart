import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../screens/today/day_plan.dart';

part 'plan_session_controller.g.dart';

/// What the user did with today's plan this app session: Today's card and
/// timeline, and You's Pal suggests, settle the same proposals here, so one
/// approved or put off on either screen is gone from both.
///
/// Kept alive so it outlives either screen. Not persisted, as Today's own
/// session never was.
@Riverpod(keepAlive: true)
class PlanSessionController extends _$PlanSessionController {
  @override
  PlanSession build() => const PlanSession();

  void settle(String id, {required bool done}) =>
      state = state.settle(id, done: done);

  void undo() => state = state.undo();

  void select(String id) => state = state.select(id);
}
