// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'area_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Sleep page, null while no nights are stored. A night counts
/// toward the day after it, so the window starts a day early.

@ProviderFor(sleepDetail)
const sleepDetailProvider = SleepDetailProvider._();

/// Streams the Sleep page, null while no nights are stored. A night counts
/// toward the day after it, so the window starts a day early.

final class SleepDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<AreaDetail?>,
          AreaDetail?,
          Stream<AreaDetail?>
        >
    with $FutureModifier<AreaDetail?>, $StreamProvider<AreaDetail?> {
  /// Streams the Sleep page, null while no nights are stored. A night counts
  /// toward the day after it, so the window starts a day early.
  const SleepDetailProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepDetailProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepDetailHash();

  @$internal
  @override
  $StreamProviderElement<AreaDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AreaDetail?> create(Ref ref) {
    return sleepDetail(ref);
  }
}

String _$sleepDetailHash() => r'240b52d27d9654053aa1b8c8824f82b1d4a9428a';

/// Streams the [AreaDetail] for [area]. Sleep reads [sleepDetailProvider]
/// instead, which is empty while no nights are stored.

@ProviderFor(areaDetail)
const areaDetailProvider = AreaDetailFamily._();

/// Streams the [AreaDetail] for [area]. Sleep reads [sleepDetailProvider]
/// instead, which is empty while no nights are stored.

final class AreaDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<AreaDetail>,
          AreaDetail,
          Stream<AreaDetail>
        >
    with $FutureModifier<AreaDetail>, $StreamProvider<AreaDetail> {
  /// Streams the [AreaDetail] for [area]. Sleep reads [sleepDetailProvider]
  /// instead, which is empty while no nights are stored.
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

String _$areaDetailHash() => r'a117657d09d72b284f049e83b2e6fd0dd1077dd7';

/// Streams the [AreaDetail] for [area]. Sleep reads [sleepDetailProvider]
/// instead, which is empty while no nights are stored.

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

  /// Streams the [AreaDetail] for [area]. Sleep reads [sleepDetailProvider]
  /// instead, which is empty while no nights are stored.

  AreaDetailProvider call(Area area) =>
      AreaDetailProvider._(argument: area, from: this);

  @override
  String toString() => r'areaDetailProvider';
}
