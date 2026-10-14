// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_envelopes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the budget envelopes (position order) and owns every envelope
/// write: the single source of truth the money providers and the envelope
/// editor read.
///
/// Writes read the current envelopes from the repository, not the streamed
/// [state], so back-to-back calls can't race the (async) stream tick.
/// Repository errors propagate to the caller.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.

@ProviderFor(BudgetEnvelopesController)
const budgetEnvelopesControllerProvider = BudgetEnvelopesControllerProvider._();

/// Streams the budget envelopes (position order) and owns every envelope
/// write: the single source of truth the money providers and the envelope
/// editor read.
///
/// Writes read the current envelopes from the repository, not the streamed
/// [state], so back-to-back calls can't race the (async) stream tick.
/// Repository errors propagate to the caller.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.
final class BudgetEnvelopesControllerProvider
    extends
        $StreamNotifierProvider<
          BudgetEnvelopesController,
          List<BudgetEnvelope>
        > {
  /// Streams the budget envelopes (position order) and owns every envelope
  /// write: the single source of truth the money providers and the envelope
  /// editor read.
  ///
  /// Writes read the current envelopes from the repository, not the streamed
  /// [state], so back-to-back calls can't race the (async) stream tick.
  /// Repository errors propagate to the caller.
  ///
  /// No retry: a failing local query would fail again, and retrying holds the
  /// screen on loading.
  const BudgetEnvelopesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'budgetEnvelopesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetEnvelopesControllerHash();

  @$internal
  @override
  BudgetEnvelopesController create() => BudgetEnvelopesController();
}

String _$budgetEnvelopesControllerHash() =>
    r'f4e9d8ee234bfeb88e66e6949afeaf39f9278c97';

/// Streams the budget envelopes (position order) and owns every envelope
/// write: the single source of truth the money providers and the envelope
/// editor read.
///
/// Writes read the current envelopes from the repository, not the streamed
/// [state], so back-to-back calls can't race the (async) stream tick.
/// Repository errors propagate to the caller.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.

abstract class _$BudgetEnvelopesController
    extends $StreamNotifier<List<BudgetEnvelope>> {
  Stream<List<BudgetEnvelope>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<List<BudgetEnvelope>>, List<BudgetEnvelope>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<BudgetEnvelope>>,
                List<BudgetEnvelope>
              >,
              AsyncValue<List<BudgetEnvelope>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
