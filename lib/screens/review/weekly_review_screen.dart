import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/insights_controller.dart';
import '../../controllers/weekly_review_controller.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';

/// Screen 17 — Weekly Review.
///
/// A Sunday ritual, the Pal-written sibling of the Monthly Review: an eyebrow +
/// headline + lede hero; a three-ring week summary of tinted stat tiles; a
/// "Wins" inset list; "Patterns" accent-bar cards; a "One thing to try"
/// gradient card seeding the Pal composer; and a "Next review" footer.
///
/// The three-ring week stats + the date eyebrows come from
/// [weeklyStatsProvider] (computed from this week's entries against goals); the
/// narrative seam lives in [weeklyReviewControllerProvider] (mirrors monthly).
/// This widget only lays out.
class WeeklyReviewScreen extends ConsumerWidget {
  const WeeklyReviewScreen({super.key});

  static const _fallbackHeadline = 'Your week in review';
  static const _fallbackLede =
      'A look at how your spending, workouts, and routines came together.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final statsAsync = ref.watch(weeklyStatsProvider);
    final stats = statsAsync.asData?.value;
    final insightsAsync = ref.watch(insightsProvider(InsightRange.week));
    final insights = insightsAsync.asData?.value;
    final headline = insights?.headline ?? _fallbackHeadline;
    final lede = insights?.lede ?? _fallbackLede;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // --- Nav: back to You + share ---------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              NavAction(
                icon: 'chevron.left',
                label: 'You',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const NavIconButton(name: 'square.and.arrow.up', semanticLabel: 'Share'),
            ],
          ),
        ),

        // --- Hero -----------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  stats == null
                      ? 'WEEKLY REVIEW'
                      : 'WEEKLY REVIEW · ${stats.rangeLabel.toUpperCase()}',
                  style: AppFonts.sf(
                      size: 12,
                      weight: FontWeight.w700,
                      color: c.accent,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(headline,
                  style: AppFonts.sf(
                      size: 30,
                      weight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.5,
                      height: 1.15)),
              const SizedBox(height: 8),
              Text(
                lede,
                style: AppFonts.sf(
                    size: 15,
                    color: c.ink3,
                    letterSpacing: -0.24,
                    height: 1.4),
              ),
            ],
          ),
        ),

        // --- Three-ring week summary ----------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(18)),
            child: statsAsync.when(
              loading: () => const _TilesPlaceholder(),
              error: (e, _) => Text("Couldn't load this week.",
                  style: AppFonts.sf(
                      size: 15, color: c.ink3, letterSpacing: -0.24)),
              data: (s) => Row(
                children: [
                  for (var i = 0; i < s.tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _StatTile(stat: s.tiles[i])),
                  ],
                ],
              ),
            ),
          ),
        ),

        // --- Wins / Patterns / One thing to try (Pal insights) --------------
        ..._qualitativeSection(context, insightsAsync.isLoading, insights),

        // --- Footer ---------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
              stats == null
                  ? 'Next review · Sunday'
                  : 'Next review · ${stats.nextReviewLabel}',
              textAlign: TextAlign.center,
              style: AppFonts.sf(
                  size: 13, color: c.ink3, letterSpacing: -0.08)),
        ),
      ],
    );
  }

  /// The Pal-found qualitative block (Wins / Patterns / One thing to try). Shows
  /// a single encouraging notice while loading or when there isn't enough data,
  /// rather than fabricating wins/patterns.
  List<Widget> _qualitativeSection(
      BuildContext context, bool loading, PalInsights? insights) {
    final c = context.colors;
    if (insights == null) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: _NoticeCard(
            text: loading
                ? 'Pal is reviewing your week…'
                : 'Keep logging through the week and Pal will gather your '
                    'wins and patterns here.',
          ),
        ),
      ];
    }
    return [
      if (insights.wins.isNotEmpty) ...[
        _SectionHeader('Wins'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Container(
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < insights.wins.length; i++)
                  _WinRow(
                    icon: insightIcon(insights.wins[i].colorToken),
                    colorToken: insights.wins[i].colorToken,
                    title: insights.wins[i].title,
                    sub: insights.wins[i].sub,
                    last: i == insights.wins.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ],
      if (insights.patterns.isNotEmpty) ...[
        _SectionHeader('Patterns'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            children: [
              for (var i = 0; i < insights.patterns.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _PatternCard(
                  colorToken: insights.patterns[i].colorToken,
                  text: insights.patterns[i].detail.isEmpty
                      ? insights.patterns[i].title
                      : '${insights.patterns[i].title} — '
                          '${insights.patterns[i].detail}',
                ),
              ],
            ],
          ),
        ),
      ],
      if (insights.suggestion != null && insights.suggestion!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: _OneThingCard(text: insights.suggestion!),
        ),
    ];
  }
}

