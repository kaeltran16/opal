// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the iOS rings widget in sync with today's progress.
///
/// Listens to [todayStateProvider] and maps each new [TodayState] onto the
/// primitive args [WidgetSyncService] expects (the services layer stays free of
/// view-model types). Has no UI surface; instantiated once at app start
/// (see `app.dart`). `fireImmediately` seeds the widget on launch.

@ProviderFor(WidgetSyncController)
const widgetSyncControllerProvider = WidgetSyncControllerProvider._();

/// Keeps the iOS rings widget in sync with today's progress.
///
/// Listens to [todayStateProvider] and maps each new [TodayState] onto the
/// primitive args [WidgetSyncService] expects (the services layer stays free of
/// view-model types). Has no UI surface; instantiated once at app start
/// (see `app.dart`). `fireImmediately` seeds the widget on launch.
final class WidgetSyncControllerProvider
    extends $NotifierProvider<WidgetSyncController, void> {
  /// Keeps the iOS rings widget in sync with today's progress.
  ///
  /// Listens to [todayStateProvider] and maps each new [TodayState] onto the
  /// primitive args [WidgetSyncService] expects (the services layer stays free of
  /// view-model types). Has no UI surface; instantiated once at app start
  /// (see `app.dart`). `fireImmediately` seeds the widget on launch.
  const WidgetSyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetSyncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetSyncControllerHash();

  @$internal
  @override
  WidgetSyncController create() => WidgetSyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$widgetSyncControllerHash() =>
    r'f16b1b800674e6c5da509966508458e0229c07ea';

/// Keeps the iOS rings widget in sync with today's progress.
///
/// Listens to [todayStateProvider] and maps each new [TodayState] onto the
/// primitive args [WidgetSyncService] expects (the services layer stays free of
/// view-model types). Has no UI surface; instantiated once at app start
/// (see `app.dart`). `fireImmediately` seeds the widget on launch.

abstract class _$WidgetSyncController extends $Notifier<void> {
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
