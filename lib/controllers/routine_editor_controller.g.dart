// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the Routine Editor (U21b). Loads an existing routine by [routineId]
/// (or a blank draft when null) plus the catalog, then mutates the draft in
/// place through small setters. [save] persists via [RoutineRepository] —
/// `insert` for a new routine, `update` for an existing one — after re-deriving
/// slot order from list position.

@ProviderFor(RoutineEditorController)
const routineEditorControllerProvider = RoutineEditorControllerFamily._();

/// Drives the Routine Editor (U21b). Loads an existing routine by [routineId]
/// (or a blank draft when null) plus the catalog, then mutates the draft in
/// place through small setters. [save] persists via [RoutineRepository] —
/// `insert` for a new routine, `update` for an existing one — after re-deriving
/// slot order from list position.
final class RoutineEditorControllerProvider
    extends
        $AsyncNotifierProvider<RoutineEditorController, RoutineEditorState> {
  /// Drives the Routine Editor (U21b). Loads an existing routine by [routineId]
  /// (or a blank draft when null) plus the catalog, then mutates the draft in
  /// place through small setters. [save] persists via [RoutineRepository] —
  /// `insert` for a new routine, `update` for an existing one — after re-deriving
  /// slot order from list position.
  const RoutineEditorControllerProvider._({
    required RoutineEditorControllerFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'routineEditorControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$routineEditorControllerHash();

  @override
  String toString() {
    return r'routineEditorControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RoutineEditorController create() => RoutineEditorController();

  @override
  bool operator ==(Object other) {
    return other is RoutineEditorControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$routineEditorControllerHash() =>
    r'37a03f4ee65c280e11eb1eee04022d91028d78f6';

/// Drives the Routine Editor (U21b). Loads an existing routine by [routineId]
/// (or a blank draft when null) plus the catalog, then mutates the draft in
/// place through small setters. [save] persists via [RoutineRepository] —
/// `insert` for a new routine, `update` for an existing one — after re-deriving
/// slot order from list position.

final class RoutineEditorControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          RoutineEditorController,
          AsyncValue<RoutineEditorState>,
          RoutineEditorState,
          FutureOr<RoutineEditorState>,
          String?
        > {
  const RoutineEditorControllerFamily._()
    : super(
        retry: null,
        name: r'routineEditorControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Drives the Routine Editor (U21b). Loads an existing routine by [routineId]
  /// (or a blank draft when null) plus the catalog, then mutates the draft in
  /// place through small setters. [save] persists via [RoutineRepository] —
  /// `insert` for a new routine, `update` for an existing one — after re-deriving
  /// slot order from list position.

  RoutineEditorControllerProvider call(String? routineId) =>
      RoutineEditorControllerProvider._(argument: routineId, from: this);

  @override
  String toString() => r'routineEditorControllerProvider';
}

/// Drives the Routine Editor (U21b). Loads an existing routine by [routineId]
/// (or a blank draft when null) plus the catalog, then mutates the draft in
/// place through small setters. [save] persists via [RoutineRepository] —
/// `insert` for a new routine, `update` for an existing one — after re-deriving
/// slot order from list position.

abstract class _$RoutineEditorController
    extends $AsyncNotifier<RoutineEditorState> {
  late final _$args = ref.$arg as String?;
  String? get routineId => _$args;

  FutureOr<RoutineEditorState> build(String? routineId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<RoutineEditorState>, RoutineEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RoutineEditorState>, RoutineEditorState>,
              AsyncValue<RoutineEditorState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
