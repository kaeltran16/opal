// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_plan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The hardcoded "Week of Apr 21" schedule. Mon→Sun: completed = 3 of 5
/// workouts, 290 min planned.

@ProviderFor(weeklyPlanController)
const weeklyPlanControllerProvider = WeeklyPlanControllerProvider._();

/// The hardcoded "Week of Apr 21" schedule. Mon→Sun: completed = 3 of 5
/// workouts, 290 min planned.

final class WeeklyPlanControllerProvider
    extends $FunctionalProvider<WeeklyPlan, WeeklyPlan, WeeklyPlan>
    with $Provider<WeeklyPlan> {
  /// The hardcoded "Week of Apr 21" schedule. Mon→Sun: completed = 3 of 5
  /// workouts, 290 min planned.
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
    r'2aec6d54721734907750de113a23559ea7da68f6';
