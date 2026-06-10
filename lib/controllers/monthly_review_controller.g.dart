// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_review_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [MonthlyStats] for the current month. Reactive: re-emits when
/// entries or rituals change. The "By the numbers" block reads this.

@ProviderFor(monthlyStats)
const monthlyStatsProvider = MonthlyStatsProvider._();

/// Streams the [MonthlyStats] for the current month. Reactive: re-emits when
/// entries or rituals change. The "By the numbers" block reads this.

final class MonthlyStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<MonthlyStats>,
          MonthlyStats,
          Stream<MonthlyStats>
        >
    with $FutureModifier<MonthlyStats>, $StreamProvider<MonthlyStats> {
  /// Streams the [MonthlyStats] for the current month. Reactive: re-emits when
  /// entries or rituals change. The "By the numbers" block reads this.
  const MonthlyStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monthlyStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monthlyStatsHash();

  @$internal
  @override
  $StreamProviderElement<MonthlyStats> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<MonthlyStats> create(Ref ref) {
    return monthlyStats(ref);
  }
}

String _$monthlyStatsHash() => r'b897646ada80a126ba7129b6b456626e972f2b14';

/// Drives the narrative card: holds the Pal-written review text with a loading
/// state, and re-requests it on [regenerate]. The narrative is the only async,
/// re-requestable piece; the stats are a separate reactive stream above.

@ProviderFor(MonthlyReviewController)
const monthlyReviewControllerProvider = MonthlyReviewControllerProvider._();

/// Drives the narrative card: holds the Pal-written review text with a loading
/// state, and re-requests it on [regenerate]. The narrative is the only async,
/// re-requestable piece; the stats are a separate reactive stream above.
final class MonthlyReviewControllerProvider
    extends $AsyncNotifierProvider<MonthlyReviewController, String> {
  /// Drives the narrative card: holds the Pal-written review text with a loading
  /// state, and re-requests it on [regenerate]. The narrative is the only async,
  /// re-requestable piece; the stats are a separate reactive stream above.
  const MonthlyReviewControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monthlyReviewControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monthlyReviewControllerHash();

  @$internal
  @override
  MonthlyReviewController create() => MonthlyReviewController();
}

String _$monthlyReviewControllerHash() =>
    r'df6003a6642c70f6926d2b15a1f3902187c5937f';

/// Drives the narrative card: holds the Pal-written review text with a loading
/// state, and re-requests it on [regenerate]. The narrative is the only async,
/// re-requestable piece; the stats are a separate reactive stream above.

abstract class _$MonthlyReviewController extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
