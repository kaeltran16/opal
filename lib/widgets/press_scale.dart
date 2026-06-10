import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/providers.dart';

/// Press-scale feedback wrapper matching the handoff interaction spec: buttons
/// scale down for 80ms while pressed (0.97 default; 0.92 for the FAB) and fire a
/// light haptic on press-down (routed through [HapticsService] — no-op on web).
class PressScale extends ConsumerStatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;
  final String? semanticLabel;

  @override
  ConsumerState<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends ConsumerState<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (down && widget.haptic) ref.read(hapticsServiceProvider).light();
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = AnimatedScale(
      scale: _down ? widget.pressedScale : 1.0,
      duration: const Duration(milliseconds: 80),
      child: widget.child,
    );
    if (enabled) {
      child = Semantics(button: true, label: widget.semanticLabel, child: child);
    }
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
