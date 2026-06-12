import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'pal_action_executor.dart';
import 'providers.dart';

part 'pal_composer_controller.g.dart';

/// Message shown when Pal is unreachable and there's nothing to log locally.
const _palOfflineReply =
    "Pal couldn't reach the server. You can still log this from the New Entry "
    'sheet.';

/// A structured quick-log payload attached to a concrete starter chip. When Pal
/// is offline, [PalComposerController.sendStarter] writes this as a local
/// [Entry] instead of hanging. Open-prompt starters carry no payload (null).
class StarterEntry {
  const StarterEntry({
    required this.type,
    required this.title,
    this.amount,
    this.category,
    this.durationMinutes,
  });

  final EntryType type;
  final String title;

  /// Money only. Pre-signed (negative = expense), mirroring [Entry.amount].
  final double? amount;
  final String? category;
  final int? durationMinutes;
}

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
      await applyPalActions(ref, result.actions);
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
    final detail = switch (payload.type) {
      EntryType.money when payload.amount != null =>
        ' · -\$${payload.amount!.abs().toStringAsFixed(2)}',
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
}
