import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/nutrition_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import 'widgets/nutrition_widgets.dart';

const _portions = ['Lighter', 'As shown', 'Larger'];

/// Opens the takeout-to-meal confirm sheet. Pass the pending [expense] and
/// Pal's [guess] from [NutritionPending].
Future<void> showNutritionConfirmSheet(
  BuildContext context, {
  required Entry expense,
  required MealEstimate guess,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // present over the shell so the sheet covers the bottom nav; without this it
    // opens on the tab's nested navigator and only fills the tab body.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NutritionConfirmSheet(expense: expense, guess: guess),
  );
}

class _NutritionConfirmSheet extends ConsumerStatefulWidget {
  const _NutritionConfirmSheet({
    required this.expense,
    required this.guess,
  });

  final Entry expense;
  final MealEstimate guess;

  @override
  ConsumerState<_NutritionConfirmSheet> createState() =>
      _NutritionConfirmSheetState();
}

class _NutritionConfirmSheetState
    extends ConsumerState<_NutritionConfirmSheet> {
  String _portion = 'As shown';
  late final TextEditingController _nameController;

  static const _factors = NutritionController.portionFactors;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.guess.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  IntRange _scaledCal() {
    final factor = _factors[_portion]!;
    return IntRange(
      (widget.guess.cal.lo * factor).round(),
      (widget.guess.cal.hi * factor).round(),
    );
  }

  Macros _scaledMacros() {
    final factor = _factors[_portion]!;
    IntRange s(IntRange r) =>
        IntRange((r.lo * factor).round(), (r.hi * factor).round());
    final base = widget.guess.macros;
    return Macros(protein: s(base.protein), carbs: s(base.carbs), fat: s(base.fat));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim().isEmpty
        ? widget.guess.name
        : _nameController.text.trim();
    await ref.read(nutritionControllerProvider.notifier).confirmFromExpense(
          widget.expense,
          widget.guess,
          name: name,
          portion: _portion,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.expense;

    final amount = e.amount != null
        ? '\$${e.amount!.abs().toStringAsFixed(2)}'
        : '';
    final time = '${e.timestamp.hour.toString().padLeft(2, '0')}:'
        '${e.timestamp.minute.toString().padLeft(2, '0')}';

    final scaledCal = _scaledCal();
    final scaledMacros = _scaledMacros();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SheetShell(
        title: 'Add as meal',
        onClose: () => Navigator.of(context).pop(),
        primaryLabel: 'Save',
        primaryEnabled: true,
        onPrimary: _save,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.lg, Spacing.lg, Spacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FROM YOUR SPENDING
              Text(
                'FROM YOUR SPENDING',
                style: AppFonts.sf(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 0.4),
              ),
              const SizedBox(height: Spacing.sm),
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: c.fill,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.nutritionTint,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Center(
                        child: AppIcon('bag.fill', size: 19, color: c.nutrition),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: AppFonts.sf(
                                size: 16,
                                weight: FontWeight.w600,
                                color: c.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            time,
                            style: AppType.footnote.copyWith(color: c.ink3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      amount,
                      style: AppFonts.sfr(
                          size: 17, weight: FontWeight.w700, color: c.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),
              // Pal's guess — sparkles eyebrow + editable name + helper.
              Row(
                children: [
                  AppIcon('sparkles', size: 13, color: c.nutrition),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    'PAL THINKS THIS WAS',
                    style: AppFonts.sf(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: c.nutrition,
                        letterSpacing: 0.4),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              TextField(
                controller: _nameController,
                style: AppFonts.sf(
                    size: 17, weight: FontWeight.w500, color: c.ink),
                decoration: InputDecoration(
                  hintText: 'Meal name',
                  hintStyle: AppFonts.sf(size: 17, color: c.ink3),
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.sm + 1),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide(
                        color: c.nutrition.withValues(alpha: 0.33),
                        width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide(color: c.nutrition, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Tap to rename if Pal got it wrong.',
                style: AppType.footnote.copyWith(color: c.ink3),
              ),
              const SizedBox(height: Spacing.lg),
              // PORTION
              Text(
                'PORTION',
                style: AppFonts.sf(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 0.4),
              ),
              const SizedBox(height: Spacing.sm),
              ChipRow(_portions, _portion, (v) => setState(() => _portion = v)),
              const SizedBox(height: Spacing.lg),
              // Live-scaled estimate card
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: c.fill,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CalRange(scaledCal, size: 36),
                        const Spacer(),
                        ConfidenceChip(widget.guess.confidence),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    MacroSplit(scaledMacros),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.md),
              // estimate note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon('leaf.fill', size: 12, color: c.ink4),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      'These are estimates from the order — you can edit the '
                      'meal anytime after saving.',
                      style:
                          AppType.footnote.copyWith(color: c.ink3, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.lg),
              // Dismiss link
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    'Not a meal — keep as expense only',
                    style: AppFonts.sf(
                        size: 14,
                        weight: FontWeight.w400,
                        color: c.ink3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
