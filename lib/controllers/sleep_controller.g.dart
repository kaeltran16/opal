// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Sleep view model. Read-only; sleep nights are written only by
/// the health sync. Mirrors [NutritionController]'s stream-build pattern.

@ProviderFor(SleepController)
const sleepControllerProvider = SleepControllerProvider._();

/// Streams the Sleep view model. Read-only; sleep nights are written only by
/// the health sync. Mirrors [NutritionController]'s stream-build pattern.
final class SleepControllerProvider
    extends $StreamNotifierProvider<SleepController, SleepState> {
  /// Streams the Sleep view model. Read-only; sleep nights are written only by
  /// the health sync. Mirrors [NutritionController]'s stream-build pattern.
  const SleepControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepControllerHash();

  @$internal
  @override
  SleepController create() => SleepController();
}

String _$sleepControllerHash() => r'b9dcbfdcbb7a635daee4748e5d1c9cb25c9bc0d6';

/// Streams the Sleep view model. Read-only; sleep nights are written only by
/// the health sync. Mirrors [NutritionController]'s stream-build pattern.

abstract class _$SleepController extends $StreamNotifier<SleepState> {
  Stream<SleepState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<SleepState>, SleepState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SleepState>, SleepState>,
              AsyncValue<SleepState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
