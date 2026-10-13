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
/// awaits routines via `.future` — matching `moveState`'s pattern over the same
/// small tables — so a saved, generated or deleted routine re-emits too.

@ProviderFor(startWorkout)
const startWorkoutProvider = StartWorkoutProvider._();

/// Streams the [StartWorkoutState] — re-emits when routines or workout history
/// change. Splits on [RoutineTag.cardio]: cardio rows vs. everything else
/// (strength grid). `lastDone` is derived from the newest matching workout per
/// routine id (not stored), so it can never drift from real history.
///
/// Drives off the live workouts stream (so "last done" stays current) and
/// awaits routines via `.future` — matching `moveState`'s pattern over the same
/// small tables — so a saved, generated or deleted routine re-emits too.

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
  /// awaits routines via `.future` — matching `moveState`'s pattern over the same
  /// small tables — so a saved, generated or deleted routine re-emits too.
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

String _$startWorkoutHash() => r'f0e847e28181d9e050883a3b1ff9c919af94f16e';

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

String _$palPickControllerHash() => r'09957af6dc0a774e3a4d3230cd4963b726d0d6c9';

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
