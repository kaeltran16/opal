// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The live routines list (display-ordered). Watched by [profileStats] so a
/// routine edit (e.g. a streak change) re-emits the stats on its own.

@ProviderFor(profileRoutines)
const profileRoutinesProvider = ProfileRoutinesProvider._();

/// The live routines list (display-ordered). Watched by [profileStats] so a
/// routine edit (e.g. a streak change) re-emits the stats on its own.

final class ProfileRoutinesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RitualRoutine>>,
          List<RitualRoutine>,
          Stream<List<RitualRoutine>>
        >
    with
        $FutureModifier<List<RitualRoutine>>,
        $StreamProvider<List<RitualRoutine>> {
  /// The live routines list (display-ordered). Watched by [profileStats] so a
  /// routine edit (e.g. a streak change) re-emits the stats on its own.
  const ProfileRoutinesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRoutinesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRoutinesHash();

  @$internal
  @override
  $StreamProviderElement<List<RitualRoutine>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RitualRoutine>> create(Ref ref) {
    return profileRoutines(ref);
  }
}

String _$profileRoutinesHash() => r'c7ecfdd83af76bae3fcc12b6616d78bafd03ed72';

/// Streams the [ProfileStats] for the "You" tab. Reactive: re-emits whenever the
/// entries or rituals change. Reads all entries (year stats span the whole year,
/// not just today) and folds them via [buildProfileStats].
///
/// Combines the two live sources by `await for`-ing entries while watching the
/// routines stream: a routine change rebuilds this provider (so the longest-
/// streak stat refreshes), and entry edits drive the inner loop.

@ProviderFor(profileStats)
const profileStatsProvider = ProfileStatsProvider._();

/// Streams the [ProfileStats] for the "You" tab. Reactive: re-emits whenever the
/// entries or rituals change. Reads all entries (year stats span the whole year,
/// not just today) and folds them via [buildProfileStats].
///
/// Combines the two live sources by `await for`-ing entries while watching the
/// routines stream: a routine change rebuilds this provider (so the longest-
/// streak stat refreshes), and entry edits drive the inner loop.

final class ProfileStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileStats>,
          ProfileStats,
          Stream<ProfileStats>
        >
    with $FutureModifier<ProfileStats>, $StreamProvider<ProfileStats> {
  /// Streams the [ProfileStats] for the "You" tab. Reactive: re-emits whenever the
  /// entries or rituals change. Reads all entries (year stats span the whole year,
  /// not just today) and folds them via [buildProfileStats].
  ///
  /// Combines the two live sources by `await for`-ing entries while watching the
  /// routines stream: a routine change rebuilds this provider (so the longest-
  /// streak stat refreshes), and entry edits drive the inner loop.
  const ProfileStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileStatsHash();

  @$internal
  @override
  $StreamProviderElement<ProfileStats> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ProfileStats> create(Ref ref) {
    return profileStats(ref);
  }
}

String _$profileStatsHash() => r'dbcfa8f5b4eeaaa3b7daf770c2b6235b4f7a3b0c';
