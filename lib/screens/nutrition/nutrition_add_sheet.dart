import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/nutrition_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import 'widgets/nutrition_widgets.dart';

// Quick-pick options with calorie ranges.
const _quickPicks = [
  _QuickPick('Greek yogurt & granola', IntRange(240, 320)),
  _QuickPick('Eggs & toast', IntRange(320, 440)),
  _QuickPick('Chicken & rice bowl', IntRange(520, 680)),
  _QuickPick('Side salad', IntRange(120, 220)),
  _QuickPick('Banana', IntRange(90, 120)),
  _QuickPick('Protein shake', IntRange(160, 240)),
];

class _QuickPick {
  const _QuickPick(this.name, this.cal);
  final String name;
  final IntRange cal;
}

const _slots = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Drink'];

/// Opens the add-by-hand sheet. Inherits the parent [ProviderScope] via the
/// ambient [BuildContext] so Riverpod providers are accessible inside the sheet.
///
/// When [meal] is non-null the sheet edits that meal in place (Save routes
/// through `updateMeal`) instead of inserting a new one.
Future<void> showNutritionAddSheet(BuildContext context, {NutritionMeal? meal}) {
  return showModalBottomSheet<void>(
    context: context,
    // present over the shell so the sheet covers the bottom nav; without this it
    // opens on the tab's nested navigator and only fills the tab body.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NutritionAddSheet(meal: meal),
  );
}

class _NutritionAddSheet extends ConsumerStatefulWidget {
  const _NutritionAddSheet({this.meal});

  /// The meal being edited, or null when adding a new one.
  final NutritionMeal? meal;

  @override
  ConsumerState<_NutritionAddSheet> createState() => _NutritionAddSheetState();
}

class _NutritionAddSheetState extends ConsumerState<_NutritionAddSheet> {
  late String _slot;
  // single source for the meal name: what the user types is what gets saved.
  // estimate only fills in calories/macros — it never rewrites this field.
  final _nameController = TextEditingController();
  bool _loading = false;
  MealEstimate? _estimate;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    if (meal != null) {
      // editing: seed slot, name, and the current estimate so Save updates.
      _slot = meal.slot;
      _estimate = MealEstimate(
        name: meal.name,
        cal: meal.cal,
        confidence: meal.confidence,
      );
      _nameController.text = meal.name;
    } else {
      // adding: default the slot to the current time of day.
      _slot = NutritionController.slotForHour(DateTime.now().hour);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _runEstimate() async {
    // guard re-entrancy: tapping Estimate and pressing Enter both call this, so
    // bail while one is in flight to avoid a double request whose later reply wins.
    if (_loading) return;
    final text = _nameController.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final est = await ref
          .read(nutritionControllerProvider.notifier)
          .estimateFor(text);
      // keep the user's typed name; only adopt the estimate's calories/macros.
      if (mounted) setState(() => _estimate = est);
    } catch (_) {
      // swallow: the field stays as-is so the user can retry or pick a common one.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyQuickPick(_QuickPick pick) {
    setState(() {
      _estimate = MealEstimate(
        name: pick.name,
        cal: pick.cal,
        confidence: NutritionConfidence.low,
      );
      _nameController.text = pick.name;
    });
  }

  // drop the estimate so the quick-pick grid returns; keeps the typed name so the
  // user can tweak it and re-estimate or pick a common one.
  void _clearEstimate() => setState(() => _estimate = null);

  Future<void> _save() async {
    final est = _estimate;
    if (est == null) return;
    final name = _nameController.text.trim().isEmpty
        ? est.name
        : _nameController.text.trim();
    final notifier = ref.read(nutritionControllerProvider.notifier);
    final meal = widget.meal;
    if (meal != null) {
      await notifier.updateMeal(meal, slot: _slot, name: name, est: est);
    } else {
      await notifier.addManualMeal(slot: _slot, name: name, est: est);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final est = _estimate;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SheetShell(
        title: widget.meal != null ? 'Adjust estimate' : 'Add a meal',
        onClose: () => Navigator.of(context).pop(),
        primaryLabel: 'Save',
        primaryEnabled: est != null,
        onPrimary: est != null ? _save : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.lg, Spacing.lg, Spacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // When
              Text(
                'WHEN',
                style: AppFonts.sf(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 0.4),
              ),
              const SizedBox(height: Spacing.sm),
              ChipRow(_slots, _slot, (v) => setState(() => _slot = v)),
              const SizedBox(height: Spacing.lg),
              // Describe → estimate, in a tinted card.
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: c.nutritionTint,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                      color: c.nutrition.withValues(alpha: 0.20), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIcon('sparkles', size: 14, color: c.nutrition),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'WHAT DID YOU EAT?',
                          style: AppFonts.sf(
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: c.nutrition,
                              letterSpacing: 0.3),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            style: AppFonts.sf(size: 15, color: c.ink),
                            decoration: InputDecoration(
                              hintText: 'greek yogurt with berries',
                              hintStyle: AppFonts.sf(size: 15, color: c.ink3),
                              filled: true,
                              fillColor: c.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: Spacing.md, vertical: Spacing.sm),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(Radii.sm),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _runEstimate(),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        GestureDetector(
                          onTap: _loading ? null : _runEstimate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.md,
                                vertical: Spacing.sm + 2),
                            decoration: BoxDecoration(
                              color: c.nutrition,
                              borderRadius: BorderRadius.circular(Radii.sm),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Estimate',
                                    style: AppFonts.sf(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),
              if (est != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CalRange(est.cal),
                    const SizedBox(width: Spacing.md),
                    ConfidenceChip(est.confidence),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                MacroSplit(est.macros),
                const SizedBox(height: Spacing.lg),
                // back out of the estimate to the quick-pick grid
                GestureDetector(
                  onTap: _clearEstimate,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Start over',
                    style: AppFonts.sf(
                        size: 14, weight: FontWeight.w600, color: c.nutrition),
                  ),
                ),
              ] else ...[
                // Quick picks
                Text(
                  'OR PICK A COMMON ONE',
                  style: AppFonts.sf(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: c.ink3,
                      letterSpacing: 0.4),
                ),
                const SizedBox(height: Spacing.sm),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: Spacing.sm,
                  mainAxisSpacing: Spacing.sm,
                  childAspectRatio: 2.8,
                  children: [
                    for (final pick in _quickPicks)
                      GestureDetector(
                        onTap: () => _applyQuickPick(pick),
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.fill,
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md, vertical: Spacing.xs),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pick.name,
                                style: AppFonts.sf(
                                    size: 13,
                                    weight: FontWeight.w500,
                                    color: c.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '≈${((pick.cal.lo + pick.cal.hi) / 2).round()} cal',
                                style: AppFonts.sfr(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: c.nutrition),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
