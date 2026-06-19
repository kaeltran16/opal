// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recap_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [RecapData] for [range] over the current period. Reactive:
/// re-emits when the period's entries or the goals change.

@ProviderFor(recapData)
const recapDataProvider = RecapDataFamily._();

/// Streams the [RecapData] for [range] over the current period. Reactive:
/// re-emits when the period's entries or the goals change.

final class RecapDataProvider
    extends
        $FunctionalProvider<AsyncValue<RecapData>, RecapData, Stream<RecapData>>
    with $FutureModifier<RecapData>, $StreamProvider<RecapData> {
  /// Streams the [RecapData] for [range] over the current period. Reactive:
  /// re-emits when the period's entries or the goals change.
  const RecapDataProvider._({
    required RecapDataFamily super.from,
    required InsightRange super.argument,
  }) : super(
         retry: null,
         name: r'recapDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recapDataHash();

  @override
  String toString() {
    return r'recapDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<RecapData> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<RecapData> create(Ref ref) {
    final argument = this.argument as InsightRange;
    return recapData(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecapDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recapDataHash() => r'ecf34a09d31e20bcb005383da174e36676c9c380';

/// Streams the [RecapData] for [range] over the current period. Reactive:
/// re-emits when the period's entries or the goals change.

final class RecapDataFamily extends $Family
    with $FunctionalFamilyOverride<Stream<RecapData>, InsightRange> {
  const RecapDataFamily._()
    : super(
        retry: null,
        name: r'recapDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Streams the [RecapData] for [range] over the current period. Reactive:
  /// re-emits when the period's entries or the goals change.

  RecapDataProvider call(InsightRange range) =>
      RecapDataProvider._(argument: range, from: this);

  @override
  String toString() => r'recapDataProvider';
}

/// Re-derives Pal's learned patterns from the data the recap already surfaces.
/// Read once when the Recap opens (the client-chosen cadence). Best-effort: a
/// model hiccup is swallowed so memory never blocks the recap.

@ProviderFor(recapMemoryRefresh)
const recapMemoryRefreshProvider = RecapMemoryRefreshProvider._();

/// Re-derives Pal's learned patterns from the data the recap already surfaces.
/// Read once when the Recap opens (the client-chosen cadence). Best-effort: a
/// model hiccup is swallowed so memory never blocks the recap.

final class RecapMemoryRefreshProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Re-derives Pal's learned patterns from the data the recap already surfaces.
  /// Read once when the Recap opens (the client-chosen cadence). Best-effort: a
  /// model hiccup is swallowed so memory never blocks the recap.
  const RecapMemoryRefreshProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recapMemoryRefreshProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recapMemoryRefreshHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return recapMemoryRefresh(ref);
  }
}

String _$recapMemoryRefreshHash() =>
    r'c966636811ae4d23a488bbd01abf7c966d23c6fb';
