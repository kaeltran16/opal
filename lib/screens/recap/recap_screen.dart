import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/insights_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/recap_controller.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/pal_label.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';

const double _minTap = 44;
const double _pillHeight = 48;
const double _rowMinHeight = 56;
const double _hairline = 1;
const double _rowIcon = 20;
const double _chevron = 14;
const String _askSeed = 'Tell me more about this recap';

/// Consolidated Recap — the single surface replacing the Weekly + Monthly
/// Reviews. A Day/Week/Month segmented control switches the period; the stats
/// come from [recapDataProvider] and the qualitative Wins / "One thing to try"
/// block reuses [insightsProvider]. This widget only lays out — all math/async
/// lives in the controllers.
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
    final insightsAsync = ref.watch(insightsProvider(_range));
    final insights = insightsAsync.asData?.value;

    return SubScreen(
      eyebrow: recapAsync.asData?.value.subtitle ?? '…',
      title: 'Recap',
      children: [
        const SizedBox(height: Spacing.xxl),
        Segmented<InsightRange>(
          options: _options,
          value: _range,
          onChanged: (v) => setState(() => _range = v),
        ),
        const SizedBox(height: Spacing.xxl),
        recapAsync.when(
          loading: () => Text('…', style: AppType.score.copyWith(color: c.ink3)),
          error: (e, _) => Text("Couldn't load this recap.",
              style: AppType.subhead.copyWith(color: c.ink3)),
          data: (r) => _Stats(stats: r.tiles(currency)),
        ),
        ..._qualitativeSection(context, insightsAsync.isLoading, insights),
        const SizedBox(height: Spacing.xxxl),
        _LinkRow(label: 'Patterns are on You', onTap: () => context.go('/you')),
      ],
    );
  }

  /// The Pal-found qualitative block (Wins / One thing to try). Shows a single
  /// encouraging notice while loading or when there isn't enough data, rather
  /// than fabricating wins.
  List<Widget> _qualitativeSection(
      BuildContext context, bool loading, PalInsights? insights) {
    final c = context.colors;
    if (insights == null) {
      return [
        const SizedBox(height: Spacing.xxxl),
        Text(
          loading
              ? 'Pal is reviewing your recap…'
              : 'Keep logging and Pal will gather your wins and patterns here.',
          style: AppType.subhead.copyWith(color: c.ink3),
        ),
      ];
    }
    final suggestion = insights.suggestion;
    return [
      if (insights.wins.isNotEmpty) ...[
        const SizedBox(height: Spacing.xxxl),
        const _Heading('Wins'),
        const SizedBox(height: Spacing.sm),
        for (final w in insights.wins)
          _WinRow(icon: insightIcon(w.colorToken), title: w.title, sub: w.sub),
      ],
      if (suggestion != null && suggestion.isNotEmpty) ...[
        const SizedBox(height: Spacing.xxxl),
        _OneThing(text: suggestion),
      ],
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text, style: AppType.headline.copyWith(color: context.colors.ink)),
      );
}

/// The period's three numbers, side by side.
class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final List<RecapStat> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: Spacing.md),
          Expanded(child: _Stat(stat: stats[i])),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.stat});

  final RecapStat stat;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // one line: a long amount shrinks rather than breaking mid-number.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(stat.value, maxLines: 1, style: AppType.score.copyWith(color: c.ink)),
        ),
        const SizedBox(height: Spacing.xs),
        Text(stat.label, style: AppType.label.copyWith(color: c.ink2)),
        Text(stat.sub, style: AppType.label.copyWith(color: c.ink3)),
      ],
    );
  }
}

/// One win on a hairline: a line icon, the win and its detail.
class _WinRow extends StatelessWidget {
  const _WinRow({required this.icon, required this.title, required this.sub});

  final String icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: _rowIcon, color: c.ink2),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.callout.copyWith(color: c.ink)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: Spacing.xxs),
                  Text(sub, style: AppType.subhead.copyWith(color: c.ink3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pal's one suggestion for the period, with a way to ask about it.
class _OneThing extends StatelessWidget {
  const _OneThing({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PalLabel(text: 'One thing to try'),
        const SizedBox(height: Spacing.sm),
        Text(text, style: AppType.body.copyWith(color: c.ink)),
        const SizedBox(height: Spacing.lg),
        _SecondaryPill(
          label: 'Ask Pal more',
          onTap: () => context.go('/pal-composer?seed=${Uri.encodeComponent(_askSeed)}'),
        ),
      ],
    );
  }
}

class _SecondaryPill extends StatelessWidget {
  const _SecondaryPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: _pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text(label, style: AppType.headline.copyWith(color: c.ink))],
        ),
      ),
    );
  }
}

/// A hairline row that opens another screen.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: _minTap),
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hair, width: _hairline)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppType.callout.copyWith(color: c.ink))),
            const SizedBox(width: Spacing.sm),
            AppIcon('chevron.right', size: _chevron, color: c.ink3),
          ],
        ),
      ),
    );
  }
}
