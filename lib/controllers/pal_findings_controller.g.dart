// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pal_findings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every Pal finding, in source order (correlations, spend patterns,
/// Nutrition's patterns, Pal's memory patterns), with the dismissed ones
/// removed. You and What Pal remembers both read this, so a dismissal leaves
/// both lists at once.

@ProviderFor(PalFindingsController)
const palFindingsControllerProvider = PalFindingsControllerProvider._();

/// Every Pal finding, in source order (correlations, spend patterns,
/// Nutrition's patterns, Pal's memory patterns), with the dismissed ones
/// removed. You and What Pal remembers both read this, so a dismissal leaves
/// both lists at once.
final class PalFindingsControllerProvider
    extends $AsyncNotifierProvider<PalFindingsController, List<PalFinding>> {
  /// Every Pal finding, in source order (correlations, spend patterns,
  /// Nutrition's patterns, Pal's memory patterns), with the dismissed ones
  /// removed. You and What Pal remembers both read this, so a dismissal leaves
  /// both lists at once.
  const PalFindingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'palFindingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$palFindingsControllerHash();

  @$internal
  @override
  PalFindingsController create() => PalFindingsController();
}

String _$palFindingsControllerHash() =>
    r'6b1652b8132e37553d740d781d93939a4fa10c71';

/// Every Pal finding, in source order (correlations, spend patterns,
/// Nutrition's patterns, Pal's memory patterns), with the dismissed ones
/// removed. You and What Pal remembers both read this, so a dismissal leaves
/// both lists at once.

abstract class _$PalFindingsController
    extends $AsyncNotifier<List<PalFinding>> {
  FutureOr<List<PalFinding>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<PalFinding>>, List<PalFinding>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<PalFinding>>, List<PalFinding>>,
              AsyncValue<List<PalFinding>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
