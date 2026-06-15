// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insights_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Structured Pal insights for a [range], or null when there isn't enough data
/// (or Pal is unreachable) — in which case the surfaces render an empty state.
///
/// One-shot (not a stream): an LLM call shouldn't fire on every entry edit. The
/// gate window is the data each surface's insight draws on — Today (day) looks
/// back two weeks for streak/patterns; week/month use their own period.

@ProviderFor(insights)
const insightsProvider = InsightsFamily._();

/// Structured Pal insights for a [range], or null when there isn't enough data
/// (or Pal is unreachable) — in which case the surfaces render an empty state.
///
/// One-shot (not a stream): an LLM call shouldn't fire on every entry edit. The
/// gate window is the data each surface's insight draws on — Today (day) looks
/// back two weeks for streak/patterns; week/month use their own period.

final class InsightsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PalInsights?>,
          PalInsights?,
          FutureOr<PalInsights?>
        >
    with $FutureModifier<PalInsights?>, $FutureProvider<PalInsights?> {
  /// Structured Pal insights for a [range], or null when there isn't enough data
  /// (or Pal is unreachable) — in which case the surfaces render an empty state.
  ///
  /// One-shot (not a stream): an LLM call shouldn't fire on every entry edit. The
  /// gate window is the data each surface's insight draws on — Today (day) looks
  /// back two weeks for streak/patterns; week/month use their own period.
  const InsightsProvider._({
    required InsightsFamily super.from,
    required InsightRange super.argument,
  }) : super(
         retry: null,
         name: r'insightsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$insightsHash();

  @override
  String toString() {
    return r'insightsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PalInsights?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PalInsights?> create(Ref ref) {
    final argument = this.argument as InsightRange;
    return insights(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InsightsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$insightsHash() => r'ec059776cd35904205bab28a258fbd56dab23a10';

/// Structured Pal insights for a [range], or null when there isn't enough data
/// (or Pal is unreachable) — in which case the surfaces render an empty state.
///
/// One-shot (not a stream): an LLM call shouldn't fire on every entry edit. The
/// gate window is the data each surface's insight draws on — Today (day) looks
/// back two weeks for streak/patterns; week/month use their own period.

final class InsightsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PalInsights?>, InsightRange> {
  const InsightsFamily._()
    : super(
        retry: null,
        name: r'insightsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Structured Pal insights for a [range], or null when there isn't enough data
  /// (or Pal is unreachable) — in which case the surfaces render an empty state.
  ///
  /// One-shot (not a stream): an LLM call shouldn't fire on every entry edit. The
  /// gate window is the data each surface's insight draws on — Today (day) looks
  /// back two weeks for streak/patterns; week/month use their own period.

  InsightsProvider call(InsightRange range) =>
      InsightsProvider._(argument: range, from: this);

  @override
  String toString() => r'insightsProvider';
}
