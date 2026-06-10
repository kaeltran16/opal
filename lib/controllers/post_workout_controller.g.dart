// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_workout_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Pal post-workout note for an *unsaved* [workout]. Separate from
/// [workoutNoteProvider] (which loads by id from the repo) because the summary
/// shows before the workout is persisted; it spins independently of the stats.

@ProviderFor(postWorkoutNote)
const postWorkoutNoteProvider = PostWorkoutNoteFamily._();

/// The Pal post-workout note for an *unsaved* [workout]. Separate from
/// [workoutNoteProvider] (which loads by id from the repo) because the summary
/// shows before the workout is persisted; it spins independently of the stats.

final class PostWorkoutNoteProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The Pal post-workout note for an *unsaved* [workout]. Separate from
  /// [workoutNoteProvider] (which loads by id from the repo) because the summary
  /// shows before the workout is persisted; it spins independently of the stats.
  const PostWorkoutNoteProvider._({
    required PostWorkoutNoteFamily super.from,
    required Workout super.argument,
  }) : super(
         retry: null,
         name: r'postWorkoutNoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$postWorkoutNoteHash();

  @override
  String toString() {
    return r'postWorkoutNoteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as Workout;
    return postWorkoutNote(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PostWorkoutNoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$postWorkoutNoteHash() => r'022191598dad02310ea84a64d8caedaf26435aa5';

/// The Pal post-workout note for an *unsaved* [workout]. Separate from
/// [workoutNoteProvider] (which loads by id from the repo) because the summary
/// shows before the workout is persisted; it spins independently of the stats.

final class PostWorkoutNoteFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, Workout> {
  const PostWorkoutNoteFamily._()
    : super(
        retry: null,
        name: r'postWorkoutNoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The Pal post-workout note for an *unsaved* [workout]. Separate from
  /// [workoutNoteProvider] (which loads by id from the repo) because the summary
  /// shows before the workout is persisted; it spins independently of the stats.

  PostWorkoutNoteProvider call(Workout workout) =>
      PostWorkoutNoteProvider._(argument: workout, from: this);

  @override
  String toString() => r'postWorkoutNoteProvider';
}

/// Owns the one-shot save of a finished session (screen 10). [save] writes the
/// [Workout] and its linked move [Entry] (plan SF-5) in repository order, then
/// latches [SaveState.saved] so the button can't double-write. Only completed
/// sets are persisted — planned-but-unlogged sets are dropped, and stored sets
/// get fresh ids so re-running the same routine never collides on a set id.

@ProviderFor(PostWorkoutController)
const postWorkoutControllerProvider = PostWorkoutControllerProvider._();

/// Owns the one-shot save of a finished session (screen 10). [save] writes the
/// [Workout] and its linked move [Entry] (plan SF-5) in repository order, then
/// latches [SaveState.saved] so the button can't double-write. Only completed
/// sets are persisted — planned-but-unlogged sets are dropped, and stored sets
/// get fresh ids so re-running the same routine never collides on a set id.
final class PostWorkoutControllerProvider
    extends $NotifierProvider<PostWorkoutController, SaveState> {
  /// Owns the one-shot save of a finished session (screen 10). [save] writes the
  /// [Workout] and its linked move [Entry] (plan SF-5) in repository order, then
  /// latches [SaveState.saved] so the button can't double-write. Only completed
  /// sets are persisted — planned-but-unlogged sets are dropped, and stored sets
  /// get fresh ids so re-running the same routine never collides on a set id.
  const PostWorkoutControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'postWorkoutControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$postWorkoutControllerHash();

  @$internal
  @override
  PostWorkoutController create() => PostWorkoutController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveState>(value),
    );
  }
}

String _$postWorkoutControllerHash() =>
    r'3ee28b3a9ed626aee4e2714ff3bb44a2d9881bfe';

/// Owns the one-shot save of a finished session (screen 10). [save] writes the
/// [Workout] and its linked move [Entry] (plan SF-5) in repository order, then
/// latches [SaveState.saved] so the button can't double-write. Only completed
/// sets are persisted — planned-but-unlogged sets are dropped, and stored sets
/// get fresh ids so re-running the same routine never collides on a set id.

abstract class _$PostWorkoutController extends $Notifier<SaveState> {
  SaveState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SaveState, SaveState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SaveState, SaveState>,
              SaveState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
