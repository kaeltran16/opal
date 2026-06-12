// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the live [SyncStatus] from the email service. The dashboard's status
/// line + progress bar read this so the staged sequence (scanning → filtering →
/// categorizing → upToDate) is driven entirely by the service, not the UI.
///
/// Seeds [SyncStatus.idle] before the service's first emission so the stream is
/// never empty (the mock only emits on [EmailSyncService.syncNow]/disconnect).

@ProviderFor(syncStatus)
const syncStatusProvider = SyncStatusProvider._();

/// Streams the live [SyncStatus] from the email service. The dashboard's status
/// line + progress bar read this so the staged sequence (scanning → filtering →
/// categorizing → upToDate) is driven entirely by the service, not the UI.
///
/// Seeds [SyncStatus.idle] before the service's first emission so the stream is
/// never empty (the mock only emits on [EmailSyncService.syncNow]/disconnect).

final class SyncStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStatus>,
          SyncStatus,
          Stream<SyncStatus>
        >
    with $FutureModifier<SyncStatus>, $StreamProvider<SyncStatus> {
  /// Streams the live [SyncStatus] from the email service. The dashboard's status
  /// line + progress bar read this so the staged sequence (scanning → filtering →
  /// categorizing → upToDate) is driven entirely by the service, not the UI.
  ///
  /// Seeds [SyncStatus.idle] before the service's first emission so the stream is
  /// never empty (the mock only emits on [EmailSyncService.syncNow]/disconnect).
  const SyncStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStatusHash();

  @$internal
  @override
  $StreamProviderElement<SyncStatus> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SyncStatus> create(Ref ref) {
    return syncStatus(ref);
  }
}

String _$syncStatusHash() => r'f18420a33aa1e934c4ae6eeaaf198b7e8401bad2';

/// Drives the Setup screen's Test-connection + Save. Delegates to
/// [EmailSyncService]; holds no credentials itself (the screen passes them in).

@ProviderFor(EmailSetupController)
const emailSetupControllerProvider = EmailSetupControllerProvider._();

/// Drives the Setup screen's Test-connection + Save. Delegates to
/// [EmailSyncService]; holds no credentials itself (the screen passes them in).
final class EmailSetupControllerProvider
    extends $NotifierProvider<EmailSetupController, EmailSetupState> {
  /// Drives the Setup screen's Test-connection + Save. Delegates to
  /// [EmailSyncService]; holds no credentials itself (the screen passes them in).
  const EmailSetupControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailSetupControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailSetupControllerHash();

  @$internal
  @override
  EmailSetupController create() => EmailSetupController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmailSetupState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmailSetupState>(value),
    );
  }
}

String _$emailSetupControllerHash() =>
    r'd22cfa66d49feaa7ee11c67af9514ecb3e297897';

/// Drives the Setup screen's Test-connection + Save. Delegates to
/// [EmailSyncService]; holds no credentials itself (the screen passes them in).

abstract class _$EmailSetupController extends $Notifier<EmailSetupState> {
  EmailSetupState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<EmailSetupState, EmailSetupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EmailSetupState, EmailSetupState>,
              EmailSetupState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Owns the Dashboard: reads the connected account, runs Sync-now (which the
/// service stages over [syncStatusProvider]) and surfaces the returned imports,
/// and disconnects. All timing lives in the service.

@ProviderFor(EmailDashboardController)
const emailDashboardControllerProvider = EmailDashboardControllerProvider._();

/// Owns the Dashboard: reads the connected account, runs Sync-now (which the
/// service stages over [syncStatusProvider]) and surfaces the returned imports,
/// and disconnects. All timing lives in the service.
final class EmailDashboardControllerProvider
    extends $NotifierProvider<EmailDashboardController, EmailDashboardState> {
  /// Owns the Dashboard: reads the connected account, runs Sync-now (which the
  /// service stages over [syncStatusProvider]) and surfaces the returned imports,
  /// and disconnects. All timing lives in the service.
  const EmailDashboardControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailDashboardControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailDashboardControllerHash();

  @$internal
  @override
  EmailDashboardController create() => EmailDashboardController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmailDashboardState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmailDashboardState>(value),
    );
  }
}

String _$emailDashboardControllerHash() =>
    r'c492b9523cfa368c7b3ab49627b5ff2e7761f75e';

/// Owns the Dashboard: reads the connected account, runs Sync-now (which the
/// service stages over [syncStatusProvider]) and surfaces the returned imports,
/// and disconnects. All timing lives in the service.

abstract class _$EmailDashboardController
    extends $Notifier<EmailDashboardState> {
  EmailDashboardState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<EmailDashboardState, EmailDashboardState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EmailDashboardState, EmailDashboardState>,
              EmailDashboardState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
