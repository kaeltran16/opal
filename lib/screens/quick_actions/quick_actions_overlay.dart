import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';
import '../../router.dart';

/// Screen 03 — Quick Actions overlay.
///
/// A full-screen dim overlay (rgba(0,0,0,0.35)) holding a 2×3 grid of six
/// action tiles. Triggered by the center FAB in [LoopShell]. Closes via the
/// "×" (top-right) or by tapping outside the grid. Entrance is a scale-up of
/// the grid from the FAB with the backdrop fading in (driven by the route's
/// transition animation).
///
/// Tiles route to the relevant screen/sheet; targets that belong to later
/// units fall back to existing stubs and are marked with a `// TODO Uxx`.
class QuickActionsOverlay extends StatelessWidget {
  const QuickActionsOverlay({super.key, this.animation});

  /// The route transition animation (0→1 on enter). Drives the backdrop fade
  /// and the grid scale-up. Falls back to a static (already-shown) value when
  /// pumped without a transition (e.g. in tests).
  final Animation<double>? animation;

  static const _spec = <_ActionSpec>[
    _ActionSpec('Log expense', 'dollarsign.circle.fill', 'money'),
    _ActionSpec('Log workout', 'dumbbell.fill', 'move'),
    _ActionSpec('Start workout', 'figure.run', 'move'),
    _ActionSpec('Complete ritual', 'sparkles', 'rituals'),
    _ActionSpec('Ask Pal', 'heart.fill', 'accent'),
    _ActionSpec('Voice entry', 'paperplane.fill', 'accent'),
  ];

  void _close(BuildContext context) {
    if (context.canPop()) context.pop();
  }

  void _onTile(BuildContext context, String label) {
    // Dismiss the overlay first, then navigate to the target.
    _close(context);
    switch (label) {
      case 'Log expense':
        context.pushNamed(AppRoute.newEntry.name); // U07
      case 'Ask Pal':
        context.pushNamed(AppRoute.askPal.name); // U16
      case 'Log workout':
      case 'Start workout':
        // TODO U12/U13/U14: route to Start Workout / Active Session.
        context.pushNamed(AppRoute.newEntry.name);
      case 'Complete ritual':
        // TODO U08: route to the Rituals tab / completion sheet.
        context.pushNamed(AppRoute.newEntry.name);
      case 'Voice entry':
        // TODO U16: route to voice/NL capture (Ask Pal for now).
        context.pushNamed(AppRoute.askPal.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final anim = animation ?? const AlwaysStoppedAnimation<double>(1);
    final curved = CurvedAnimation(
      parent: anim,
      curve: const Cubic(0.2, 0.8, 0.2, 1),
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dim backdrop + tap-outside-to-close.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _close(context),
              child: FadeTransition(
                opacity: anim,
                child: const ColoredBox(color: Color(0x59000000)), // rgba(0,0,0,0.35)
              ),
            ),
          ),
          // The grid scales up from near the FAB (bottom-center) and fades in.
          Positioned.fill(
            child: FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
                alignment: const Alignment(0, 0.9),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      children: [
                        // Close "×" top-right.
                        Align(
                          alignment: Alignment.topRight,
                          child: _CloseButton(onTap: () => _close(context)),
                        ),
                        // 2×3 grid of action tiles, centered in the remaining
                        // space. Wrapped in a tap-absorbing detector so taps on
                        // the tiles don't fall through to the backdrop, and made
                        // scrollable so it never overflows on short screens.
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            child: Center(
                              child: SingleChildScrollView(
                                child: GridView.count(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 1.45,
                                  children: [
                                    for (final a in _spec)
                                      _ActionTile(
                                        spec: a,
                                        color: c.forType(a.typeToken),
                                        onTap: () =>
                                            _onTile(context, a.label),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSpec {
  const _ActionSpec(this.label, this.icon, this.typeToken);
  final String label;
  final String icon;
  final String typeToken; // 'money' | 'move' | 'rituals' | 'accent'
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.spec,
    required this.color,
    required this.onTap,
  });

  final _ActionSpec spec;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: spec.label,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.hair, width: 0.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1F000000), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type-tinted icon square (48×48).
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: AppIcon(spec.icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            // Label (SF 14/500).
            Text(
              spec.label,
              style: AppFonts.sf(
                size: 14,
                weight: FontWeight.w500,
                color: c.ink,
                letterSpacing: -0.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Close',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: c.hair, width: 0.5),
        ),
        alignment: Alignment.center,
        child: AppIcon('xmark', size: 16, color: c.ink2),
      ),
    );
  }
}
