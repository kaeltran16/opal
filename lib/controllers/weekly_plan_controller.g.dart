// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_plan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The week schedule, anchored to the CURRENT week. Mon→Sun: completed = 3 of 5
/// workouts, 290 min planned. Dates are derived relative to today so the plan
/// always shows this week; per-day content/status is fixed.

@ProviderFor(weeklyPlanController)
const weeklyPlanControllerProvider = WeeklyPlanControllerProvider._();

/// The week schedule, anchored to the CURRENT week. Mon→Sun: completed = 3 of 5
/// workouts, 290 min planned. Dates are derived relative to today so the plan
/// always shows this week; per-day content/status is fixed.

final class WeeklyPlanControllerProvider
    extends $FunctionalProvider<WeeklyPlan, WeeklyPlan, WeeklyPlan>
    with $Provider<WeeklyPlan> {
  /// The week schedule, anchored to the CURRENT week. Mon→Sun: completed = 3 of 5
  /// workouts, 290 min planned. Dates are derived relative to today so the plan
  /// always shows this week; per-day content/status is fixed.
  const WeeklyPlanControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weeklyPlanControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weeklyPlanControllerHash();

  @$internal
  @override
  $ProviderElement<WeeklyPlan> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WeeklyPlan create(Ref ref) {
    return weeklyPlanController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeeklyPlan value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeeklyPlan>(value),
    );
  }
}

String _$weeklyPlanControllerHash() =>
    r'd31b80a2ae4610790e7cb39bc56c276d5f81bb98';
