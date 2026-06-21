import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/correlations_controller.dart';
import '../../controllers/insights_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/recap_controller.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/correlation_card.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/pal_avatar.dart';

/// Consolidated Recap — the single surface replacing the Weekly + Monthly
/// Reviews. A Day/Week/Month segmented control switches the period; the stat
/// tiles come from [recapDataProvider] and the qualitative Wins / Patterns /
/// "One thing to try" block reuses [insightsProvider]. This widget only lays
/// out — all math/async lives in the controllers.
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key, this.initialRange = InsightRange.day});

  /// The range the screen opens on (deep links pass week/month).
  final InsightRange initialRange;

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  late InsightRange _range = widget.initialRange;

  static const _options = [
    (InsightRange.day, 'Day'),
    (InsightRange.week, 'Week'),
    (InsightRange.month, 'Month'),
  ];

  @override
  void initState() {
    super.initState();
    // opening the recap is the client-chosen cadence to re-derive Pal's learned
    // patterns from the data shown here. fire-and-forget and best-effort.
    ref.read(recapMemoryRefreshProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final recapAsync = ref.watch(recapDataProvider(_range));
    final recap = recapAsync.asData?.value;
    final insightsAsync = ref.watch(insightsProvider(_range));
    final insights = insightsAsync.asData?.value;
    final surfaced =
        ref.watch(surfacedCorrelationsProvider).asData?.value ?? const [];

    return ColoredBox(
      color: c.bg,
      child: LargeTitleScrollView(
        title: 'Recap',
        subtitle: recap?.subtitle ?? '…',
        leading: NavAction(
          icon: 'chevron.left',
          label: 'You',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        trailing: const NavIconButton(
          name: 'square.and.arrow.up',
          semanticLabel: 'Share',
        ),
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          // --- Range picker ---------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xl),
            child: Segmented<InsightRange>(
              options: _options,
              value: _range,
              onChanged: (v) => setState(() => _range = v),
            ),
          ),

          // --- Three-tile summary ---------------------------------------------
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
            child: Container(
              padding: const EdgeInsets.all(Spacing.xl),
              decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.lg)),
              child: recapAsync.when(
                loading: () => const _TilesPlaceholder(),
                error: (e, _) => Text("Couldn't load this recap.",
                    style: AppType.subhead.copyWith(color: c.ink3)),
                data: (r) {
                  final tiles = r.tiles(currency);
                  return Row(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: Spacing.md),
                        Expanded(child: _StatTile(stat: tiles[i])),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),

          // --- Strongest cross-dimension correlation --------------------------
          // gated on surfaced only — renders even when Pal insights are absent;
          // narration falls back to the card's template when null.
          if (surfaced.isNotEmpty) ...[
            _SectionHeader('Connections'),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, 0, Spacing.lg, Spacing.xl),
              child: CorrelationCard(
                correlation: surfaced.first,
                narration: insights?.correlationNarration,
              ),
            ),
          ],

          // --- Wins / Patterns / One thing to try (Pal insights) --------------
          ..._qualitativeSection(context, insightsAsync.isLoading, insights),
        ],
      ),
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
          padding:
              const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: _NoticeCard(
            text: loading
                ? 'Pal is reviewing your recap…'
                : 'Keep logging and Pal will gather your wins and patterns '
                    'here.',
          ),
        ),
      ];
    }
    return [
      if (insights.wins.isNotEmpty) ...[
        _SectionHeader('Wins'),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: Container(
            decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.card)),
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
          padding:
              const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: Column(
            children: [
              for (var i = 0; i < insights.patterns.length; i++) ...[
                if (i > 0) const SizedBox(height: Spacing.sm),
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
          padding:
              const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: _OneThingCard(text: insights.suggestion!),
        ),
    ];
  }
}

/// A muted surface card used for the Recap's loading / empty notice.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
      child: Text(text,
          style: AppType.subhead.copyWith(color: c.ink3, height: 1.4)),
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
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.md),
      child: Text(text,
          style: AppType.title2.copyWith(color: c.ink, letterSpacing: 0.35)),
    );
  }
}

/// Loading state for the three-tile summary, keeping the row's height stable.
class _TilesPlaceholder extends StatelessWidget {
  const _TilesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text('…',
        style: AppType.title2.copyWith(
            fontWeight: FontWeight.w400, color: c.ink3, letterSpacing: -0.3));
  }
}

/// One tinted stat tile: `{color}14` bg, color label, big value, sub.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});
  final RecapStat stat;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(stat.colorToken);
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.label.toUpperCase(),
              style: AppType.caption2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3)),
          const SizedBox(height: Spacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(stat.value,
                maxLines: 1,
                style: AppFonts.sfr(
                    size: 22,
                    weight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.3)),
          ),
          const SizedBox(height: Spacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(stat.sub,
                maxLines: 1,
                style: AppType.caption2
                    .copyWith(color: c.ink3, letterSpacing: -0.08)),
          ),
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
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(Radii.md)),
            alignment: Alignment.center,
            child: AppIcon(icon, size: 16, color: c.onAccent),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppType.subhead
                        .copyWith(fontWeight: FontWeight.w600, color: c.ink)),
                const SizedBox(height: 1),
                Text(sub,
                    style: AppType.caption
                        .copyWith(color: c.ink3, letterSpacing: -0.08)),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
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
          color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.md, Spacing.md, Spacing.lg, Spacing.md),
                child: Text(text,
                    style:
                        AppType.subhead.copyWith(color: c.ink, height: 1.4)),
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

  static const _seed = 'Tell me more about this recap';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.accent.withValues(alpha: 0.07),
            c.rituals.withValues(alpha: 0.07),
          ],
        ),
        border: Border.all(color: c.accent.withValues(alpha: 0.20), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PalAvatar(size: 22, glyphSize: 11),
              const SizedBox(width: Spacing.sm),
              Text('ONE THING TO TRY',
                  style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.ink3,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            text,
            style: AppType.body.copyWith(color: c.ink, height: 1.4),
          ),
          const SizedBox(height: Spacing.md),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                context.go('/pal-composer?seed=${Uri.encodeComponent(_seed)}'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text('Ask Pal more',
                  style: AppType.footnote.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.onAccent,
                      letterSpacing: -0.15)),
            ),
          ),
        ],
      ),
    );
  }
}
