import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/services.dart';
import 'pal_action_executor.dart';
import 'providers.dart';

part 'ask_pal_controller.g.dart';

/// The Ask-Pal chat view model: the running [messages] transcript plus an
/// [isLoading] flag that drives the typing indicator.
///
/// The screen is dumb — it renders this state and calls [send]. State resets
/// per session because the controller is *not* kept alive (default `autoDispose`
/// from `@riverpod`), so leaving and re-entering the chat starts fresh.
class AskPalState {
  const AskPalState({this.messages = const [], this.isLoading = false});

  /// The conversation so far, oldest first.
  final List<PalMessage> messages;

  /// True while awaiting a [PalService.chat] reply (shows the typing dots).
  final bool isLoading;

  /// True before the user has sent anything (drives the empty-state chips).
  bool get isEmpty => messages.isEmpty;

  AskPalState copyWith({List<PalMessage>? messages, bool? isLoading}) =>
      AskPalState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
      );
}

/// Owns the Ask-Pal conversation, the [PalService.chat] round-trip, and the
/// auto-apply + undo of any mutations the reply carried.
@riverpod
class AskPalController extends _$AskPalController {
  /// Reversal data per assistant message index (only for turns that mutated).
  final Map<int, AppliedActions> _undo = {};

  @override
  AskPalState build() => const AskPalState();

  /// Appends the user's [text], shows the typing indicator, then sends it to
  /// Pal. Any actions in the reply are applied immediately (entries logged,
  /// goals changed) and recorded so the turn can be undone. No-ops on empty
  /// input or while a reply is pending; a transport failure surfaces a message
  /// rather than leaving the typing indicator spinning forever.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final history = state.messages;
    state = state.copyWith(
      messages: [...history, PalMessage(role: PalRole.user, text: trimmed, timestamp: DateTime.now())],
      isLoading: true,
    );

    try {
      final result = await ref.read(palServiceProvider).chat(history, trimmed);
      final applied = await applyPalActions(ref, result.actions);
      // the chat auto-disposes on leave; don't touch state after an await if so.
      if (!ref.mounted) return;
      final messages = [
        ...state.messages,
        PalMessage(
          role: PalRole.assistant,
          text: result.reply,
          timestamp: DateTime.now(),
          actions: result.actions,
        ),
      ];
      if (!applied.isEmpty) _undo[messages.length - 1] = applied;
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        messages: [
          ...state.messages,
          PalMessage(
            role: PalRole.assistant,
            text: "Sorry — I couldn't reach Pal just now. Try again in a moment.",
            timestamp: DateTime.now(),
          ),
        ],
        isLoading: false,
      );
    }
  }

  /// Reverses the actions applied by the assistant message at [index]: deletes
  /// the entries it created and restores the prior goals. Marks the message
  /// [PalMessage.undone] so the UI can reflect it.
  Future<void> undo(int index) async {
    final rec = _undo.remove(index);
    if (rec == null) return;

    final entries = ref.read(entryRepositoryProvider);
    for (final id in rec.entryIds) {
      await entries.deleteById(id);
    }
    final routines = ref.read(routineRepositoryProvider);
    for (final id in rec.routineIds) {
      await routines.deleteById(id);
    }
    if (rec.priorGoals != null) {
      await ref.read(goalsRepositoryProvider).save(rec.priorGoals!);
    }

    if (index >= 0 && index < state.messages.length) {
      final messages = [...state.messages];
      messages[index] = messages[index].copyWith(undone: true);
      state = state.copyWith(messages: messages);
    }
  }
}
