import 'dart:ui' show ImageFilter;
import 'package:flutter/widgets.dart';
import '../theme/theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

class LoopTab {
  const LoopTab(this.id, this.label, this.icon);
  final String id;
  final String label;
  final String icon;
}

const _tabs = [
  LoopTab('today', 'Today', 'house.fill'),
  LoopTab('move', 'Workout', 'figure.run'),
  LoopTab('add', '', 'plus'),
  LoopTab('nutrition', 'Nutrition', 'leaf.fill'),
  LoopTab('more', 'More', 'ellipsis'),
];

/// Blurred bottom tab bar with a raised center FAB that opens the Pal composer.
class LoopTabBar extends StatelessWidget {
  const LoopTabBar({
    super.key,
    required this.active,
    required this.onTab,
    required this.onFab,
  });

  final String active;
  final ValueChanged<String> onTab;
  final VoidCallback onFab;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xxl),
          decoration: BoxDecoration(
            color: c.blur,
            border: Border(top: BorderSide(color: c.hair, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final t in _tabs)
                if (t.id == 'add')
                  _Fab(onTap: onFab)
                else
                  Expanded(
                    child: _TabItem(
                      tab: t,
                      active: active == t.id,
                      onTap: () => onTab(t.id),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.active, required this.onTap});
  final LoopTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.accent : c.ink3;
    return PressScale(
      onTap: onTap,
      semanticLabel: '${tab.label} tab',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(tab.icon, size: 24, color: color),
            const SizedBox(height: Spacing.xs),
            Text(
              tab.label,
              style: AppType.caption2
                  .copyWith(fontWeight: FontWeight.w500, color: color, letterSpacing: 0.1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.92,
      semanticLabel: 'Pal composer',
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.only(bottom: Spacing.xxs),
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          // accent-tinted glow (not a neutral elevation shadow) — kept inline.
          boxShadow: [
            BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: AppIcon('plus', size: 22, color: c.onAccent),
      ),
    );
  }
}
