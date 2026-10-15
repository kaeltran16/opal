/// The haptics seam (ritual toggle, set-complete, rest-timer ticks).
///
/// Wraps Flutter's `HapticFeedback`. On web/Windows it is a no-op (feel is only
/// verifiable on device). light/medium/success map to
/// lightImpact/mediumImpact/heavyImpact on iOS (U21/U27 wire the call-sites).
///
/// Fire-and-forget: a cue never holds up the action it accompanies, so a save
/// cannot wait on a platform channel. A failed cue still surfaces as an
/// uncaught error.
abstract interface class HapticsService {
  void light();
  void medium();
  void success();
}
