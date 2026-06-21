import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/pal_avatar.dart';
import '../../widgets/press_scale.dart';

/// The shared header for the four tab roots. Single source of truth for the
/// top-nav pattern: a Profile avatar (leading) and a Pal orb (trailing) on
/// every tab, plus one tab-specific [contextualAction] after the orb.
///
/// Pushed/secondary screens keep using [LargeTitleScrollView] directly — they
/// must not inherit these anchors, so the anchors live here, not in the base.
class TabHeaderScrollView extends StatelessWidget {
  const TabHeaderScrollView({
    super.key,
    required this.title,
    this.subtitle,
    this.contextualAction,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final String title;
  final String? subtitle;

  /// The single tab-specific action shown after the Pal orb; null = none.
  final Widget? contextualAction;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LargeTitleScrollView(
      title: title,
      subtitle: subtitle,
      controller: controller,
      padding: padding,
      leading: PressScale(
        semanticLabel: 'You',
        onTap: () => context.pushNamed(AppRoute.you.name),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AppIcon('person.crop.circle.fill', size: 30, color: c.accent),
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressScale(
            semanticLabel: 'Open Pal',
            onTap: () => context.pushNamed(AppRoute.pal.name),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                  child: PalAvatar(size: 32, glyphSize: 16, glow: true)),
            ),
          ),
          if (contextualAction != null) ...[
            const SizedBox(width: Spacing.sm),
            contextualAction!,
          ],
        ],
      ),
      children: children,
    );
  }
}
