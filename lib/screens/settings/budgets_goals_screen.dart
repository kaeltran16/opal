import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../email/email_nav.dart';

/// Settings → Budgets & goals.
///
/// Edits the single [Goals] record (daily budget / move minutes / ritual
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
  int _rituals = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await ref.read(goalsRepositoryProvider).get();
    if (!mounted) return;
    setState(() {
      _budget = g.dailyBudget;
      _move = g.dailyMoveMinutes;
      _rituals = g.dailyRitualTarget;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    if (!_loaded || _saving) return;
    setState(() => _saving = true);
    await ref.read(goalsRepositoryProvider).save(Goals(
          dailyBudget: _budget,
          dailyMoveMinutes: _move,
          dailyRitualTarget: _rituals,
        ));
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
          const SizedBox(height: 8),
          if (!_loaded)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('…',
                  textAlign: TextAlign.center,
                  style: AppFonts.sf(
                      size: 17, color: c.ink3, letterSpacing: -0.43)),
            )
          else
            InsetSection(
              header: 'Daily targets',
              footer: 'Targets power your daily rings and Pal’s nudges.',
              children: [
                _StepperRow(
                  icon: 'dollarsign.circle.fill',
                  color: c.money,
                  label: 'Budget',
                  value: '\$${_budget.round()}',
                  onMinus: () =>
                      setState(() => _budget = (_budget - 5).clamp(0, 100000)),
                  onPlus: () => setState(() => _budget += 5),
                ),
                _StepperRow(
                  icon: 'figure.run',
                  color: c.move,
                  label: 'Move',
                  value: '$_move min',
                  onMinus: () =>
                      setState(() => _move = (_move - 5).clamp(0, 1440)),
                  onPlus: () => setState(() => _move = (_move + 5).clamp(0, 1440)),
                ),
                _StepperRow(
                  icon: 'sparkles',
                  color: c.rituals,
                  label: 'Rituals',
                  value: '$_rituals',
                  last: true,
                  onMinus: () =>
                      setState(() => _rituals = (_rituals - 1).clamp(0, 50)),
                  onPlus: () =>
                      setState(() => _rituals = (_rituals + 1).clamp(0, 50)),
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
    required this.onMinus,
    required this.onPlus,
    this.last = false,
  });

  final String icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(7)),
                  alignment: Alignment.center,
                  child: AppIcon(icon, size: 17, color: const Color(0xFFFFFFFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: AppFonts.sf(
                          size: 17, color: c.ink, letterSpacing: -0.43)),
                ),
                Text(value,
                    style: AppFonts.sf(
                        size: 17,
                        color: c.ink2,
                        letterSpacing: -0.43,
                        tabular: true)),
                const SizedBox(width: 10),
                _StepButton(icon: CupertinoIcons.minus, onTap: onMinus),
                const SizedBox(width: 8),
                _StepButton(icon: CupertinoIcons.add, onTap: onPlus),
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
