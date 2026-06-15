/// The local-notifications seam (ritual reminders, budget alerts, sync-done).
///
/// Abstracted in U03; `flutter_local_notifications` is wired on device (U27).
/// On web/Windows the [NoopNotificationService] does nothing — delivery is only
/// verifiable on a real iOS build via TestFlight.
library;

import 'package:flutter/material.dart' show TimeOfDay;

/// Stable notification ids — one per recurring/event notification type so a
/// re-schedule replaces (rather than duplicates) the prior one, and a cancel
/// targets the right slot.
abstract final class NotificationIds {
  /// Daily ritual reminder (one recurring slot).
  static const int ritualReminder = 1;

  /// Over-budget alert (one-shot, re-fired at most once per day).
  static const int budgetAlert = 2;
}

/// Default time-of-day for the daily ritual reminder when the user hasn't
/// picked one (09:00 local).
const TimeOfDay kDefaultReminderTime = TimeOfDay(hour: 9, minute: 0);

/// Copy for the daily ritual reminder. Kept here so the screen (toggle-on path)
/// and the reconcile controller (startup path) schedule identical content.
const String kRitualReminderTitle = 'Time for your rituals';
const String kRitualReminderBody = 'A quick nudge to keep your routine going.';

/// A scheduled local notification request.
class NotificationRequest {
  const NotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
}

abstract interface class NotificationService {
  /// Request OS permission (mock: returns true).
  Future<bool> requestPermissions();

  /// Schedule a one-shot notification.
  Future<void> schedule(NotificationRequest request);

  /// Schedule a notification that recurs every day at [time] (local). Replaces
  /// any existing notification with the same [id]. Used for the ritual reminder.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  });

  /// Cancel a previously scheduled notification by id.
  Future<void> cancel(int id);

  /// Cancel everything.
  Future<void> cancelAll();
}
