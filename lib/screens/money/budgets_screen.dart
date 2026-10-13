import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/area_state.dart';
import '../../controllers/budget_advisories_controller.dart';
import '../../controllers/budget_recommendations_controller.dart';
import '../../controllers/budgets_controller.dart';
import '../../controllers/providers.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/state_colors.dart';
import '../you/sub_screen.dart';

const double _minTap = 44;
const double _rowMinHeight = 48;
const double _hairline = 1;
const double _rowIcon = 20;
const double _optionsIcon = 20;
const double _barHeight = 4;
const double _rowLineHeight = 22 / 16;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Money: this month's budget. What is left leads, then each envelope as a
/// hairline row with its bar, then Pal's suggested caps and advisories.
/// Watches [budgetsDataProvider] (current-month per-category spend + pacing).
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(budgetsDataProvider);
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final month = async.asData?.value.month ?? clock.now();
    final quiet = AppType.subhead.copyWith(color: c.ink3);

    return SubScreen(
      eyebrow: kMonths[month.month - 1],
      title: 'Budgets',
      children: [
        async.when(
          loading: () => _notice(Text('…', style: AppType.body.copyWith(color: c.ink3))),
          error: (e, _) {
            debugPrint('budgets: loading failed: $e');
            return _notice(Text("Couldn't load your budgets.", style: quiet));
          },
          data: (data) => _Body(data: data, currency: currency),
        ),
      ],
    );
  }

  static Widget _notice(Widget child) => Padding(
        padding: const EdgeInsets.only(top: Spacing.xxl),
        child: child,
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.currency});

  final BudgetsData data;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = budgetState(
      spent: data.totalSpent,
      budget: data.totalCap,
      elapsed: data.monthPaceFraction,
    );
    final left = data.totalLeft;
    final daysLeft = data.daysLeft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.xxl),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(formatCurrency(left.abs(), currency),
              maxLines: 1, style: AppType.display.copyWith(color: c.ink)),
        ),
        Wrap(
          spacing: Spacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(left < 0 ? 'over this month' : 'left this month',
                style: AppType.subhead.copyWith(color: c.ink2)),
            if (_isOff(state))
              Text(state.word, style: AppType.label.copyWith(color: c.wordInkFor(state))),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          '${formatCurrency(data.totalSpent, currency)} of '
          '${formatCurrency(data.totalCap, currency)} · '
          '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left',
          style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular),
        ),
        const SizedBox(height: Spacing.xxxl),
        Row(
          children: [
            const Expanded(child: _Heading('Envelopes')),
            Semantics(
              button: true,
              label: 'Budget options',
              child: SizedBox(
                width: _minTap,
                height: _minTap,
                child: Center(
                  child: AppIcon('slider.horizontal.3', size: _optionsIcon, color: c.ink2),
                ),
              ),
            ),
          ],
        ),
        for (final spend in data.envelopes)
          _EnvelopeRow(spend: spend, currency: currency, elapsed: data.monthPaceFraction),
        _SuggestedCaps(currency: currency),
        _BudgetAdvisories(currency: currency),
        const SizedBox(height: Spacing.xxxl),
        const _Row(icon: 'plus', title: 'New envelope'),
        const _Row(
          icon: 'arrow.triangle.2.circlepath',
          title: 'Roll unused into next month',
          value: 'On',
        ),
        const _Footer('Adjust caps anytime — Pal nudges you before an envelope runs dry.'),
      ],
    );
  }
}

/// Off track: the only states that show their word.
bool _isOff(AreaState state) => state == AreaState.watch || state == AreaState.care;

/// One envelope: its icon, name, what is left or over, the state word when off
/// track, and a bar of its spend against the cap.
class _EnvelopeRow extends StatelessWidget {
  const _EnvelopeRow({required this.spend, required this.currency, required this.elapsed});

  final EnvelopeSpend spend;
  final Currency currency;
  final double elapsed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final env = spend.envelope;
    final state = budgetState(spent: spend.spent, budget: spend.cap, elapsed: elapsed);
    final over = state == AreaState.care;
    // a zero cap has nothing to be over, so it reads as nothing left.
    final amount = over
        ? '${formatCurrency(spend.remaining.abs(), currency)} over'
        : '${formatCurrency(spend.remaining.clamp(0, double.infinity), currency)} left';
    final radius = BorderRadius.circular(Radii.pill);

