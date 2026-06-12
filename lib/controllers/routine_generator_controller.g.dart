// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_generator_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the Routine Generator (Handoff #2). Holds the exercise catalog (the
/// `available` list passed to Pal and the source for resolving names/icons in
/// the preview), and a [RoutineGeneratorState] union the screen renders.
///
/// [generate] calls the [PalService.generateRoutine] seam (mirrors the
/// Pal-pick loading pattern). [save] persists the previewed draft as a real
/// [Routine] via [RoutineRepository.insert] — the same create path the Routine
/// Editor uses — assigning empty ids so the repo mints UUIDs.

@ProviderFor(RoutineGeneratorController)
const routineGeneratorControllerProvider =
    RoutineGeneratorControllerProvider._();

/// Drives the Routine Generator (Handoff #2). Holds the exercise catalog (the
/// `available` list passed to Pal and the source for resolving names/icons in
/// the preview), and a [RoutineGeneratorState] union the screen renders.
///
/// [generate] calls the [PalService.generateRoutine] seam (mirrors the
/// Pal-pick loading pattern). [save] persists the previewed draft as a real
/// [Routine] via [RoutineRepository.insert] — the same create path the Routine
/// Editor uses — assigning empty ids so the repo mints UUIDs.
final class RoutineGeneratorControllerProvider
    extends
        $NotifierProvider<RoutineGeneratorController, RoutineGeneratorState> {
  /// Drives the Routine Generator (Handoff #2). Holds the exercise catalog (the
  /// `available` list passed to Pal and the source for resolving names/icons in
  /// the preview), and a [RoutineGeneratorState] union the screen renders.
  ///
  /// [generate] calls the [PalService.generateRoutine] seam (mirrors the
  /// Pal-pick loading pattern). [save] persists the previewed draft as a real
  /// [Routine] via [RoutineRepository.insert] — the same create path the Routine
  /// Editor uses — assigning empty ids so the repo mints UUIDs.
  const RoutineGeneratorControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routineGeneratorControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routineGeneratorControllerHash();

  @$internal
  @override
  RoutineGeneratorController create() => RoutineGeneratorController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoutineGeneratorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoutineGeneratorState>(value),
    );
  }
}

String _$routineGeneratorControllerHash() =>
    r'c676a8b6e77f739f3b6a2073a42ef4c22c5d7e88';

/// Drives the Routine Generator (Handoff #2). Holds the exercise catalog (the
/// `available` list passed to Pal and the source for resolving names/icons in
/// the preview), and a [RoutineGeneratorState] union the screen renders.
///
/// [generate] calls the [PalService.generateRoutine] seam (mirrors the
/// Pal-pick loading pattern). [save] persists the previewed draft as a real
/// [Routine] via [RoutineRepository.insert] — the same create path the Routine
/// Editor uses — assigning empty ids so the repo mints UUIDs.

abstract class _$RoutineGeneratorController
    extends $Notifier<RoutineGeneratorState> {
  RoutineGeneratorState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<RoutineGeneratorState, RoutineGeneratorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RoutineGeneratorState, RoutineGeneratorState>,
              RoutineGeneratorState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
