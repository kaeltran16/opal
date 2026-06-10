import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/weekly_review_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';

/// Screen 17 — Weekly Review (mock).
///
/// A Sunday ritual, the Pal-written sibling of the Monthly Review: an eyebrow +
/// headline + lede hero; a three-ring week summary of tinted stat tiles; a
/// "Wins" inset list; "Patterns" accent-bar cards; a "One thing to try"
/// gradient card seeding the Pal composer; and a "Next review" footer.
///
/// The three-ring week stats are the canned [kWeeklyReviewStats]; the
/// narrative seam lives in [weeklyReviewControllerProvider] (mirrors monthly).
/// This widget only lays out.
class WeeklyReviewScreen extends ConsumerWidget {
  const WeeklyReviewScreen({super.key});

  /// "Wins" rows: (icon, colorToken, title, sub).
  static const _wins = <(String, String, String, String)>[
    ('figure.run', 'move', '11-day move streak', 'Longest in 3 months'),
    ('dollarsign.circle.fill', 'money', '\$160 under budget', '\$435 of \$595'),
    ('sparkles', 'rituals', 'Morning pages 6/7', 'Missed only Saturday'),
  ];

  /// "Patterns" cards: (colorToken, rich text). The bolded spans from the mock
  /// are dropped to plain text — the app has no inline-bold body style and the
  /// house Pattern rows render flat; copy is otherwise verbatim.
  static const _patterns = <(String, String)>[
    (
      'money',
      'Fridays cost you 2.8× an average day — Verve + Tartine + dinner out.',
    ),
    (
      'move',
      'You moved 73 min on ritual days vs 42 min on skipped-ritual days.',
    ),
    (
      'rituals',
      'Reading Pachinko averaged 28 min, 3 nights this week.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // --- Nav: back to You + share ---------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon('chevron.left', size: 20, color: c.accent),
                      const SizedBox(width: 2),
                      Text('You',
                          style: AppFonts.sf(
                              size: 17,
                              color: c.accent,
                              letterSpacing: -0.43)),
                    ],
                  ),
                ),
              ),
              const NavIconButton(name: 'square.and.arrow.up'),
            ],
          ),
        ),

        // --- Hero -----------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WEEKLY REVIEW · APR 17–23',
                  style: AppFonts.sf(
                      size: 12,
                      weight: FontWeight.w700,
                      color: c.accent,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('Your steadiest week this month.',
                  style: AppFonts.sf(
                      size: 30,
                      weight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.5,
                      height: 1.15)),
              const SizedBox(height: 8),
              Text(
                "Movement stayed consistent, rituals held together, and you "
                "came in under budget. Let's look closer.",
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
            child: Row(
              children: [
                for (var i = 0; i < kWeeklyReviewStats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _StatTile(stat: kWeeklyReviewStats[i])),
                ],
              ],
            ),
          ),
        ),

        // --- Wins -----------------------------------------------------------
        _SectionHeader('Wins'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Container(
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _wins.length; i++)
                  _WinRow(
                    icon: _wins[i].$1,
                    colorToken: _wins[i].$2,
                    title: _wins[i].$3,
                    sub: _wins[i].$4,
                    last: i == _wins.length - 1,
                  ),
              ],
            ),
          ),
        ),

        // --- Patterns -------------------------------------------------------
        _SectionHeader('Patterns'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            children: [
              for (var i = 0; i < _patterns.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _PatternCard(
                    colorToken: _patterns[i].$1, text: _patterns[i].$2),
              ],
            ],
          ),
        ),

        // --- One thing to try -----------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: _OneThingCard(),
        ),

        // --- Footer ---------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Next review · Sunday, Apr 30',
              textAlign: TextAlign.center,
              style: AppFonts.sf(
                  size: 13, color: c.ink3, letterSpacing: -0.08)),
        ),
      ],
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
  const _OneThingCard();

  static const _seed = 'Tell me more about my Friday spending';

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
            'Plan a grocery trip Thursday evening — your Friday splurges drop '
            '60% the weeks you do.',
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
