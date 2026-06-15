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
