import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/providers.dart';
import '../theme/theme.dart';
import '../util/format.dart';
import 'app_icon.dart';
import 'press_scale.dart';

/// Budget editor bottom sheet (Handoff §3), opened from You ▸ Goals ▸ budget row.
///
/// Holds the amount + period as local sheet state with a Daily/Weekly segmented
/// control, ±5/±25 circular steppers, preset chips, and a Pal footnote. On Save
/// it persists only the daily budget (rescaling a weekly amount back to daily),
/// reusing [goalsRepositoryProvider] so the Today rings and Pal nudges update;
/// the move/ritual targets are preserved via [Goals.copyWith].
class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, required this.dailyBudget});

  /// The current daily budget, used to seed the sheet.
  final double dailyBudget;

  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

enum _Period { daily, weekly }

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  _Period _period = _Period.daily;
  late int _amount = widget.dailyBudget.round();
  bool _saving = false;

  // USD-centric bases; scaled by the active currency's [budgetScale] so a VND
  // budget editor offers sane magnitudes instead of single-digit dong.
  static const _dailyPresetsBase = [50, 75, 100, 150];
  static const _weeklyPresetsBase = [350, 500, 700, 1000];

  Currency get _currency => ref.read(appSettingsControllerProvider).currency;
  int get _scale => _currency.budgetScale;

  List<int> get _dailyPresets => [for (final p in _dailyPresetsBase) p * _scale];
  List<int> get _weeklyPresets =>
      [for (final p in _weeklyPresetsBase) p * _scale];

  int get _dailyStep => 5 * _scale;
  int get _weeklyStep => 25 * _scale;
  int get _step => _period == _Period.daily ? _dailyStep : _weeklyStep;

  void _bump(int delta) {
    setState(() => _amount = (_amount + delta).clamp(_step, 1 << 30));
  }

  /// Rescales a weekly amount to its nearest daily-step equivalent (floored at
  /// the daily step). Single source for the weekly→daily conversion used by both
  /// the period switch and [_dailyAmount].
  int _weeklyToDaily(int weekly) {
    final daily = (weekly / 7 / _dailyStep).round() * _dailyStep;
    return daily < _dailyStep ? _dailyStep : daily;
  }

  void _switchPeriod(_Period p) {
    if (p == _period) return;
    setState(() {
      // rescale so the displayed amount stays roughly equivalent across periods
      if (p == _Period.weekly) {
        _amount = ((_amount * 7 / _weeklyStep).round() * _weeklyStep)
            .clamp(_weeklyStep, 1 << 30);
      } else {
        _amount = _weeklyToDaily(_amount);
      }
      _period = p;
    });
  }

  /// The equivalent daily amount, regardless of the active period.
  int get _dailyAmount =>
      _period == _Period.daily ? _amount : _weeklyToDaily(_amount);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ref.read(goalsRepositoryProvider);
    final current = await repo.get();
    await repo.save(current.copyWith(dailyBudget: _dailyAmount.toDouble()));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final presets = _period == _Period.daily ? _dailyPresets : _weeklyPresets;

    return Stack(
      children: [
        // backdrop (tap to dismiss without saving)
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: ColoredBox(color: c.scrim),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.lg)),
            child: ColoredBox(
              color: c.bg,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NavRow(onCancel: () => Navigator.of(context).pop(), onSave: _saving ? null : _save),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Spacing.lg, Spacing.xl, Spacing.lg, Spacing.xl),
                      child: Column(
                        children: [
                          _PeriodSegmented(period: _period, onChanged: _switchPeriod),
                          const SizedBox(height: Spacing.xxl),
                          _AmountStepper(
                            amount: _amount,
                            currency: _currency,
                            caption: _period == _Period.daily ? 'PER DAY' : 'PER WEEK',
                            onMinus: () => _bump(-_step),
                            onPlus: () => _bump(_step),
                          ),
                          const SizedBox(height: Spacing.xxl),
                          _PresetChips(
                            presets: presets,
                            selected: _amount,
                            currency: _currency,
                            onSelect: (v) => setState(() => _amount = v),
                          ),
                          const SizedBox(height: Spacing.xl),
                          _Footnote(period: _period),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cancel / Budget / Save nav row with a hairline bottom border.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.onCancel, required this.onSave});
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.lg, Spacing.lg, Spacing.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      child: Row(
        children: [
          PressScale(
            onTap: onCancel,
            semanticLabel: 'Cancel',
            child: Text('Cancel', style: AppType.body.copyWith(color: c.accent)),
          ),
          Expanded(
            child: Text('Budget',
                textAlign: TextAlign.center,
                style: AppType.headline.copyWith(color: c.ink)),
          ),
          PressScale(
            onTap: onSave,
            semanticLabel: 'Save',
            child: Text('Save',
                style: AppType.headline
                    .copyWith(color: onSave == null ? c.ink4 : c.accent)),
          ),
        ],
      ),
    );
  }
}

