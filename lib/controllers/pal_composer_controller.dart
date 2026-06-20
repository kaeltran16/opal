import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../util/format.dart';
import 'pal_action_executor.dart';
import 'providers.dart';

part 'pal_composer_controller.g.dart';

/// Message shown when Pal is unreachable and there's nothing to log locally.
const _palOfflineReply =
    "Pal couldn't reach the server. You can still log this from the New Entry "
    'sheet.';

/// The Pal-composer chat view model: the running [messages] transcript plus an
/// [isLoading] flag that drives the typing dots, and an [expanded] flag that
/// flips the sheet from the compact greeting state into the chat.
///
/// Seeded via the family [seed] param: a non-empty seed initializes the
/// transcript with that user message, expanded + loading, and fires the first
/// [PalService.chat] round-trip on build. The controller auto-disposes, so each
/// presentation of the sheet starts fresh.
class PalComposerState {
  const PalComposerState({
    this.messages = const [],
    this.isLoading = false,
    this.expanded = false,
  });

  /// The conversation so far, oldest first.
  final List<PalMessage> messages;

  /// True while awaiting a [PalService.chat] reply (shows the typing dots).
  final bool isLoading;

  /// True once the user has sent anything — hides the compact affordances and
  /// shows the scrolling message list.
  final bool expanded;

  PalComposerState copyWith({
    List<PalMessage>? messages,
    bool? isLoading,
    bool? expanded,
  }) =>
      PalComposerState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        expanded: expanded ?? this.expanded,
      );
}

/// Owns the Pal-composer conversation and the [PalService.chat] round-trip.
@riverpod
class PalComposerController extends _$PalComposerController {
  /// Reversal data per assistant message index (only for turns that mutated).
  final Map<int, AppliedActions> _undo = {};

  @override
  PalComposerState build({String? seed}) {
    final trimmedSeed = seed?.trim() ?? '';
    if (trimmedSeed.isEmpty) return const PalComposerState();

    // Seed: open expanded with the user's first message and fire its reply.
    final userMessage = PalMessage(
      role: PalRole.user,
      text: trimmedSeed,
      timestamp: DateTime.now(),
    );
    Future.microtask(() => _reply(const [], trimmedSeed));
    return PalComposerState(
      messages: [userMessage],
      isLoading: true,
      expanded: true,
    );
  }

