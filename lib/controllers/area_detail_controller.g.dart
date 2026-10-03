// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'area_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [AreaDetail] for [tracker]. The entries `await for` drives entry
/// edits; watching the goals, routines and weekly plan providers rebuilds this
/// one when only those change.

@ProviderFor(areaDetail)
const areaDetailProvider = AreaDetailFamily._();

/// Streams the [AreaDetail] for [tracker]. The entries `await for` drives entry
/// edits; watching the goals, routines and weekly plan providers rebuilds this
/// one when only those change.

final class AreaDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<AreaDetail>,
          AreaDetail,
          Stream<AreaDetail>
        >
    with $FutureModifier<AreaDetail>, $StreamProvider<AreaDetail> {
  /// Streams the [AreaDetail] for [tracker]. The entries `await for` drives entry
  /// edits; watching the goals, routines and weekly plan providers rebuilds this
  /// one when only those change.
  const AreaDetailProvider._({
    required AreaDetailFamily super.from,
    required DetailTracker super.argument,
  }) : super(
         retry: null,
         name: r'areaDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$areaDetailHash();

  @override
  String toString() {
    return r'areaDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<AreaDetail> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AreaDetail> create(Ref ref) {
    final argument = this.argument as DetailTracker;
    return areaDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AreaDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$areaDetailHash() => r'9d606c2b61d03d89d3b0a4cf14952b765abdd594';

/// Streams the [AreaDetail] for [tracker]. The entries `await for` drives entry
/// edits; watching the goals, routines and weekly plan providers rebuilds this
/// one when only those change.

final class AreaDetailFamily extends $Family
    with $FunctionalFamilyOverride<Stream<AreaDetail>, DetailTracker> {
  const AreaDetailFamily._()
    : super(
        retry: null,
        name: r'areaDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Streams the [AreaDetail] for [tracker]. The entries `await for` drives entry
  /// edits; watching the goals, routines and weekly plan providers rebuilds this
  /// one when only those change.

  AreaDetailProvider call(DetailTracker tracker) =>
      AreaDetailProvider._(argument: tracker, from: this);

  @override
  String toString() => r'areaDetailProvider';
}
