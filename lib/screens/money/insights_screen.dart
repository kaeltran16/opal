import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/insights_money_controller.dart';
import '../../controllers/providers.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/controls.dart';
import '../../widgets/donut_chart.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

/// Insights — month-over-month spend trend + category breakdown. A Segmented
/// control toggles between the Trend tab (headline stats + 6-month bar chart +
/// "What changed") and the Categories tab (donut + legend + per-category list).
/// All math lives in [insightsDataProvider]; this screen only lays out.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String _tab = 'trend';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dataAsync = ref.watch(insightsDataProvider);
    final currency = ref.watch(appSettingsControllerProvider).currency;

    return ColoredBox(
      color: c.bg,
      child: LargeTitleScrollView(
        title: 'Insights',
        padding: const EdgeInsets.only(bottom: 40),
        leading: NavAction(
          icon: 'chevron.left',
          label: 'You',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        trailing: const NavIconButton(
          name: 'square.and.arrow.up',
          semanticLabel: 'Share',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.xs, Spacing.lg, Spacing.lg),
            child: Segmented<String>(
              options: const [('trend', 'Trend'), ('cats', 'Categories')],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          dataAsync.when(
            loading: () => const _Notice('Gathering your spending…'),
            error: (e, _) => const _Notice("Couldn't load insights."),
            data: (data) => _tab == 'trend'
                ? _TrendTab(data: data, currency: currency)
                : _CategoriesTab(data: data, currency: currency),
          ),
        ],
      ),
    );
  }
}

// ─── Trend tab ────────────────────────────────────────────────────────────────

class _TrendTab extends StatelessWidget {
  const _TrendTab({required this.data, required this.currency});

  final InsightsData data;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mom = data.momPct;
    final down = mom != null && mom < 0;
    return Column(
      children: [
        // Headline stat tiles.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, 0, Spacing.lg, Spacing.lg),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'This month',
                  value: formatCurrency(data.currentTotal, currency),
                  sub: 'so far',
                  valueColor: c.ink,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _StatTile(
                  label: 'vs last month',
                  value: mom == null
                      ? '—'
                      : '${down ? '−' : '+'}${mom.abs()}%',
                  sub: formatCurrency(data.lastFullTotal, currency),
                  valueColor: mom == null ? c.ink : (down ? c.move : c.money),
                ),
              ),
            ],
          ),
        ),

        // Bar chart card.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.xl, Spacing.lg, Spacing.md),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(Radii.xl)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Monthly spend',
                        style: AppType.headline.copyWith(color: c.ink)),
                    Text('avg ${formatCurrency(data.average, currency)}',
                        style: AppType.footnote
                            .copyWith(color: c.ink3, letterSpacing: -0.08)),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                MonthlyBarChart(
                  months: data.months,
                  average: data.average,
                  color: c.money,
                ),
              ],
            ),
          ),
        ),

        // What changed.
        InsetSection(
          header: 'What changed',
          children: _whatChanged(context),
        ),
      ],
    );
  }

  /// Up to three deterministic rows: largest positive delta, largest negative
  /// delta, and a current-vs-average summary. Computed from the data, no Pal.
  List<Widget> _whatChanged(BuildContext context) {
    final c = context.colors;
    final withDelta =
        data.categories.where((cat) => cat.deltaPct != null).toList();
    final ups = withDelta.where((cat) => cat.deltaPct! > 0).toList()
      ..sort((a, b) => b.deltaPct!.compareTo(a.deltaPct!));
    final downs = withDelta.where((cat) => cat.deltaPct! < 0).toList()
      ..sort((a, b) => a.deltaPct!.compareTo(b.deltaPct!));

    final rows = <_Change>[];
    if (ups.isNotEmpty) {
      final top = ups.first;
      rows.add(_Change(
        icon: 'arrow.up.right',
        iconBg: c.money,
        title: '${top.label} up ${top.deltaPct!.abs()}%',
        subtitle: 'More than last month',
      ));
    }
    if (downs.isNotEmpty) {
      final top = downs.first;
      rows.add(_Change(
        icon: 'arrow.down.right',
        iconBg: c.move,
        title: '${top.label} down ${top.deltaPct!.abs()}%',
        subtitle: 'Less than last month',
      ));
    }
    // Summary: pace against the running average.
    final avg = data.average;
    final cur = data.currentTotal;
    if (avg > 0) {
      final underAvg = avg - cur;
      rows.add(_Change(
        icon: 'flame.fill',
        iconBg: c.rituals,
        title: underAvg >= 0
            ? 'On track to finish under average'
            : 'Running above your average',
        subtitle:
            '${formatCurrency(underAvg.abs(), currency)} ${underAvg >= 0 ? 'under' : 'over'} the ${formatCurrency(avg, currency)} average',
      ));
    }

    if (rows.isEmpty) {
      return [
        _ChangeRow(
          change: _Change(
            icon: 'chart.bar.fill',
            iconBg: c.money,
            title: 'Not enough history yet',
            subtitle: 'Keep logging and changes will show here',
          ),
          last: true,
        ),
      ];
    }
    return [
      for (var i = 0; i < rows.length; i++)
        _ChangeRow(change: rows[i], last: i == rows.length - 1),
    ];
  }
}

