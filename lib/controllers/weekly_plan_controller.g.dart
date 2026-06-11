// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_plan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the derived [WeeklyPlan], anchored to the current week. Re-emits when
/// the persisted schedule changes; each tick re-reads routines, the exercise
/// catalog, and workout history so completion/derivation stay current.

@ProviderFor(weeklyPlanController)
const weeklyPlanControllerProvider = WeeklyPlanControllerProvider._();

/// Streams the derived [WeeklyPlan], anchored to the current week. Re-emits when
/// the persisted schedule changes; each tick re-reads routines, the exercise
/// catalog, and workout history so completion/derivation stay current.

final class WeeklyPlanControllerProvider
    extends
        $FunctionalProvider<
          AsyncValue<WeeklyPlan>,
          WeeklyPlan,
          Stream<WeeklyPlan>
        >
    with $FutureModifier<WeeklyPlan>, $StreamProvider<WeeklyPlan> {
  /// Streams the derived [WeeklyPlan], anchored to the current week. Re-emits when
  /// the persisted schedule changes; each tick re-reads routines, the exercise
  /// catalog, and workout history so completion/derivation stay current.
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
  $StreamProviderElement<WeeklyPlan> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<WeeklyPlan> create(Ref ref) {
    return weeklyPlanController(ref);
  }
}

String _$weeklyPlanControllerHash() =>
    r'dc72515aa6074eef6f111b95230d9bc704b891a4';
