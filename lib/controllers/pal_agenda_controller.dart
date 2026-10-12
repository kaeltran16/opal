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
@Riverpod(retry: _noRetry)
Future<PalAgenda> palAgenda(Ref ref) => ref.watch(palServiceProvider).agenda();

// riverpod's auto-retry holds a failure as loading, which Today reads as
// online; the failure must show at once. pull to refresh and resume fetch
// again.
Duration? _noRetry(int retryCount, Object error) => null;
