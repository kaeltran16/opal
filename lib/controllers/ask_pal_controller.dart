import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/services.dart';
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

/// Owns the Ask-Pal conversation and the [PalService.chat] round-trip.
@riverpod
class AskPalController extends _$AskPalController {
  @override
  AskPalState build() => const AskPalState();

  /// Appends the user's [text], shows the typing indicator, then appends the
  /// assistant's mock reply. No-ops on empty input or while a reply is pending.
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
    );

    final reply = await ref.read(palServiceProvider).chat(history, trimmed);

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
