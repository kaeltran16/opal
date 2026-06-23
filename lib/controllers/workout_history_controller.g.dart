// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_history_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [WorkoutHistoryState] for [range]: re-emits when the workout
/// store changes. The catalog and routines are awaited once via `.future`.

@ProviderFor(workoutHistory)
const workoutHistoryProvider = WorkoutHistoryFamily._();

/// Streams the [WorkoutHistoryState] for [range]: re-emits when the workout
/// store changes. The catalog and routines are awaited once via `.future`.

final class WorkoutHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutHistoryState>,
          WorkoutHistoryState,
          Stream<WorkoutHistoryState>
        >
    with
        $FutureModifier<WorkoutHistoryState>,
        $StreamProvider<WorkoutHistoryState> {
  /// Streams the [WorkoutHistoryState] for [range]: re-emits when the workout
  /// store changes. The catalog and routines are awaited once via `.future`.
  const WorkoutHistoryProvider._({
    required WorkoutHistoryFamily super.from,
    required WorkoutHistoryRange super.argument,
  }) : super(
         retry: null,
         name: r'workoutHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutHistoryHash();

  @override
  String toString() {
    return r'workoutHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<WorkoutHistoryState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WorkoutHistoryState> create(Ref ref) {
    final argument = this.argument as WorkoutHistoryRange;
    return workoutHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutHistoryHash() => r'00000000000000000000000000000000workout1';

/// Streams the [WorkoutHistoryState] for [range]: re-emits when the workout
/// store changes. The catalog and routines are awaited once via `.future`.

final class WorkoutHistoryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<WorkoutHistoryState>, WorkoutHistoryRange> {
  const WorkoutHistoryFamily._()
    : super(
        retry: null,
        name: r'workoutHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Streams the [WorkoutHistoryState] for [range]: re-emits when the workout
  /// store changes. The catalog and routines are awaited once via `.future`.

  WorkoutHistoryProvider call(WorkoutHistoryRange range) =>
      WorkoutHistoryProvider._(argument: range, from: this);

  @override
  String toString() => r'workoutHistoryProvider';
}
