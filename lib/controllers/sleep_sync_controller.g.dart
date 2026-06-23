// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pulls recent nights from Health and upserts them into [SleepRepository].
/// Deterministic id (`health:sleep:<date>` or the Health sourceRef) so a
/// re-sync overwrites rather than duplicates. Best-effort: a failed pull must
/// not crash startup. Syncs on construction.

@ProviderFor(SleepSyncController)
const sleepSyncControllerProvider = SleepSyncControllerProvider._();

/// Pulls recent nights from Health and upserts them into [SleepRepository].
/// Deterministic id (`health:sleep:<date>` or the Health sourceRef) so a
/// re-sync overwrites rather than duplicates. Best-effort: a failed pull must
/// not crash startup. Syncs on construction.
final class SleepSyncControllerProvider
    extends $NotifierProvider<SleepSyncController, void> {
  /// Pulls recent nights from Health and upserts them into [SleepRepository].
  /// Deterministic id (`health:sleep:<date>` or the Health sourceRef) so a
  /// re-sync overwrites rather than duplicates. Best-effort: a failed pull must
  /// not crash startup. Syncs on construction.
  const SleepSyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepSyncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepSyncControllerHash();

  @$internal
  @override
  SleepSyncController create() => SleepSyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$sleepSyncControllerHash() =>
    r'b4b9364e97d231ae05efbf82e6a767dc51b0ef46';

/// Pulls recent nights from Health and upserts them into [SleepRepository].
/// Deterministic id (`health:sleep:<date>` or the Health sourceRef) so a
/// re-sync overwrites rather than duplicates. Best-effort: a failed pull must
/// not crash startup. Syncs on construction.

abstract class _$SleepSyncController extends $Notifier<void> {
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
