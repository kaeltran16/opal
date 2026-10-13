// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'area_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [AreaDetail] for [area]. Sleep has no data source, so its page
/// does not watch this provider.

@ProviderFor(areaDetail)
const areaDetailProvider = AreaDetailFamily._();

/// Streams the [AreaDetail] for [area]. Sleep has no data source, so its page
/// does not watch this provider.

final class AreaDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<AreaDetail>,
          AreaDetail,
          Stream<AreaDetail>
        >
    with $FutureModifier<AreaDetail>, $StreamProvider<AreaDetail> {
  /// Streams the [AreaDetail] for [area]. Sleep has no data source, so its page
  /// does not watch this provider.
  const AreaDetailProvider._({
    required AreaDetailFamily super.from,
    required Area super.argument,
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
    final argument = this.argument as Area;
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

String _$areaDetailHash() => r'bd30a99d7e89f346a0c6610a6fcd13b677f608a2';

/// Streams the [AreaDetail] for [area]. Sleep has no data source, so its page
/// does not watch this provider.

final class AreaDetailFamily extends $Family
    with $FunctionalFamilyOverride<Stream<AreaDetail>, Area> {
  const AreaDetailFamily._()
    : super(
        retry: null,
        name: r'areaDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Streams the [AreaDetail] for [area]. Sleep has no data source, so its page
  /// does not watch this provider.

  AreaDetailProvider call(Area area) =>
      AreaDetailProvider._(argument: area, from: this);

  @override
  String toString() => r'areaDetailProvider';
}
