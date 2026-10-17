// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pal_agenda_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Pal Home hub payload (proposals to approve, autopilot list, memory,
/// streak) from the `/agenda` seam. One-shot, not a stream — it's fetched when
/// the hub opens, not on every entry edit.
///
/// A failed fetch is left as an error, not an empty agenda: Today reads the
/// error as Pal being offline and falls back to the clock. A failed refresh
/// keeps the last proposals as the error's value, so callers read
/// `.value ?? const PalAgenda()`.
///
/// No retry: a failure held as loading reads as online on Today. Pull to
/// refresh and resume build it again.
///
/// A plain rebuild (first open, resume) may serve the service's cached reply
/// for the day; [PalAgendaRefresh.fetchFresh] makes the next one fetch past it.

@ProviderFor(palAgenda)
const palAgendaProvider = PalAgendaProvider._();

/// The Pal Home hub payload (proposals to approve, autopilot list, memory,
/// streak) from the `/agenda` seam. One-shot, not a stream — it's fetched when
/// the hub opens, not on every entry edit.
///
/// A failed fetch is left as an error, not an empty agenda: Today reads the
/// error as Pal being offline and falls back to the clock. A failed refresh
/// keeps the last proposals as the error's value, so callers read
/// `.value ?? const PalAgenda()`.
///
/// No retry: a failure held as loading reads as online on Today. Pull to
/// refresh and resume build it again.
///
/// A plain rebuild (first open, resume) may serve the service's cached reply
/// for the day; [PalAgendaRefresh.fetchFresh] makes the next one fetch past it.

final class PalAgendaProvider
    extends
        $FunctionalProvider<
          AsyncValue<PalAgenda>,
          PalAgenda,
          FutureOr<PalAgenda>
        >
    with $FutureModifier<PalAgenda>, $FutureProvider<PalAgenda> {
  /// The Pal Home hub payload (proposals to approve, autopilot list, memory,
  /// streak) from the `/agenda` seam. One-shot, not a stream — it's fetched when
  /// the hub opens, not on every entry edit.
  ///
  /// A failed fetch is left as an error, not an empty agenda: Today reads the
  /// error as Pal being offline and falls back to the clock. A failed refresh
  /// keeps the last proposals as the error's value, so callers read
  /// `.value ?? const PalAgenda()`.
  ///
  /// No retry: a failure held as loading reads as online on Today. Pull to
  /// refresh and resume build it again.
  ///
  /// A plain rebuild (first open, resume) may serve the service's cached reply
  /// for the day; [PalAgendaRefresh.fetchFresh] makes the next one fetch past it.
  const PalAgendaProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'palAgendaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$palAgendaHash();

  @$internal
  @override
  $FutureProviderElement<PalAgenda> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<PalAgenda> create(Ref ref) {
    return palAgenda(ref);
  }
}

String _$palAgendaHash() => r'c45cadcf5a125533baeabe170b0665f153fd9fd6';

@ProviderFor(palAgendaRefresh)
const palAgendaRefreshProvider = PalAgendaRefreshProvider._();

final class PalAgendaRefreshProvider
    extends
        $FunctionalProvider<
          PalAgendaRefresh,
          PalAgendaRefresh,
          PalAgendaRefresh
        >
    with $Provider<PalAgendaRefresh> {
  const PalAgendaRefreshProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'palAgendaRefreshProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$palAgendaRefreshHash();

  @$internal
  @override
  $ProviderElement<PalAgendaRefresh> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PalAgendaRefresh create(Ref ref) {
    return palAgendaRefresh(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PalAgendaRefresh value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PalAgendaRefresh>(value),
    );
  }
}

String _$palAgendaRefreshHash() => r'3f1bac8f751ada116f5af162afb2d5496744e7e1';
