import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../theme/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/inset_section.dart';
import '../email/email_nav.dart';

/// Settings → Appearance.
///
/// Theme control (Light/Dark brightness) backed by the
/// persisted [AppSettingsController]. Selections apply immediately; a 'You'
/// back action pops the screen, matching the sibling settings screens.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);

    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40), // kept literal: off-grid list bottom inset
        children: [
          EmailNavBar(
            title: 'Appearance',
            leadingLabel: 'You',
            onLeading: () => context.pop(),
          ),
          const SizedBox(height: Spacing.sm),
          InsetSection(
            header: 'Theme',
            children: [
              Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Segmented<Brightness>(
                  options: const [
                    (Brightness.light, 'Light'),
                    (Brightness.dark, 'Dark')
                  ],
                  value: settings.brightness,
                  onChanged: controller.setBrightness,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
