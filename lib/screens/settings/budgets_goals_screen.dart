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
import '../../widgets/inset_section.dart';
import '../email/email_nav.dart';

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
      await ref.read(goalsRepositoryProvider).save(Goals(
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
    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          EmailNavBar(
            title: 'Budgets & goals',
            leadingLabel: 'You',
            onLeading: () => context.pop(),
            trailingLabel: 'Save',
            onTrailing: _save,
            trailingEnabled: _loaded && !_saving,
          ),
          const SizedBox(height: Spacing.sm),
          InsetSection(
            header: 'Currency',
            footer:
                'Changes how amounts display across the app. Existing amounts '
                'are not converted.',
            children: [
              Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Segmented<Currency>(
                  options: const [
                    (Currency.usd, 'USD (\$)'),
                    (Currency.vnd, 'VND (₫)'),
                  ],
                  value: currency,
                  onChanged: (v) => ref
                      .read(appSettingsControllerProvider.notifier)
                      .setCurrency(v),
                ),
              ),
            ],
          ),
          if (!_loaded)
            Padding(
              padding: const EdgeInsets.all(Spacing.xxl),
              child: Text('…',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: c.ink3)),
            )
          else
            InsetSection(
              header: 'Daily targets',
              footer:
                  'Targets power your daily rings and Pal’s nudges. The Routines ring tracks how many of your routines you complete each day — manage routines in Rituals.',
              children: [
                _StepperRow(
                  icon: 'dollarsign.circle.fill',
                  color: c.money,
                  label: 'Budget',
                  value: formatCurrency(_budget, currency),
                  onMinus: () => setState(
                      () => _budget = (_budget - budgetStep).clamp(0, budgetMax)),
                  onPlus: () => setState(
                      () => _budget = (_budget + budgetStep).clamp(0, budgetMax)),
                ),
                _StepperRow(
                  icon: 'figure.run',
                  color: c.move,
                  label: 'Workout',
                  value: '$_move kcal',
                  onMinus: () =>
                      setState(() => _move = (_move - 50).clamp(0, 5000)),
                  onPlus: () => setState(() => _move = (_move + 50).clamp(0, 5000)),
                ),
                _StepperRow(
                  icon: 'sparkles',
                  color: c.rituals,
                  label: 'Routines',
                  // Derived from the number of routines you have — completing
                  // all of them closes the ring. Edit routines in Rituals.
                  value: _routineCount == 1
                      ? '1 routine'
                      : '$_routineCount routines',
                  showSteppers: false,
                  last: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One inset-grouped row: tinted icon + label + current value + −/+ steppers.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onMinus,
    this.onPlus,
    this.showSteppers = true,
    this.last = false,
  });

  final String icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool showSteppers;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(Radii.sm)),
                  alignment: Alignment.center,
                  child: AppIcon(icon, size: 17, color: c.onAccent),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(label,
                      style: AppType.body.copyWith(color: c.ink)),
                ),
                Text(value,
                    style: AppType.body.copyWith(
                        color: c.ink2,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                if (showSteppers) ...[
                  const SizedBox(width: Spacing.md),
                  _StepButton(
                      icon: CupertinoIcons.minus, onTap: onMinus ?? () {}),
                  const SizedBox(width: Spacing.sm),
                  _StepButton(icon: CupertinoIcons.add, onTap: onPlus ?? () {}),
                ],
              ],
            ),
          ),
        ),
        if (!last)
          Positioned(
            left: 57,
            right: 0,
            bottom: 0,
            child: Container(height: 0.5, color: c.hair),
          ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: c.fill, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: c.accent),
      ),
    );
  }
}
