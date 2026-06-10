// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [WorkoutDetailState] for [workoutId]: the session aggregate, its
/// per-exercise set groups (names resolved via the catalog), and the trailing
/// 8-week volume buckets computed from all workouts. Re-emits when the workout
/// store changes.

@ProviderFor(workoutDetail)
const workoutDetailProvider = WorkoutDetailFamily._();

/// Streams the [WorkoutDetailState] for [workoutId]: the session aggregate, its
/// per-exercise set groups (names resolved via the catalog), and the trailing
/// 8-week volume buckets computed from all workouts. Re-emits when the workout
/// store changes.

final class WorkoutDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutDetailState>,
          WorkoutDetailState,
          Stream<WorkoutDetailState>
        >
    with
        $FutureModifier<WorkoutDetailState>,
        $StreamProvider<WorkoutDetailState> {
  /// Streams the [WorkoutDetailState] for [workoutId]: the session aggregate, its
  /// per-exercise set groups (names resolved via the catalog), and the trailing
  /// 8-week volume buckets computed from all workouts. Re-emits when the workout
  /// store changes.
  const WorkoutDetailProvider._({
    required WorkoutDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutDetailHash();

  @override
  String toString() {
    return r'workoutDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<WorkoutDetailState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WorkoutDetailState> create(Ref ref) {
    final argument = this.argument as String;
    return workoutDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutDetailHash() => r'2875cb6720a518b2ab6f671c4bca0cbe38859af6';

/// Streams the [WorkoutDetailState] for [workoutId]: the session aggregate, its
/// per-exercise set groups (names resolved via the catalog), and the trailing
/// 8-week volume buckets computed from all workouts. Re-emits when the workout
/// store changes.

final class WorkoutDetailFamily extends $Family
    with $FunctionalFamilyOverride<Stream<WorkoutDetailState>, String> {
  const WorkoutDetailFamily._()
    : super(
        retry: null,
        name: r'workoutDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Streams the [WorkoutDetailState] for [workoutId]: the session aggregate, its
  /// per-exercise set groups (names resolved via the catalog), and the trailing
  /// 8-week volume buckets computed from all workouts. Re-emits when the workout
  /// store changes.

  WorkoutDetailProvider call(String workoutId) =>
      WorkoutDetailProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'workoutDetailProvider';
}

/// The Pal post-workout note for [workoutId], with a loading state. Separate
/// from [workoutDetailProvider] so the note can spin independently of the
/// (reactive) stats.

@ProviderFor(workoutNote)
const workoutNoteProvider = WorkoutNoteFamily._();

/// The Pal post-workout note for [workoutId], with a loading state. Separate
/// from [workoutDetailProvider] so the note can spin independently of the
/// (reactive) stats.

final class WorkoutNoteProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The Pal post-workout note for [workoutId], with a loading state. Separate
  /// from [workoutDetailProvider] so the note can spin independently of the
  /// (reactive) stats.
  const WorkoutNoteProvider._({
    required WorkoutNoteFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutNoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutNoteHash();

  @override
  String toString() {
    return r'workoutNoteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String;
    return workoutNote(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutNoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutNoteHash() => r'878955e503eada35472c728427b1bb035328c314';

/// The Pal post-workout note for [workoutId], with a loading state. Separate
/// from [workoutDetailProvider] so the note can spin independently of the
/// (reactive) stats.

final class WorkoutNoteFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  const WorkoutNoteFamily._()
    : super(
        retry: null,
        name: r'workoutNoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The Pal post-workout note for [workoutId], with a loading state. Separate
  /// from [workoutDetailProvider] so the note can spin independently of the
  /// (reactive) stats.

  WorkoutNoteProvider call(String workoutId) =>
      WorkoutNoteProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'workoutNoteProvider';
}