    return _Hairline(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Row(
                children: [
                  AppIcon(env.icon, size: _rowIcon, color: c.ink2),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(env.category,
                        style: AppType.callout.copyWith(color: c.ink, height: _rowLineHeight)),
                  ),
                  const SizedBox(width: Spacing.md),
                  Flexible(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: Spacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(amount,
                            style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular)),
                        if (_isOff(state))
                          Text(state.word,
                              style: AppType.label.copyWith(color: c.wordInkFor(state))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(color: c.track, borderRadius: radius),
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: spend.progress.clamp(0.0, 1.0),
                child: Container(
                  height: _barHeight,
                  decoration: BoxDecoration(color: c.arcFor(state), borderRadius: radius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only "Suggested caps" section: watches [budgetRecommendationsProvider]
/// and lists each category's suggested monthly cap with a short reasoning line.
/// Renders nothing while loading, on error, or when there's nothing to suggest.
class _SuggestedCaps extends ConsumerWidget {
  const _SuggestedCaps({required this.currency});

  final Currency currency;

  static String _trendWord(SpendTrend trend) => switch (trend) {
        SpendTrend.increasing => 'trending up',
        SpendTrend.decreasing => 'trending down',
        SpendTrend.stable => 'steady',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(budgetRecommendationsProvider).asData?.value ?? const [];
    if (recs.isEmpty) return const SizedBox.shrink();

    return _Section(
      heading: 'Suggested caps',
      footer: 'From your spending over the last 3 months.',
      rows: [
        for (final rec in recs)
          _Row(
            title: rec.category,
            subtitle: '${formatCurrency(rec.monthlyAverage, currency)}/mo'
                ' · ${_trendWord(rec.trend)}'
                ' · +${(rec.bufferFraction * 100).round()}% buffer',
            value: formatCurrency(rec.suggestedCap, currency),
          ),
      ],
    );
  }
}

/// Read-only advisory sections: categories drawing real money with no envelope,
/// and envelopes carrying more headroom than the category actually uses.
/// Watches [budgetAdvisoriesProvider]; renders nothing while loading, on error,
/// or when there's nothing to say — same boundary as [_SuggestedCaps].
class _BudgetAdvisories extends ConsumerWidget {
  const _BudgetAdvisories({required this.currency});

  final Currency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advisories = ref.watch(budgetAdvisoriesProvider).asData?.value;
    if (advisories == null || advisories.isEmpty) return const SizedBox.shrink();

    final unbudgeted = advisories.unbudgeted;
    final savings = advisories.savings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unbudgeted.isNotEmpty)
          _Section(
            heading: 'No envelope yet',
            footer: 'Categories you are spending on without a cap.',
            rows: [
              for (final u in unbudgeted)
                _Row(
                  title: u.category,
                  subtitle: '${formatCurrency(u.monthSpend, currency)} this month',
                  value: formatCurrency(u.suggestedCap, currency),
                ),
            ],
          ),
        if (savings.isNotEmpty)
          _Section(
            heading: 'Room to trim',
            footer: 'Envelopes with more headroom than the last 3 months used.',
            rows: [
              for (final s in savings)
                _Row(
                  title: s.category,
                  subtitle: '${formatCurrency(s.monthlyAverage, currency)}/mo'
                      ' of ${formatCurrency(s.cap, currency)}',
                  value: formatCurrency(s.suggestedCap, currency),
                ),
            ],
          ),
      ],
    );
  }
}

/// A heading, its hairline rows and a footer, a section gap above.
class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.footer, required this.rows});

  final String heading;
  final String footer;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.xxxl),
        _Heading(heading),
        const SizedBox(height: Spacing.xs),
        ...rows,
        _Footer(footer),
      ],
    );
  }
}

/// A read-only hairline row: optional icon, title over an optional subtitle,
/// and an optional value at the right.
class _Row extends StatelessWidget {
  const _Row({this.icon, required this.title, this.subtitle, this.value});

  final String? icon;
  final String title;
  final String? subtitle;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icon = this.icon;
    final subtitle = this.subtitle;
    final value = this.value;
    return _Hairline(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        child: MergeSemantics(
          child: Row(
            children: [
              if (icon != null) ...[
                AppIcon(icon, size: _rowIcon, color: c.ink2),
                const SizedBox(width: Spacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppType.callout.copyWith(color: c.ink, height: _rowLineHeight)),
                    if (subtitle != null)
                      Text(subtitle, style: AppType.subhead.copyWith(color: c.ink3)),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: Spacing.md),
                Text(value,
                    style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A 1px hairline above [child].
class _Hairline extends StatelessWidget {
  const _Hairline({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.hair, width: _hairline)),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: AppType.headline.copyWith(color: context.colors.ink)),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Text(text, style: AppType.subhead.copyWith(color: context.colors.ink3)),
    );
  }
}
