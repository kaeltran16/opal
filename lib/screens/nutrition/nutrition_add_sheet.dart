import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/nutrition_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/press_scale.dart';
import 'widgets/nutrition_widgets.dart';

const double _minTap = 44;
const double _pillHeight = 48;
const double _rowHeight = 48;
const double _hairline = 1;
const double _spinner = 16;
const double _spinnerStroke = 2;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

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
      _slot = NutritionController.slotForHour(clock.now().hour);
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel('When'),
              const SizedBox(height: Spacing.sm),
              ChipRow(_slots, _slot, (v) => setState(() => _slot = v)),
              const SizedBox(height: Spacing.xxl),
              const _SectionLabel('What did you eat?'),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: AppType.body.copyWith(color: c.ink),
                      decoration: InputDecoration(
                        hintText: 'greek yogurt with berries',
                        hintStyle: AppType.body.copyWith(color: c.ink3),
                        filled: true,
                        fillColor: c.surface2,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: Spacing.xl, vertical: Spacing.md),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _runEstimate(),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  _EstimateButton(
                    loading: _loading,
                    onTap: _loading ? null : _runEstimate,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xxl),
              if (est != null) ...[
                CalRange(est.cal),
                const SizedBox(height: Spacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConfidenceChip(est.confidence),
                ),
                const SizedBox(height: Spacing.sm),
                MacroSplit(est.macros),
                // back out of the estimate to the quick picks
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PressScale(
                    onTap: _clearEstimate,
                    semanticLabel: 'Start over',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: _minTap),
                      child: Align(
                        widthFactor: 1,
                        child: Text('Start over',
                            style: AppType.headline.copyWith(color: c.ink)),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const _SectionLabel('Or pick a common one'),
                const SizedBox(height: Spacing.xs),
                for (final pick in _quickPicks)
                  _QuickPickRow(pick: pick, onTap: () => _applyQuickPick(pick)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppType.label.copyWith(color: context.colors.ink3));
}

/// The secondary pill that asks Pal for an estimate; a spinner while it runs.
class _EstimateButton extends StatelessWidget {
  const _EstimateButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Estimate',
      child: Container(
        constraints: const BoxConstraints(minHeight: _pillHeight, minWidth: _pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        alignment: Alignment.center,
        child: loading
            ? Semantics(
                label: 'Estimating',
                child: SizedBox.square(
                  dimension: _spinner,
                  child: CircularProgressIndicator(strokeWidth: _spinnerStroke, color: c.ink),
                ),
              )
            : Text('Estimate', style: AppType.headline.copyWith(color: c.ink)),
      ),
    );
  }
}

/// A common meal as a hairline row: name left, its rough kcal right.
class _QuickPickRow extends StatelessWidget {
  const _QuickPickRow({required this.pick, required this.onTap});

  final _QuickPick pick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final kcal = '${pick.cal.mid} kcal';
    return PressScale(
      onTap: onTap,
      semanticLabel: '${pick.name}, $kcal',
      child: Container(
        constraints: const BoxConstraints(minHeight: _rowHeight),
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hair, width: _hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(pick.name, style: AppType.callout.copyWith(color: c.ink)),
            ),
            const SizedBox(width: Spacing.md),
            Text(kcal,
                style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular)),
          ],
        ),
      ),
    );
  }
}
