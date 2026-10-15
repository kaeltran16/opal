import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'pal_label.dart';

const double _leadGap = Spacing.sm;
const double _leadMaxWidth = 330;
// the lines Pal's line may take in the serif before it steps down to body.
const int _leadMaxLines = 3;
const double _cardGap = 14;
const double _sideShare = 0.5;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Pal's line in the serif under its label: the lead of a screen.
class PalLead extends StatelessWidget {
  const PalLead({super.key, this.label = 'Pal', required this.text, this.muted = false});

  final String label;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _leadGap,
        children: [
          PalLabel(text: label),
          PalLeadText(text, color: muted ? c.ink3 : c.ink),
        ],
      ),
    );
  }
}

/// Pal's line itself: the serif `lead` while it fits three lines, else `body`
/// at full length. A Pal sentence is never cut short.
class PalLeadText extends StatelessWidget {
  const PalLeadText(this.text, {super.key, required this.color, this.maxWidth = _leadMaxWidth});

  final String text;
  final Color color;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final lead = AppType.lead.copyWith(color: color);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: LayoutBuilder(builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: lead),
          maxLines: _leadMaxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth);
        final fits = !painter.didExceedMaxLines;
        painter.dispose();
        return Text(text, style: fits ? lead : AppType.body.copyWith(color: color));
      }),
    );
  }
}

/// The lead's one card: when, what, a primary and at most one secondary.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.meta,
    required this.title,
    required this.primary,
    this.secondary,
  });

  final String meta;
  final String title;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final secondary = this.secondary;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _cardGap,
        children: [
          // when and what are one heading, apart from the buttons below it
          Semantics(
            container: true,
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Spacing.xxs,
              children: [
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: c.ink3, fontFeatures: _tabular)),
                Text(title, style: AppType.title.copyWith(color: c.ink)),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, box) => Row(
              spacing: Spacing.sm,
              children: [
                // each button its own stop, apart from the heading
                Expanded(child: Semantics(container: true, child: primary)),
                if (secondary != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * _sideShare),
                    child: Semantics(container: true, child: secondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
