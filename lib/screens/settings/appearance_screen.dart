import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/nav_bar.dart';

/// Settings → Appearance.
///
/// Theme controls (Light/Dark brightness + accent swatch) backed by the
/// persisted [AppSettingsController]. Selections apply immediately; there is no
/// dismiss since this is a full screen pushed within the You tab.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);

    return ColoredBox(
      color: c.bg,
      child: LargeTitleScrollView(
        title: 'Appearance',
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THEME',
                    style: AppFonts.sf(
                        size: 13, color: c.ink3, letterSpacing: 0.3)),
                const SizedBox(height: 10),
                Segmented<Brightness>(
                  options: const [
                    (Brightness.light, 'Light'),
                    (Brightness.dark, 'Dark')
                  ],
                  value: settings.brightness,
                  onChanged: controller.setBrightness,
                ),
                const SizedBox(height: 24),
                Text('ACCENT',
                    style: AppFonts.sf(
                        size: 13, color: c.ink3, letterSpacing: 0.3)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final a in AppAccent.values)
                      GestureDetector(
                        onTap: () => controller.setAccent(a),
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
                              ? const AppIcon('checkmark',
                                  size: 16, color: Color(0xFFFFFFFF))
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
