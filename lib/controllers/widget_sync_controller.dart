import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analysis/area_state.dart';
import '../screens/today/today_logic.dart';
import '../services/widget_sync/widget_sync_service.dart';
import '../util/format.dart';
import 'providers.dart';
import 'today_controller.dart';

part 'widget_sync_controller.g.dart';

/// Keeps the iOS rings widget in sync with today's progress.
///
/// Listens to [todayStateProvider] and the currency setting, and maps each
/// change onto a [WidgetSnapshot] (the services layer stays free of view-model
/// types). Has no UI surface; instantiated once at app start (see `app.dart`).
/// `fireImmediately` seeds the widget on launch.
@Riverpod(keepAlive: true)
class WidgetSyncController extends _$WidgetSyncController {
  @override
  void build() {
    final service = ref.watch(widgetSyncServiceProvider);
    void push(TodayState? s) {
      if (s == null) return;
      final currency = ref.read(appSettingsControllerProvider).currency;
      service.sync(buildWidgetSnapshot(s.glance, currency, clock.now()));
    }

    ref.listen(todayStateProvider, (_, next) => push(next.asData?.value),
        fireImmediately: true);
    ref.listen(appSettingsControllerProvider, (prev, next) {
      if (prev?.currency == next.currency) return;
      push(ref.read(todayStateProvider).asData?.value);
    });
  }
}

/// The widget payload for [n] synced at [now]: display-ready values, ring
/// fractions, and each row's state changes from now until local midnight, so
/// the widget flips its word on time while the app is closed.
WidgetSnapshot buildWidgetSnapshot(
  GlanceNumbers n,
  Currency currency,
  DateTime now,
) {
  // DateTime(y, m, d + 1) is the next local midnight even across DST.
  final until = DateTime(now.year, now.month, now.day + 1);
  final start = DateTime(now.year, now.month, now.day, now.hour, now.minute);

  List<StateChange> schedule(AreaState Function(DateTime t) stateAt) {
    final changes = <StateChange>[];
    for (var t = start;
        t.isBefore(until);
        t = t.add(const Duration(minutes: 1))) {
      final state = stateAt(t);
      if (changes.isNotEmpty && changes.last.state == state.name) continue;
      changes.add(StateChange(at: t, state: state.name, word: state.word));
    }
    return changes;
  }

  return WidgetSnapshot(
    until: until,
    move: WidgetRow(
      fraction: _fraction(n.moveKcal, n.moveGoal),
      value: n.moveGoal > 0
          ? '${n.moveKcal} of ${n.moveGoal} kcal'
          : '${n.moveKcal} kcal',
      states: schedule(
          (t) => progressState(done: n.moveKcal, goal: n.moveGoal, now: t)),
    ),
    routines: WidgetRow(
      fraction: _fraction(n.routinesDone, n.routinesTotal),
      value: n.routinesTotal > 0
          ? '${n.routinesDone} of ${n.routinesTotal} done'
          : 'None today',
      states: schedule((t) =>
          progressState(done: n.routinesDone, goal: n.routinesTotal, now: t)),
    ),
    money: WidgetRow(
      value: _moneyValue(n, currency),
      states: schedule(
          (t) => moneyState(spent: n.spent, budget: n.budget, now: t)),
    ),
  );
}

double _fraction(num done, num goal) =>
    goal <= 0 ? 0 : (done / goal).clamp(0.0, 1.0);

String _moneyValue(GlanceNumbers n, Currency currency) {
  if (n.budget <= 0) return 'No budget';
  final budget = formatCurrency(n.budget, currency);
  if (n.spent > n.budget) {
    return '${formatCurrency(n.spent - n.budget, currency)} over $budget';
  }
  return '${formatCurrency(n.budget - n.spent, currency)} left of $budget';
}
