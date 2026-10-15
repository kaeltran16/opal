import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../screens/today/day_plan.dart';
import '../util/dates.dart';
import 'providers.dart';

part 'plan_session_controller.g.dart';

/// What the user did with today's plan: Today's card and timeline, and You's
/// Pal suggests, settle the same proposals here, so one approved or put off
/// on either screen is gone from both.
///
/// Kept alive so it outlives either screen. The settled map is saved for the
/// day, so a relaunch keeps the day's put-offs; the undo history is not, as
/// the toast that offers it is gone after a relaunch anyway.
@Riverpod(keepAlive: true)
class PlanSessionController extends _$PlanSessionController {
  @override
  PlanSession build() => _load(startOfDay(clock.now()));

  void putOff(PlanItem item) =>
      _apply(state.settle(item.id, done: false, label: 'Put off until tomorrow: ${item.title}'));

  void approve(PlanItem item) =>
      _apply(state.settle(item.id, done: true, label: item.doneDetail ?? item.title));

  void bringBack(PlanItem item) =>
      _apply(state.bringBack(item.id, label: '${item.title} is back on today'));

  /// Reverses the last change once it is saved, so a failed save leaves the
  /// change in place for the toast to retry.
  Future<void> undo() async {
    final next = state.undo();
    await _save(next);
    state = next;
  }

  void dismissNotice() => state = state.dismissNotice();

  /// Starts the new day's session when [now] is past the session's day, for an
  /// app left open across midnight.
  void syncDay(DateTime now) {
    final day = startOfDay(now);
    if (day != state.day) state = _load(day);
  }

  PlanSession _load(DateTime day) =>
      PlanSession(day: day, settled: ref.read(settingsRepositoryProvider).planSettled(day));

  void _apply(PlanSession next) {
    state = next;
    // _save logs the failure; the change still shows for this session.
    _save(next).ignore();
  }

  Future<void> _save(PlanSession session) async {
    try {
      await ref.read(settingsRepositoryProvider).setPlanSettled(session.day, session.settled);
    } catch (e) {
      debugPrint("plan session: couldn't save the plan for ${session.day}: $e");
      rethrow;
    }
  }
}
