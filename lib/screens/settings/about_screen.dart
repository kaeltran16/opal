import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../you/sub_screen.dart';

const double _rowMinHeight = 48;
const double _hairline = 1;

/// Settings → About.
///
/// App identity (name + version) and a few static facts. The version
/// constant lives only here (shown in the header and the Version row); bump it
/// on release.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.0';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SubScreen(
      eyebrow: 'Settings',
      title: 'About',
      children: [
        const SizedBox(height: Spacing.xxl),
        Text('Opal', style: AppType.title.copyWith(color: c.ink)),
        const SizedBox(height: Spacing.xxs),
        Text('Version $_version', style: AppType.subhead.copyWith(color: c.ink3)),
        const SizedBox(height: Spacing.xxl),
        const _ValueRow(title: 'Version', value: _version),
        const _ValueRow(title: 'Built with', value: 'Flutter'),
        const _ValueRow(title: 'Storage', value: 'On device'),
        Container(
          padding: const EdgeInsets.only(top: Spacing.sm),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.hair, width: _hairline)),
          ),
          child: Text('A calm tracker for money, workouts, and routines.',
              style: AppType.subhead.copyWith(color: c.ink3)),
        ),
      ],
    );
  }
}

/// A read-only hairline row: [title] at the left, [value] at the right.
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppType.callout.copyWith(color: c.ink))),
          const SizedBox(width: Spacing.md),
          Text(value, style: AppType.subhead.copyWith(color: c.ink3)),
        ],
      ),
    );
  }
}
