// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_brief_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pal's lead sentence for Today, from the daily-insights seam. Holds the last
/// good headline so a later failure never blanks the brief; errors resolve to
/// the previous value (or null) rather than an error state, so Today falls
/// back to its local numbers instead of an error view.

@ProviderFor(TodayBrief)
const todayBriefProvider = TodayBriefProvider._();

/// Pal's lead sentence for Today, from the daily-insights seam. Holds the last
/// good headline so a later failure never blanks the brief; errors resolve to
/// the previous value (or null) rather than an error state, so Today falls
/// back to its local numbers instead of an error view.
final class TodayBriefProvider
    extends $AsyncNotifierProvider<TodayBrief, String?> {
  /// Pal's lead sentence for Today, from the daily-insights seam. Holds the last
  /// good headline so a later failure never blanks the brief; errors resolve to
  /// the previous value (or null) rather than an error state, so Today falls
  /// back to its local numbers instead of an error view.
  const TodayBriefProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayBriefProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayBriefHash();

  @$internal
  @override
  TodayBrief create() => TodayBrief();
}

String _$todayBriefHash() => r'99be516bcdfc145341ff80c1d7895aecd29de796';

/// Pal's lead sentence for Today, from the daily-insights seam. Holds the last
/// good headline so a later failure never blanks the brief; errors resolve to
/// the previous value (or null) rather than an error state, so Today falls
/// back to its local numbers instead of an error view.

abstract class _$TodayBrief extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
