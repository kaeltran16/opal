// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mood_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Mood view model and owns check-in logging. Mirrors
/// [NutritionController]'s stream-build pattern.

@ProviderFor(MoodController)
const moodControllerProvider = MoodControllerProvider._();

/// Streams the Mood view model and owns check-in logging. Mirrors
/// [NutritionController]'s stream-build pattern.
final class MoodControllerProvider
    extends $StreamNotifierProvider<MoodController, MoodState> {
  /// Streams the Mood view model and owns check-in logging. Mirrors
  /// [NutritionController]'s stream-build pattern.
  const MoodControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moodControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moodControllerHash();

  @$internal
  @override
  MoodController create() => MoodController();
}

String _$moodControllerHash() => r'87b7c9a5787d456b6854e1dcc6ffcf4ce928415a';

/// Streams the Mood view model and owns check-in logging. Mirrors
/// [NutritionController]'s stream-build pattern.

abstract class _$MoodController extends $StreamNotifier<MoodState> {
  Stream<MoodState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<MoodState>, MoodState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MoodState>, MoodState>,
              AsyncValue<MoodState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
