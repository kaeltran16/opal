// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budgets_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [BudgetsData] for the current month. Reactive: re-emits whenever
/// this month's entries change. Reads envelopes one-shot per emission.

@ProviderFor(budgetsData)
const budgetsDataProvider = BudgetsDataProvider._();

/// Streams the [BudgetsData] for the current month. Reactive: re-emits whenever
/// this month's entries change. Reads envelopes one-shot per emission.

final class BudgetsDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<BudgetsData>,
          BudgetsData,
          Stream<BudgetsData>
        >
    with $FutureModifier<BudgetsData>, $StreamProvider<BudgetsData> {
  /// Streams the [BudgetsData] for the current month. Reactive: re-emits whenever
  /// this month's entries change. Reads envelopes one-shot per emission.
  const BudgetsDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetsDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetsDataHash();

  @$internal
  @override
  $StreamProviderElement<BudgetsData> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BudgetsData> create(Ref ref) {
    return budgetsData(ref);
  }
}

String _$budgetsDataHash() => r'91a609e59d387ee53c1f9e876ff045277950bd5d';
