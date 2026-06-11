import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'providers.dart';
import 'today_controller.dart';

part 'widget_sync_controller.g.dart';

/// Keeps the iOS rings widget in sync with today's progress.
///
/// Listens to [todayStateProvider] and maps each new [TodayState] onto the
/// primitive args [WidgetSyncService] expects (the services layer stays free of
/// view-model types). Has no UI surface; instantiated once at app start
/// (see `app.dart`). `fireImmediately` seeds the widget on launch.
@Riverpod(keepAlive: true)
class WidgetSyncController extends _$WidgetSyncController {
  @override
  void build() {
    final service = ref.watch(widgetSyncServiceProvider);
    ref.listen(todayStateProvider, (_, next) {
      final s = next.asData?.value;
      if (s == null) return;
      service.sync(
        moneyRing: s.moneyRing,
        moveRing: s.moveRing,
        ritualsRing: s.ritualsRing,
        moneySpent: s.moneySpent,
        dailyBudget: s.goals.dailyBudget,
        moveMinutes: s.moveMinutes,
        dailyMoveMinutes: s.goals.dailyMoveMinutes,
        ritualsDone: s.ritualsDone,
        dailyRitualTarget: s.goals.dailyRitualTarget,
      );
    }, fireImmediately: true);
  }
}
