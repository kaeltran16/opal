// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_review_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the Pal-written weekly narrative: holds the review text with a loading
/// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
/// — reuses the [PalService.review] seam, passing the review week's start date
/// (Apr 17) so the mock returns canned text.

@ProviderFor(WeeklyReviewController)
const weeklyReviewControllerProvider = WeeklyReviewControllerProvider._();

/// Drives the Pal-written weekly narrative: holds the review text with a loading
/// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
/// — reuses the [PalService.review] seam, passing the review week's start date
/// (Apr 17) so the mock returns canned text.
final class WeeklyReviewControllerProvider
    extends $AsyncNotifierProvider<WeeklyReviewController, String> {
  /// Drives the Pal-written weekly narrative: holds the review text with a loading
  /// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
  /// — reuses the [PalService.review] seam, passing the review week's start date
  /// (Apr 17) so the mock returns canned text.
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
    r'bfa200a262c2f34c701579120f1df79556da9e29';

/// Drives the Pal-written weekly narrative: holds the review text with a loading
/// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
/// — reuses the [PalService.review] seam, passing the review week's start date
/// (Apr 17) so the mock returns canned text.

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
