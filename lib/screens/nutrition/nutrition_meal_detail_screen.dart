import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/nutrition_controller.dart';
import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';
import 'nutrition_add_sheet.dart';
import 'widgets/nutrition_widgets.dart';

const String _backLabel = 'Nutrition';
const double _minTap = 44;
const double _pillHeight = 48;
const double _rowHeight = 48;
const double _hairline = 1;
const double _sourceIcon = 16;
const double _rowIcon = 20;
// kept literal: the canvas gaps the source line's sparkles 6 from its text.
const double _sourceGap = 6;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Screen: Meal detail. Looked up from [NutritionState.meals] by [mealId].
/// Shows the estimate, its macros, where it came from, and actions.
class NutritionMealDetailScreen extends ConsumerWidget {
  const NutritionMealDetailScreen({super.key, required this.mealId});

  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nutritionControllerProvider);

    return async.when(
      loading: () => const _Notice(title: 'Loading', text: 'Loading…'),
      error: (e, st) => const _Notice(title: 'Not found', text: 'Meal not found.'),
      data: (state) {
        NutritionMeal? meal;
        for (final m in state.meals) {
          if (m.id == mealId) {
            meal = m;
            break;
          }
        }
        if (meal == null) {
          return const _Notice(title: 'Not found', text: 'Meal not found.');
        }
        final expense = meal.linkedEntryId != null
            ? state.linkedExpenses[meal.linkedEntryId]
            : null;
        return _Body(meal: meal, expense: expense);
      },
    );
  }
}

/// The chrome with one plain line, while the meal loads or when it is gone.
class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      backLabel: _backLabel,
      eyebrow: 'Meal',
      title: title,
      children: [
        const SizedBox(height: Spacing.xxl),
        Text(text, style: AppType.subhead.copyWith(color: context.colors.ink3)),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.meal, this.expense});

  final NutritionMeal meal;
  final Entry? expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final note = meal.note;
    final from = meal.source == NutritionSource.takeout ? 'the order' : 'what you logged';

    return SubScreen(
      backLabel: _backLabel,
      eyebrow: '${meal.slot} · ${meal.time}',
      title: meal.name,
      children: [
        const SizedBox(height: Spacing.md),
        CalRange(meal.cal, hero: true),
        const SizedBox(height: Spacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon('sparkles', size: _sourceIcon, color: c.ink2),
            const SizedBox(width: _sourceGap),
            Expanded(
              child: Text(
                'From $from, ${meal.confidence.label}',
                style: AppType.label.copyWith(color: c.ink2),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xl),
        const _Heading('Macros'),
        MacroSplit(meal.macros),
        if (note != null && note.isNotEmpty)
          Text(note, style: AppType.subhead.copyWith(color: c.ink2)),
        if (meal.tags.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          Text(meal.tags.join(' · '), style: AppType.subhead.copyWith(color: c.ink3)),
        ],
        const SizedBox(height: Spacing.xl),
        const _Heading('Where this came from'),
        const SizedBox(height: Spacing.sm),
        _SourceRow(meal: meal, expense: expense),
        const SizedBox(height: Spacing.xl),
        Row(
          children: [
            Expanded(child: _AdjustButton(meal: meal)),
            const SizedBox(width: Spacing.sm),
            _RemoveButton(mealId: meal.id),
          ],
        ),
      ],
    );
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

/// One hairline row: the linked expense, or that the meal was added by hand.
class _SourceRow extends ConsumerWidget {
  const _SourceRow({required this.meal, this.expense});

  final NutritionMeal meal;
  final Entry? expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final linked = meal.linkedEntryId != null;
    final amount = expense?.amount;
    final (icon, title, subtitle) = switch (expense) {
      final e? => ('creditcard.fill', e.title, 'Linked expense'),
      null when linked => ('creditcard.fill', 'Linked expense', 'From a linked expense'),
      null => ('pencil', 'Added by hand', 'Not from an expense'),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
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
                Text(subtitle, style: AppType.subhead.copyWith(color: c.ink3)),
              ],
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: Spacing.md),
            Text(
              formatCurrency(amount.abs(), currency),
              style: AppType.subhead.copyWith(color: c.ink, fontFeatures: _tabular),
            ),
          ],
        ],
      ),
    );
  }
}

/// The secondary pill: opens the add sheet seeded with this meal.
class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.meal});
  final NutritionMeal meal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      // seed the sheet with this meal so Save edits it in place instead of
      // inserting a duplicate.
      onTap: () => showNutritionAddSheet(context, meal: meal),
      semanticLabel: 'Adjust estimate',
      child: Container(
        constraints: const BoxConstraints(minHeight: _pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          'Adjust estimate',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.headline.copyWith(color: c.ink),
        ),
      ),
    );
  }
}

/// Deletes the meal, then returns to where it was opened from.
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
      semanticLabel: 'Delete',
      child: Container(
        constraints: const BoxConstraints(minHeight: _minTap, minWidth: _minTap),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        alignment: Alignment.center,
        child: Text('Delete', style: AppType.headline.copyWith(color: c.careInk)),
      ),
    );
  }
}
