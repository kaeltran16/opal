import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../analysis/correlations.dart';
import '../theme/theme.dart';
import '../widgets/correlation_view.dart';
import 'app_icon.dart';
import 'press_scale.dart';

/// A surfaced cross-dimension correlation: eyebrow, narrated (or templated)
/// body, and a tap-to-reveal trust sheet. Tapping opens [showCorrelationTrustSheet].
class CorrelationCard extends StatelessWidget {
  const CorrelationCard({super.key, required this.correlation, this.narration});

  final Correlation correlation;
  final String? narration;

  // kept for any callers that still reference them directly
  static String _label(Dimension d) => switch (d) {
        Dimension.money => 'Money',
        Dimension.move => 'Move',
        Dimension.rituals => 'Rituals',
        Dimension.nutrition => 'Nutrition',
        Dimension.sleep => 'Sleep',
        Dimension.mood => 'Mood',
      };

  static String _token(Dimension d) => _label(d).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final aColor = c.forType(_token(correlation.a));
    final bColor = c.forType(_token(correlation.b));
    final view = CorrelationView(correlation);
    // narration param wins over the templated view line
    final body = narration ?? view.line;

    return PressScale(
      onTap: () => showCorrelationTrustSheet(context, correlation),
      semanticLabel: body,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 22px gradient circle with sparkles icon
                _GradientCircle(colorA: aColor, colorB: bColor),
                const SizedBox(width: Spacing.sm),
                Text(
                  'PAL NOTICED',
                  style: AppType.caption2.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                AppIcon('chevron.right', size: 13, color: c.ink4),
              ],
            ),
            const SizedBox(height: Spacing.sm + Spacing.xs),
            Text(
              body,
              style: AppType.subhead.copyWith(
                color: c.ink,
                letterSpacing: -0.24,
                height: 1.35,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Tap to see the numbers.',
              style: AppType.footnote.copyWith(color: c.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientCircle extends StatelessWidget {
  const _GradientCircle({required this.colorA, required this.colorB});
  final Color colorA;
  final Color colorB;

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorA, colorB],
          ),
        ),
        child: const Center(
          child: AppIcon('sparkles', size: 11, color: Color(0xFFFFFFFF)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Trust sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Modal bottom sheet exposing the full breakdown + provenance for a correlation.
///
/// Signature is stable — changing it would break Recap + NutritionPatterns.
Future<void> showCorrelationTrustSheet(
    BuildContext context, Correlation correlation) {
  final bg = context.colors.bg;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: bg,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (ctx) => _TrustSheetContent(correlation: correlation),
  );
}

class _TrustSheetContent extends StatelessWidget {
  const _TrustSheetContent({required this.correlation});
  final Correlation correlation;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final view = CorrelationView(correlation);
    final cA = c.forType(correlation.a.name);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.94,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Radii.lg)),
          ),
          child: Column(
            children: [
              // grabber + header — non-scrolling sticky
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.md, Spacing.sm, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // grabber
                    Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.ink4.withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      children: [
                        _PairTag(correlation: correlation, colors: c),
                        const Spacer(),
                        // close button
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c.fill,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: AppIcon('xmark',
                                  size: 13, color: c.ink3),
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.xs),
                      ],
                    ),
                    const SizedBox(height: Spacing.lg),
                  ],
                ),
              ),
              // scrollable body
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.lg, 0, Spacing.lg, Spacing.xxxl),
                  children: [
                    // claim
                    Text(
                      view.claim,
                      style: AppType.title3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),

                    // side-by-side comparison card — only when breakdown exists
                    if (view.compareLow != null) ...[
                      _SideBySideCard(
                          view: view, cA: cA, colors: c),
                      const SizedBox(height: Spacing.md),
                    ],

                    // underlying numbers card — only when numbers is non-empty
                    if (view.numbers.isNotEmpty) ...[
                      _NumbersCard(numbers: view.numbers, colors: c),
                      const SizedBox(height: Spacing.md),
                    ],

                    // source row
                    Row(
                      children: [
                        AppIcon('heart.fill',
                            size: 13, color: c.ink4),
                        const SizedBox(width: Spacing.xs),
                        Expanded(
                          child: Text(
                            view.source,
                            style: AppType.caption.copyWith(
                                color: c.ink3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),

                    // "why you're seeing this" box
                    _WhyBox(why: view.why, colors: c),
                    const SizedBox(height: Spacing.md),

                    // Ask Pal button
                    _AskPalButton(claim: view.claim, colors: c),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── PairTag ─────────────────────────────────────────────────────────────────

class _PairTag extends StatelessWidget {
  const _PairTag({required this.correlation, required this.colors});
  final Correlation correlation;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final aColor = colors.forType(correlation.a.name);
    final bColor = colors.forType(correlation.b.name);
    final view = CorrelationView(correlation);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundDot(color: aColor),
        const SizedBox(width: Spacing.xs),
        _RoundDot(color: bColor),
        const SizedBox(width: Spacing.sm),
        Text(
          view.pairLabel.toUpperCase(),
          style: AppType.caption2.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.ink3,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _RoundDot extends StatelessWidget {
  const _RoundDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ─── Side-by-side card ───────────────────────────────────────────────────────

class _SideBySideCard extends StatelessWidget {
  const _SideBySideCard({
    required this.view,
    required this.cA,
    required this.colors,
  });
  final CorrelationView view;
  final Color cA;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final low = view.compareLow!;
    // compareHigh may theoretically be null if compareLow is not, but both
    // are driven by the same breakdown null-check — safe to use ! here.
    final high = view.compareHigh!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIDE BY SIDE',
            style: AppType.caption2.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.ink3,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: Spacing.md),
          _CompareRow(item: low, strong: true, cA: cA, colors: colors),
          const SizedBox(height: Spacing.md),
          _CompareRow(item: high, strong: false, cA: cA, colors: colors),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.item,
    required this.strong,
    required this.cA,
    required this.colors,
  });
  final CompareItem item;
  final bool strong;
  final Color cA;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.label,
                style:
                    AppType.subhead.copyWith(color: colors.ink2)),
            Text(
              item.value,
              style: AppType.subhead.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        LayoutBuilder(
          builder: (_, constraints) {
            final trackW = constraints.maxWidth;
            return Stack(
              children: [
                // track
                Container(
                  height: 8,
                  width: trackW,
                  decoration: BoxDecoration(
                    color: cA.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                ),
                // fill
                Container(
                  height: 8,
                  width: (trackW * item.frac).clamp(0.0, trackW),
                  decoration: BoxDecoration(
                    color: strong
                        ? cA
                        : cA.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Underlying numbers card ─────────────────────────────────────────────────

class _NumbersCard extends StatelessWidget {
  const _NumbersCard({required this.numbers, required this.colors});
  final List<(String, String)> numbers;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        children: [
          for (var i = 0; i < numbers.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: colors.hair),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.md),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(numbers[i].$1,
                      style: AppType.footnote.copyWith(
                          color: colors.ink2,
                          fontSize: 14.5)),
                  Text(numbers[i].$2,
                      style: AppType.footnote.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                          fontSize: 14.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Why box ─────────────────────────────────────────────────────────────────

class _WhyBox extends StatelessWidget {
  const _WhyBox({required this.why, required this.colors});
  final String why;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon('sparkles', size: 13, color: colors.ink3),
              const SizedBox(width: Spacing.xs),
              Text(
                "WHY YOU'RE SEEING THIS",
                style: AppType.caption2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.ink3,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            why,
            style: AppType.footnote.copyWith(
              color: colors.ink2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ask Pal button ───────────────────────────────────────────────────────────

class _AskPalButton extends StatelessWidget {
  const _AskPalButton({required this.claim, required this.colors});
  final String claim;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(
          '/pal-composer?seed=${Uri.encodeComponent(claim)}'),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: colors.hair, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.md + Spacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon('sparkles', size: 16, color: colors.accent),
            const SizedBox(width: Spacing.sm),
            Text(
              'Ask Pal about this',
              style: AppType.callout.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
