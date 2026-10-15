// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rituals_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Rituals view model and owns the step toggle / complete actions.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.

@ProviderFor(RitualsController)
const ritualsControllerProvider = RitualsControllerProvider._();

/// Streams the Rituals view model and owns the step toggle / complete actions.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.
final class RitualsControllerProvider
    extends $StreamNotifierProvider<RitualsController, RitualsState> {
  /// Streams the Rituals view model and owns the step toggle / complete actions.
  ///
  /// No retry: a failing local query would fail again, and retrying holds the
  /// screen on loading.
  const RitualsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
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

String _$ritualsControllerHash() => r'5b7728d1660d0792313fda0b6665989e8262bf9f';

/// Streams the Rituals view model and owns the step toggle / complete actions.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.

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
