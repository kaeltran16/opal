/// The local-notifications seam (ritual reminders, budget alerts, sync-done).
///
/// Abstracted in U03; `flutter_local_notifications` is wired on device (U27).
/// On web/Windows the [NoopNotificationService] does nothing — delivery is only
/// verifiable on a real iOS build via TestFlight.
library;

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

  /// Cancel a previously scheduled notification by id.
  Future<void> cancel(int id);

  /// Cancel everything.
  Future<void> cancelAll();
}
