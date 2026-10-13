import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/providers.dart';
import '../../theme/theme.dart';
import '../../widgets/controls.dart';
import '../you/sub_screen.dart';

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

    return SubScreen(
      eyebrow: 'Settings',
      title: 'Appearance',
      children: [
        const SizedBox(height: Spacing.xxl),
        Semantics(
          header: true,
          child: Text('Theme', style: AppType.headline.copyWith(color: c.ink)),
        ),
        const SizedBox(height: Spacing.md),
        Segmented<Brightness>(
          options: const [(Brightness.light, 'Light'), (Brightness.dark, 'Dark')],
          value: settings.brightness,
          onChanged: controller.setBrightness,
        ),
      ],
    );
  }
}
