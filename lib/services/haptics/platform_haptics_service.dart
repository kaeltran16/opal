import 'dart:async';

import 'package:flutter/services.dart';

import 'haptics_service.dart';

/// Default [HapticsService] backed by Flutter's [HapticFeedback].
///
/// On iOS these map to the Taptic Engine; on web/Windows the platform channel
/// calls are silent no-ops, so this is safe to use everywhere. The feel is only
/// verifiable on a real device (U27).
class PlatformHapticsService implements HapticsService {
  const PlatformHapticsService();

  @override
  void light() => unawaited(HapticFeedback.lightImpact());

  @override
  void medium() => unawaited(HapticFeedback.mediumImpact());

  @override
  void success() => unawaited(HapticFeedback.heavyImpact());
}