/// One TREND headline tile (surface, radius 16).
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String sub;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.ink3,
                  letterSpacing: 0.4)),
          const SizedBox(height: Spacing.xs),
          Text(value,
              style: AppFonts.sfr(
                  size: 26,
                  weight: FontWeight.w700,
                  color: valueColor,
                  letterSpacing: -0.6)),
          const SizedBox(height: 1),
          Text(sub,
              style: AppType.caption
                  .copyWith(color: c.ink3, letterSpacing: -0.08)),
        ],
      ),
    );
  }
}

/// View-model for one "What changed" row.
@immutable
class _Change {
  const _Change({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });
  final String icon;
  final Color iconBg;
  final String title;
  final String subtitle;
}

/// One "What changed" row: tinted icon tile + title + subtitle, hairline below
/// inset to the title (no chevron).
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change, required this.last});
  final _Change change;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                  color: change.iconBg,
                  borderRadius: BorderRadius.circular(Radii.sm)),
              alignment: Alignment.center,
              child: AppIcon(change.icon, size: 16, color: c.onAccent),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(change.title,
                      style: AppType.body.copyWith(color: c.ink)),
                  const SizedBox(height: 1),
                  Text(change.subtitle,
                      style: AppType.footnote
                          .copyWith(color: c.ink3, letterSpacing: -0.08)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Categories tab ───────────────────────────────────────────────────────────

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({required this.data, required this.currency});

  final InsightsData data;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cats = data.categories;
    final monthLabel =
        data.months.isEmpty ? '' : data.months.last.label.toUpperCase();
    final maxFraction =
        cats.fold<double>(0, (m, e) => e.fraction > m ? e.fraction : m);

    return Column(
      children: [
        // Donut + legend.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(Radii.xl)),
            child: Row(
              children: [
                CategoryDonut(
                  categories: cats,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // donut hole is ~96px (132 − 2×18); scale long totals down
                      SizedBox(
                        width: 92,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                              formatCurrency(data.currentTotal, currency),
                              maxLines: 1,
                              style: AppFonts.sfr(
                                  size: 22,
                                  weight: FontWeight.w700,
                                  color: c.ink,
                                  letterSpacing: -0.5)),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text('$monthLabel TOTAL',
                          style: AppType.caption2.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.ink3,
                              letterSpacing: 0.2)),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.xxl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final cat in cats.take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.sm),
                          child: _LegendRow(cat: cat),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // By category.
        InsetSection(
          header: 'By category',
          footer: 'Change shown vs. last month.',
          children: [
            for (var i = 0; i < cats.length; i++)
              _CategoryRow(
                cat: cats[i],
                currency: currency,
                maxFraction: maxFraction,
                last: i == cats.length - 1,
              ),
          ],
        ),
      ],
    );
  }
}

/// One legend entry: color dot + name + percent.
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.cat});
  final CategoryInsight cat;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
              color: c.forType(cat.colorToken),
              borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(cat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.footnote
                  .copyWith(color: c.ink2, letterSpacing: -0.08)),
        ),
        const SizedBox(width: Spacing.xs),
        Text('${(cat.fraction * 100).round()}%',
            style: AppType.footnote.copyWith(
                fontWeight: FontWeight.w600,
                color: c.ink3,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}

/// One "By category" row: icon tile + name + amount + delta line, with a thin
/// bar under the name sized to fraction / maxFraction. Hairline inset to title.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.cat,
    required this.currency,
    required this.maxFraction,
    required this.last,
  });

  final CategoryInsight cat;
  final Currency currency;
  final double maxFraction;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(cat.colorToken);
    final d = cat.deltaPct;
    final deltaText = d == null
        ? ''
        : d == 0
            ? '—'
            : '${d > 0 ? '↑' : '↓'} ${d.abs()}%';
    final deltaColor = (d == null || d == 0) ? c.ink3 : (d > 0 ? c.money : c.move);
    final barFrac = maxFraction == 0 ? 0.0 : cat.fraction / maxFraction;

    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(Radii.sm)),
                alignment: Alignment.center,
                child: AppIcon(cat.icon, size: 16, color: c.onAccent),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(cat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead.copyWith(
                        fontWeight: FontWeight.w500, color: c.ink)),
              ),
              const SizedBox(width: Spacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatCurrency(cat.amount, currency),
                      style: AppType.subhead.copyWith(
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  if (deltaText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(deltaText,
                          style: AppType.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: deltaColor,
                              letterSpacing: -0.08)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Padding(
            // align under the name, past the 29 icon + 12 gap.
            padding: const EdgeInsets.only(left: 41),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Stack(
                children: [
                  Container(
                      height: 4, color: color.withValues(alpha: 0.13)),
                  FractionallySizedBox(
                    widthFactor: barFrac.clamp(0.0, 1.0),
                    child: Container(height: 4, color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A muted surface card for the loading / error / empty notice.
class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
        child: Text(text,
            style: AppType.subhead.copyWith(color: c.ink3, height: 1.4)),
      ),
    );
  }
}
