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
  const PalAgendaProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
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

String _$palAgendaHash() => r'cde3b80044a82f4b978e759e87e7ea56a2103c77';
