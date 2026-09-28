// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spend_habits_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's recurring expenses for the current daypart — the local source for
/// New Entry's quick picks.
///
/// Reactive: re-emits whenever in-window entries change, so logging something
/// feeds straight back into the picks. `now` is captured per subscription, so
/// the daypart is the one in force when the surface opened.

@ProviderFor(spendHabits)
const spendHabitsProvider = SpendHabitsProvider._();

/// The user's recurring expenses for the current daypart — the local source for
/// New Entry's quick picks.
///
/// Reactive: re-emits whenever in-window entries change, so logging something
/// feeds straight back into the picks. `now` is captured per subscription, so
/// the daypart is the one in force when the surface opened.

final class SpendHabitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<sh.HabitPick>>,
          List<sh.HabitPick>,
          Stream<List<sh.HabitPick>>
        >
    with
        $FutureModifier<List<sh.HabitPick>>,
        $StreamProvider<List<sh.HabitPick>> {
  /// The user's recurring expenses for the current daypart — the local source for
  /// New Entry's quick picks.
  ///
  /// Reactive: re-emits whenever in-window entries change, so logging something
  /// feeds straight back into the picks. `now` is captured per subscription, so
  /// the daypart is the one in force when the surface opened.
  const SpendHabitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spendHabitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spendHabitsHash();

  @$internal
  @override
  $StreamProviderElement<List<sh.HabitPick>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<sh.HabitPick>> create(Ref ref) {
    return spendHabits(ref);
  }
}

String _$spendHabitsHash() => r'3a4f1e7ac9659771de7182d3dc03a96af66cef7c';
