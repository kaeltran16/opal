// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spend_patterns_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Spend patterns over the rolling window — biggest weekday, weekend split,
/// daypart peak, no-spend streak, standout expenses.
///
/// Reactive: re-emits whenever in-window entries change. Every finding is
/// independently gated, so an [sp.SpendPatterns.isEmpty] result is the honest
/// answer for a thin history rather than a failure.

@ProviderFor(spendPatterns)
const spendPatternsProvider = SpendPatternsProvider._();

/// Spend patterns over the rolling window — biggest weekday, weekend split,
/// daypart peak, no-spend streak, standout expenses.
///
/// Reactive: re-emits whenever in-window entries change. Every finding is
/// independently gated, so an [sp.SpendPatterns.isEmpty] result is the honest
/// answer for a thin history rather than a failure.

final class SpendPatternsProvider
    extends
        $FunctionalProvider<
          AsyncValue<sp.SpendPatterns>,
          sp.SpendPatterns,
          Stream<sp.SpendPatterns>
        >
    with $FutureModifier<sp.SpendPatterns>, $StreamProvider<sp.SpendPatterns> {
  /// Spend patterns over the rolling window — biggest weekday, weekend split,
  /// daypart peak, no-spend streak, standout expenses.
  ///
  /// Reactive: re-emits whenever in-window entries change. Every finding is
  /// independently gated, so an [sp.SpendPatterns.isEmpty] result is the honest
  /// answer for a thin history rather than a failure.
  const SpendPatternsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spendPatternsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spendPatternsHash();

  @$internal
  @override
  $StreamProviderElement<sp.SpendPatterns> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<sp.SpendPatterns> create(Ref ref) {
    return spendPatterns(ref);
  }
}

String _$spendPatternsHash() => r'6bfc13821bc9e70e85ddeb82855160f9f693e5a2';
