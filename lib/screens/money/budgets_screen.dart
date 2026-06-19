import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/budgets_controller.dart';
import '../../controllers/providers.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/spend_ring.dart';

/// Money — monthly budget envelopes with live spent / left rings. Watches
/// [budgetsDataProvider] (current-month per-category spend + pacing) and renders
/// a total hero ring, a 2-column envelope grid, and inert action rows.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(budgetsDataProvider);
    final currency = ref.watch(appSettingsControllerProvider).currency;

    return ColoredBox(
      color: c.bg,
      child: LargeTitleScrollView(
        title: 'Budgets',
        leading: NavAction(
          icon: 'chevron.left',
          label: 'You',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        trailing: const NavIconButton(
          name: 'slider.horizontal.3',
          semanticLabel: 'Budget options',
        ),
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          async.when(
            loading: () => _centered(
              Text('…', style: AppType.body.copyWith(color: c.ink3)),
            ),
            error: (e, _) => _centered(
              Text(
                "Couldn't load your budgets.",
                textAlign: TextAlign.center,
                style: AppType.subhead.copyWith(color: c.ink3, letterSpacing: -0.24),
              ),
            ),
            data: (data) => _Body(data: data, currency: currency),
          ),
        ],
      ),
    );
  }

  static Widget _centered(Widget child) => Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Center(child: child),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.currency});

  final BudgetsData data;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final month = BudgetsScreen._monthNames[data.month.month - 1];
    final progress = data.totalProgress;
    final over = progress > 1;
    final onPace = data.onPace;
    final daysLeft = data.daysLeft;

    final paceLabel = onPace
        ? 'On pace · $daysLeft days left'
        : '${((progress - data.monthPaceFraction) * 100).round()}% ahead of pace · $daysLeft days left';

    final envelopes = data.envelopes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Hero: total budget ring ---
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: 22),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                SpendRing(
                  progress: progress,
                  color: c.money,
                  size: 116,
                  stroke: 12,
                  over: over,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(progress * 100).round()}%',
                        style: AppFonts.sfr(
                          size: 26,
                          weight: FontWeight.w700,
                          color: c.ink,
                          letterSpacing: -0.6,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        'USED',
                        style: AppFonts.sf(
                          size: 11,
                          weight: FontWeight.w600,
                          color: c.ink3,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatCurrency(data.totalLeft, currency),
                        style: AppFonts.sfr(
                          size: 34,
                          weight: FontWeight.w700,
                          color: c.ink,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        'left to spend',
                        style: AppFonts.sf(
                          size: 15,
                          weight: FontWeight.w600,
                          color: c.money,
                          letterSpacing: -0.24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatCurrency(data.totalSpent, currency)} of ${formatCurrency(data.totalCap, currency)} · $month',
                        style: AppFonts.sf(
                          size: 13,
                          color: c.ink2,
                          letterSpacing: -0.08,
                          tabular: true,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      _PaceBar(progress: progress, pace: data.monthPaceFraction),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        paceLabel,
                        style: AppFonts.sf(
                          size: 12,
                          weight: FontWeight.w600,
                          color: onPace ? c.move : c.money,
                          letterSpacing: -0.08,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- Envelopes grid ---
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xs),
          child: Text(
            'ENVELOPES',
            style: AppFonts.sf(
              size: 13,
              color: c.ink3,
              letterSpacing: -0.08,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
          child: Column(
            children: [
              for (var i = 0; i < envelopes.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i + 2 < envelopes.length ? Spacing.md : 0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _EnvelopeCard(spend: envelopes[i], currency: currency),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: i + 1 < envelopes.length
                            ? _EnvelopeCard(spend: envelopes[i + 1], currency: currency)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // --- Actions ---
        InsetSection(
          footer: 'Adjust caps anytime — Pal nudges you before an envelope runs dry.',
          children: [
            ListRow(
              icon: 'plus.circle.fill',
              iconBg: c.money,
              title: 'New envelope',
            ),
            ListRow(
              icon: 'arrow.triangle.2.circlepath',
              iconBg: c.accent,
              title: 'Roll unused into next month',
              value: 'On',
              valueColor: c.move,
              chevron: false,
              last: true,
            ),
          ],
        ),
      ],
    );
  }
}

/// The hero pace bar: a rounded fill at [progress] over a fill track, with a
/// vertical marker at the month's calendar [pace].
class _PaceBar extends StatelessWidget {
  const _PaceBar({required this.progress, required this.pace});

  final double progress;
  final double pace;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final over = progress > 1;
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 3,
                left: 0,
                right: 0,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.fill,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
              Positioned(
                top: 3,
                left: 0,
                child: Container(
                  width: w * progress.clamp(0.0, 1.0),
                  height: 6,
                  decoration: BoxDecoration(
                    color: over ? c.red : c.money,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: w * pace.clamp(0.0, 1.0) - 1,
                child: Container(
                  width: 2,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c.ink.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EnvelopeCard extends StatelessWidget {
  const _EnvelopeCard({required this.spend, required this.currency});

  final EnvelopeSpend spend;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final env = spend.envelope;
    final over = spend.over;
    final color = over ? c.red : c.forType(env.colorToken);
    final ringColor = c.forType(env.colorToken);
    final progress = spend.progress;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                alignment: Alignment.center,
                child: AppIcon(env.icon, size: 16, color: c.onAccent),
              ),
              SpendRing(
                progress: progress,
                color: ringColor,
                size: 40,
                stroke: 5,
                over: over,
                child: Text(
                  '${(progress * 100).round()}',
                  style: AppFonts.sf(
                    size: 10,
                    weight: FontWeight.w700,
                    color: over ? c.red : c.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            env.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.sf(
              size: 15,
              weight: FontWeight.w600,
              color: c.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: Spacing.xxs),
          Text(
            '${formatCurrency(spend.spent, currency)} of ${formatCurrency(spend.cap, currency)}',
            style: AppFonts.sf(
              size: 12,
              color: c.ink3,
              letterSpacing: -0.08,
              tabular: true,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            over
                ? '${formatCurrency(spend.remaining.abs(), currency)} over'
                : '${formatCurrency(spend.remaining, currency)} left',
            style: AppFonts.sf(
              size: 12,
              weight: FontWeight.w600,
              color: over ? c.red : c.ink2,
              letterSpacing: -0.08,
            ),
          ),
        ],
      ),
    );
  }
}
