import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';
import '../../router.dart';

/// Screen 03 — Quick Actions sheet.
///
/// A dim overlay (rgba(0,0,0,0.4)) with a bottom-anchored surface that slides
/// up, holding a grabber, a "QUICK ACTIONS" eyebrow, and three full-width list
/// rows (44×44 tinted icon + title + subtitle + chevron). Triggered by the
/// center FAB in [LoopShell]. Closes by tapping outside.
///
/// Rows route to the relevant screen/sheet; targets that belong to later units
/// fall back to existing stubs.
class QuickActionsOverlay extends StatelessWidget {
  const QuickActionsOverlay({super.key, this.animation});

  /// The route transition animation (0→1 on enter). Drives the backdrop fade
  /// and the sheet slide-up. Falls back to a static (already-shown) value when
  /// pumped without a transition (e.g. in tests).
  final Animation<double>? animation;

  static const _spec = <_ActionSpec>[
    _ActionSpec('Log entry', 'Money, meal, or workout — natural language',
        'plus.circle.fill', 'accent'),
    _ActionSpec('Start workout', 'Pick a routine or freestyle', 'play.fill',
        'move'),
    _ActionSpec('Ask Pal', 'Chat about your patterns', 'sparkles', 'rituals'),
  ];

  void _close(BuildContext context) {
    if (context.canPop()) context.pop();
  }

  void _onRow(BuildContext context, String label) {
    // Dismiss the sheet first, then navigate to the target.
    _close(context);
    switch (label) {
      case 'Log entry':
        context.pushNamed(AppRoute.newEntry.name); // U07
      case 'Start workout':
        context.pushNamed(AppRoute.startWorkout.name); // U12 -> /move/start
      case 'Ask Pal':
        context.pushNamed(AppRoute.askPal.name); // U16
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final anim = animation ?? const AlwaysStoppedAnimation<double>(1);
    final curved = CurvedAnimation(
      parent: anim,
      curve: const Cubic(0.22, 1, 0.36, 1),
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
                child: ColoredBox(color: c.scrim),
              ),
            ),
          ),
          // Bottom-anchored sheet that slides up.
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              // Absorb taps so they don't fall through to the backdrop.
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(Radii.lg)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Grabber.
                          Center(
                            child: Container(
                              width: 36,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: Spacing.lg),
                              decoration: BoxDecoration(
                                color: c.hair,
                                borderRadius: BorderRadius.circular(Radii.xs),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                Spacing.sm, 0, Spacing.sm, Spacing.sm),
                            child: Text(
                              'QUICK ACTIONS',
                              style: AppType.caption2.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.ink3,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          for (var i = 0; i < _spec.length; i++)
                            _ActionRow(
                              spec: _spec[i],
                              color: c.forType(_spec[i].typeToken),
                              showDivider: i < _spec.length - 1,
                              onTap: () => _onRow(context, _spec[i].label),
                            ),
                        ],
                      ),
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
  const _ActionSpec(this.title, this.subtitle, this.icon, this.typeToken);
  final String title;
  final String subtitle;
  final String icon;
  final String typeToken; // 'money' | 'move' | 'rituals' | 'accent'

  String get label => title;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.spec,
    required this.color,
    required this.showDivider,
    required this.onTap,
  });

  final _ActionSpec spec;
  final Color color;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: spec.title,
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: c.hair, width: 0.5))
              : null,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              alignment: Alignment.center,
              child: AppIcon(spec.icon, size: 20, color: color),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.title,
                    style: AppType.callout.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    spec.subtitle,
                    style: AppType.footnote.copyWith(
                      color: c.ink3,
                      letterSpacing: -0.08,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            AppIcon('chevron.right', size: 14, color: c.ink4),
          ],
        ),
      ),
    );
  }
}
