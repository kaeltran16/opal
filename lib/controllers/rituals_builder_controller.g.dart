// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rituals_builder_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams all routines (in display order) and owns add/edit/delete/reorder for
/// the Rituals Builder. Mirrors [RitualsController]'s streaming idiom; writes go
/// straight through [RitualRepository] and the live stream drives the UI.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.

@ProviderFor(RitualsBuilderController)
const ritualsBuilderControllerProvider = RitualsBuilderControllerProvider._();

/// Streams all routines (in display order) and owns add/edit/delete/reorder for
/// the Rituals Builder. Mirrors [RitualsController]'s streaming idiom; writes go
/// straight through [RitualRepository] and the live stream drives the UI.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.
final class RitualsBuilderControllerProvider
    extends
        $StreamNotifierProvider<RitualsBuilderController, List<RitualRoutine>> {
  /// Streams all routines (in display order) and owns add/edit/delete/reorder for
  /// the Rituals Builder. Mirrors [RitualsController]'s streaming idiom; writes go
  /// straight through [RitualRepository] and the live stream drives the UI.
  ///
  /// No retry: a failing local query would fail again, and retrying holds the
  /// screen on loading.
  const RitualsBuilderControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'ritualsBuilderControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ritualsBuilderControllerHash();

  @$internal
  @override
  RitualsBuilderController create() => RitualsBuilderController();
}

String _$ritualsBuilderControllerHash() =>
    r'984acb580a08d492857e68a1d3ee325a041ef43d';

/// Streams all routines (in display order) and owns add/edit/delete/reorder for
/// the Rituals Builder. Mirrors [RitualsController]'s streaming idiom; writes go
/// straight through [RitualRepository] and the live stream drives the UI.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.

abstract class _$RitualsBuilderController
    extends $StreamNotifier<List<RitualRoutine>> {
  Stream<List<RitualRoutine>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<RitualRoutine>>, List<RitualRoutine>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<RitualRoutine>>, List<RitualRoutine>>,
              AsyncValue<List<RitualRoutine>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
