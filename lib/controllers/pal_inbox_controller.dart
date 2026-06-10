import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'pal_inbox_controller.g.dart';

/// The Pal-inbox filter pills. `all`/`unread` are count-based; the three tracker
/// filters match a note's [PalNote.category].
enum InboxFilter { all, unread, money, move, rituals }

/// The Pal-inbox view model: the full note list (newest first), the active
/// filter, the unread count, and the filtered slice the timeline renders. The
/// screen is dumb — filtering/counting lives here.
class PalInboxState {
  const PalInboxState({required this.notes, required this.filter});

  /// All notes, newest first.
  final List<PalNote> notes;
  final InboxFilter filter;

  int get unreadCount => notes.where((n) => n.unread).length;

  /// The slice shown for [filter].
  List<PalNote> get visible => switch (filter) {
        InboxFilter.all => notes,
        InboxFilter.unread => notes.where((n) => n.unread).toList(),
        InboxFilter.money =>
          notes.where((n) => n.category == EntryType.money).toList(),
        InboxFilter.move =>
          notes.where((n) => n.category == EntryType.move).toList(),
        InboxFilter.rituals =>
          notes.where((n) => n.category == EntryType.rituals).toList(),
      };

  PalInboxState copyWith({List<PalNote>? notes, InboxFilter? filter}) =>
      PalInboxState(
        notes: notes ?? this.notes,
        filter: filter ?? this.filter,
      );
}

/// Streams the Pal-inbox notes folded with the active filter, and owns the
/// filter selection + read actions. Mirrors [RitualsController]'s stream pattern
/// (`build` yields from the repo stream) with the filter kept as local state.
@riverpod
class PalInboxController extends _$PalInboxController {
  InboxFilter _filter = InboxFilter.all;

  @override
  Stream<PalInboxState> build() async* {
    final repo = ref.watch(palNoteRepositoryProvider);
    await for (final notes in repo.watchNotes()) {
      yield PalInboxState(notes: notes, filter: _filter);
    }
  }

  /// Switches the active filter, re-emitting the current notes immediately.
  void setFilter(InboxFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    final notes = state.value?.notes;
    if (notes != null) {
      state = AsyncData(PalInboxState(notes: notes, filter: filter));
    }
  }

  Future<void> markRead(String id) =>
      ref.read(palNoteRepositoryProvider).markRead(id);

  Future<void> markAllRead() =>
      ref.read(palNoteRepositoryProvider).markAllRead();
}
