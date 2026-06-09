// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the Today view model: combines the live entries + goals streams with
/// the day's health sample. Re-emits whenever the DB changes.

@ProviderFor(todayState)
const todayStateProvider = TodayStateProvider._();

/// Streams the Today view model: combines the live entries + goals streams with
/// the day's health sample. Re-emits whenever the DB changes.

final class TodayStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<TodayState>,
          TodayState,
          Stream<TodayState>
        >
    with $FutureModifier<TodayState>, $StreamProvider<TodayState> {
  /// Streams the Today view model: combines the live entries + goals streams with
  /// the day's health sample. Re-emits whenever the DB changes.
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

String _$todayStateHash() => r'858009e7312308fd2809fa52ca6ea7adb9f9d5c4';
