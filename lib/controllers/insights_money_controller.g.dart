// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insights_money_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [InsightsData] over a rolling 6-month window. Reactive: re-emits
/// whenever entries in the window change. Also re-emits when an envelope changes.

@ProviderFor(insightsData)
const insightsDataProvider = InsightsDataProvider._();

/// Streams the [InsightsData] over a rolling 6-month window. Reactive: re-emits
/// whenever entries in the window change. Also re-emits when an envelope changes.

final class InsightsDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<InsightsData>,
          InsightsData,
          Stream<InsightsData>
        >
    with $FutureModifier<InsightsData>, $StreamProvider<InsightsData> {
  /// Streams the [InsightsData] over a rolling 6-month window. Reactive: re-emits
  /// whenever entries in the window change. Also re-emits when an envelope changes.
  const InsightsDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'insightsDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$insightsDataHash();

  @$internal
  @override
  $StreamProviderElement<InsightsData> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<InsightsData> create(Ref ref) {
    return insightsData(ref);
  }
}

String _$insightsDataHash() => r'eee9d20588673dcc8d4f47667b649043e2c87cfa';
