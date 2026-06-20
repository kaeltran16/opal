import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/nutrition_controller.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';
import 'nutrition_add_sheet.dart';
import 'nutrition_confirm_sheet.dart';
import 'widgets/nutrition_widgets.dart';

/// Nutrition landing — hero, pending expense card, today's meals, week strip,
/// and cross-tracker connections. All state lives in [NutritionController].
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(nutritionControllerProvider);

    return async.when(
      loading: () => Center(
        child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text(
            "Couldn't load nutrition.\n$e",
            textAlign: TextAlign.center,
            style: AppType.subhead.copyWith(color: c.ink3, letterSpacing: -0.24),
          ),
        ),
      ),
      data: (state) => _NutritionBody(state: state),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────────────

class _NutritionBody extends StatelessWidget {
  const _NutritionBody({required this.state});
  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    return LargeTitleScrollView(
      title: 'Nutrition',
      subtitle: "how you've been eating",
      trailing: NavIconButton(
        name: 'plus',
        semanticLabel: 'Add a meal',
        onTap: () => showNutritionAddSheet(context),
      ),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        _TodayHero(state: state),
        if (state.pending != null) _PendingCard(pending: state.pending!),
        _MealsSection(state: state),
        _WeekSection(state: state),
        _ConnectionsSection(state: state),
      ],
    );
  }
}

