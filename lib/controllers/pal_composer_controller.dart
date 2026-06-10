import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/services.dart';
import 'providers.dart';

part 'pal_composer_controller.g.dart';

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

  /// Calls [PalService.chat] with [history] + [message] and appends the reply.
  Future<void> _reply(List<PalMessage> history, String message) async {
    final reply = await ref.read(palServiceProvider).chat(history, message);
    state = state.copyWith(
      messages: [
        ...state.messages,
        PalMessage(
          role: PalRole.assistant,
          text: reply,
          timestamp: DateTime.now(),
        ),
      ],
      isLoading: false,
    );
  }
}
