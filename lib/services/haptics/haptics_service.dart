/// The haptics seam (ritual toggle, set-complete, rest-timer ticks).
///
/// Wraps Flutter's `HapticFeedback`. On web/Windows it is a no-op (feel is only
/// verifiable on device). light/medium/success map to
/// lightImpact/mediumImpact/heavyImpact on iOS (U21/U27 wire the call-sites).
abstract interface class HapticsService {
  Future<void> light();
  Future<void> medium();
  Future<void> success();
}
