import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/repositories.dart';
import '../models/models.dart';
import '../services/health/health_service.dart';
import 'providers.dart';

part 'health_sync_controller.g.dart';

/// Pulls today's active energy from the server and upserts ONE health-sourced
/// move [Entry] so it feeds the move ring.
///
/// The entry id is deterministic (`health:move:<date>`) so a re-sync overwrites
/// the day's value rather than duplicating it. Instantiated once at app start
/// (see `app.dart`); `fireImmediately` syncs on launch.
@Riverpod(keepAlive: true)
class HealthSyncController extends _$HealthSyncController {
  @override
  void build() {
    final service = ref.watch(healthServiceProvider);
    final entries = ref.watch(entryRepositoryProvider);
    // fire-and-forget: a failed health pull must not crash startup.
    _sync(service, entries);
  }

  Future<void> _sync(HealthService service, EntryRepository entries) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = await service.fetchDay(today);
    if (day.activeEnergyKcal == 0) return; // no data yet

    final date = _formatDate(today);
    await entries.upsert(Entry(
      id: 'health:move:$date',
      timestamp: DateTime(today.year, today.month, today.day, 12),
      type: EntryType.move,
      title: 'Apple Watch',
      detail: day.steps > 0 ? '${day.steps} steps' : null,
      calories: day.activeEnergyKcal,
      source: EntrySource.health,
      sourceRef: 'health:active-energy:$date',
    ));
  }

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