// ─── Today hero ──────────────────────────────────────────────────────────────

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.state});
  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = c.nutrition;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          boxShadow: [
            // accent glow — off-scale color, kept inline per plan pattern
            BoxShadow(
              color: tone.withValues(alpha: 0.25),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xl),
          child: Stack(
            children: [
              // base tone gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tone,
                        tone.withValues(alpha: 0.87),
                        tone.withValues(alpha: 0.69),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              // translucent white blob, top-right
              Positioned(
                top: -50,
                right: -40,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: const BoxDecoration(
                    color: Color(0x1AFFFFFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // diagonal hairline hatch
              Positioned.fill(
                child: CustomPaint(painter: _HatchPainter()),
              ),
              Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Eyebrow
                    Text(
                      'TODAY',
                      style: AppType.caption2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xD9FFFFFF),
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    // Calorie range
                    CalRange(state.day.cal, size: 42, light: true),
                    const SizedBox(height: Spacing.md),
                    // Feel pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: Spacing.xxs),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        state.day.feel,
                        style: AppFonts.sf(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    // Divider
                    Container(
                        height: 0.5, color: const Color(0x4DFFFFFF)),
                    const SizedBox(height: Spacing.md),
                    // Macro split
                    MacroSplit(state.day.macros, light: true),
                    const SizedBox(height: Spacing.md),
                    // Meta line
                    Text(
                      '${state.day.meals} meals · '
                      '${state.day.takeout} takeout, '
                      '${state.day.home} home · '
                      '${state.day.note}',
                      style: AppType.subhead.copyWith(
                        color: const Color(0xE6FFFFFF),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diagonal hairline hatch — mirrors _HatchPainter in rituals_screen.dart.
class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1;
    const spacing = 25.0;
    final extent = size.width + size.height;
    for (var d = -size.height; d < extent; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height * 1.43, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => false;
}

// ─── Pending card ─────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.pending});
  final NutritionPending pending;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = pending.expense;
    final guess = pending.guess;

    // format amount as "$XX.XX"
    final amount = e.amount != null
        ? '\$${e.amount!.abs().toStringAsFixed(2)}'
        : '';
    final time = '${e.timestamp.hour.toString().padLeft(2, '0')}:'
        '${e.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          border: Border.all(
              color: c.nutrition.withValues(alpha: 0.40), width: 1.5),
          borderRadius: BorderRadius.circular(Radii.lg),
          color: c.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eyebrow
            Text(
              'AN EXPENSE LOOKS LIKE A MEAL',
              style: AppType.caption2.copyWith(
                fontWeight: FontWeight.w700,
                color: c.nutrition,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bag tile
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.nutritionTint,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Center(
                    child: AppIcon('bag.fill', size: 18, color: c.nutrition),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guess.name,
                        style: AppFonts.sf(
                            size: 15,
                            weight: FontWeight.w600,
                            color: c.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${e.title} · $amount · $time',
                        style:
                            AppType.footnote.copyWith(color: c.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            // "Add meal" pill
            PressScale(
              onTap: () => showNutritionConfirmSheet(
                context,
                expense: e,
                guess: guess,
              ),
              child: Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  color: c.nutrition,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Add meal',
                  style: AppFonts.sf(
                    size: 15,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meals section ────────────────────────────────────────────────────────────

class _MealsSection extends StatelessWidget {
  const _MealsSection({required this.state});
  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    // Mon / Tue … Sun
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // DateTime weekday: 1=Mon … 7=Sun
    final dayLabel = weekdays[now.weekday - 1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xs, 0, Spacing.xs, Spacing.sm),
            child: Text(
              'Meals · $dayLabel',
              style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.ink3,
                  letterSpacing: 0.8),
            ),
          ),
          if (state.meals.isEmpty)
            Container(
              padding: const EdgeInsets.all(Spacing.xl),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
              ),
              child: Center(
                child: Text(
                  'No meals logged yet today.',
                  style: AppType.subhead.copyWith(color: c.ink3),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
              ),
              child: Column(
                children: [
                  for (var i = 0; i < state.meals.length; i++)
                    MealRow(
                      state.meals[i],
                      last: i == state.meals.length - 1,
                      onTap: () => context.pushNamed(
                        AppRoute.nutritionMeal.name,
                        pathParameters: {'id': state.meals[i].id},
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── This week ───────────────────────────────────────────────────────────────

class _WeekSection extends StatelessWidget {
  const _WeekSection({required this.state});
  final NutritionState state;

  static const _barMaxH = 52.0;
  static const _barMinH = 6.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week',
              style: AppFonts.sf(
                  size: 15,
                  weight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.2),
            ),
            const SizedBox(height: Spacing.lg),
            // Bars row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final wd in state.week)
                  Expanded(
                    child: _WeekBar(
                      wd: wd,
                      barMaxH: _barMaxH,
                      barMinH: _barMinH,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            // Footer
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.nutrition,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  'dot marks a takeout day',
                  style: AppType.caption.copyWith(color: c.ink3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.wd,
    required this.barMaxH,
    required this.barMinH,
  });

  final NutritionWeekDay wd;
  final double barMaxH;
  final double barMinH;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final load = wd.load;
    final isFuture = load == null;
    final barH = isFuture
        ? barMinH
        : (barMinH + load * (barMaxH - barMinH)).clamp(barMinH, barMaxH);
    final barColor = wd.today ? c.nutrition : c.nutrition.withValues(alpha: 0.30);
    final hasTakeout = wd.takeout > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Takeout dot above bar
        SizedBox(
          height: 10,
          child: hasTakeout
              ? Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.nutrition,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 2),
        // Bar or dashed box for future days
        if (isFuture)
          DottedBorderBox(
            color: c.hair,
            radius: Radii.xs,
            child: SizedBox(height: barMinH, width: double.infinity),
          )
        else
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: barH,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(Radii.xs),
              ),
            ),
          ),
        const SizedBox(height: Spacing.xs),
        // Day label
        Text(
          wd.day,
          style: AppFonts.sf(
            size: 11,
            weight: wd.today ? FontWeight.w700 : FontWeight.w400,
            color: wd.today ? c.nutrition : c.ink3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Connections section ──────────────────────────────────────────────────────

class _ConnectionsSection extends StatelessWidget {
  const _ConnectionsSection({required this.state});
  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (state.patterns.isEmpty) return const SizedBox.shrink();

    // Featured card = first pattern; rest are summarized below.
    final featured = state.patterns.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xs, 0, Spacing.xs, Spacing.sm),
            child: Text(
              'Connections',
              style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.ink3,
                  letterSpacing: 0.8),
            ),
          ),
          // Featured Pal card
          PressScale(
            onTap: () => context.pushNamed(AppRoute.palComposer.name),
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.nutrition,
                    c.money,
                  ],
                ),
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dots + eyebrow
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.nutrition,
                          border: Border.all(
                              color: Colors.white, width: 1.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.money,
                          border: Border.all(
                              color: Colors.white, width: 1.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        'PAL NOTICED',
                        style: AppType.caption2.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xD9FFFFFF),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    featured.title,
                    style: AppFonts.sf(
                      size: 17,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    featured.body,
                    style: AppType.subhead.copyWith(
                      color: const Color(0xE6FFFFFF),
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          // "See all patterns" row
          PressScale(
            onTap: () =>
                context.pushNamed(AppRoute.nutritionPatterns.name),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.md),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
              ),
              child: Row(
                children: [
                  Text(
                    'See all patterns',
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w500,
                        color: c.ink),
                  ),
                  const Spacer(),
                  AppIcon('chevron.right', size: 14, color: c.ink4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
