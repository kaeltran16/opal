// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pal_inbox_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Pal-inbox notes folded with the active filter, and owns the
/// filter selection + read actions. Mirrors [RitualsController]'s stream pattern
/// (`build` yields from the repo stream) with the filter kept as local state.

@ProviderFor(PalInboxController)
const palInboxControllerProvider = PalInboxControllerProvider._();

/// Streams the Pal-inbox notes folded with the active filter, and owns the
/// filter selection + read actions. Mirrors [RitualsController]'s stream pattern
/// (`build` yields from the repo stream) with the filter kept as local state.
final class PalInboxControllerProvider
    extends $StreamNotifierProvider<PalInboxController, PalInboxState> {
  /// Streams the Pal-inbox notes folded with the active filter, and owns the
  /// filter selection + read actions. Mirrors [RitualsController]'s stream pattern
  /// (`build` yields from the repo stream) with the filter kept as local state.
  const PalInboxControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'palInboxControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$palInboxControllerHash();

  @$internal
  @override
  PalInboxController create() => PalInboxController();
}

String _$palInboxControllerHash() =>
    r'2b02752e8c840f5730421925916796746e0fddb5';

/// Streams the Pal-inbox notes folded with the active filter, and owns the
/// filter selection + read actions. Mirrors [RitualsController]'s stream pattern
/// (`build` yields from the repo stream) with the filter kept as local state.

abstract class _$PalInboxController extends $StreamNotifier<PalInboxState> {
  Stream<PalInboxState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<PalInboxState>, PalInboxState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PalInboxState>, PalInboxState>,
              AsyncValue<PalInboxState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
