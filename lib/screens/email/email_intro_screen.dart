import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/email_sync_controller.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';
import 'email_dashboard_screen.dart';

const double _pillHeight = 48;
const double _rowHeight = 56;
const double _hairline = 1;
const double _leadIcon = 28;
const double _rowIcon = 20;

/// Email sync intro: what it does, how it works, and Connect, which opens
/// Gmail setup.
class EmailIntroScreen extends ConsumerWidget {
  const EmailIntroScreen({super.key});

  static const _steps = <(String icon, String title, String sub)>[
    (
      'bell.fill',
      'Your bank sends alerts',
      '"You spent \$12.40 at Blue Bottle" — most cards do this',
    ),
    (
      'magnifyingglass',
      'Pal reads only those',
      'Filtered by sender list before anything is parsed',
    ),
    (
      'sparkles',
      'It lands on Today',
      'Categorized, deduped, tagged as synced',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // the intro is the `/email` entry and the back-stop beneath setup and the
    // dashboard, so a connected account must surface the dashboard here, or
    // backing out of setup lands on this pitch and the connection looks lost.
    // disconnecting there rebuilds this screen into the pitch, so it must not pop.
    if (ref.watch(emailDashboardControllerProvider).isConnected) {
      return const EmailDashboardScreen(popOnDisconnect: false);
    }
    final c = context.colors;
    final quiet = AppType.subhead.copyWith(color: c.ink3);

    return SubScreen(
      eyebrow: 'Settings',
      title: 'Email sync',
      children: [
        const SizedBox(height: Spacing.xxl),
        AppIcon('tray.fill', size: _leadIcon, color: c.ink2),
        const SizedBox(height: Spacing.md),
        Text('Stop logging card charges by hand.',
            style: AppType.headline.copyWith(color: c.ink)),
        const SizedBox(height: Spacing.sm),
        Text(
          'Connect your inbox with a read-only app password. Pal scans for bank '
          'alert emails in the background and drops them on your timeline — '
          'categorized, deduped, silent.',
          style: AppType.subhead.copyWith(color: c.ink2),
        ),
        const SizedBox(height: Spacing.xxxl),
        Semantics(
          header: true,
          child: Text('How it works', style: AppType.headline.copyWith(color: c.ink)),
        ),
        const SizedBox(height: Spacing.sm),
        for (final step in _steps) _StepRow(step: step),
        const SizedBox(height: Spacing.lg),
        Text(
          'App password, not your real one. You generate a disposable password '
          'in your email settings — Pal stores it encrypted in the iOS keychain. '
          'Revoke it anytime from Gmail without touching anything else.',
          style: quiet,
        ),
        const SizedBox(height: Spacing.xxl),
        _ConnectPill(onTap: () => context.pushNamed('emailSetup')),
        const SizedBox(height: Spacing.md),
        Text('iCloud, Outlook, any IMAP coming',
            textAlign: TextAlign.center, style: quiet),
      ],
    );
  }
}

/// One "How it works" step under a hairline: icon, title and detail.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final (String, String, String) step;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, title, sub) = step;
    return Container(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: _rowIcon, color: c.ink2),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.callout.copyWith(color: c.ink)),
                const SizedBox(height: Spacing.xxs),
                Text(sub, style: AppType.subhead.copyWith(color: c.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The screen's one primary pill.
class _ConnectPill extends StatelessWidget {
  const _ConnectPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Connect',
      child: Container(
        constraints: const BoxConstraints(minHeight: _pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        alignment: Alignment.center,
        child: Text('Connect', style: AppType.headline.copyWith(color: c.bg)),
      ),
    );
  }
}
