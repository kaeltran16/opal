// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

/// Streams the Today view model from the live entries + goals streams.
/// Re-emits whenever either changes: the entries `await for` drives entry
/// edits, and watching [goalsStreamProvider] rebuilds this provider on a
/// goals-only edit.

@ProviderFor(todayState)
const todayStateProvider = TodayStateProvider._();

/// Streams the Today view model from the live entries + goals streams.
/// Re-emits whenever either changes: the entries `await for` drives entry
/// edits, and watching [goalsStreamProvider] rebuilds this provider on a
/// goals-only edit.

final class TodayStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<TodayState>,
          TodayState,
          Stream<TodayState>
        >
    with $FutureModifier<TodayState>, $StreamProvider<TodayState> {
  /// Streams the Today view model from the live entries + goals streams.
  /// Re-emits whenever either changes: the entries `await for` drives entry
  /// edits, and watching [goalsStreamProvider] rebuilds this provider on a
  /// goals-only edit.
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

String _$todayStateHash() => r'44a83932629ff08a262a339bfd705f516b696fce';
