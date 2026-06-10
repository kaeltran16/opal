/// Barrel export for the service interfaces + their DTOs and mock/no-op impls.
///
/// Every external dependency (Pal, Email, Health, Notifications, Haptics) sits
/// behind an interface here so the mock and the real impl are swappable via a
/// Riverpod provider override (U03). Real impls land later (U23/U24/U27).
library;

export 'email/email_sync_service.dart';
export 'email/mock_email_sync_service.dart';
export 'email/real_email_sync_service.dart';
export 'haptics/haptics_service.dart';
export 'haptics/platform_haptics_service.dart';
export 'health/health_kit_service.dart';
export 'health/health_service.dart';
export 'health/mock_health_service.dart';
export 'live_activity/live_activity_service.dart';
export 'notifications/local_notification_service.dart';
export 'notifications/noop_notification_service.dart';
export 'notifications/notification_service.dart';
export 'siri/siri_shortcuts_service.dart';
export 'pal/device_token_store.dart';
export 'pal/http_pal_service.dart';
export 'pal/mock_pal_service.dart';
export 'pal/pal_context_builder.dart';
export 'pal/pal_service.dart';
