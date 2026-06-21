import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/inset_section.dart';
import '../email/email_nav.dart';

/// Settings hub: the single home for every settings sub-screen. Without it
/// Appearance, Privacy, and About had no entry point at all, and the You-tab
/// "Settings" row opened Budgets & goals directly.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    void open(AppRoute route) => context.pushNamed(route.name);
    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          EmailNavBar(
            title: 'Settings',
            leadingLabel: 'You',
            onLeading: () => context.pop(),
          ),
          const SizedBox(height: Spacing.sm),
          InsetSection(
            header: 'Preferences',
            children: [
              ListRow(
                icon: 'target',
                iconBg: c.money,
                title: 'Budgets & goals',
                onTap: () => open(AppRoute.budgetsGoals),
              ),
              ListRow(
                icon: 'slider.horizontal.3',
                iconBg: c.accent,
                title: 'Appearance',
                onTap: () => open(AppRoute.appearance),
              ),
              ListRow(
                icon: 'bell.fill',
                iconBg: c.red,
                title: 'Notifications',
                onTap: () => open(AppRoute.notificationSettings),
                last: true,
              ),
            ],
          ),
          InsetSection(
            header: 'Data & privacy',
            children: [
              ListRow(
                icon: 'lock.fill',
                iconBg: c.ink3,
                title: 'Privacy',
                onTap: () => open(AppRoute.privacy),
              ),
              ListRow(
                icon: 'square.and.arrow.up',
                iconBg: c.ink3,
                title: 'Export data',
                onTap: () => open(AppRoute.exportData),
                last: true,
              ),
            ],
          ),
          InsetSection(
            header: 'About',
            children: [
              ListRow(
                icon: 'book.closed.fill',
                iconBg: c.ink3,
                title: 'About Opal',
                onTap: () => open(AppRoute.about),
                last: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
