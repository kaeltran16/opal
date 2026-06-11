import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/monthly_review_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';

/// Screen 14 — Monthly Review (mock).
///
/// A month title + "Monthly review" subtitle; a Pal-written narrative card
/// (gradient accent background, "Written by Pal" sparkle label, a Regenerate
/// pill that re-requests the text); a "By the numbers" block of four big stat
/// rows computed from the repositories for the current month; and a "Patterns
/// Pal found" block of three insight rows.
///
/// The narrative comes from [monthlyReviewControllerProvider] (loading +
/// regenerate); the stats from [monthlyStatsProvider]. This widget only lays
/// out — all math/async lives in the controllers.
class MonthlyReviewScreen extends ConsumerWidget {
  const MonthlyReviewScreen({super.key});

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Qualitative "Patterns Pal found" insights. These are correlational claims
  /// with no structured data source yet (the narrative `/review` seam returns
  /// prose, not structured patterns), so they stay canned rather than
  /// fabricating numbers from the aggregates above.
  // TODO(pal): structured insights endpoint — replace canned Patterns.
  static const _patterns = <(String, String)>[
    (
      'Morning rituals lower food spending',
      'On days you journal, food costs drop 32%',
    ),
    (
      'Friday is your spendiest day',
      'Average \$94 — mostly dinner out',
    ),
    (
      'Movement and sleep are linked',
      'You move 40% more after 7+ hour nights',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final now = DateTime.now();
    final monthName = _months[now.month - 1];

    final narrative = ref.watch(monthlyReviewControllerProvider);
    final statsAsync = ref.watch(monthlyStatsProvider);

    return LargeTitleScrollView(
      title: monthName,
      subtitle: 'Monthly review',
      leading: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: AppIcon('chevron.left', size: 20, color: c.accent),
      ),
      trailing: const NavIconButton(name: 'ellipsis'),
      padding: const EdgeInsets.only(bottom: 48),
      children: [
        // --- Narrative card (gradient accent bg, "Written by Pal") -----------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
          child: _NarrativeCard(narrative: narrative),
        ),

        // --- By the numbers --------------------------------------------------
        _SectionHeader('By the numbers'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          child: Container(
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: statsAsync.when(
              loading: () => const _StatsPlaceholder(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text("Couldn't load this month.",
                    style: AppFonts.sf(
                        size: 15, color: c.ink3, letterSpacing: -0.24)),
              ),
              data: (stats) {
                final rows = stats.rows;
                return Column(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      _StatRow(stat: rows[i], last: i == rows.length - 1),
                  ],
                );
              },
            ),
          ),
        ),

        // --- Patterns Pal found ----------------------------------------------
        _SectionHeader('Patterns Pal found'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Container(
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _patterns.length; i++)
                  _PatternRow(
                    title: _patterns[i].$1,
                    detail: _patterns[i].$2,
                    last: i == _patterns.length - 1,
                  ),
              ],
            ),
          ),
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
              size: 22, weight: FontWeight.w700, color: c.ink, letterSpacing: 0.35)),
    );
  }
}

/// Gradient accent narrative card with the "Written by Pal" sparkle label and a
/// Regenerate pill. Shows a loading shimmer line while the text is fetched.
class _NarrativeCard extends ConsumerWidget {
  const _NarrativeCard({required this.narrative});
  final AsyncValue<String> narrative;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final loading = narrative.isLoading;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // design uses {accent}18 → {rituals}18 (~9% alpha)
          colors: [
            c.accent.withValues(alpha: 0.09),
            c.rituals.withValues(alpha: 0.09),
          ],
        ),
        border: Border.all(
            color: c.accent.withValues(alpha: 0.20), width: 0.5),
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
              Text('WRITTEN BY PAL',
                  style: AppFonts.sf(
                      size: 12,
                      weight: FontWeight.w700,
                      color: c.ink3,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            narrative.when(
              loading: () => 'Pal is reading your month…',
              error: (_, _) => "Pal couldn't write your review just now.",
              data: (text) => text,
            ),
            style: AppFonts.sf(
                size: 17,
                color: loading ? c.ink3 : c.ink,
                letterSpacing: -0.43,
                height: 1.4),
          ),
          const SizedBox(height: 14),
          _RegeneratePill(loading: loading),
        ],
      ),
    );
  }
}

class _RegeneratePill extends ConsumerWidget {
  const _RegeneratePill({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading
          ? null
          : () =>
              ref.read(monthlyReviewControllerProvider.notifier).regenerate(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('sparkles', size: 13, color: c.accent),
            const SizedBox(width: 6),
            Text(loading ? 'Writing…' : 'Regenerate',
                style: AppFonts.sf(
                    size: 13,
                    weight: FontWeight.w600,
                    color: c.accent,
                    letterSpacing: -0.08)),
          ],
        ),
      ),
    );
  }
}

/// One big "By the numbers" row: tinted icon tile + label + big value/unit.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat, required this.last});
  final ReviewStat stat;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(stat.colorToken);
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: AppIcon(stat.icon, size: 18, color: const Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.label,
                    style: AppFonts.sf(
                        size: 13,
                        weight: FontWeight.w500,
                        color: c.ink3,
                        letterSpacing: -0.08)),
                if (stat.sub != null) ...[
                  const SizedBox(height: 1),
                  Text(stat.sub!,
                      style: AppFonts.sf(
                          size: 12, color: c.ink3, letterSpacing: -0.08)),
                ],
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(stat.value,
                  style: AppFonts.sfr(
                      size: 22, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.3)),
              if (stat.unit != null) ...[
                const SizedBox(width: 4),
                Text(stat.unit!,
                    style: AppFonts.sf(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.ink3,
                        letterSpacing: 0.3)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsPlaceholder extends StatelessWidget {
  const _StatsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text('…',
          style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
    );
  }
}

/// One "Patterns Pal found" insight row: sparkle icon + title + detail line.
class _PatternRow extends StatelessWidget {
  const _PatternRow({
    required this.title,
    required this.detail,
    required this.last,
  });
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon('sparkles', size: 16, color: c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.24)),
                const SizedBox(height: 2),
                Text(detail,
                    style: AppFonts.sf(
                        size: 13,
                        color: c.ink3,
                        letterSpacing: -0.08,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
