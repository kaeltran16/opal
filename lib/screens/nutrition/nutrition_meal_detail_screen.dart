import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/nutrition_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';
import 'nutrition_add_sheet.dart';
import 'widgets/nutrition_widgets.dart';

/// Screen: Meal detail. Looked up from [NutritionState.meals] by [mealId].
/// Shows the estimate hero, tags, provenance, a connection card, and actions.
class NutritionMealDetailScreen extends ConsumerWidget {
  const NutritionMealDetailScreen({super.key, required this.mealId});

  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(nutritionControllerProvider);

    return ColoredBox(
      color: c.bg,
      child: async.when(
        loading: () => const Center(child: Text('…')),
        error: (e, st) => _notFound(context, c),
        data: (state) {
          NutritionMeal? meal;
          for (final m in state.meals) {
            if (m.id == mealId) {
              meal = m;
              break;
            }
          }
          if (meal == null) return _notFound(context, c);
          return _Body(meal: meal);
        },
      ),
    );
  }

  Widget _notFound(BuildContext context, AppColors c) {
    return LargeTitleScrollView(
      title: 'Meal',
      leading: NavAction(
        icon: 'chevron.left',
        label: 'Nutrition',
        onTap: () => context.pop(),
        semanticLabel: 'Back to Nutrition',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.xxxl, Spacing.lg, 0),
          child: Center(
            child: Text(
              'Meal not found.',
              style: AppType.subhead.copyWith(color: c.ink3),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.meal});

  final NutritionMeal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return LargeTitleScrollView(
      title: meal.name,
      subtitle: meal.note,
      leading: NavAction(
        icon: 'chevron.left',
        label: 'Nutrition',
        onTap: () => context.pop(),
        semanticLabel: 'Back to Nutrition',
      ),
      padding: const EdgeInsets.only(bottom: 48),
      children: [
        // ── source tag + slot · time ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.sm, Spacing.lg, Spacing.md),
          child: Row(
            children: [
              SourceTag(meal.source),
              const SizedBox(width: Spacing.sm),
              Text(
                '${meal.slot} · ${meal.time}',
                style: AppFonts.sf(size: 13, color: c.ink3),
              ),
            ],
          ),
        ),

        // ── estimate hero card ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: c.nutritionTint,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                  color: c.nutrition.withValues(alpha: 0.13), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CalRange(meal.cal, size: 40),
                const SizedBox(height: Spacing.md),
                ConfidenceChip(meal.confidence),
                const SizedBox(height: Spacing.md),
                MacroSplit(meal.macros),
                const SizedBox(height: Spacing.md),
                // Pal note line
                Row(
                  children: [
                    AppIcon('sparkles', size: 12, color: c.nutrition),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      "Pal's estimate — ${meal.confidence.label}",
                      style: AppFonts.sf(
                          size: 12,
                          color: c.nutrition,
                          weight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // ── tags wrap ─────────────────────────────────────────────────────
        if (meal.tags.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: [
                for (final tag in meal.tags) _TagChip(label: tag),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
        ],

        // ── where this came from ──────────────────────────────────────────
        InsetSection(
          header: 'Where this came from',
          children: [
            meal.linkedEntryId != null
                ? const ListRow(
                    icon: 'creditcard.fill',
                    title: 'Linked expense',
                    subtitle: 'From a linked expense',
                    chevron: false,
                    last: true,
                  )
                : const ListRow(
                    icon: 'pencil',
                    title: 'Added by hand',
                    chevron: false,
                    last: true,
                  ),
          ],
        ),

        // ── connection card (move-tinted) ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: c.move.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                  color: c.move.withValues(alpha: 0.13), width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.move.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Center(
                      child: AppIcon('figure.run', size: 18, color: c.move)),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NUTRITION × WORKOUT',
                        style: AppFonts.sf(
                          size: 11,
                          weight: FontWeight.w700,
                          color: c.move,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fuel around your training.',
                        style: AppFonts.sf(size: 13, color: c.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // ── action buttons ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: _AdjustButton(mealId: meal.id),
        ),
        const SizedBox(height: Spacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: _RemoveButton(mealId: meal.id),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.xxs),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: AppFonts.sf(size: 12, weight: FontWeight.w500, color: c.ink2),
      ),
    );
  }
}

class _AdjustButton extends ConsumerWidget {
  const _AdjustButton({required this.mealId});
  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return PressScale(
      onTap: () => showNutritionAddSheet(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        decoration: BoxDecoration(
          color: c.nutritionTint,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
              color: c.nutrition.withValues(alpha: 0.20), width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          'Adjust estimate',
          style: AppFonts.sf(
              size: 15, weight: FontWeight.w600, color: c.nutrition),
        ),
      ),
    );
  }
}

class _RemoveButton extends ConsumerWidget {
  const _RemoveButton({required this.mealId});
  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return PressScale(
      onTap: () async {
        await ref
            .read(nutritionControllerProvider.notifier)
            .deleteMeal(mealId);
        if (context.mounted) context.pop();
      },
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        // off-grid tap-target padding — keep literal.
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Text(
          'Remove',
          style: AppFonts.sf(size: 15, weight: FontWeight.w500, color: c.red),
        ),
      ),
    );
  }
}
