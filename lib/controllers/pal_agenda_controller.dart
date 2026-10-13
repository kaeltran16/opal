import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'pal_agenda_controller.g.dart';

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
@Riverpod(retry: noRetry)
Future<PalAgenda> palAgenda(Ref ref) => ref.watch(palServiceProvider).agenda();
