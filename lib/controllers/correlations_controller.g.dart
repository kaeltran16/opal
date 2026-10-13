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
///
/// No retry: a failing local query would fail again, and retrying holds Pal's
/// findings loading.

@ProviderFor(surfacedCorrelations)
const surfacedCorrelationsProvider = SurfacedCorrelationsProvider._();

/// Surfaced cross-dimension correlations over the rolling window, strongest
/// first. Computed on-device from entries + meals; empty when nothing clears
/// the confidence bar (the honest empty state). Single source of truth shared
/// by the Insights and Nutrition surfaces.
///
/// No retry: a failing local query would fail again, and retrying holds Pal's
/// findings loading.

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
  ///
  /// No retry: a failing local query would fail again, and retrying holds Pal's
  /// findings loading.
  const SurfacedCorrelationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
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
    r'5300244381e6bcf6b0f81977cd1cdade83318144';
