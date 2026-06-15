import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'pal_agenda_controller.g.dart';

/// The Pal Home hub payload (proposals to approve, autopilot list, memory,
/// streak) from the `/agenda` seam. One-shot, not a stream — it's fetched when
/// the hub opens, not on every entry edit.
///
/// An unreachable backend / timeout / malformed payload degrades to an empty
/// [PalAgenda] (the screen shows its caught-up empty states) rather than an
/// error screen — matching [insights]'s graceful-degradation boundary.
@riverpod
Future<PalAgenda> palAgenda(Ref ref) async {
  final pal = ref.watch(palServiceProvider);
  try {
    return await pal.agenda();
  } catch (_) {
    return const PalAgenda();
  }
}
