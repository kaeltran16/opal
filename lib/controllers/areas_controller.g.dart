// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'areas_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(_recentEntries)
const _recentEntriesProvider = _RecentEntriesProvider._();

final class _RecentEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Entry>>,
          List<Entry>,
          Stream<List<Entry>>
        >
    with $FutureModifier<List<Entry>>, $StreamProvider<List<Entry>> {
  const _RecentEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_recentEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_recentEntriesHash();

  @$internal
  @override
  $StreamProviderElement<List<Entry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Entry>> create(Ref ref) {
    return _recentEntries(ref);
  }
}

String _$_recentEntriesHash() => r'8babe9f042cf54ae3d48f9f480aa91194930765e';

@ProviderFor(_recentMeals)
const _recentMealsProvider = _RecentMealsProvider._();

final class _RecentMealsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NutritionMeal>>,
          List<NutritionMeal>,
          Stream<List<NutritionMeal>>
        >
    with
        $FutureModifier<List<NutritionMeal>>,
        $StreamProvider<List<NutritionMeal>> {
  const _RecentMealsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_recentMealsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_recentMealsHash();

  @$internal
  @override
  $StreamProviderElement<List<NutritionMeal>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<NutritionMeal>> create(Ref ref) {
    return _recentMeals(ref);
  }
}

String _$_recentMealsHash() => r'ec12199d99ce6a3be478a61506476291b0231e13';

@ProviderFor(_recentCheckins)
const _recentCheckinsProvider = _RecentCheckinsProvider._();

final class _RecentCheckinsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MoodCheckin>>,
          List<MoodCheckin>,
          Stream<List<MoodCheckin>>
        >
    with
        $FutureModifier<List<MoodCheckin>>,
        $StreamProvider<List<MoodCheckin>> {
  const _RecentCheckinsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_recentCheckinsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_recentCheckinsHash();

  @$internal
  @override
  $StreamProviderElement<List<MoodCheckin>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MoodCheckin>> create(Ref ref) {
    return _recentCheckins(ref);
  }
}

String _$_recentCheckinsHash() => r'543fb5151ef48b7e8a1b013da9be97c5cb5568d7';

@ProviderFor(_recentNights)
const _recentNightsProvider = _RecentNightsProvider._();

final class _RecentNightsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SleepNight>>,
          List<SleepNight>,
          Stream<List<SleepNight>>
        >
    with $FutureModifier<List<SleepNight>>, $StreamProvider<List<SleepNight>> {
  const _RecentNightsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_recentNightsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_recentNightsHash();

  @$internal
  @override
  $StreamProviderElement<List<SleepNight>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SleepNight>> create(Ref ref) {
    return _recentNights(ref);
  }
}

String _$_recentNightsHash() => r'080e405c318f832bfc11a78215630ead49d6d320';

/// Streams the Areas tab view model. Watching each source's `.future`
/// rebuilds this provider when today's numbers, entries, meals or check-ins
/// change.

@ProviderFor(areasSummary)
const areasSummaryProvider = AreasSummaryProvider._();

/// Streams the Areas tab view model. Watching each source's `.future`
/// rebuilds this provider when today's numbers, entries, meals or check-ins
/// change.

final class AreasSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<AreasSummary>,
          AreasSummary,
          Stream<AreasSummary>
        >
    with $FutureModifier<AreasSummary>, $StreamProvider<AreasSummary> {
  /// Streams the Areas tab view model. Watching each source's `.future`
  /// rebuilds this provider when today's numbers, entries, meals or check-ins
  /// change.
  const AreasSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'areasSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$areasSummaryHash();

  @$internal
  @override
  $StreamProviderElement<AreasSummary> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AreasSummary> create(Ref ref) {
    return areasSummary(ref);
  }
}

String _$areasSummaryHash() => r'7bf68a285c573dad5732eed154699e915e059683';
