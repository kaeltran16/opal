import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';

// kept literal: the shell overlay under the content, tab bar gap 8 + bar 62 +
// gap 10 + ask bar 52.
const double kSubScreenShellOverlay = 132;
// kept literal: where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _minTap = 44;
const double _backIcon = 24;
// the chevron hangs into the gutter so its stroke lines up with the text edge.
const double _backHang = Spacing.sm;

/// A screen pushed from You: a back control to [backLabel], an [eyebrow] over
/// a [title], then [children].
class SubScreen extends StatelessWidget {
  const SubScreen({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.children,
    this.backLabel = 'You',
  });

  final String eyebrow;
  final String title;
  final List<Widget> children;

  /// The screen the back control returns to.
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final safe = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.lg,
          math.max(_contentTop, safe.top + Spacing.xs),
          Spacing.lg,
          kSubScreenShellOverlay + Spacing.xxl + safe.bottom,
        ),
        children: [
          _BackHeader(label: backLabel),
          const SizedBox(height: Spacing.md + Spacing.sm),
          Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: AppType.label.copyWith(color: c.ink3)),
                const SizedBox(height: Spacing.xxs),
                Text(title, style: AppType.title.copyWith(color: c.ink)),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Back to [label] at the left.
class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Transform.translate(
        offset: const Offset(-_backHang, 0),
        child: PressScale(
          onTap: () => Navigator.of(context).pop(),
          semanticLabel: 'Back to $label',
          child: Container(
            constraints: const BoxConstraints(minHeight: _minTap),
            padding: const EdgeInsets.only(right: Spacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon('chevron.left', size: _backIcon, color: c.ink),
                const SizedBox(width: Spacing.xxs),
                Text(label, style: AppType.headline.copyWith(color: c.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
