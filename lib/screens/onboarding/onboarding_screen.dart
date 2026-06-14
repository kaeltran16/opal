import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../data/seed/seed_data.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';

/// Screen 01 — Onboarding (first-run setup), U17.
///
/// Four full-screen steps (no nav/tab bar): Welcome → Daily budget → Move goal
/// → Routines (three time-of-day routines — Morning / Midday / Evening — on by
/// default). On finish, writes a single [Goals] record, seeds the enabled
/// [RitualRoutine]s, and flips `onboardingComplete` in `SettingsRepository`,
/// at which point the `router.dart` redirect gate releases the app to Today.
///
/// All persistence goes through the repository providers so tests can override
/// the DB/prefs; the UI state (current step + selections) is purely ephemeral.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Budget chip options (handoff: $50/$85/$120/$200, default $85).
const _budgetOptions = <double>[50, 85, 120, 200];

/// Move-goal chip options in active-energy kcal (300/500/700/900, default 500).
const _moveOptions = <int>[300, 500, 700, 900];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 4;

  int _step = 0;
  double _budget = 85;
  int _moveKcal = 500;
  bool _saving = false;

  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// The three time-of-day routines offered on step 4.
  static final _routines = SeedData.ritualRoutines();

  /// Routine ids enabled on step 4 — all three on by default. Controls which
  /// routines get seeded on finish.
  late final Set<String> _selectedRoutineIds = {
    for (final r in _routines) r.id,
  };

  Future<void> _next() async {
    if (_saving) return;
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      return;
    }
    await _finish();
  }

  /// Persists Goals, ensures the default ritual routines exist, then flips the
  /// onboarding flag.
  Future<void> _finish() async {
    setState(() => _saving = true);

    final goals = ref.read(goalsRepositoryProvider);
    final rituals = ref.read(ritualRepositoryProvider);
    final settings = ref.read(settingsRepositoryProvider);

    try {
      await settings.setDisplayName(_nameController.text);

      await goals.save(Goals(
        dailyBudget: _budget,
        dailyMoveKcal: _moveKcal,
        dailyRitualTarget: 5,
      ));

      // Rituals are now the three time-of-day routines (Morning / Midday /
      // Evening). Seed the enabled ones idempotently so onboarding is
      // self-sufficient even when the DB seeder hasn't run.
      for (final routine in _routines) {
        if (_selectedRoutineIds.contains(routine.id)) {
          await rituals.upsertRoutine(routine);
        }
      }

      await settings.setOnboardingComplete(true);

      if (!mounted) return;
      // Land on Today; the redirect gate would also do this, but going
      // explicitly avoids waiting on a router refresh tick.
      context.goNamed(AppRoute.today.name);
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
    final step = _step;

    final Color heroColor = switch (step) {
      1 => c.money,
      2 => c.move,
      3 => c.rituals,
      _ => c.accent,
    };

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xxl,
            Spacing.xxl,
            Spacing.xxl,
            Spacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressDots(step: step, count: _stepCount),
              const SizedBox(height: 36), // off-grid hero gap, no token

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(glyph: _heroGlyph(step), color: heroColor),
                      const SizedBox(height: Spacing.xxl),
                      Text(
                        _title(step),
                        textAlign: TextAlign.center,
                        style: AppType.amount.copyWith(
                          color: c.ink,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.lg,
                        ),
                        child: Text(
                          _body(step),
                          textAlign: TextAlign.center,
                          style: AppType.body.copyWith(
                            color: c.ink3,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.xl),
                      ..._stepContent(step, c, heroColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              _Cta(
                label: _cta(step),
                enabled: !_saving && _canContinue(step),
                onTap: _next,
              ),
              if (step > 0) ...[
                const SizedBox(height: Spacing.md),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _saving ? null : _finish,
                    child: Text(
                      'Skip',
                      style: AppType.subhead.copyWith(
                        color: c.ink3,
                        letterSpacing: -0.24,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Per-step content -----------------------------------------------------

  bool _canContinue(int step) {
    // Require at least one routine on the final step; other steps always have a
    // default selection, so they're always continuable.
    if (step == 3) return _selectedRoutineIds.isNotEmpty;
    return true;
  }

  List<Widget> _stepContent(int step, AppColors c, Color heroColor) {
    switch (step) {
      case 0:
        return [
          _NameField(
            controller: _nameController,
            accent: heroColor,
            onSubmitted: (_) => _next(),
          ),
        ];
      case 1:
        return [
          _BigValue(text: '\$${_budget.toStringAsFixed(0)}', color: c.ink),
          const SizedBox(height: Spacing.xxl),
          _ChipRow(
            labels: [for (final v in _budgetOptions) '\$${v.toStringAsFixed(0)}'],
            selectedIndex: _budgetOptions.indexOf(_budget),
            selectedColor: heroColor,
            onSelected: (i) => setState(() => _budget = _budgetOptions[i]),
          ),
        ];
      case 2:
        return [
          _BigValue(text: '$_moveKcal KCAL', color: c.ink),
          const SizedBox(height: Spacing.xxl),
          _ChipRow(
            labels: [for (final m in _moveOptions) '$m kcal'],
            selectedIndex: _moveOptions.indexOf(_moveKcal),
            selectedColor: heroColor,
            onSelected: (i) => setState(() => _moveKcal = _moveOptions[i]),
          ),
        ];
      case 3:
        return [
          _RoutinePicker(
            routines: _routines,
            selected: _selectedRoutineIds,
            onToggle: (id) => setState(() {
              if (_selectedRoutineIds.contains(id)) {
                _selectedRoutineIds.remove(id);
              } else {
                _selectedRoutineIds.add(id);
              }
            }),
          ),
        ];
      default:
        return const [];
    }
  }

  String _heroGlyph(int step) => switch (step) {
        1 => '\$',
        2 => '◐',
        3 => '✧',
        _ => '✦',
      };

  String _title(int step) => switch (step) {
        1 => 'Set a daily\nbudget',
        2 => 'Pick a\nworkout goal',
        3 => 'Choose your\nroutines',
        _ => 'Welcome to\nOpal',
      };

  String _body(int step) => switch (step) {
        1 => "We'll help you stay under it — gently.",
        2 => 'Any session counts — we track the calories you burn.',
        3 =>
          'Three time-of-day routines to anchor your day — Morning, Midday, Evening. Edit the steps anytime.',
        _ =>
          "One app for money, workouts, and the little routines that hold your day together. What should we call you?",
      };

  String _cta(int step) => switch (step) {
        0 => 'Get started',
        3 => 'Start tracking',
        _ => 'Continue',
      };
}

/// Optional name input shown on the Welcome step. Styled to match the budget /
/// move chips (surface fill, hairline border). Empty is allowed — the profile
/// falls back to "You".
class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.accent,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final Color accent;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        cursorColor: accent,
        onSubmitted: onSubmitted,
        style: AppType.body.copyWith(color: c.ink),
        decoration: InputDecoration(
          hintText: 'Your name',
          hintStyle: AppType.body.copyWith(color: c.ink3),
          filled: true,
          fillColor: c.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.lg,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            borderSide: BorderSide(color: c.hair, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Centered progress dots: active = 20px accent, inactive = 6px fill.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.step, required this.count});
  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: Spacing.sm),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: i == step ? 20 : 6, // fixed dot sizes
            height: 6,
            decoration: BoxDecoration(
              color: i == step ? c.accent : c.fill,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
        ],
      ],
    );
  }
}

/// 96×96 tinted rounded-square hero with a centered glyph.
class _Hero extends StatelessWidget {
  const _Hero({required this.glyph, required this.color});
  final String glyph;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.xxl),
          boxShadow: [
            // accent-tinted glow, not neutral elevation — kept inline
            BoxShadow(
              color: color.withValues(alpha: 0.20),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          glyph,
          style: AppType.amountLg.copyWith(color: color),
        ),
      ),
    );
  }
}

