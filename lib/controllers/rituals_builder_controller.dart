import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'rituals_builder_controller.g.dart';

/// Rewrites each ritual's [Ritual.order] to its index in [list], leaving the
/// rest untouched. Pure so the reorder math is unit-testable in isolation.
List<Ritual> reindex(List<Ritual> list) => [
      for (var i = 0; i < list.length; i++)
        if (list[i].order == i) list[i] else list[i].copyWith(order: i),
    ];

/// Streams all rituals (in display order) and owns add/edit/delete/reorder for
/// the Rituals Builder. Mirrors [RitualsController]'s streaming idiom; writes go
/// straight through [RitualRepository] and the live stream drives the UI.
@riverpod
class RitualsBuilderController extends _$RitualsBuilderController {
  @override
  Stream<List<Ritual>> build() {
    return ref.watch(ritualRepositoryProvider).watchRituals();
  }

  /// Upserts [ritual]. A new ritual (empty id) is appended: its order is set to
  /// the current count so it lands at the end of the list. Existing rituals keep
  /// their id, order, and streak (preserved by the caller via copyWith).
  ///
  /// Reads the count from the repository, not the streamed [state], so back-to-
  /// back calls can't race the (async) stream tick.
  Future<void> addOrUpdate(Ritual ritual) async {
    final repo = ref.read(ritualRepositoryProvider);
    if (ritual.id.isEmpty) {
      final count = (await repo.getAll()).length;
      // insert assigns the UUID for an empty id.
      await repo.insert(ritual.copyWith(order: count));
      return;
    }
    await repo.upsert(ritual);
  }

  Future<void> delete(String id) async {
    final repo = ref.read(ritualRepositoryProvider);
    await repo.deleteById(id);
    // reindex the survivors (authoritative repo order) so positions stay
    // gap-free and 0-based.
    final remaining = await repo.getAll();
    await repo.reorder(reindex(remaining));
  }

  /// Moves the ritual at [oldIndex] to [newIndex] and persists every changed
  /// position. [newIndex] is the post-removal target index supplied by
  /// `ReorderableListView.onReorderItem` and indexes into the repository's
  /// current order — the same order the streamed list renders.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final repo = ref.read(ritualRepositoryProvider);
    final list = await repo.getAll();
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    await repo.reorder(reindex(list));
  }
}
