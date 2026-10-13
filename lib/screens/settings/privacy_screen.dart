import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';

const double _rowMinHeight = 56;
const double _linkMinHeight = 48;
const double _hairline = 1;
const double _chevron = 14;

/// You → Data and privacy.
///
/// Opal is local-first, so this explains what is stored on the device and the
/// only two cases where data leaves it (Pal and email sync, both opt-in), then
/// links to exporting data and notification settings. No toggles — there is
/// nothing collected to turn off.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      eyebrow: 'Settings',
      title: 'Data and privacy',
      children: [
        const SizedBox(height: Spacing.xxl),
        const _Heading('Your data'),
        const SizedBox(height: Spacing.sm),
        const _FactRow(
          title: 'Stored on this device',
          subtitle: 'A local database — no cloud account.',
        ),
        const _FactRow(
          title: 'No tracking',
          subtitle: 'No third-party analytics or trackers.',
        ),
        const _Footer('Opal has no account and no analytics. Your timeline never '
            'leaves the device unless you use a feature below.'),
        const SizedBox(height: Spacing.xxl),
        const _Heading('When data leaves your device'),
        const SizedBox(height: Spacing.sm),
        const _FactRow(
          title: 'Pal',
          subtitle: 'Text you send to Pal is processed to reply.',
        ),
        const _FactRow(
          title: 'Pal memory',
          subtitle: 'Facts you mention and patterns Pal learns, '
              'stored to personalize replies. Clear anytime in Pal.',
        ),
        const _FactRow(
          title: 'Email sync',
          subtitle: 'Only if connected; reads filtered bank alerts.',
        ),
        const _Footer('Both are opt-in and only send what each feature needs.'),
        const SizedBox(height: Spacing.xxl),
        _LinkRow(
          title: 'Export data',
          onTap: () => context.pushNamed(AppRoute.exportData.name),
        ),
        _LinkRow(
          title: 'Notifications',
          onTap: () => context.pushNamed(AppRoute.notificationSettings.name),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text, style: AppType.headline.copyWith(color: context.colors.ink)),
      );
}

/// A section's closing note, under a hairline.
class _Footer extends StatelessWidget {
  const _Footer(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(top: Spacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Text(text, style: AppType.subhead.copyWith(color: c.ink3)),
    );
  }
}

/// A read-only hairline row: what is true, then why.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: AppType.callout.copyWith(color: c.ink)),
          const SizedBox(height: Spacing.xxs),
          Text(subtitle, style: AppType.subhead.copyWith(color: c.ink3)),
        ],
      ),
    );
  }
}

/// A hairline row that opens another screen.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      child: PressScale(
        onTap: onTap,
        semanticLabel: title,
        child: Container(
          constraints: const BoxConstraints(minHeight: _linkMinHeight),
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.hair, width: _hairline)),
          ),
          child: Row(
            children: [
              Expanded(child: Text(title, style: AppType.callout.copyWith(color: c.ink))),
              const SizedBox(width: Spacing.sm),
              AppIcon('chevron.right', size: _chevron, color: c.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
