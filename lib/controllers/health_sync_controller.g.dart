// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pulls today's active energy from the server and upserts ONE health-sourced
/// move [Entry] so it feeds the move ring.
///
/// The entry id is deterministic (`health:move:<date>`) so a re-sync overwrites
/// the day's value rather than duplicating it. Instantiated once at app start
/// (see `app.dart`); `fireImmediately` syncs on launch.

@ProviderFor(HealthSyncController)
const healthSyncControllerProvider = HealthSyncControllerProvider._();

/// Pulls today's active energy from the server and upserts ONE health-sourced
/// move [Entry] so it feeds the move ring.
///
/// The entry id is deterministic (`health:move:<date>`) so a re-sync overwrites
/// the day's value rather than duplicating it. Instantiated once at app start
/// (see `app.dart`); `fireImmediately` syncs on launch.
final class HealthSyncControllerProvider
    extends $NotifierProvider<HealthSyncController, void> {
  /// Pulls today's active energy from the server and upserts ONE health-sourced
  /// move [Entry] so it feeds the move ring.
  ///
  /// The entry id is deterministic (`health:move:<date>`) so a re-sync overwrites
  /// the day's value rather than duplicating it. Instantiated once at app start
  /// (see `app.dart`); `fireImmediately` syncs on launch.
  const HealthSyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthSyncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthSyncControllerHash();

  @$internal
  @override
  HealthSyncController create() => HealthSyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$healthSyncControllerHash() =>
    r'0447ca54780c6305e6beb8c4b97a5a86d829c3d1';

/// Pulls today's active energy from the server and upserts ONE health-sourced
/// move [Entry] so it feeds the move ring.
///
/// The entry id is deterministic (`health:move:<date>`) so a re-sync overwrites
/// the day's value rather than duplicating it. Instantiated once at app start
/// (see `app.dart`); `fireImmediately` syncs on launch.

abstract class _$HealthSyncController extends $Notifier<void> {
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
