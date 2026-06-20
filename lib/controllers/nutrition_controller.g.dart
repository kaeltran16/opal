// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Nutrition view model and owns meal logging actions.

@ProviderFor(NutritionController)
const nutritionControllerProvider = NutritionControllerProvider._();

/// Streams the Nutrition view model and owns meal logging actions.
final class NutritionControllerProvider
    extends $StreamNotifierProvider<NutritionController, NutritionState> {
  /// Streams the Nutrition view model and owns meal logging actions.
  const NutritionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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
    r'823fe45038f8abe02b0e5044a0aaf0e9f56810b9';

/// Streams the Nutrition view model and owns meal logging actions.

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
