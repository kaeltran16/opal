// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ask_pal_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the Ask-Pal conversation, the [PalService.chat] round-trip, and the
/// auto-apply + undo of any mutations the reply carried.

@ProviderFor(AskPalController)
const askPalControllerProvider = AskPalControllerProvider._();

/// Owns the Ask-Pal conversation, the [PalService.chat] round-trip, and the
/// auto-apply + undo of any mutations the reply carried.
final class AskPalControllerProvider
    extends $NotifierProvider<AskPalController, AskPalState> {
  /// Owns the Ask-Pal conversation, the [PalService.chat] round-trip, and the
  /// auto-apply + undo of any mutations the reply carried.
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

String _$askPalControllerHash() => r'c5bf6fbf5671615ad29d2e28c020b2d255a0a0d0';

/// Owns the Ask-Pal conversation, the [PalService.chat] round-trip, and the
/// auto-apply + undo of any mutations the reply carried.

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