/// A muted surface card used for the Weekly Review's loading / empty notice.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(14)),
      child: Text(text,
          style: AppFonts.sf(
              size: 15, color: c.ink3, letterSpacing: -0.24, height: 1.4)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(text,
          style: AppFonts.sf(
              size: 22,
              weight: FontWeight.w700,
              color: c.ink,
              letterSpacing: 0.35)),
    );
  }
}

/// Loading state for the three-ring summary, keeping the row's height stable.
class _TilesPlaceholder extends StatelessWidget {
  const _TilesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text('…',
        style: AppFonts.sf(size: 22, color: c.ink3, letterSpacing: -0.3));
  }
}

/// One tinted three-ring stat tile: `{color}14` bg, color label, big value, sub.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});
  final WeekStat stat;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(stat.colorToken);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.label.toUpperCase(),
              style: AppFonts.sf(
                  size: 11,
                  weight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(stat.value,
              style: AppFonts.sfr(
                  size: 22,
                  weight: FontWeight.w700,
                  color: c.ink,
                  letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(stat.sub,
              style: AppFonts.sf(
                  size: 11, color: c.ink3, letterSpacing: -0.08)),
        ],
      ),
    );
  }
}

/// One "Wins" row: type-colored icon tile + title + sub + trailing check.
class _WinRow extends StatelessWidget {
  const _WinRow({
    required this.icon,
    required this.colorToken,
    required this.title,
    required this.sub,
    required this.last,
  });
  final String icon;
  final String colorToken;
  final String title;
  final String sub;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(colorToken);
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: AppIcon(icon, size: 16, color: const Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.24)),
                const SizedBox(height: 1),
                Text(sub,
                    style: AppFonts.sf(
                        size: 12, color: c.ink3, letterSpacing: -0.08)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppIcon('checkmark', size: 14, color: color),
        ],
      ),
    );
  }
}

/// One "Patterns" card: 3px left color bar + body text on a surface card.
class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.colorToken, required this.text});
  final String colorToken;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(colorToken);
    return Container(
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 13, 14, 13),
                child: Text(text,
                    style: AppFonts.sf(
                        size: 15,
                        color: c.ink,
                        letterSpacing: -0.24,
                        height: 1.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "One thing to try" gradient card: gradient sparkle circle + uppercase label
/// + suggestion + "Ask Pal more" pill that opens the Pal composer pre-filled.
class _OneThingCard extends StatelessWidget {
  const _OneThingCard({required this.text});
  final String text;

  static const _seed = 'Tell me more about this week';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.accent.withValues(alpha: 0.07),
            c.rituals.withValues(alpha: 0.07),
          ],
        ),
        border:
            Border.all(color: c.accent.withValues(alpha: 0.20), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.accent, c.rituals],
                  ),
                ),
                alignment: Alignment.center,
                child: const AppIcon('sparkles',
                    size: 11, color: Color(0xFFFFFFFF)),
              ),
              const SizedBox(width: 8),
              Text('ONE THING TO TRY',
                  style: AppFonts.sf(
                      size: 12,
                      weight: FontWeight.w700,
                      color: c.ink3,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppFonts.sf(
                size: 17, color: c.ink, letterSpacing: -0.43, height: 1.4),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go(
                '/pal-composer?seed=${Uri.encodeComponent(_seed)}'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('Ask Pal more',
                  style: AppFonts.sf(
                      size: 14,
                      weight: FontWeight.w600,
                      color: const Color(0xFFFFFFFF),
                      letterSpacing: -0.15)),
            ),
          ),
        ],
      ),
    );
  }
}
