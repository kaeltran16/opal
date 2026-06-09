// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ask_pal_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the Ask-Pal conversation and the [PalService.chat] round-trip.

@ProviderFor(AskPalController)
const askPalControllerProvider = AskPalControllerProvider._();

/// Owns the Ask-Pal conversation and the [PalService.chat] round-trip.
final class AskPalControllerProvider
    extends $NotifierProvider<AskPalController, AskPalState> {
  /// Owns the Ask-Pal conversation and the [PalService.chat] round-trip.
  const AskPalControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'askPalControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$askPalControllerHash();

  @$internal
  @override
  AskPalController create() => AskPalController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AskPalState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AskPalState>(value),
    );
  }
}

String _$askPalControllerHash() => r'db13504fa933926c1cce6f148eb3fe4daf76f57b';

/// Owns the Ask-Pal conversation and the [PalService.chat] round-trip.

abstract class _$AskPalController extends $Notifier<AskPalState> {
  AskPalState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AskPalState, AskPalState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AskPalState, AskPalState>,
              AskPalState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
