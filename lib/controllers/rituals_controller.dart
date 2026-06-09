import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'rituals_controller.g.dart';

/// The fully-computed Rituals view model: the day's rituals (in display order)
/// plus the set of ritual ids already completed today (derived from the live
/// ritual-type [Entry] stream). The screen is dumb — all math lives here.
class RitualsState {
  const RitualsState({
    required this.rituals,
    required this.completedIds,
    this.entryIdsByRitual = const {},
  });

  /// Today's rituals, in display order.
  final List<Ritual> rituals;

  /// Ids of rituals that have a ritual-type [Entry] logged today.
  final Set<String> completedIds;

  /// Today's ritual-[Entry] ids, grouped by `ritualId`, so toggle-off can
  /// delete the exact rows without re-querying a stream.
  final Map<String, List<String>> entryIdsByRitual;

  /// Number completed today.
  int get doneCount => rituals.where((r) => completedIds.contains(r.id)).length;

  /// Total rituals for the day.
  int get totalCount => rituals.length;

  /// Completion fraction (0..1); 0 when there are no rituals.
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  /// Best current streak across the day's rituals (for the subtitle).
  int get bestStreak =>
      rituals.isEmpty ? 0 : rituals.map((r) => r.streak).reduce((a, b) => a > b ? a : b);

  bool isDone(String ritualId) => completedIds.contains(ritualId);
}

/// Streams the Rituals view model and owns the toggle action.
///
/// Combines the live rituals stream with today's ritual-type entries so the
/// per-ritual completion state stays in sync with the Today rings (both read
/// the same [Entry] rows).
@riverpod
class RitualsController extends _$RitualsController {
  @override
  Stream<RitualsState> build() async* {
    final ritualRepo = ref.watch(ritualRepositoryProvider);
    final entryRepo = ref.watch(entryRepositoryProvider);

    // Re-emit whenever today's entries change; re-read rituals each tick
    // (small list, cheap) so a newly-added ritual shows up immediately.
    await for (final entries in entryRepo.watchToday()) {
      final rituals = await ritualRepo.getAll();
      final completed = <String>{};
      final byRitual = <String, List<String>>{};
      for (final e in entries) {
        if (e.type == EntryType.rituals && e.ritualId != null) {
          completed.add(e.ritualId!);
          (byRitual[e.ritualId!] ??= <String>[]).add(e.id);
        }
      }
      yield RitualsState(
        rituals: rituals,
        completedIds: completed,
        entryIdsByRitual: byRitual,
      );
    }
  }

  /// Toggles [ritual]'s completion for today.
  ///
  /// When not yet done, writes a ritual-type [Entry] (so the Today rituals ring
  /// updates) and fires a light haptic (no-op on web). When already done,
  /// removes today's matching entry. The live stream drives the UI update.
  Future<void> toggle(Ritual ritual) async {
    final entryRepo = ref.read(entryRepositoryProvider);
    final current = state.value;
    final alreadyDone = current?.isDone(ritual.id) ?? false;

    if (alreadyDone) {
      // Remove today's matching ritual entry/entries (ids tracked in state, so
      // no extra stream query is needed).
      final ids = current?.entryIdsByRitual[ritual.id] ?? const <String>[];
      for (final id in ids) {
        await entryRepo.deleteById(id);
      }
      return;
    }

    await entryRepo.insert(
      Entry(
        id: '',
        timestamp: DateTime.now(),
        type: EntryType.rituals,
        title: ritual.title,
        ritualId: ritual.id,
        source: EntrySource.manual,
      ),
    );
    await ref.read(hapticsServiceProvider).light();
  }
}
