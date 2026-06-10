import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../data/seed/seed_data.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';

/// Screen 01 — Onboarding (first-run setup), U17.
///
/// Four full-screen steps (no nav/tab bar): Welcome → Daily budget → Move goal
/// → pick-5 Rituals. On finish, writes a single [Goals] record, inserts the
/// selected [Ritual]s, and flips `onboardingComplete` in `SettingsRepository`,
/// at which point the `router.dart` redirect gate releases the app to Today.
///
/// All persistence goes through the repository providers so tests can override
/// the DB/prefs; the UI state (current step + selections) is purely ephemeral.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// One suggested ritual offered on step 4 (icon + title + default-on flag).
class _SuggestedRitual {
  const _SuggestedRitual(this.icon, this.title, {this.defaultOn = false});
  final String icon;
  final String title;
  final bool defaultOn;
}

const _suggestedRituals = <_SuggestedRitual>[
  _SuggestedRitual('book.closed.fill', 'Morning pages', defaultOn: true),
  _SuggestedRitual('tray.fill', 'Inbox zero', defaultOn: true),
  _SuggestedRitual('character.book.closed.fill', 'Language practice',
      defaultOn: true),
  _SuggestedRitual('dumbbell.fill', 'Stretch'),
  _SuggestedRitual('books.vertical.fill', 'Read before bed', defaultOn: true),
  _SuggestedRitual('heart.fill', 'Meditate', defaultOn: true),
];

/// Budget chip options (handoff: $50/$85/$120/$200, default $85).
const _budgetOptions = <double>[50, 85, 120, 200];

/// Move-goal chip options in minutes (handoff: 20/45/60/90, default 60).
const _moveOptions = <int>[20, 45, 60, 90];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 4;

  int _step = 0;
  double _budget = 85;
  int _moveMinutes = 60;
  bool _saving = false;

  /// Selected ritual titles, seeded from the default-on suggestions.
  late final Set<String> _selectedRituals = {
    for (final r in _suggestedRituals)
      if (r.defaultOn) r.title,
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

    await goals.save(Goals(
      dailyBudget: _budget,
      dailyMoveMinutes: _moveMinutes,
      dailyRitualTarget: 5,
    ));

    // Rituals are now the three time-of-day routines (Morning / Midday /
    // Evening). Seed them idempotently so onboarding is self-sufficient even
    // when the DB seeder hasn't run; the step-4 picks express intent only.
    for (final routine in SeedData.ritualRoutines()) {
      await rituals.upsertRoutine(routine);
    }

    await settings.setOnboardingComplete(true);

    if (!mounted) return;
    // Land on Today; the redirect gate would also do this, but going
    // explicitly avoids waiting on a router refresh tick.
    context.goNamed(AppRoute.today.name);
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressDots(step: step, count: _stepCount),
              const SizedBox(height: 36),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(glyph: _heroGlyph(step), color: heroColor),
                      const SizedBox(height: 24),
                      Text(
                        _title(step),
                        textAlign: TextAlign.center,
                        style: AppFonts.sfr(
                          size: 34,
                          weight: FontWeight.w700,
                          color: c.ink,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _body(step),
                          textAlign: TextAlign.center,
                          style: AppFonts.sf(
                            size: 17,
                            color: c.ink3,
                            letterSpacing: -0.43,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ..._stepContent(step, c, heroColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Cta(
                label: _cta(step),
                enabled: !_saving && _canContinue(step),
                onTap: _next,
              ),
              if (step > 0) ...[
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _saving ? null : _finish,
                    child: Text(
                      'Skip',
                      style: AppFonts.sf(
                        size: 15,
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
    // Require at least one ritual on the final step; other steps always have a
    // default selection, so they're always continuable.
    if (step == 3) return _selectedRituals.isNotEmpty;
    return true;
  }

  List<Widget> _stepContent(int step, AppColors c, Color heroColor) {
    switch (step) {
      case 1:
        return [
          _BigValue(text: '\$${_budget.toStringAsFixed(0)}', color: c.ink),
          const SizedBox(height: 24),
          _ChipRow(
            labels: [for (final v in _budgetOptions) '\$${v.toStringAsFixed(0)}'],
            selectedIndex: _budgetOptions.indexOf(_budget),
            selectedColor: heroColor,
            onSelected: (i) => setState(() => _budget = _budgetOptions[i]),
          ),
        ];
      case 2:
        return [
          _BigValue(text: '$_moveMinutes MIN', color: c.ink),
          const SizedBox(height: 24),
          _ChipRow(
            labels: [for (final m in _moveOptions) '$m min'],
            selectedIndex: _moveOptions.indexOf(_moveMinutes),
            selectedColor: heroColor,
            onSelected: (i) => setState(() => _moveMinutes = _moveOptions[i]),
          ),
        ];
      case 3:
        return [
          _RitualPicker(
            suggestions: _suggestedRituals,
            selected: _selectedRituals,
            onToggle: (title) => setState(() {
              if (_selectedRituals.contains(title)) {
                _selectedRituals.remove(title);
              } else {
                _selectedRituals.add(title);
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
        2 => 'Any kind of workout counts — run, walk, yoga, anything.',
        3 =>
          'Six small things you want to do each day. You can edit these anytime.',
        _ =>
          'One app for money, workouts, and the little routines that hold your day together.',
      };

  String _cta(int step) => switch (step) {
        0 => 'Get started',
        3 => 'Start tracking',
        _ => 'Continue',
      };
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
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: i == step ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == step ? c.accent : c.fill,
              borderRadius: BorderRadius.circular(100),
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
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
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
          style: AppFonts.sfr(size: 48, weight: FontWeight.w700, color: color),
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
        size: 64,
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
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: i == selectedIndex ? selectedColor : c.surface,
                borderRadius: BorderRadius.circular(100),
                border: i == selectedIndex
                    ? null
                    : Border.all(color: c.hair, width: 0.5),
              ),
              child: Text(
                labels[i],
                style: AppFonts.sf(
                  size: 15,
                  weight: FontWeight.w500,
                  color: i == selectedIndex
                      ? const Color(0xFFFFFFFF)
                      : c.ink,
                  letterSpacing: -0.24,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Multi-select rituals list with per-row toggle switches.
class _RitualPicker extends StatelessWidget {
  const _RitualPicker({
    required this.suggestions,
    required this.selected,
    required this.onToggle,
  });

  final List<_SuggestedRitual> suggestions;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < suggestions.length; i++)
            _RitualRow(
              ritual: suggestions[i],
              on: selected.contains(suggestions[i].title),
              showDivider: i < suggestions.length - 1,
              onToggle: () => onToggle(suggestions[i].title),
            ),
        ],
      ),
    );
  }
}

class _RitualRow extends StatelessWidget {
  const _RitualRow({
    required this.ritual,
    required this.on,
    required this.showDivider,
    required this.onToggle,
  });

  final _SuggestedRitual ritual;
  final bool on;
  final bool showDivider;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: c.hair, width: 0.5))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: c.rituals,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: AppIcon(ritual.icon, size: 15, color: const Color(0xFFFFFFFF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ritual.title,
                style: AppFonts.sf(size: 15, color: c.ink, letterSpacing: -0.24),
              ),
            ),
            _Toggle(on: on, color: c.move, track: c.fill),
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
        borderRadius: BorderRadius.circular(100),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(2),
          width: 20,
          height: 20,
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
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppFonts.sf(
              size: 17,
              weight: FontWeight.w600,
              color: const Color(0xFFFFFFFF),
              letterSpacing: -0.43,
            ),
          ),
        ),
      ),
    );
  }
}
