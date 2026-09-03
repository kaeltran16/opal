// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_reconcile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(NotificationReconcileController)
const notificationReconcileControllerProvider =
    NotificationReconcileControllerProvider._();

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
final class NotificationReconcileControllerProvider
    extends $NotifierProvider<NotificationReconcileController, void> {
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
  const NotificationReconcileControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationReconcileControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationReconcileControllerHash();

  @$internal
  @override
  NotificationReconcileController create() => NotificationReconcileController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$notificationReconcileControllerHash() =>
    r'd366b24b7050055ddc2250092d34fe33df169e8a';

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

abstract class _$NotificationReconcileController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
