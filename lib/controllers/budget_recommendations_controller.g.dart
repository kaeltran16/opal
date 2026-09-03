// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_recommendations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams suggested caps for the current month, recomputed whenever the last
/// three months' entries change. Reads envelopes one-shot per emission.

@ProviderFor(budgetRecommendations)
const budgetRecommendationsProvider = BudgetRecommendationsProvider._();

/// Streams suggested caps for the current month, recomputed whenever the last
/// three months' entries change. Reads envelopes one-shot per emission.

final class BudgetRecommendationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BudgetRecommendation>>,
          List<BudgetRecommendation>,
          Stream<List<BudgetRecommendation>>
        >
    with
        $FutureModifier<List<BudgetRecommendation>>,
        $StreamProvider<List<BudgetRecommendation>> {
  /// Streams suggested caps for the current month, recomputed whenever the last
  /// three months' entries change. Reads envelopes one-shot per emission.
  const BudgetRecommendationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetRecommendationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetRecommendationsHash();

  @$internal
  @override
  $StreamProviderElement<List<BudgetRecommendation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<BudgetRecommendation>> create(Ref ref) {
    return budgetRecommendations(ref);
  }
}

String _$budgetRecommendationsHash() =>
    r'8f64076f04845dbfa716a478bd030e9e62ae642c';
