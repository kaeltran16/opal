// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'money_recurring_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [SubscriptionsState]; re-emits whenever subscriptions change.

@ProviderFor(subscriptions)
const subscriptionsProvider = SubscriptionsProvider._();

/// Streams the [SubscriptionsState]; re-emits whenever subscriptions change.

final class SubscriptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SubscriptionsState>,
          SubscriptionsState,
          Stream<SubscriptionsState>
        >
    with
        $FutureModifier<SubscriptionsState>,
        $StreamProvider<SubscriptionsState> {
  /// Streams the [SubscriptionsState]; re-emits whenever subscriptions change.
  const SubscriptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionsHash();

  @$internal
  @override
  $StreamProviderElement<SubscriptionsState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SubscriptionsState> create(Ref ref) {
    return subscriptions(ref);
  }
}

String _$subscriptionsHash() => r'72972b69e3087722bd5067ca79d199f0fd5e3c93';

/// Streams the [BillsState]; re-emits whenever bills change.

@ProviderFor(bills)
const billsProvider = BillsProvider._();

/// Streams the [BillsState]; re-emits whenever bills change.

final class BillsProvider
    extends
        $FunctionalProvider<
          AsyncValue<BillsState>,
          BillsState,
          Stream<BillsState>
        >
    with $FutureModifier<BillsState>, $StreamProvider<BillsState> {
  /// Streams the [BillsState]; re-emits whenever bills change.
  const BillsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'billsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$billsHash();

  @$internal
  @override
  $StreamProviderElement<BillsState> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<BillsState> create(Ref ref) {
    return bills(ref);
  }
}

String _$billsHash() => r'4ac369372947e0ee553461536db3d02e503ce4c8';
