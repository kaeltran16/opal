// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_advisories_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the advisory findings, recomputed whenever entries in the window
/// change. Reads envelopes one-shot per emission, mirroring
/// `budgetRecommendations`.
///
/// The window spans the three completed months (for the savings average) plus
/// the current one (for uncovered spend), so both detectors share a single
/// subscription.

@ProviderFor(budgetAdvisories)
const budgetAdvisoriesProvider = BudgetAdvisoriesProvider._();

/// Streams the advisory findings, recomputed whenever entries in the window
/// change. Reads envelopes one-shot per emission, mirroring
/// `budgetRecommendations`.
///
/// The window spans the three completed months (for the savings average) plus
/// the current one (for uncovered spend), so both detectors share a single
/// subscription.

final class BudgetAdvisoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<BudgetAdvisories>,
          BudgetAdvisories,
          Stream<BudgetAdvisories>
        >
    with $FutureModifier<BudgetAdvisories>, $StreamProvider<BudgetAdvisories> {
  /// Streams the advisory findings, recomputed whenever entries in the window
  /// change. Reads envelopes one-shot per emission, mirroring
  /// `budgetRecommendations`.
  ///
  /// The window spans the three completed months (for the savings average) plus
  /// the current one (for uncovered spend), so both detectors share a single
  /// subscription.
  const BudgetAdvisoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetAdvisoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetAdvisoriesHash();

  @$internal
  @override
  $StreamProviderElement<BudgetAdvisories> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BudgetAdvisories> create(Ref ref) {
    return budgetAdvisories(ref);
  }
}

String _$budgetAdvisoriesHash() => r'b1704725181184b2225e8ae851bfdb11111c9761';
