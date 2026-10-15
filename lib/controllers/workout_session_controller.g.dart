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
///
/// The session outlives its screen (minimise, browse other tabs, Resume) until
/// [finish] releases it.

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
///
/// The session outlives its screen (minimise, browse other tabs, Resume) until
/// [finish] releases it.
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
  ///
  /// The session outlives its screen (minimise, browse other tabs, Resume) until
  /// [finish] releases it.
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
    r'812eaec106b0b3203baa0f07e76329efecf3a640';

/// Wraps the pure [WorkoutSession] engine in a Riverpod Notifier for screen 09.
///
/// Loads the routine + exercise catalog (keyed by [routineId]), constructs one
/// engine, and exposes an immutable [ActiveSessionState] snapshot. Owns the real
/// rest `Timer.periodic`: while resting it ticks the engine each second, re-emits
/// the snapshot, and fires haptic cues at 10s (medium) and 0s (success). The
/// timer is cancelled on rest end and on dispose. Commands delegate to the engine
/// and re-snapshot; persistence on [finish] is U14's concern (plan SF-5).
///
/// The session outlives its screen (minimise, browse other tabs, Resume) until
/// [finish] releases it.

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
  ///
  /// The session outlives its screen (minimise, browse other tabs, Resume) until
  /// [finish] releases it.

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
///
/// The session outlives its screen (minimise, browse other tabs, Resume) until
/// [finish] releases it.

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

/// The routine id of the session that is running, or null. Only one runs at a
/// time; `openWorkoutSession` reads it to resume rather than start another.

@ProviderFor(RunningSession)
const runningSessionProvider = RunningSessionProvider._();

/// The routine id of the session that is running, or null. Only one runs at a
/// time; `openWorkoutSession` reads it to resume rather than start another.
final class RunningSessionProvider
    extends $NotifierProvider<RunningSession, String?> {
  /// The routine id of the session that is running, or null. Only one runs at a
  /// time; `openWorkoutSession` reads it to resume rather than start another.
  const RunningSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningSessionHash();

  @$internal
  @override
  RunningSession create() => RunningSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$runningSessionHash() => r'a1cd3a99e847a51b0b5b2326acdef1f4f0429536';

/// The routine id of the session that is running, or null. Only one runs at a
/// time; `openWorkoutSession` reads it to resume rather than start another.

abstract class _$RunningSession extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
