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
/// An unreachable backend / timeout / malformed payload degrades to an empty
/// [PalAgenda] (the screen shows its caught-up empty states) rather than an
/// error screen — matching [insights]'s graceful-degradation boundary.

@ProviderFor(palAgenda)
const palAgendaProvider = PalAgendaProvider._();

/// The Pal Home hub payload (proposals to approve, autopilot list, memory,
/// streak) from the `/agenda` seam. One-shot, not a stream — it's fetched when
/// the hub opens, not on every entry edit.
///
/// An unreachable backend / timeout / malformed payload degrades to an empty
/// [PalAgenda] (the screen shows its caught-up empty states) rather than an
/// error screen — matching [insights]'s graceful-degradation boundary.

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
  /// An unreachable backend / timeout / malformed payload degrades to an empty
  /// [PalAgenda] (the screen shows its caught-up empty states) rather than an
  /// error screen — matching [insights]'s graceful-degradation boundary.
  const PalAgendaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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

String _$palAgendaHash() => r'af64c9b6a8e485c581e620424091663d8af2e384';
