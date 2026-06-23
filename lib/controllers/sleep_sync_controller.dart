import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/repositories.dart';
import '../models/models.dart';
import 'providers.dart';

part 'sleep_sync_controller.g.dart';

/// Pulls recent nights from Health and upserts them into [SleepRepository].
/// Deterministic id (`health:sleep:<date>` or the Health sourceRef) so a
/// re-sync overwrites rather than duplicates. Best-effort: a failed pull must
/// not crash startup. Syncs on construction.
@Riverpod(keepAlive: true)
class SleepSyncController extends _$SleepSyncController {
  static const int _windowDays = 30;

  @override
  void build() {
    // fire-and-forget on construction
    syncOnce();
  }

  Future<void> syncOnce() async {
    try {
      final service = ref.read(healthServiceProvider);
      final repo = ref.read(sleepRepositoryProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = today.subtract(const Duration(days: _windowDays - 1));
      final to = today.add(const Duration(days: 1));
      final nights = await service.fetchSleep(from, to);
      for (final n in nights) {
        final date = _date(n.night);
        await repo.upsert(SleepNight(
          id: n.sourceRef ?? 'health:sleep:$date',
          night: n.night,
          asleepMinutes: n.asleepMinutes,
          inBedMinutes: n.inBedMinutes,
          bedtime: n.bedtime,
          wake: n.wake,
          deepMinutes: n.deepMinutes,
          remMinutes: n.remMinutes,
          coreMinutes: n.coreMinutes,
          awakeMinutes: n.awakeMinutes,
          wakes: n.wakes,
          source: EntrySource.health,
          sourceRef: n.sourceRef,
        ));
      }
    } catch (_) {
      // swallow: sleep is supplementary; the screen just shows needs-sync.
    }
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
