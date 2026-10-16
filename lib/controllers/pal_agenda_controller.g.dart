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
/// refresh and resume fetch again.

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
/// refresh and resume fetch again.

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
  /// refresh and resume fetch again.
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

String _$palAgendaHash() => r'86920f65c56e95e5c342cc70e53538b669fd101f';
