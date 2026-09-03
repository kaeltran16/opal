import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/notifications/notification_service.dart';
import 'budget_alert_controller.dart';
import 'providers.dart';

part 'notification_reconcile_controller.g.dart';

/// Brings scheduled notifications in line with persisted toggle state on launch.
///
/// The OS holds scheduled notifications across launches, but the persisted
/// toggle is the source of truth — a reminder time changed while the app was
/// closed, or a reschedule that never landed, would drift. So on init: if
/// `ritualReminders` is on, (re)schedule the daily reminder at the configured
/// time; if off, cancel it.
///
/// Also runs [BudgetAlertController.checkPeriodic]. The over-budget alert stays
/// event-driven (it fires on the entry that crosses the line), but the pace and
/// category-spike signals compare whole weeks and months, so they have no
/// triggering entry — startup is where they get looked at.
///
/// Instantiated once at app start (see `app.dart`), mirroring
/// [HealthSyncController] / [WidgetSyncController]. Fire-and-forget: a failed
/// reconcile must not crash startup.
@Riverpod(keepAlive: true)
class NotificationReconcileController extends _$NotificationReconcileController {
  @override
  void build() {
    _reconcile();
  }

  Future<void> _reconcile() async {
    await _reconcileRitualReminder();
    // Independent of the reminder outcome: a cancelled ritual reminder says
    // nothing about whether the budget signals should be looked at.
    await ref.read(budgetAlertControllerProvider.notifier).checkPeriodic();
  }

  Future<void> _reconcileRitualReminder() async {
    final settings = ref.read(settingsRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);

    if (!settings.ritualReminders) {
      await notifications.cancel(NotificationIds.ritualReminder);
      return;
    }

    await notifications.scheduleDaily(
      id: NotificationIds.ritualReminder,
      title: kRitualReminderTitle,
      body: kRitualReminderBody,
      time: settings.reminderTime,
    );
  }
}
