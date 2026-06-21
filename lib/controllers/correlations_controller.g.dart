// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'correlations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Surfaced cross-dimension correlations over the rolling window, strongest
/// first. Computed on-device from entries + meals; empty when nothing clears
/// the confidence bar (the honest empty state). Single source of truth shared
/// by the Insights and Nutrition surfaces.

@ProviderFor(surfacedCorrelations)
const surfacedCorrelationsProvider = SurfacedCorrelationsProvider._();

/// Surfaced cross-dimension correlations over the rolling window, strongest
/// first. Computed on-device from entries + meals; empty when nothing clears
/// the confidence bar (the honest empty state). Single source of truth shared
/// by the Insights and Nutrition surfaces.

final class SurfacedCorrelationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<corr.Correlation>>,
          List<corr.Correlation>,
          FutureOr<List<corr.Correlation>>
        >
    with
        $FutureModifier<List<corr.Correlation>>,
        $FutureProvider<List<corr.Correlation>> {
  /// Surfaced cross-dimension correlations over the rolling window, strongest
  /// first. Computed on-device from entries + meals; empty when nothing clears
  /// the confidence bar (the honest empty state). Single source of truth shared
  /// by the Insights and Nutrition surfaces.
  const SurfacedCorrelationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'surfacedCorrelationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$surfacedCorrelationsHash();

  @$internal
  @override
  $FutureProviderElement<List<corr.Correlation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<corr.Correlation>> create(Ref ref) {
    return surfacedCorrelations(ref);
  }
}

String _$surfacedCorrelationsHash() =>
    r'b8b1f18b3677e310cdeb36ee5bb6a0c0730461ef';
