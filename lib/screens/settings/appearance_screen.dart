import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/press_scale.dart';
import '../email/email_nav.dart';

/// Settings → Appearance.
///
/// Theme controls (Light/Dark brightness + accent swatch) backed by the
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
        padding: const EdgeInsets.only(bottom: 40),
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
          InsetSection(
            header: 'Accent',
            children: [
              Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Wrap(
                  spacing: Spacing.lg,
                  runSpacing: Spacing.lg,
                  children: [
                    for (final a in AppAccent.values)
                      PressScale(
                        onTap: () => controller.setAccent(a),
                        semanticLabel: a.label,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: settings.brightness == Brightness.dark
                                ? a.dark()
                                : a.light(),
                            shape: BoxShape.circle,
                            border: a == settings.accent
                                ? Border.all(color: c.ink, width: 2)
                                : Border.all(color: c.hair, width: 0.5),
                          ),
                          child: a == settings.accent
                              ? AppIcon('checkmark',
                                  size: 16, color: c.onAccent)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
