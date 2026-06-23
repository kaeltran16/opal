import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

/// The Dimensions hub — a list off Today linking to the secondary dimensions
/// (Sleep & Mood). Built to extend: future dimensions drop in as more rows.
class DimensionsHubScreen extends StatelessWidget {
  const DimensionsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LargeTitleScrollView(
      title: 'Dimensions',
      // fixed bottom inset clearing the floating tab bar / FAB (matches Today).
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const SizedBox(height: Spacing.sm),
        InsetSection(
          // solid dimension-color tiles (white glyph) match the timeline rows;
          // ListRow paints its glyph onAccent, so a pale tint would be invisible.
          children: [
            ListRow(
              icon: 'moon.stars.fill',
              iconBg: c.sleep,
              title: 'Sleep',
              subtitle: 'Synced from Health',
              onTap: () => context.pushNamed(AppRoute.sleep.name),
            ),
            ListRow(
              icon: 'heart.fill',
              iconBg: c.mood,
              title: 'Mood',
              subtitle: "How you've been feeling",
              onTap: () => context.pushNamed(AppRoute.mood.name),
              last: true,
            ),
          ],
        ),
      ],
    );
  }
}
