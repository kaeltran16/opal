import 'package:flutter/material.dart' show TimeOfDay;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/notifications/notification_service.dart';
import '../services/pal/pal_service.dart';
import '../util/dates.dart' show clockLabel;
import 'providers.dart';

part 'autopilot_controller.g.dart';

/// What Pal handles quietly: a fixed, app-defined list. [id] is the key the
/// agenda's model subtitles arrive under.
enum Automation {
  spendNudge('spend_nudge', 'Spend nudge', 'dollarsign.circle.fill'),
  routineReminders('routine_reminders', 'Routine reminders', 'bell.fill');

  const Automation(this.id, this.title, this.icon);

  final String id;
  final String title;
  final String icon;
}

/// The Autopilot switches, which are the stored notification settings: Spend
/// nudge is `budgetAlerts` and Routine reminders is `ritualReminders`.
///
/// Autopilot and Notifications both switch through here, so the two screens
/// and You's count can never disagree.
@Riverpod(keepAlive: true)
class Automations extends _$Automations {
  @override
  Map<Automation, bool> build() {
    final settings = ref.read(settingsRepositoryProvider);
    return {
      Automation.spendNudge: settings.budgetAlerts,
      Automation.routineReminders: settings.ritualReminders,
    };
  }

  /// Saves [on] for [a] and applies it. Returns false when Routine reminders
  /// was switched on but notification permission was denied, so nothing was
  /// scheduled.
  Future<bool> set(Automation a, bool on) async {
    state = {...state, a: on};
    final settings = ref.read(settingsRepositoryProvider);
    switch (a) {
      // BudgetAlertController reads the setting on each check.
      case Automation.spendNudge:
        await settings.setBudgetAlerts(on);
        return true;
      case Automation.routineReminders:
        await settings.setRitualReminders(on);
        return _applyRoutineReminder(on);
    }
  }

  Future<bool> _applyRoutineReminder(bool on) async {
    final notifications = ref.read(notificationServiceProvider);
    if (!on) {
      await notifications.cancel(NotificationIds.ritualReminder);
      return true;
    }
    if (!await notifications.requestPermissions()) return false;
    await notifications.scheduleDaily(
      id: NotificationIds.ritualReminder,
      title: kRitualReminderTitle,
      body: kRitualReminderBody,
      time: ref.read(settingsRepositoryProvider).reminderTime,
    );
    return true;
  }
}

/// The model's line for [a] from [agenda], else the app's own.
String subtitleFor(Automation a, PalAgenda? agenda, TimeOfDay reminderTime) {
  final model = agenda?.autopilotSubtitles[a.id];
  if (model != null && model.isNotEmpty) return model;
  return switch (a) {
    Automation.spendNudge => "Alerts you when today's spending passes your budget.",
    Automation.routineReminders =>
      'A daily nudge at ${clockLabel(reminderTime.hour * TimeOfDay.minutesPerHour + reminderTime.minute)}.',
  };
}