/// Daily / Weekly pill segmented control.
class _PeriodSegmented extends StatelessWidget {
  const _PeriodSegmented({required this.period, required this.onChanged});
  final _Period period;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Spacing.xxs),
      decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(Radii.sm)),
      child: Row(
        children: [
          _seg(context, 'Daily', _Period.daily),
          _seg(context, 'Weekly', _Period.weekly),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, String label, _Period p) {
    final c = context.colors;
    final active = p == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(p),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: active ? c.surface : const Color(0x00000000),
            borderRadius: BorderRadius.circular(Radii.sm),
            boxShadow: active ? Elevation.sm(c.shadow) : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: AppType.footnote.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active ? c.ink : c.ink3,
                  letterSpacing: -0.15)),
        ),
      ),
    );
  }
}

/// Big amount with circular −/+ steppers and a PER DAY/PER WEEK caption.
class _AmountStepper extends StatelessWidget {
  const _AmountStepper({
    required this.amount,
    required this.caption,
    required this.currency,
    required this.onMinus,
    required this.onPlus,
  });
  final int amount;
  final Currency currency;
  final String caption;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _circle(context, CupertinoIcons.minus, onMinus, 'Decrease'),
        const SizedBox(width: Spacing.xxl),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatCurrency(amount, currency),
                style: AppFonts.sfr(
                    size: 54, weight: FontWeight.w700, color: c.money, letterSpacing: -1.8)),
            Text(caption,
                style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w600, color: c.ink3, letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(width: Spacing.xxl),
        _circle(context, CupertinoIcons.add, onPlus, 'Increase'),
      ],
    );
  }

  Widget _circle(BuildContext context, IconData icon, VoidCallback onTap, String label) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.hair, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: c.ink),
      ),
    );
  }
}

/// Preset amount chips; the chip matching the current amount is highlighted.
class _PresetChips extends StatelessWidget {
  const _PresetChips({
    required this.presets,
    required this.selected,
    required this.currency,
    required this.onSelect,
  });
  final List<int> presets;
  final int selected;
  final Currency currency;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final p in presets)
          GestureDetector(
            onTap: () => onSelect(p),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: p == selected ? c.moneyTint : c.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: p == selected ? c.money : c.hair, width: 1),
              ),
              child: Text(formatCurrency(p, currency),
                  style: AppFonts.sfr(
                      size: 15,
                      weight: FontWeight.w600,
                      color: p == selected ? c.money : c.ink2)),
            ),
          ),
      ],
    );
  }
}

/// Pal footnote card explaining how the budget drives nudges.
class _Footnote extends StatelessWidget {
  const _Footnote({required this.period});
  final _Period period;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final word = period == _Period.daily ? 'daily' : 'weekly';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon('sparkles', size: 15, color: c.accent),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              'Pal nudges you as you near your $word budget — gently, and never blocks a purchase.',
              style: AppType.footnote
                  .copyWith(color: c.ink2, letterSpacing: -0.08, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
