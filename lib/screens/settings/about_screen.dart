import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../email/email_nav.dart';

/// Settings → About.
///
/// App identity (glyph + name + version) and a few static facts. Version is a
/// single source here and on the Profile row; bump both together on release.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.0';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          EmailNavBar(
            title: 'About',
            leadingLabel: 'You',
            onLeading: () => context.pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon('sparkles', size: 40, color: const Color(0xFFFFFFFF)),
                ),
                const SizedBox(height: 14),
                Text(
                  'Opal',
                  style: AppFonts.sf(
                      size: 26,
                      weight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.4),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version $_version',
                  style: AppFonts.sf(
                      size: 15, color: c.ink3, letterSpacing: -0.24),
                ),
              ],
            ),
          ),
          InsetSection(
            footer: 'A calm tracker for money, workouts, and routines.',
            children: [
              ListRow(
                title: 'Version',
                value: _version,
                chevron: false,
              ),
              ListRow(
                title: 'Built with',
                value: 'Flutter',
                chevron: false,
              ),
              ListRow(
                title: 'Storage',
                value: 'On device',
                chevron: false,
                last: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
