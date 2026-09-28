import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/nav_bar.dart';

/// The shared header for tab roots and the screens nested under Today. The
/// ask bar replaces the old Pal orb and You is a tab, so the only trailing
/// widget is one tab-specific [contextualAction]; the leading is a back
/// button whenever the route can pop (Sleep, Mood and Rituals under Today).
class TabHeaderScrollView extends StatelessWidget {
  const TabHeaderScrollView({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.largeTitle,
    this.contextualAction,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? largeTitle;

  /// The single tab-specific trailing action; null = none.
  final Widget? contextualAction;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    // the route's own navigator, not GoRouter.canPop: a sheet pushed over a
    // tab root would otherwise give the root a back button on rebuild.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return LargeTitleScrollView(
      title: title,
      subtitle: subtitle,
      eyebrow: eyebrow,
      largeTitle: largeTitle,
      controller: controller,
      padding: padding,
      leading: canPop
          ? NavAction(
              icon: 'chevron.left',
              label: 'Back',
              semanticLabel: 'Back',
              onTap: () => context.pop(),
            )
          : null,
      trailing: contextualAction,
      children: children,
    );
  }
}
