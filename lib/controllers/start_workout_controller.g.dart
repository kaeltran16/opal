// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'start_workout_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [StartWorkoutState] — re-emits when routines or workout history
/// change. Splits on [RoutineTag.cardio]: cardio rows vs. everything else
/// (strength grid). `lastDone` is derived from the newest matching workout per
/// routine id (not stored), so it can never drift from real history.
///
/// Drives off the live workouts stream (so "last done" stays current) and
/// re-reads routines each tick — matching `moveState`'s pattern over the same
/// small tables.

@ProviderFor(startWorkout)
const startWorkoutProvider = StartWorkoutProvider._();

/// Streams the [StartWorkoutState] — re-emits when routines or workout history
/// change. Splits on [RoutineTag.cardio]: cardio rows vs. everything else
/// (strength grid). `lastDone` is derived from the newest matching workout per
/// routine id (not stored), so it can never drift from real history.
///
/// Drives off the live workouts stream (so "last done" stays current) and
/// re-reads routines each tick — matching `moveState`'s pattern over the same
/// small tables.

final class StartWorkoutProvider
    extends
        $FunctionalProvider<
          AsyncValue<StartWorkoutState>,
          StartWorkoutState,
          Stream<StartWorkoutState>
        >
    with
        $FutureModifier<StartWorkoutState>,
        $StreamProvider<StartWorkoutState> {
  /// Streams the [StartWorkoutState] — re-emits when routines or workout history
  /// change. Splits on [RoutineTag.cardio]: cardio rows vs. everything else
  /// (strength grid). `lastDone` is derived from the newest matching workout per
  /// routine id (not stored), so it can never drift from real history.
  ///
  /// Drives off the live workouts stream (so "last done" stays current) and
  /// re-reads routines each tick — matching `moveState`'s pattern over the same
  /// small tables.
  const StartWorkoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'startWorkoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$startWorkoutHash();

  @$internal
  @override
  $StreamProviderElement<StartWorkoutState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<StartWorkoutState> create(Ref ref) {
    return startWorkout(ref);
  }
}

String _$startWorkoutHash() => r'6efe1275b34721904b5378d3c5b2c3f321f70c00';

/// Drives the "Pal's pick" card: holds the current [WorkoutSuggestion] with a
/// loading state and re-requests a different pick on [another]. Mirrors the
/// monthly-review narrative controller (mock-service call + regenerate).

@ProviderFor(PalPickController)
const palPickControllerProvider = PalPickControllerProvider._();

/// Drives the "Pal's pick" card: holds the current [WorkoutSuggestion] with a
/// loading state and re-requests a different pick on [another]. Mirrors the
/// monthly-review narrative controller (mock-service call + regenerate).
final class PalPickControllerProvider
    extends $AsyncNotifierProvider<PalPickController, WorkoutSuggestion> {
  /// Drives the "Pal's pick" card: holds the current [WorkoutSuggestion] with a
  /// loading state and re-requests a different pick on [another]. Mirrors the
  /// monthly-review narrative controller (mock-service call + regenerate).
  const PalPickControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'palPickControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$palPickControllerHash();

  @$internal
  @override
  PalPickController create() => PalPickController();
}

String _$palPickControllerHash() => r'a83e1f6c14205963601762aa34ba9785b585f4b4';

/// Drives the "Pal's pick" card: holds the current [WorkoutSuggestion] with a
/// loading state and re-requests a different pick on [another]. Mirrors the
/// monthly-review narrative controller (mock-service call + regenerate).

abstract class _$PalPickController extends $AsyncNotifier<WorkoutSuggestion> {
  FutureOr<WorkoutSuggestion> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<WorkoutSuggestion>, WorkoutSuggestion>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WorkoutSuggestion>, WorkoutSuggestion>,
              AsyncValue<WorkoutSuggestion>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