  /// Appends the user's [text], shows the typing indicator, then appends the
  /// assistant's reply. No-ops on empty input or while a reply is pending.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final history = state.messages;
    final userMessage = PalMessage(
      role: PalRole.user,
      text: trimmed,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...history, userMessage],
      isLoading: true,
      expanded: true,
    );

    await _reply(history, trimmed);
  }

  /// Sends a starter chip [label] through Pal. When the chip carries a
  /// structured [payload] and Pal is unreachable, logs the entry locally
  /// (exactly like the New Entry sheet) instead of just failing — so the
  /// composer's quick-logs work offline. Open-prompt chips ([payload] null)
  /// fall back to the graceful failure message.
  Future<void> sendStarter(String label, StarterEntry? payload) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final history = state.messages;
    state = state.copyWith(
      messages: [
        ...history,
        PalMessage(
          role: PalRole.user,
          text: trimmed,
          timestamp: DateTime.now(),
        ),
      ],
      isLoading: true,
      expanded: true,
    );

    await _reply(history, trimmed, payload: payload);
  }

  /// Calls [PalService.chat] with [history] + [message] and appends the reply.
  ///
  /// On a Pal failure the chat never hangs: it resolves [isLoading] and either
  /// logs [payload] locally (with a confirmation) when present, or appends the
  /// graceful offline message.
  Future<void> _reply(
    List<PalMessage> history,
    String message, {
    StarterEntry? payload,
  }) async {
    try {
      final result = await ref.read(palServiceProvider).chat(history, message);
      // apply any logging / goal / routine changes the reply carried, same as Ask-Pal
      final applied = await applyPalActions(ref, result.actions);
      final index = state.messages.length; // index the assistant message will occupy
      if (!applied.isEmpty) _undo[index] = applied;
      _appendAssistant(result.reply, actions: result.actions);
    } on PalException {
      await _handleOffline(payload);
    } catch (_) {
      await _handleOffline(payload);
    }
  }

  /// Logs [payload] locally when present (confirming it), else reports offline.
  /// Always resolves [isLoading] — a local-insert failure falls back to the
  /// generic offline message rather than re-hanging the composer.
  Future<void> _handleOffline(StarterEntry? payload) async {
    if (payload == null) {
      _appendAssistant(_palOfflineReply);
      return;
    }
    try {
      await ref.read(entryRepositoryProvider).insert(_entryFor(payload));
      _appendAssistant(_offlineConfirmation(payload));
    } catch (_) {
      _appendAssistant(_palOfflineReply);
    }
  }

  /// Builds a manual [Entry] from a starter [payload], mirroring the New Entry
  /// sheet's `_add` (negative money amounts, minutes as duration).
  Entry _entryFor(StarterEntry payload) => Entry(
        id: '',
        timestamp: DateTime.now(),
        type: payload.type,
        title: payload.title,
        amount: payload.amount,
        duration: payload.durationMinutes,
        category: payload.category,
        source: EntrySource.manual,
      );

  String _offlineConfirmation(StarterEntry payload) {
    final currency = ref.read(appSettingsControllerProvider).currency;
    final detail = switch (payload.type) {
      EntryType.money when payload.amount != null =>
        ' · −${formatCurrency(payload.amount!.abs(), currency)}',
      EntryType.move when payload.durationMinutes != null =>
        ' · ${payload.durationMinutes} min',
      _ => '',
    };
    return 'Logged ${payload.title}$detail offline.';
  }

  void _appendAssistant(String text, {List<PalAction> actions = const []}) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        PalMessage(
          role: PalRole.assistant,
          text: text,
          timestamp: DateTime.now(),
          actions: actions,
        ),
      ],
      isLoading: false,
    );
  }

  /// Reverses the actions applied by the assistant message at [index]: deletes
  /// the entries/routines it created and restores the prior goals. Marks the
  /// message [PalMessage.undone] so the UI can reflect it.
  Future<void> undo(int index) async {
    final rec = _undo.remove(index);
    if (rec == null) return;
    await _reverse(rec);

    if (index >= 0 && index < state.messages.length) {
      final messages = [...state.messages];
      messages[index] = messages[index].copyWith(undone: true);
      state = state.copyWith(messages: messages);
    }
  }

  /// Edits a logged turn: reverses the assistant message at [index]'s mutation,
  /// removes that turn (its user line + this assistant card) from the transcript,
  /// and returns the original user text so the composer can refill it for a fix.
  /// Returns '' when there's nothing to recover. Unlike [undo] (which keeps the
  /// card and flags it undone), Edit takes the entry off-screen entirely.
  Future<String> editLog(int index) async {
    final rec = _undo.remove(index);
    if (rec != null) await _reverse(rec);

    final messages = state.messages;
    if (index < 0 || index >= messages.length) return '';

    // The turn spans the preceding user message (if any) and this assistant one.
    var start = index, count = 1;
    var refill = '';
    if (index - 1 >= 0 && messages[index - 1].role == PalRole.user) {
      start = index - 1;
      count = 2;
      refill = messages[index - 1].text;
    }

    final next = [...messages]..removeRange(start, start + count);
    // Splicing shifts every later message down by [count]; re-key the undo map
    // so the surviving turns' reversal data still points at the right index.
    final rebuilt = <int, AppliedActions>{};
    _undo.forEach((k, v) {
      if (k < start) {
        rebuilt[k] = v;
      } else if (k >= start + count) {
        rebuilt[k - count] = v;
      }
    });
    _undo
      ..clear()
      ..addAll(rebuilt);

    state = state.copyWith(messages: next);
    return refill;
  }

  /// Reverses one turn's auto-applied mutations: deletes the entries/routines it
  /// created and restores the goals snapshot it changed. Shared by [undo] and
  /// [editLog].
  Future<void> _reverse(AppliedActions rec) async {
    final entries = ref.read(entryRepositoryProvider);
    for (final id in rec.entryIds) {
      await entries.deleteById(id);
    }
    final routines = ref.read(routineRepositoryProvider);
    for (final id in rec.routineIds) {
      await routines.deleteById(id);
    }
    if (rec.priorGoals != null) {
      await ref.read(goalsRepositoryProvider).upsert(rec.priorGoals!);
    }
  }
}
