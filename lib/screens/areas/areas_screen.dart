import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/area.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

/// Clears the floating tab bar and ask bar.
const double _shellOverlay = 132;

/// The Areas tab: one row per area, each opening its page.
class AreasScreen extends ConsumerWidget {
  const AreasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return LargeTitleScrollView(
      title: 'Areas',
      padding: EdgeInsets.only(
          bottom: _shellOverlay + Spacing.xxl + MediaQuery.paddingOf(context).bottom),
      children: [
        InsetSection(
          children: [
            for (final area in Area.values)
              ListRow(
                icon: area.glyph,
                iconBg: c.fill,
                iconColor: c.ink,
                title: area.title,
                // go, not push: the page sits under /areas, so back pops here.
                onTap: () => context.goNamed(areaRoute(area).name),
                last: area == Area.values.last,
              ),
          ],
        ),
      ],
    );
  }
}
