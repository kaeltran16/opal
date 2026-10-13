// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Nutrition view model and owns meal logging actions.
///
/// No retry: a failing local query would fail again, and retrying holds Pal's
/// findings loading.

@ProviderFor(NutritionController)
const nutritionControllerProvider = NutritionControllerProvider._();

/// Streams the Nutrition view model and owns meal logging actions.
///
/// No retry: a failing local query would fail again, and retrying holds Pal's
/// findings loading.
final class NutritionControllerProvider
    extends $StreamNotifierProvider<NutritionController, NutritionState> {
  /// Streams the Nutrition view model and owns meal logging actions.
  ///
  /// No retry: a failing local query would fail again, and retrying holds Pal's
  /// findings loading.
  const NutritionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'nutritionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nutritionControllerHash();

  @$internal
  @override
  NutritionController create() => NutritionController();
}

String _$nutritionControllerHash() =>
    r'118ff3e7d806b998fdf53c3b293991bd8ea2153c';

/// Streams the Nutrition view model and owns meal logging actions.
///
/// No retry: a failing local query would fail again, and retrying holds Pal's
/// findings loading.

abstract class _$NutritionController extends $StreamNotifier<NutritionState> {
  Stream<NutritionState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<NutritionState>, NutritionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<NutritionState>, NutritionState>,
              AsyncValue<NutritionState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
