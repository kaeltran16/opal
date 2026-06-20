import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/nutrition_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
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
Future<void> showNutritionAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NutritionAddSheet(),
  );
}

class _NutritionAddSheet extends ConsumerStatefulWidget {
  const _NutritionAddSheet();

  @override
  ConsumerState<_NutritionAddSheet> createState() => _NutritionAddSheetState();
}

class _NutritionAddSheetState extends ConsumerState<_NutritionAddSheet> {
  String _slot = 'Lunch';
  final _textController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;
  MealEstimate? _estimate;

  @override
  void dispose() {
    _textController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _runEstimate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final est = await ref
          .read(nutritionControllerProvider.notifier)
          .estimateFor(text);
      if (mounted) {
        setState(() {
          _estimate = est;
          _nameController.text = est.name;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyQuickPick(_QuickPick pick) {
    final est = MealEstimate(
      name: pick.name,
      cal: pick.cal,
      confidence: NutritionConfidence.low,
    );
    setState(() {
      _estimate = est;
      _nameController.text = est.name;
    });
  }

  Future<void> _save() async {
    final est = _estimate;
    if (est == null) return;
    final name = _nameController.text.trim().isEmpty
        ? est.name
        : _nameController.text.trim();
    await ref.read(nutritionControllerProvider.notifier).addManualMeal(
          slot: _slot,
          name: name,
          est: est,
        );
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
        title: 'Add a meal',
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
              // Slot selector
              ChipRow(_slots, _slot, (v) => setState(() => _slot = v)),
              const SizedBox(height: Spacing.lg),
              // Free-text + Estimate button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: AppFonts.sf(size: 15, color: c.ink),
                      decoration: InputDecoration(
                        hintText: 'What did you eat?',
                        hintStyle: AppFonts.sf(size: 15, color: c.ink3),
                        filled: true,
                        fillColor: c.fill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md, vertical: Spacing.sm),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.md),
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
                          horizontal: Spacing.md, vertical: Spacing.sm + 2),
                      decoration: BoxDecoration(
                        color: c.nutrition,
                        borderRadius: BorderRadius.circular(Radii.md),
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
              const SizedBox(height: Spacing.lg),
              if (est != null) ...[
                // Editable name
                TextField(
                  controller: _nameController,
                  style: AppFonts.sf(
                      size: 17, weight: FontWeight.w600, color: c.ink),
                  decoration: InputDecoration(
                    hintText: 'Meal name',
                    hintStyle: AppFonts.sf(size: 17, color: c.ink3),
                    filled: true,
                    fillColor: c.fill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.sm),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
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
              ] else ...[
                // Quick picks
                Text(
                  'Quick picks',
                  style: AppFonts.sf(
                      size: 13,
                      weight: FontWeight.w600,
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
                              Text(
                                '${pick.cal.lo}–${pick.cal.hi} cal',
                                style: AppFonts.sfr(size: 12, color: c.ink3),
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
