// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pal_composer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the Pal-composer conversation and the [PalService.chat] round-trip.

@ProviderFor(PalComposerController)
const palComposerControllerProvider = PalComposerControllerFamily._();

/// Owns the Pal-composer conversation and the [PalService.chat] round-trip.
final class PalComposerControllerProvider
    extends $NotifierProvider<PalComposerController, PalComposerState> {
  /// Owns the Pal-composer conversation and the [PalService.chat] round-trip.
  const PalComposerControllerProvider._({
    required PalComposerControllerFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'palComposerControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$palComposerControllerHash();

  @override
  String toString() {
    return r'palComposerControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PalComposerController create() => PalComposerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PalComposerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PalComposerState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PalComposerControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$palComposerControllerHash() =>
    r'35b603f890bd0b2516fb4001cfbb3ef9a9001480';

/// Owns the Pal-composer conversation and the [PalService.chat] round-trip.

final class PalComposerControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PalComposerController,
          PalComposerState,
          PalComposerState,
          PalComposerState,
          String?
        > {
  const PalComposerControllerFamily._()
    : super(
        retry: null,
        name: r'palComposerControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Owns the Pal-composer conversation and the [PalService.chat] round-trip.

  PalComposerControllerProvider call({String? seed}) =>
      PalComposerControllerProvider._(argument: seed, from: this);

  @override
  String toString() => r'palComposerControllerProvider';
}

/// Owns the Pal-composer conversation and the [PalService.chat] round-trip.

abstract class _$PalComposerController extends $Notifier<PalComposerState> {
  late final _$args = ref.$arg as String?;
  String? get seed => _$args;

  PalComposerState build({String? seed});
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(seed: _$args);
    final ref = this.ref as $Ref<PalComposerState, PalComposerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PalComposerState, PalComposerState>,
              PalComposerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
