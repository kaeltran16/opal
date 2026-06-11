import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
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

  static const _dailyPresets = [50, 75, 100, 150];
  static const _weeklyPresets = [350, 500, 700, 1000];

  int get _step => _period == _Period.daily ? 5 : 25;

  void _bump(int delta) {
    setState(() => _amount = (_amount + delta).clamp(_step, 1 << 30));
  }

  void _switchPeriod(_Period p) {
    if (p == _period) return;
    setState(() {
      // rescale so the displayed amount stays roughly equivalent across periods
      if (p == _Period.weekly) {
        _amount = ((_amount * 7 / 25).round() * 25).clamp(25, 1 << 30);
      } else {
        _amount = ((_amount / 7 / 5).round() * 5).clamp(5, 1 << 30);
        if (_amount < 5) _amount = 5;
      }
      _period = p;
    });
  }

  /// The equivalent daily amount, regardless of the active period.
  int get _dailyAmount => _period == _Period.daily
      ? _amount
      : (_amount / 7 / 5).round() * 5 < 5
          ? 5
          : (_amount / 7 / 5).round() * 5;

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
            child: const ColoredBox(color: Color(0x59000000)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: ColoredBox(
              color: c.bg,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NavRow(onCancel: () => Navigator.of(context).pop(), onSave: _saving ? null : _save),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                      child: Column(
                        children: [
                          _PeriodSegmented(period: _period, onChanged: _switchPeriod),
                          const SizedBox(height: 26),
                          _AmountStepper(
                            amount: _amount,
                            caption: _period == _Period.daily ? 'PER DAY' : 'PER WEEK',
                            onMinus: () => _bump(-_step),
                            onPlus: () => _bump(_step),
                          ),
                          const SizedBox(height: 24),
                          _PresetChips(
                            presets: presets,
                            selected: _amount,
                            onSelect: (v) => setState(() => _amount = v),
                          ),
                          const SizedBox(height: 20),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      child: Row(
        children: [
          PressScale(
            onTap: onCancel,
            semanticLabel: 'Cancel',
            child: Text('Cancel',
                style: AppFonts.sf(size: 17, color: c.accent, letterSpacing: -0.43)),
          ),
          Expanded(
            child: Text('Budget',
                textAlign: TextAlign.center,
                style: AppFonts.sf(
                    size: 17, weight: FontWeight.w600, color: c.ink, letterSpacing: -0.43)),
          ),
          PressScale(
            onTap: onSave,
            semanticLabel: 'Save',
            child: Text('Save',
                style: AppFonts.sf(
                    size: 17,
                    weight: FontWeight.w600,
                    color: onSave == null ? c.ink4 : c.accent,
                    letterSpacing: -0.43)),
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
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(9)),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.surface : const Color(0x00000000),
            borderRadius: BorderRadius.circular(7),
            boxShadow: active
                ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: AppFonts.sf(
                  size: 14,
                  weight: FontWeight.w600,
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
    required this.onMinus,
    required this.onPlus,
  });
  final int amount;
  final String caption;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  String _grouped(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _circle(context, CupertinoIcons.minus, onMinus, 'Decrease'),
        const SizedBox(width: 22),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\$${_grouped(amount)}',
                style: AppFonts.sfr(
                    size: 54, weight: FontWeight.w700, color: c.money, letterSpacing: -1.8)),
            Text(caption,
                style: AppFonts.sf(
                    size: 12, weight: FontWeight.w600, color: c.ink3, letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(width: 22),
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
  const _PresetChips({required this.presets, required this.selected, required this.onSelect});
  final List<int> presets;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in presets)
          GestureDetector(
            onTap: () => onSelect(p),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: p == selected ? c.moneyTint : c.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: p == selected ? c.money : c.hair, width: 1),
              ),
              child: Text('\$$p',
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon('sparkles', size: 15, color: c.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pal nudges you as you near your $word budget — gently, and never blocks a purchase.',
              style: AppFonts.sf(size: 13, color: c.ink2, letterSpacing: -0.08, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
