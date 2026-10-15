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
    required ({String? seed, String? about}) super.argument,
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
        '$argument';
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
    r'5783c797f5a7083101962160a6fc30a9206a52fe';

/// Owns the Pal-composer conversation and the [PalService.chat] round-trip.

final class PalComposerControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PalComposerController,
          PalComposerState,
          PalComposerState,
          PalComposerState,
          ({String? seed, String? about})
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

  PalComposerControllerProvider call({String? seed, String? about}) =>
      PalComposerControllerProvider._(
        argument: (seed: seed, about: about),
        from: this,
      );

  @override
  String toString() => r'palComposerControllerProvider';
}

/// Owns the Pal-composer conversation and the [PalService.chat] round-trip.

abstract class _$PalComposerController extends $Notifier<PalComposerState> {
  late final _$args = ref.$arg as ({String? seed, String? about});
  String? get seed => _$args.seed;
  String? get about => _$args.about;

  PalComposerState build({String? seed, String? about});
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(seed: _$args.seed, about: _$args.about);
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
