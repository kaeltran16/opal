// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'move_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Move view model off the live workouts stream, plus the routines
/// and non-workout move entries re-read each tick. Re-emits whenever the
/// workouts table changes.

@ProviderFor(moveState)
const moveStateProvider = MoveStateProvider._();

/// Streams the Move view model off the live workouts stream, plus the routines
/// and non-workout move entries re-read each tick. Re-emits whenever the
/// workouts table changes.

final class MoveStateProvider
    extends
        $FunctionalProvider<AsyncValue<MoveState>, MoveState, Stream<MoveState>>
    with $FutureModifier<MoveState>, $StreamProvider<MoveState> {
  /// Streams the Move view model off the live workouts stream, plus the routines
  /// and non-workout move entries re-read each tick. Re-emits whenever the
  /// workouts table changes.
  const MoveStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moveStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moveStateHash();

  @$internal
  @override
  $StreamProviderElement<MoveState> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<MoveState> create(Ref ref) {
    return moveState(ref);
  }
}

String _$moveStateHash() => r'2348241cdf103e867d25be4cf73da906d373a1d1';
