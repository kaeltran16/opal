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
/// Opal is local-first, so this explains what is stored on the device and what
/// leaves it: Pal, which reads the timeline on its own whenever its surfaces
/// load, the memory it keeps server-side, and email sync, the one opt-in. Then
/// links to exporting data and notification settings.
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
        const _Footer('Opal has no account and no analytics. Data leaves the '
            'device only through the features below.'),
        const SizedBox(height: Spacing.xxl),
        const _Heading('When data leaves your device'),
        const SizedBox(height: Spacing.sm),
        const _FactRow(
          title: 'Pal',
          subtitle: 'When Today, You or Recap load, Pal gets your timeline: '
              'entry titles, merchants, amounts and times, workouts and goals. '
              'Anything you type to Pal is sent too.',
        ),
        const _FactRow(
          title: 'Pal memory',
          subtitle: 'Facts you mention and patterns Pal finds in your timeline, '
              "kept on Pal's server to personalize replies. Clear anytime in Pal.",
        ),
        const _FactRow(
          title: 'Email sync',
          subtitle: 'Only if you connect it; reads filtered bank alerts and receipts.',
        ),
        const _Footer('Email sync is opt-in. Pal is part of the app and reads your '
            'timeline without you typing anything.'),
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
