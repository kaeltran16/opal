import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';

const double _minTap = 44;
const double _pillHeight = 48;
const double _rowMinHeight = 48;
const double _hairline = 1;
const double _rowIcon = 20;
const double _stepIcon = 16;
const double _rowLineHeight = 22 / 16;
const double _disabledOpacity = 0.4;
const int _moveStep = 50;
const int _moveMax = 5000;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Settings → Budgets & goals.
///
/// Edits the single [Goals] record (daily budget / move kcal / ritual
/// target) with steppers and persists it via [GoalsRepository] on Save. The
/// same targets drive the Today rings and Pal's nudges.
class BudgetsGoalsScreen extends ConsumerStatefulWidget {
  const BudgetsGoalsScreen({super.key});

  @override
  ConsumerState<BudgetsGoalsScreen> createState() => _BudgetsGoalsScreenState();
}

class _BudgetsGoalsScreenState extends ConsumerState<BudgetsGoalsScreen> {
  bool _loaded = false;
  bool _saving = false;
  double _budget = 0;
  int _move = 0;
  // The persisted ritual target is no longer user-editable here: the Today
  // "Routines" metric is completed-routines ÷ total-routines, so the
  // denominator derives from the actual routine count ([_routineCount]). We
  // still keep the stored [Goals.dailyRitualTarget] value untouched on save so
  // the period-based "rituals kept" metrics (reviews/insights/Pal) are
  // unaffected.
  int _ritualTarget = 0;
  int _routineCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await ref.read(goalsRepositoryProvider).get();
    final routines = await ref.read(ritualRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() {
      _budget = g.dailyBudget;
      _move = g.dailyMoveKcal;
      _ritualTarget = g.dailyRitualTarget;
      _routineCount = routines.length;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    if (!_loaded || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(goalsRepositoryProvider).upsert(Goals(
            dailyBudget: _budget,
            dailyMoveKcal: _move,
            dailyRitualTarget: _ritualTarget,
          ));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save — try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = ref.watch(appSettingsControllerProvider);
    final currency = settings.currency;
    // budget steps scale with the currency so VND offers sane magnitudes
    final budgetStep = (5 * currency.budgetScale).toDouble();
    final budgetMax = (100000 * currency.budgetScale).toDouble();
    return SubScreen(
      eyebrow: 'Settings',
      title: 'Budgets & goals',
      children: [
        const SizedBox(height: Spacing.xxl),
        const _Heading('Currency'),
        const SizedBox(height: Spacing.md),
        Segmented<Currency>(
          options: const [
            (Currency.usd, 'USD (\$)'),
            (Currency.vnd, 'VND (₫)'),
          ],
          value: currency,
          onChanged: (v) =>
              ref.read(appSettingsControllerProvider.notifier).setCurrency(v),
        ),
        const _Footer(
            'Changes how amounts display across the app. Existing amounts are not converted.'),
        const SizedBox(height: Spacing.xxxl),
        const _Heading('Daily targets'),
        const SizedBox(height: Spacing.xs),
        if (!_loaded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
            child: Text('…',
                textAlign: TextAlign.center, style: AppType.body.copyWith(color: c.ink3)),
          )
        else ...[
          _StepperRow(
            icon: 'dollarsign.circle.fill',
            label: 'Budget',
            value: formatCurrency(_budget, currency),
            onMinus: () =>
                setState(() => _budget = (_budget - budgetStep).clamp(0, budgetMax)),
            onPlus: () =>
                setState(() => _budget = (_budget + budgetStep).clamp(0, budgetMax)),
          ),
          _StepperRow(
            icon: 'figure.run',
            label: 'Workout',
            value: '$_move kcal',
            onMinus: () => setState(() => _move = (_move - _moveStep).clamp(0, _moveMax)),
            onPlus: () => setState(() => _move = (_move + _moveStep).clamp(0, _moveMax)),
          ),
          _StepperRow(
            icon: 'sparkles',
            label: 'Routines',
            // Derived from the number of routines you have — completing
            // all of them closes the ring. Edit routines in Rituals.
            value: _routineCount == 1 ? '1 routine' : '$_routineCount routines',
          ),
          const _Footer(
              'Targets power your daily rings and Pal’s nudges. The Routines ring tracks how '
              'many of your routines you complete each day — manage routines in Rituals.'),
        ],
        const SizedBox(height: Spacing.xxxl),
        _SavePill(enabled: _loaded && !_saving, onTap: _save),
      ],
    );
  }
}

/// One hairline row: line icon, label over its current value, then −/+
/// steppers when [onMinus] and [onPlus] are given.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onMinus,
    this.onPlus,
  });

  final String icon;
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final onMinus = this.onMinus;
    final onPlus = this.onPlus;
    return Container(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        children: [
          AppIcon(icon, size: _rowIcon, color: c.ink2),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppType.callout.copyWith(color: c.ink, height: _rowLineHeight)),
                  Text(value,
                      style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular)),
                ],
              ),
            ),
          ),
          if (onMinus != null && onPlus != null) ...[
            const SizedBox(width: Spacing.md),
            _StepButton(icon: CupertinoIcons.minus, label: 'Decrease $label', onTap: onMinus),
            const SizedBox(width: Spacing.sm),
            _StepButton(icon: CupertinoIcons.add, label: 'Increase $label', onTap: onPlus),
          ],
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: _minTap,
        height: _minTap,
        decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: _stepIcon, color: c.ink),
      ),
    );
  }
}

/// The screen's one primary action, dimmed until the goals have loaded.
class _SavePill extends StatelessWidget {
  const _SavePill({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Save',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: PressScale(
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: _pillHeight),
            decoration: BoxDecoration(
              color: c.ink,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            alignment: Alignment.center,
            child: Text('Save', style: AppType.headline.copyWith(color: c.bg)),
          ),
        ),
      ),
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
