// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spending_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [DetailData] for a [tracker]. Reactive: re-emits whenever the
/// entries or goals change. Reads all entries (the detail shows recent history
/// across days, not just today) and folds them via [buildDetailData].

@ProviderFor(detailData)
const detailDataProvider = DetailDataFamily._();

/// Streams the [DetailData] for a [tracker]. Reactive: re-emits whenever the
/// entries or goals change. Reads all entries (the detail shows recent history
/// across days, not just today) and folds them via [buildDetailData].

final class DetailDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<DetailData>,
          DetailData,
          Stream<DetailData>
        >
    with $FutureModifier<DetailData>, $StreamProvider<DetailData> {
  /// Streams the [DetailData] for a [tracker]. Reactive: re-emits whenever the
  /// entries or goals change. Reads all entries (the detail shows recent history
  /// across days, not just today) and folds them via [buildDetailData].
  const DetailDataProvider._({
    required DetailDataFamily super.from,
    required DetailTracker super.argument,
  }) : super(
         retry: null,
         name: r'detailDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$detailDataHash();

  @override
  String toString() {
    return r'detailDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<DetailData> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DetailData> create(Ref ref) {
    final argument = this.argument as DetailTracker;
    return detailData(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DetailDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$detailDataHash() => r'8364fd47572e009c2755c8d3ab6cd39a166963ea';

/// Streams the [DetailData] for a [tracker]. Reactive: re-emits whenever the
/// entries or goals change. Reads all entries (the detail shows recent history
/// across days, not just today) and folds them via [buildDetailData].

final class DetailDataFamily extends $Family
    with $FunctionalFamilyOverride<Stream<DetailData>, DetailTracker> {
  const DetailDataFamily._()
    : super(
        retry: null,
        name: r'detailDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Streams the [DetailData] for a [tracker]. Reactive: re-emits whenever the
  /// entries or goals change. Reads all entries (the detail shows recent history
  /// across days, not just today) and folds them via [buildDetailData].

  DetailDataProvider call(DetailTracker tracker) =>
      DetailDataProvider._(argument: tracker, from: this);

  @override
  String toString() => r'detailDataProvider';
}

/// The money spending detail (handoff screen 06). A thin alias over
/// [detailDataProvider] fixed to [DetailTracker.money] — the named
/// "spending controller / breakdown provider" the unit calls for. Move/Rituals
/// detail just request `detailDataProvider(DetailTracker.move|rituals)`.

@ProviderFor(spendingDetail)
const spendingDetailProvider = SpendingDetailProvider._();

/// The money spending detail (handoff screen 06). A thin alias over
/// [detailDataProvider] fixed to [DetailTracker.money] — the named
/// "spending controller / breakdown provider" the unit calls for. Move/Rituals
/// detail just request `detailDataProvider(DetailTracker.move|rituals)`.

final class SpendingDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<DetailData>,
          DetailData,
          Stream<DetailData>
        >
    with $FutureModifier<DetailData>, $StreamProvider<DetailData> {
  /// The money spending detail (handoff screen 06). A thin alias over
  /// [detailDataProvider] fixed to [DetailTracker.money] — the named
  /// "spending controller / breakdown provider" the unit calls for. Move/Rituals
  /// detail just request `detailDataProvider(DetailTracker.move|rituals)`.
  const SpendingDetailProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spendingDetailProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spendingDetailHash();

  @$internal
  @override
  $StreamProviderElement<DetailData> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DetailData> create(Ref ref) {
    return spendingDetail(ref);
  }
}

String _$spendingDetailHash() => r'a1b10dfb0308514f137c281bce7b9231dfa90e28';
