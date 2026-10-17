import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictation for the Pal composer: speech in, the words heard so far out.
///
/// iOS runs the system recognizer through `speech_to_text`. Everywhere else
/// wire [NoopSpeechService], which hides the mic.
abstract interface class SpeechService {
  /// Whether this platform can dictate at all. False hides the mic.
  bool get supported;

  /// Whether dictation can start now. Asks for mic and speech recognition
  /// permission the first time; false once either is refused.
  Future<bool> ready();

  /// Dictates until the speaker pauses or [stop] is called. Emits everything
  /// heard so far, not just the newest words, and closes when recognition
  /// ends. Call only after [ready] answers true.
  Stream<String> listen();

  /// Ends dictation; the last words heard arrive before the stream closes.
  Future<void> stop();
}

/// No dictation (web, tests, desktop, Android).
class NoopSpeechService implements SpeechService {
  const NoopSpeechService();

  @override
  bool get supported => false;

  @override
  Future<bool> ready() async => false;

  @override
  Stream<String> listen() => const Stream.empty();

  @override
  Future<void> stop() async {}
}

/// The system recognizer, through `speech_to_text`. The plugin is a
/// singleton that takes its status and error listeners once, so one instance
/// serves every session.
class PluginSpeechService implements SpeechService {
  final SpeechToText _stt = SpeechToText();
  StreamController<String>? _words;

  @override
  bool get supported => true;

  @override
  Future<bool> ready() async {
    try {
      return await _stt.initialize(onStatus: _onStatus, onError: _onError);
    } on PlatformException catch (e) {
      debugPrint('dictation unavailable: $e');
      return false;
    }
  }

  @override
  Stream<String> listen() {
    _close();
    final words = _words = StreamController<String>();
    _stt
        .listen(
          onResult: (r) {
            if (!words.isClosed) words.add(r.recognizedWords);
            if (r.finalResult) words.close();
          },
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.dictation,
            autoPunctuation: true,
            cancelOnError: true,
          ),
        )
        .catchError((Object e) {
          debugPrint('dictation failed to start: $e');
          _close();
        });
    return words.stream;
  }

  @override
  Future<void> stop() => _stt.stop();

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus) _close();
  }

  void _onError(SpeechRecognitionError e) {
    debugPrint('dictation error: ${e.errorMsg}');
    _close();
  }

  void _close() {
    _words?.close();
    _words = null;
  }
}
