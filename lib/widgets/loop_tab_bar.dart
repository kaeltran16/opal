import 'dart:ui' show ImageFilter;
import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';

class LoopTab {
  const LoopTab(this.id, this.label, this.icon);
  final String id;
  final String label;
  final String icon;
}

const _tabs = [
  LoopTab('today', 'Today', 'house.fill'),
  LoopTab('move', 'Move', 'figure.run'),
  LoopTab('add', '', 'plus'),
  LoopTab('rituals', 'Rituals', 'sparkles'),
  LoopTab('profile', 'You', 'person.crop.circle.fill'),
];

/// Blurred bottom tab bar with a raised center FAB (Quick Actions).
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
          padding: const EdgeInsets.only(top: 8, bottom: 24),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(tab.icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: AppFonts.sf(
                  size: 10, weight: FontWeight.w500, color: color, letterSpacing: 0.1),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: const AppIcon('plus', size: 22, color: Color(0xFFFFFFFF)),
      ),
    );
  }
}
