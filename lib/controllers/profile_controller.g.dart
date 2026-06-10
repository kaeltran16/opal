// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the [ProfileStats] for the "You" tab. Reactive: re-emits whenever the
/// entries or rituals change. Reads all entries (year stats span the whole year,
/// not just today) and folds them via [buildProfileStats].

@ProviderFor(profileStats)
const profileStatsProvider = ProfileStatsProvider._();

/// Streams the [ProfileStats] for the "You" tab. Reactive: re-emits whenever the
/// entries or rituals change. Reads all entries (year stats span the whole year,
/// not just today) and folds them via [buildProfileStats].

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

String _$profileStatsHash() => r'14d3afdcad933446bdc4e9e2eb11ca6b1d0a5ceb';
