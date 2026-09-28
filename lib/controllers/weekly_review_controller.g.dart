// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_review_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [WeeklyStats] for the current week (Mon–Sun). Reactive: re-emits
/// when this week's entries or the goals change.

@ProviderFor(weeklyStats)
const weeklyStatsProvider = WeeklyStatsProvider._();

/// Streams the [WeeklyStats] for the current week (Mon–Sun). Reactive: re-emits
/// when this week's entries or the goals change.

final class WeeklyStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<WeeklyStats>,
          WeeklyStats,
          Stream<WeeklyStats>
        >
    with $FutureModifier<WeeklyStats>, $StreamProvider<WeeklyStats> {
  /// Streams the [WeeklyStats] for the current week (Mon–Sun). Reactive: re-emits
  /// when this week's entries or the goals change.
  const WeeklyStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weeklyStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weeklyStatsHash();

  @$internal
  @override
  $StreamProviderElement<WeeklyStats> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WeeklyStats> create(Ref ref) {
    return weeklyStats(ref);
  }
}

String _$weeklyStatsHash() => r'9e416d9394d0f9e3cac1192eaead0c551b6f9caf';

/// Drives the Pal-written weekly narrative: holds the review text with a loading
/// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
/// — reuses the [PalService.review] seam, passing the current week's start.

@ProviderFor(WeeklyReviewController)
const weeklyReviewControllerProvider = WeeklyReviewControllerProvider._();

/// Drives the Pal-written weekly narrative: holds the review text with a loading
/// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
/// — reuses the [PalService.review] seam, passing the current week's start.
final class WeeklyReviewControllerProvider
    extends $AsyncNotifierProvider<WeeklyReviewController, String> {
  /// Drives the Pal-written weekly narrative: holds the review text with a loading
  /// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
  /// — reuses the [PalService.review] seam, passing the current week's start.
  const WeeklyReviewControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weeklyReviewControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weeklyReviewControllerHash();

  @$internal
  @override
  WeeklyReviewController create() => WeeklyReviewController();
}

String _$weeklyReviewControllerHash() =>
    r'392d07fef69a8584180d01ae341a4b8580836b94';

/// Drives the Pal-written weekly narrative: holds the review text with a loading
/// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
/// — reuses the [PalService.review] seam, passing the current week's start.

abstract class _$WeeklyReviewController extends $AsyncNotifier<String> {
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
