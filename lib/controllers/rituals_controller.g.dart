// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rituals_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Rituals view model and owns the step toggle / complete actions.

@ProviderFor(RitualsController)
const ritualsControllerProvider = RitualsControllerProvider._();

/// Streams the Rituals view model and owns the step toggle / complete actions.
final class RitualsControllerProvider
    extends $StreamNotifierProvider<RitualsController, RitualsState> {
  /// Streams the Rituals view model and owns the step toggle / complete actions.
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

String _$ritualsControllerHash() => r'fa5fb562e3111b2ca108ef9eb4ad8e7a2a4727ce';

/// Streams the Rituals view model and owns the step toggle / complete actions.

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
