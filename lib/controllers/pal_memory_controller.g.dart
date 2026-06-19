// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pal_memory_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pal's persistent memory for the "What Pal remembers" section. One-shot like
/// [palAgenda]; an unreachable backend degrades to an empty digest rather than
/// an error.

@ProviderFor(palMemory)
const palMemoryProvider = PalMemoryProvider._();

/// Pal's persistent memory for the "What Pal remembers" section. One-shot like
/// [palAgenda]; an unreachable backend degrades to an empty digest rather than
/// an error.

final class PalMemoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<PalMemoryDigest>,
          PalMemoryDigest,
          FutureOr<PalMemoryDigest>
        >
    with $FutureModifier<PalMemoryDigest>, $FutureProvider<PalMemoryDigest> {
  /// Pal's persistent memory for the "What Pal remembers" section. One-shot like
  /// [palAgenda]; an unreachable backend degrades to an empty digest rather than
  /// an error.
  const PalMemoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'palMemoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$palMemoryHash();

  @$internal
  @override
  $FutureProviderElement<PalMemoryDigest> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PalMemoryDigest> create(Ref ref) {
    return palMemory(ref);
  }
}

String _$palMemoryHash() => r'be660963981a2a1e0f291ed65861337b4f88160b';
