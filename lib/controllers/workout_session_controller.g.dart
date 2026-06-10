// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Wraps the pure [WorkoutSession] engine in a Riverpod Notifier for screen 09.
///
/// Loads the routine + exercise catalog (keyed by [routineId]), constructs one
/// engine, and exposes an immutable [ActiveSessionState] snapshot. Owns the real
/// rest `Timer.periodic`: while resting it ticks the engine each second, re-emits
/// the snapshot, and fires haptic cues at 10s (medium) and 0s (success). The
/// timer is cancelled on rest end and on dispose. Commands delegate to the engine
/// and re-snapshot; persistence on [finish] is U14's concern (plan SF-5).

@ProviderFor(WorkoutSessionController)
const workoutSessionControllerProvider = WorkoutSessionControllerFamily._();

/// Wraps the pure [WorkoutSession] engine in a Riverpod Notifier for screen 09.
///
/// Loads the routine + exercise catalog (keyed by [routineId]), constructs one
/// engine, and exposes an immutable [ActiveSessionState] snapshot. Owns the real
/// rest `Timer.periodic`: while resting it ticks the engine each second, re-emits
/// the snapshot, and fires haptic cues at 10s (medium) and 0s (success). The
/// timer is cancelled on rest end and on dispose. Commands delegate to the engine
/// and re-snapshot; persistence on [finish] is U14's concern (plan SF-5).
final class WorkoutSessionControllerProvider
    extends
        $AsyncNotifierProvider<WorkoutSessionController, ActiveSessionState> {
  /// Wraps the pure [WorkoutSession] engine in a Riverpod Notifier for screen 09.
  ///
  /// Loads the routine + exercise catalog (keyed by [routineId]), constructs one
  /// engine, and exposes an immutable [ActiveSessionState] snapshot. Owns the real
  /// rest `Timer.periodic`: while resting it ticks the engine each second, re-emits
  /// the snapshot, and fires haptic cues at 10s (medium) and 0s (success). The
  /// timer is cancelled on rest end and on dispose. Commands delegate to the engine
  /// and re-snapshot; persistence on [finish] is U14's concern (plan SF-5).
  const WorkoutSessionControllerProvider._({
    required WorkoutSessionControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutSessionControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutSessionControllerHash();

  @override
  String toString() {
    return r'workoutSessionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorkoutSessionController create() => WorkoutSessionController();

  @override
  bool operator ==(Object other) {
    return other is WorkoutSessionControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutSessionControllerHash() =>
    r'd10284e5792a1262641cb4b44a9b452d371d35e2';

/// Wraps the pure [WorkoutSession] engine in a Riverpod Notifier for screen 09.
///
/// Loads the routine + exercise catalog (keyed by [routineId]), constructs one
/// engine, and exposes an immutable [ActiveSessionState] snapshot. Owns the real
/// rest `Timer.periodic`: while resting it ticks the engine each second, re-emits
/// the snapshot, and fires haptic cues at 10s (medium) and 0s (success). The
/// timer is cancelled on rest end and on dispose. Commands delegate to the engine
/// and re-snapshot; persistence on [finish] is U14's concern (plan SF-5).

final class WorkoutSessionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          WorkoutSessionController,
          AsyncValue<ActiveSessionState>,
          ActiveSessionState,
          FutureOr<ActiveSessionState>,
          String
        > {
  const WorkoutSessionControllerFamily._()
    : super(
        retry: null,
        name: r'workoutSessionControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Wraps the pure [WorkoutSession] engine in a Riverpod Notifier for screen 09.
  ///
  /// Loads the routine + exercise catalog (keyed by [routineId]), constructs one
  /// engine, and exposes an immutable [ActiveSessionState] snapshot. Owns the real
  /// rest `Timer.periodic`: while resting it ticks the engine each second, re-emits
  /// the snapshot, and fires haptic cues at 10s (medium) and 0s (success). The
  /// timer is cancelled on rest end and on dispose. Commands delegate to the engine
  /// and re-snapshot; persistence on [finish] is U14's concern (plan SF-5).

  WorkoutSessionControllerProvider call(String routineId) =>
      WorkoutSessionControllerProvider._(argument: routineId, from: this);

  @override
  String toString() => r'workoutSessionControllerProvider';
}

/// Wraps the pure [WorkoutSession] engine in a Riverpod Notifier for screen 09.
///
/// Loads the routine + exercise catalog (keyed by [routineId]), constructs one
/// engine, and exposes an immutable [ActiveSessionState] snapshot. Owns the real
/// rest `Timer.periodic`: while resting it ticks the engine each second, re-emits
/// the snapshot, and fires haptic cues at 10s (medium) and 0s (success). The
/// timer is cancelled on rest end and on dispose. Commands delegate to the engine
/// and re-snapshot; persistence on [finish] is U14's concern (plan SF-5).

abstract class _$WorkoutSessionController
    extends $AsyncNotifier<ActiveSessionState> {
  late final _$args = ref.$arg as String;
  String get routineId => _$args;

  FutureOr<ActiveSessionState> build(String routineId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<ActiveSessionState>, ActiveSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ActiveSessionState>, ActiveSessionState>,
              AsyncValue<ActiveSessionState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
