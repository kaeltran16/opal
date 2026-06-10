// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rituals_builder_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams all rituals (in display order) and owns add/edit/delete/reorder for
/// the Rituals Builder. Mirrors [RitualsController]'s streaming idiom; writes go
/// straight through [RitualRepository] and the live stream drives the UI.

@ProviderFor(RitualsBuilderController)
const ritualsBuilderControllerProvider = RitualsBuilderControllerProvider._();

/// Streams all rituals (in display order) and owns add/edit/delete/reorder for
/// the Rituals Builder. Mirrors [RitualsController]'s streaming idiom; writes go
/// straight through [RitualRepository] and the live stream drives the UI.
final class RitualsBuilderControllerProvider
    extends $StreamNotifierProvider<RitualsBuilderController, List<Ritual>> {
  /// Streams all rituals (in display order) and owns add/edit/delete/reorder for
  /// the Rituals Builder. Mirrors [RitualsController]'s streaming idiom; writes go
  /// straight through [RitualRepository] and the live stream drives the UI.
  const RitualsBuilderControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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
    r'8f662b4b0e83629d22dbf959fad4922bbb06195a';

/// Streams all rituals (in display order) and owns add/edit/delete/reorder for
/// the Rituals Builder. Mirrors [RitualsController]'s streaming idiom; writes go
/// straight through [RitualRepository] and the live stream drives the UI.

abstract class _$RitualsBuilderController
    extends $StreamNotifier<List<Ritual>> {
  Stream<List<Ritual>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Ritual>>, List<Ritual>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Ritual>>, List<Ritual>>,
              AsyncValue<List<Ritual>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
