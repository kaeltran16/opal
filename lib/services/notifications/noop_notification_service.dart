import 'package:flutter/material.dart' show TimeOfDay;

import 'notification_service.dart';

/// No-op [NotificationService] for web/Windows preview + tests.
///
/// Local-notification delivery cannot be verified off-device, so this does
/// nothing. The real `flutter_local_notifications` impl is wired on the
/// borrowed Mac (U27) behind the same interface.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(NotificationRequest request) async {}

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}
