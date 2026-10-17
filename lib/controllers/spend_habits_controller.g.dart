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

String _$spendHabitsHash() => r'd21c4b372572105a97c162ae629281e6489e841c';

/// The composer's predicted logs: [spendHabits]' picks minus those already
/// logged this daypart, plus the [logged] titles themselves so the composer can
/// drop a Pal chip for them too (Pal's chips may be a cached reply from before
/// the log).

@ProviderFor(composerHabits)
const composerHabitsProvider = ComposerHabitsProvider._();

/// The composer's predicted logs: [spendHabits]' picks minus those already
/// logged this daypart, plus the [logged] titles themselves so the composer can
/// drop a Pal chip for them too (Pal's chips may be a cached reply from before
/// the log).

final class ComposerHabitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<({Set<String> logged, List<sh.HabitPick> picks})>,
          ({Set<String> logged, List<sh.HabitPick> picks}),
          Stream<({Set<String> logged, List<sh.HabitPick> picks})>
        >
    with
        $FutureModifier<({Set<String> logged, List<sh.HabitPick> picks})>,
        $StreamProvider<({Set<String> logged, List<sh.HabitPick> picks})> {
  /// The composer's predicted logs: [spendHabits]' picks minus those already
  /// logged this daypart, plus the [logged] titles themselves so the composer can
  /// drop a Pal chip for them too (Pal's chips may be a cached reply from before
  /// the log).
  const ComposerHabitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'composerHabitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$composerHabitsHash();

  @$internal
  @override
  $StreamProviderElement<({Set<String> logged, List<sh.HabitPick> picks})>
  $createElement($ProviderPointer pointer) => $StreamProviderElement(pointer);

  @override
  Stream<({Set<String> logged, List<sh.HabitPick> picks})> create(Ref ref) {
    return composerHabits(ref);
  }
}

String _$composerHabitsHash() => r'1447748fd86a1cd1234c28f00f61844f8833de08';
