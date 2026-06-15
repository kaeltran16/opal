// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The selected timeline mode. Tapping the Today timeline toggle flips it; the
/// [todayState] stream watches it and rebuilds its buckets accordingly.

@ProviderFor(TimelineModeController)
const timelineModeControllerProvider = TimelineModeControllerProvider._();

/// The selected timeline mode. Tapping the Today timeline toggle flips it; the
/// [todayState] stream watches it and rebuilds its buckets accordingly.
final class TimelineModeControllerProvider
    extends $NotifierProvider<TimelineModeController, TimelineMode> {
  /// The selected timeline mode. Tapping the Today timeline toggle flips it; the
  /// [todayState] stream watches it and rebuilds its buckets accordingly.
  const TimelineModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timelineModeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timelineModeControllerHash();

  @$internal
  @override
  TimelineModeController create() => TimelineModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimelineMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimelineMode>(value),
    );
  }
}

String _$timelineModeControllerHash() =>
    r'1e8e82bbdb39c1abf69c4fb1468db8780a0a280f';

/// The selected timeline mode. Tapping the Today timeline toggle flips it; the
/// [todayState] stream watches it and rebuilds its buckets accordingly.

abstract class _$TimelineModeController extends $Notifier<TimelineMode> {
  TimelineMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<TimelineMode, TimelineMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TimelineMode, TimelineMode>,
              TimelineMode,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// The live goals row (defaults until set). Watched by [todayState] so a
/// goals-only edit (budget/targets in Settings) re-emits Today on its own.

@ProviderFor(goalsStream)
const goalsStreamProvider = GoalsStreamProvider._();

/// The live goals row (defaults until set). Watched by [todayState] so a
/// goals-only edit (budget/targets in Settings) re-emits Today on its own.

final class GoalsStreamProvider
    extends $FunctionalProvider<AsyncValue<Goals>, Goals, Stream<Goals>>
    with $FutureModifier<Goals>, $StreamProvider<Goals> {
  /// The live goals row (defaults until set). Watched by [todayState] so a
  /// goals-only edit (budget/targets in Settings) re-emits Today on its own.
  const GoalsStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'goalsStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$goalsStreamHash();

  @$internal
  @override
  $StreamProviderElement<Goals> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Goals> create(Ref ref) {
    return goalsStream(ref);
  }
}

String _$goalsStreamHash() => r'7bdb2c2e9e4d0a113140641c242ed65d89263c2d';

/// Streams the Today view model from the live entries + goals + routines
/// streams. Re-emits whenever any changes: the entries `await for` drives entry
/// edits, and watching [goalsStreamProvider] / [ritualRoutinesStreamProvider]
/// rebuilds this provider on a goals- or routine-only edit.

@ProviderFor(todayState)
const todayStateProvider = TodayStateProvider._();

/// Streams the Today view model from the live entries + goals + routines
/// streams. Re-emits whenever any changes: the entries `await for` drives entry
/// edits, and watching [goalsStreamProvider] / [ritualRoutinesStreamProvider]
/// rebuilds this provider on a goals- or routine-only edit.

final class TodayStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<TodayState>,
          TodayState,
          Stream<TodayState>
        >
    with $FutureModifier<TodayState>, $StreamProvider<TodayState> {
  /// Streams the Today view model from the live entries + goals + routines
  /// streams. Re-emits whenever any changes: the entries `await for` drives entry
  /// edits, and watching [goalsStreamProvider] / [ritualRoutinesStreamProvider]
  /// rebuilds this provider on a goals- or routine-only edit.
  const TodayStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayStateHash();

  @$internal
  @override
  $StreamProviderElement<TodayState> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<TodayState> create(Ref ref) {
    return todayState(ref);
  }
}

String _$todayStateHash() => r'dbe401dcc08564b9dbfa3ecc43f982b07b45a99a';
