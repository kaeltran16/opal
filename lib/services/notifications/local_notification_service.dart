import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

/// Real [NotificationService] backed by `flutter_local_notifications`.
///
/// Wired on a real iOS build (U27) behind the same seam the rest of the app
/// codes against; web/Windows/tests keep the [NoopNotificationService] since
/// local-notification delivery is only verifiable on-device (TestFlight).
///
/// ## Initialization contract
/// This service assumes the timezone database has already been loaded and the
/// local location set during app startup (the orchestrator does this in
/// `main.dart`):
///
/// ```dart
/// tz.initializeTimeZones();
/// tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
/// ```
///
/// The service only ever *reads* `tz.local`; it never initializes the DB
/// itself. Plugin initialization is lazy and idempotent via [_ensureInit] so
/// the first call to any method (typically [requestPermissions]) sets it up.
class LocalNotificationService implements NotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// iOS-only notification details. A budget alert / ritual reminder is a
  /// plain alert+sound+badge notification; no custom categories needed.
  static const DarwinNotificationDetails _iosDetails =
      DarwinNotificationDetails();

  /// Minimal cross-platform detail bundle (iOS is the only live target, but
  /// `zonedSchedule` requires a [NotificationDetails]).
  static const NotificationDetails _details =
      NotificationDetails(iOS: _iosDetails);

  /// Lazily initialize the plugin exactly once.
  ///
  /// Permission prompting is deferred to [requestPermissions] (we pass
  /// `requestAlertPermission: false` etc. here) so the OS dialog only appears
  /// when the app explicitly asks for it.
  Future<void> _ensureInit() async {
    if (_initialized) return;

    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    await _ensureInit();

    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    final granted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return granted ?? false;
  }

  @override
  Future<void> schedule(NotificationRequest request) async {
    await _ensureInit();

    await _plugin.zonedSchedule(
      request.id,
      request.title,
      request.body,
      tz.TZDateTime.from(request.scheduledAt, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _ensureInit();
    await _plugin.cancel(id);
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInit();
    await _plugin.cancelAll();
  }
}
