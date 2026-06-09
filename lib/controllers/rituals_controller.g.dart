// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rituals_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Rituals view model and owns the toggle action.
///
/// Combines the live rituals stream with today's ritual-type entries so the
/// per-ritual completion state stays in sync with the Today rings (both read
/// the same [Entry] rows).

@ProviderFor(RitualsController)
const ritualsControllerProvider = RitualsControllerProvider._();

/// Streams the Rituals view model and owns the toggle action.
///
/// Combines the live rituals stream with today's ritual-type entries so the
/// per-ritual completion state stays in sync with the Today rings (both read
/// the same [Entry] rows).
final class RitualsControllerProvider
    extends $StreamNotifierProvider<RitualsController, RitualsState> {
  /// Streams the Rituals view model and owns the toggle action.
  ///
  /// Combines the live rituals stream with today's ritual-type entries so the
  /// per-ritual completion state stays in sync with the Today rings (both read
  /// the same [Entry] rows).
  const RitualsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ritualsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ritualsControllerHash();

  @$internal
  @override
  RitualsController create() => RitualsController();
}

String _$ritualsControllerHash() => r'5a49a7a46f5b95c111e4da51f7a817626930c6a3';

/// Streams the Rituals view model and owns the toggle action.
///
/// Combines the live rituals stream with today's ritual-type entries so the
/// per-ritual completion state stays in sync with the Today rings (both read
/// the same [Entry] rows).

abstract class _$RitualsController extends $StreamNotifier<RitualsState> {
  Stream<RitualsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<RitualsState>, RitualsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RitualsState>, RitualsState>,
              AsyncValue<RitualsState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
