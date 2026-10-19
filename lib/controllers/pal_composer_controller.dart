import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../util/format.dart';
import 'pal_action_executor.dart';
import 'providers.dart';

part 'pal_composer_controller.g.dart';

/// Shown when the request never got an answer (network failure).
const _palUnreachableReply = "Pal couldn't reach the server.";

/// Shown when the server answered but Pal failed, or the reply took too long.
const _palFailedReply = "Pal couldn't answer that just now. Try again in a moment.";

/// Appended only when the failed message looks like something to log.
const _manualEntryHint = ' You can still log this from the New Entry sheet.';

/// Outcome of a composer send, so the screen can react. [offlineFallback] means
/// Pal was unreachable for a free-text message that looks loggable — the screen
/// routes the user to the manual New Entry sheet instead of leaving them stuck.
enum PalSendResult { completed, offlineFallback }

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
  /// Reversal data per assistant message index (only for turns that mutated),
  /// one per action; null once that action has been reversed.
  final Map<int, List<AppliedAction?>> _undo = {};

  /// Interactive chat round-trips bail out well before the service's 30s cap so
  /// a slow / unreachable backend can't lock the composer; on a miss we degrade
  /// to the offline path (local log or manual-entry handoff) instead of hanging.
  static const _chatTimeout = Duration(seconds: 12);

  /// Whether an offline free-text message looks like a quantified log (carries a
  /// number and is not a question) — the signal we use to offer the manual New
  /// Entry fallback.
  static bool _looksLoggable(String message) =>
      RegExp(r'\d').hasMatch(message) && !message.trimRight().endsWith('?');

  @override
  PalComposerState build({String? seed, String? about}) {
    final trimmedSeed = seed?.trim() ?? '';
    if (trimmedSeed.isEmpty) return const PalComposerState();

    // Seed: open expanded with the user's first message and fire its reply.
    // [about] rides on that message for Pal; the bubble shows the seed alone.
    final note = about?.trim();
    final userMessage = PalMessage(
      role: PalRole.user,
      text: trimmedSeed,
      timestamp: clock.now(),
      note: note == null || note.isEmpty ? null : note,
    );
    Future.microtask(() => _reply(const [], userMessage.modelText));
    return PalComposerState(
      messages: [userMessage],
      isLoading: true,
      expanded: true,
    );
  }

  /// Appends the user's [text], shows the typing indicator, then appends the
  /// assistant's reply. No-ops on empty input or while a reply is pending.
  /// Returns [PalSendResult.offlineFallback] when Pal was unreachable for a
  /// loggable message, so the screen can hand off to the manual New Entry sheet.
  Future<PalSendResult> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return PalSendResult.completed;

    final history = state.messages;
    final userMessage = PalMessage(
      role: PalRole.user,
      text: trimmed,
      timestamp: clock.now(),
    );
    state = state.copyWith(
      messages: [...history, userMessage],
      isLoading: true,
      expanded: true,
    );

    return _reply(history, trimmed);
  }

  /// Sends a starter chip [label] through Pal. When the chip carries a
  /// structured [payload] and Pal is unreachable, logs the entry locally
  /// (exactly like the New Entry sheet) instead of just failing — so the
  /// composer's quick-logs work offline. Open-prompt chips ([payload] null)
  /// fall back to the graceful failure message. [about] rides on the message
  /// for Pal only, as a seed's does.
  Future<void> sendStarter(String label, StarterEntry? payload, {String? about}) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final history = state.messages;
    final note = about?.trim();
    final message = PalMessage(
      role: PalRole.user,
      text: trimmed,
      timestamp: clock.now(),
      note: note == null || note.isEmpty ? null : note,
    );
    state = state.copyWith(
      messages: [...history, message],
      isLoading: true,
      expanded: true,
    );

    await _reply(history, message.modelText, payload: payload);
  }

  /// Calls [PalService.chat] with [history] + [message] and appends the reply.
  ///
  /// On a Pal failure the chat never hangs: it resolves [isLoading] and either
  /// logs [payload] locally (with a confirmation) when present, or appends the
  /// graceful offline message.
  Future<PalSendResult> _reply(
    List<PalMessage> history,
    String message, {
    StarterEntry? payload,
  }) async {
    try {
      final result = await ref
          .read(palServiceProvider)
          .chat(history, message)
          .timeout(_chatTimeout);
      // apply any logging / goal / routine changes the reply carried, same as Ask-Pal
      final applied = await applyPalActions(ref, result.actions);
      final index = state.messages.length; // index the assistant message will occupy
      if (applied.isNotEmpty) _undo[index] = List<AppliedAction?>.of(applied);
      _appendAssistant(result.reply, actions: result.actions);
      return PalSendResult.completed;
    } on PalException catch (e) {
      final reached = e.statusCode != null;
      return _handleOffline(payload, message, reached: reached);
    } catch (_) {
      // the composer's own timeout: the server may have been reached.
      return _handleOffline(payload, message, reached: true);
    }
  }

  /// Logs [payload] locally when present (confirming it), else reports the
  /// failure: [reached] says whether the server answered, so the copy never
  /// claims it was unreachable when the model failed. Always resolves
  /// [isLoading] — a local-insert failure falls back to the failure message
  /// rather than re-hanging the composer. For free-text [message]s that look
  /// loggable, signals [PalSendResult.offlineFallback] so the screen can route
  /// to the manual New Entry sheet.
  Future<PalSendResult> _handleOffline(
    StarterEntry? payload,
    String message, {
    required bool reached,
  }) async {
    final failure = reached ? _palFailedReply : _palUnreachableReply;
    if (payload != null) {
      try {
        await ref.read(entryRepositoryProvider).insert(_entryFor(payload));
        _appendAssistant(_offlineConfirmation(payload), offline: true);
      } catch (_) {
        _appendAssistant(failure, offline: true);
      }
      return PalSendResult.completed;
    }
    final loggable = _looksLoggable(message);
    _appendAssistant(loggable ? '$failure$_manualEntryHint' : failure, offline: true);
    return loggable ? PalSendResult.offlineFallback : PalSendResult.completed;
  }

  /// Builds a manual [Entry] from a starter [payload], mirroring the New Entry
  /// sheet's `_add` (negative money amounts, minutes as duration).
  Entry _entryFor(StarterEntry payload) => Entry(
        id: '',
        timestamp: clock.now(),
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

  void _appendAssistant(
    String text, {
    List<PalAction> actions = const [],
    bool offline = false,
  }) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        PalMessage(
          role: PalRole.assistant,
          text: text,
          timestamp: clock.now(),
          actions: actions,
          offline: offline,
        ),
      ],
      isLoading: false,
    );
  }

  /// Reverses one [action] of the assistant message at [index]: deletes what it
  /// created or restores the goal it changed, and marks just that action undone
  /// so the turn's other rows stay as they are.
  Future<void> undo(int index, int action) async {
    final rec = _take(index, action);
    if (rec == null) return;
    await reversePalAction(ref, rec);

    final messages = [...state.messages];
    final m = messages[index];
    messages[index] = m.copyWith(undone: {...m.undone, action});
    state = state.copyWith(messages: messages);
  }

  /// Edits one logged [action] of the assistant message at [index]: reverses it,
  /// takes it off-screen, and returns text for the composer to refill for a fix.
  /// A turn that did only this removes the whole turn (its user line too) and
  /// refills what the user typed; in a turn that did several things only this
  /// row goes, and the refill describes it alone so a resend logs nothing twice.
  /// Returns '' when there's nothing to recover.
  Future<String> editLog(int index, int action) async {
    final messages = state.messages;
    if (index < 0 || index >= messages.length) return '';
    final m = messages[index];
    if (action < 0 || action >= m.actions.length) return '';
    final rec = _take(index, action);
    if (rec != null) await reversePalAction(ref, rec);

    if (m.actions.length > 1) {
      final records = _undo[index];
      if (records != null) records.removeAt(action);
      final next = [...messages];
      next[index] = m.copyWith(
        actions: [...m.actions]..removeAt(action),
        undone: {for (final u in m.undone) if (u != action) u > action ? u - 1 : u},
      );
      state = state.copyWith(messages: next);
      return _describeForRefill(m.actions[action]);
    }
    return _removeTurn(index);
  }

  /// Takes the reversal record for [action] of message [index], once.
  AppliedAction? _take(int index, int action) {
    final records = _undo[index];
    if (records == null || action < 0 || action >= records.length) return null;
    final rec = records[action];
    records[action] = null;
    return rec;
  }

  /// Removes the turn ending at assistant message [index] (and the user line
  /// before it) and returns that user text.
  String _removeTurn(int index) {
    final messages = state.messages;
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
    final rebuilt = <int, List<AppliedAction?>>{};
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

  /// One logged action as the user might retype it, for an Edit refill.
  String _describeForRefill(PalAction action) {
    final currency = ref.read(appSettingsControllerProvider).currency;
    return switch (action) {
      LogEntryAction(type: EntryType.money, :final amount?) =>
        '${action.title} ${formatCurrency(amount, currency, withSign: true)}',
      LogEntryAction(type: EntryType.move, :final durationMinutes?) =>
        '${action.title} $durationMinutes min',
      LogEntryAction() => action.title,
      LogMealAction() => action.name,
      SetGoalAction() || CreateRoutineAction() => '',
    };
  }
}