/// Large tabular value display (budget / move goal).
class _BigValue extends StatelessWidget {
  const _BigValue({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppFonts.sfr(
        size: 72,
        weight: FontWeight.w700,
        color: color,
        letterSpacing: -2,
        height: 1,
      ),
    );
  }
}

/// Single-select pill chip row (budget / move goal).
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.labels,
    required this.selectedIndex,
    required this.selectedColor,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final Color selectedColor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.md,
              ),
              decoration: BoxDecoration(
                color: i == selectedIndex ? selectedColor : c.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: i == selectedIndex
                    ? null
                    : Border.all(color: c.hair, width: 0.5),
              ),
              child: Text(
                labels[i],
                style: AppType.subhead.copyWith(
                  fontWeight: FontWeight.w500,
                  color: i == selectedIndex ? c.onAccent : c.ink,
                  letterSpacing: -0.24,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The three time-of-day routines with per-row toggle switches.
class _RoutinePicker extends StatelessWidget {
  const _RoutinePicker({
    required this.routines,
    required this.selected,
    required this.onToggle,
  });

  final List<RitualRoutine> routines;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < routines.length; i++)
            _RoutineRow(
              routine: routines[i],
              on: selected.contains(routines[i].id),
              showDivider: i < routines.length - 1,
              onToggle: () => onToggle(routines[i].id),
            ),
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.routine,
    required this.on,
    required this.showDivider,
    required this.onToggle,
  });

  final RitualRoutine routine;
  final bool on;
  final bool showDivider;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = c.forType(routine.colorKey);
    final steps = routine.steps.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: c.hair, width: 0.5))
              : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              alignment: Alignment.center,
              child: AppIcon(routine.icon, size: 16, color: c.onAccent),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.name,
                    style: AppType.subhead.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.24,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${routine.time} · $steps ${steps == 1 ? 'step' : 'steps'}',
                    style: AppType.caption.copyWith(
                      color: c.ink3,
                      letterSpacing: -0.08,
                    ),
                  ),
                ],
              ),
            ),
            _Toggle(on: on, color: tone, track: c.fill),
          ],
        ),
      ),
    );
  }
}

/// 40×24 iOS-style toggle pill (purely visual; parent owns state).
class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.color, required this.track});
  final bool on;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 24,
      decoration: BoxDecoration(
        color: on ? color : track,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(Spacing.xxs),
          width: 20,
          height: 20,
          // fixed iOS toggle knob: always-white with a tight knob shadow (kept
          // literal — snapping blur 4→8 would change the control's intent)
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width 56px accent CTA button.
class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.enabled, required this.onTap});
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppType.headline.copyWith(color: c.onAccent),
          ),
        ),
      ),
    );
  }
}
