// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pal_suggestions_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pal-generated quick-pick chips for [surface] (the `/suggestions` seam).
/// One-shot, family-keyed by surface. An unreachable backend / timeout /
/// malformed payload degrades to an empty list, so each surface renders its
/// own static fallback (mirrors [palAgenda]'s graceful-degradation boundary).

@ProviderFor(palSuggestions)
const palSuggestionsProvider = PalSuggestionsFamily._();

/// Pal-generated quick-pick chips for [surface] (the `/suggestions` seam).
/// One-shot, family-keyed by surface. An unreachable backend / timeout /
/// malformed payload degrades to an empty list, so each surface renders its
/// own static fallback (mirrors [palAgenda]'s graceful-degradation boundary).

final class PalSuggestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PalSuggestion>>,
          List<PalSuggestion>,
          FutureOr<List<PalSuggestion>>
        >
    with
        $FutureModifier<List<PalSuggestion>>,
        $FutureProvider<List<PalSuggestion>> {
  /// Pal-generated quick-pick chips for [surface] (the `/suggestions` seam).
  /// One-shot, family-keyed by surface. An unreachable backend / timeout /
  /// malformed payload degrades to an empty list, so each surface renders its
  /// own static fallback (mirrors [palAgenda]'s graceful-degradation boundary).
  const PalSuggestionsProvider._({
    required PalSuggestionsFamily super.from,
    required SuggestionSurface super.argument,
  }) : super(
         retry: null,
         name: r'palSuggestionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$palSuggestionsHash();

  @override
  String toString() {
    return r'palSuggestionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<PalSuggestion>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PalSuggestion>> create(Ref ref) {
    final argument = this.argument as SuggestionSurface;
    return palSuggestions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PalSuggestionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$palSuggestionsHash() => r'13f4ccd67930218e118e4a57370ed63123448507';

/// Pal-generated quick-pick chips for [surface] (the `/suggestions` seam).
/// One-shot, family-keyed by surface. An unreachable backend / timeout /
/// malformed payload degrades to an empty list, so each surface renders its
/// own static fallback (mirrors [palAgenda]'s graceful-degradation boundary).

final class PalSuggestionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<PalSuggestion>>,
          SuggestionSurface
        > {
  const PalSuggestionsFamily._()
    : super(
        retry: null,
        name: r'palSuggestionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Pal-generated quick-pick chips for [surface] (the `/suggestions` seam).
  /// One-shot, family-keyed by surface. An unreachable backend / timeout /
  /// malformed payload degrades to an empty list, so each surface renders its
  /// own static fallback (mirrors [palAgenda]'s graceful-degradation boundary).

  PalSuggestionsProvider call(SuggestionSurface surface) =>
      PalSuggestionsProvider._(argument: surface, from: this);

  @override
  String toString() => r'palSuggestionsProvider';
}
