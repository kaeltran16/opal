import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../widgets/inset_section.dart';
import '../email/email_nav.dart';

/// Settings → Privacy.
///
/// Informational: Opal is local-first, so this explains what is stored on the
/// device and the only two cases where data leaves it (Pal and email sync,
/// both opt-in). No toggles — there is nothing collected to turn off.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          EmailNavBar(
            title: 'Privacy',
            leadingLabel: 'Settings',
            onLeading: () => context.pop(),
          ),
          const SizedBox(height: Spacing.sm),
          InsetSection(
            header: 'Your data',
            footer: 'Opal has no account and no analytics. Your timeline never '
                'leaves the device unless you use a feature below.',
            children: [
              ListRow(
                icon: 'lock.fill',
                iconBg: c.ink3,
                title: 'Stored on this device',
                subtitle: 'A local database — no cloud account.',
                chevron: false,
              ),
              ListRow(
                icon: 'person.crop.circle.fill',
                iconBg: c.ink3,
                title: 'No tracking',
                subtitle: 'No third-party analytics or trackers.',
                chevron: false,
                last: true,
              ),
            ],
          ),
          InsetSection(
            header: 'When data leaves your device',
            footer: 'Both are opt-in and only send what each feature needs.',
            children: [
              ListRow(
                icon: 'sparkles',
                iconBg: c.accent,
                title: 'Pal',
                subtitle: 'Text you send to Pal is processed to reply.',
                chevron: false,
              ),
              ListRow(
                icon: 'brain.head.profile',
                iconBg: c.accent,
                title: 'Pal memory',
                subtitle: 'Facts you mention and patterns Pal learns, '
                    'stored to personalize replies. Clear anytime in Pal.',
                chevron: false,
              ),
              ListRow(
                icon: 'envelope.fill',
                iconBg: c.accent,
                title: 'Email sync',
                subtitle: 'Only if connected; reads filtered bank alerts.',
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
