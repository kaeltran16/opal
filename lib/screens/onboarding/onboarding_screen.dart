import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../data/seed/seed_data.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/failure_note.dart';
import '../../widgets/pal_label.dart';
import '../../widgets/press_scale.dart';

// safe area minimums: the top sits 60 from the screen top, as on the board.
const _padTop = 60.0;
const _padSide = 16.0;
const _padBottom = 34.0;
const _barGap = 8.0;
const _leadTop = 32.0;
const _leadGap = 8.0;
const _leadMaxWidth = 330.0;
const _fieldTop = 28.0;
const _fieldHeight = 52.0;
const _fieldPadSide = 16.0;
const _amountTop = 32.0;
const _optionsTop = 24.0;
const _rowsTop = 24.0;
const _rowMinHeight = 64.0;
const _rowIcon = 22.0;
const _rowGap = 14.0;
const _rowTextGap = 2.0;
const _noneTop = 12.0;
const _hairline = 1.0;
const _alertGap = 12.0;
const _pillHeight = 48.0;
const _skipTop = 4.0;
const _skipHeight = 48.0;
const _ritualTarget = 5;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

const _stepCount = 4;
const _budgetOptions = <double>[50, 85, 120, 200];
const _moveOptions = <int>[300, 500, 700, 900];

const _titles = [
  'Welcome to Opal',
  'Set a daily budget',
  'Pick a workout goal',
  'Choose your routines',
];
const _bodies = [
  'One app for money, workouts, and the little routines that hold your day '
      'together. What should we call you?',
  "We'll help you stay under it, gently.",
  'Any session counts. We track the calories you burn.',
  'Three time-of-day routines to anchor your day. Edit the steps anytime.',
];
const _ctas = ['Get started', 'Continue', 'Continue', 'Start tracking'];
const _noneOn = 'Pick at least one routine to start.';

String _stepCountLabel(int n) => n == 1 ? '1 step' : '$n steps';
String _dollars(double v) => '\$${v.toStringAsFixed(0)}';

/// First-run setup: four full-screen steps (name, daily budget, move goal,
/// routines). Finishing writes [Goals], seeds the enabled [RitualRoutine]s and
/// flips `onboardingComplete`, which releases the router gate to Today.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static final _routines = SeedData.ritualRoutines();

  int _step = 0;
  double _budget = 85;
  int _moveKcal = 500;
  bool _saving = false;
  bool _saveError = false;
  final Set<String> _selectedRoutineIds = {for (final r in _routines) r.id};

  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _noneSelected => _step == _stepCount - 1 && _selectedRoutineIds.isEmpty;

  Future<void> _next() async {
    if (_saving || _noneSelected) return;
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      return;
    }
    await _finish();
  }

  void _toggle(String id) => setState(() {
        _saveError = false;
        if (!_selectedRoutineIds.remove(id)) _selectedRoutineIds.add(id);
      });

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _saveError = false;
    });

    final goals = ref.read(goalsRepositoryProvider);
    final rituals = ref.read(ritualRepositoryProvider);
    final settings = ref.read(settingsRepositoryProvider);

    try {
      await settings.setDisplayName(_nameController.text.trim());
      await goals.upsert(Goals(
        dailyBudget: _budget,
        dailyMoveKcal: _moveKcal,
        dailyRitualTarget: _ritualTarget,
      ));
      // seeded here so onboarding works even when the db seeder has not run.
      for (final routine in _routines) {
        if (_selectedRoutineIds.contains(routine.id)) {
          await rituals.upsertRoutine(routine);
        }
      }
      await settings.setOnboardingComplete(true);

      if (!mounted) return;
      // the redirect gate would also land here, but only on a later refresh.
      context.goNamed(AppRoute.today.name);
    } catch (e, st) {
      debugPrint('onboarding: saving the setup failed: $e\n$st');
      if (mounted) setState(() => _saveError = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final step = _step;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        minimum: const EdgeInsets.fromLTRB(_padSide, _padTop, _padSide, _padBottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${step + 1} of $_stepCount',
                style: AppType.caption.copyWith(color: c.ink3, fontFeatures: _tabular)),
            const SizedBox(height: _barGap),
            ProgressBar(value: (step + 1) / _stepCount, color: c.ink),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Lead(title: _titles[step], body: _bodies[step]),
                    ..._stepContent(step),
                  ],
                ),
              ),
            ),
            if (_saveError) ...[
              const FailureNote(),
              const SizedBox(height: _alertGap),
            ],
            _Pill(
              label: _ctas[step],
              onTap: _saving || _noneSelected ? null : _next,
            ),
            if (step > 0) ...[
              const SizedBox(height: _skipTop),
              PressScale(
                onTap: _saving ? null : _finish,
                semanticLabel: 'Skip',
                child: SizedBox(
                  height: _skipHeight,
                  child: Center(
                    child: Text('Skip', style: AppType.headline.copyWith(color: c.ink2)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _stepContent(int step) => switch (step) {
        0 => [
            const SizedBox(height: _fieldTop),
            _NameField(controller: _nameController, onSubmitted: (_) => _next()),
          ],
        1 => [
            const SizedBox(height: _amountTop),
            _Amount(
              value: _dollars(_budget),
              of: 'to spend each day',
            ),
            const SizedBox(height: _optionsTop),
            Segmented<double>(
              options: [for (final v in _budgetOptions) (v, _dollars(v))],
              value: _budget,
              onChanged: (v) => setState(() => _budget = v),
            ),
          ],
        2 => [
            const SizedBox(height: _amountTop),
            _Amount(
              value: '$_moveKcal',
              unit: ' kcal',
              of: 'of active energy each day',
            ),
            const SizedBox(height: _optionsTop),
            Segmented<int>(
              options: [for (final m in _moveOptions) (m, '$m kcal')],
              value: _moveKcal,
              onChanged: (m) => setState(() => _moveKcal = m),
            ),
          ],
        _ => [
            const SizedBox(height: _rowsTop),
            for (final r in _routines)
              _RoutineRow(
                routine: r,
                on: _selectedRoutineIds.contains(r.id),
                onToggle: () => _toggle(r.id),
              ),
            if (_selectedRoutineIds.isEmpty) const _NoneOn(),
          ],
      };
}

/// Pal's label, the step's serif headline and its body.
class _Lead extends StatelessWidget {
  const _Lead({required this.title, required this.body});

  final String title, body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: _leadTop),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _leadGap,
        children: [
          const PalLabel(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _leadMaxWidth),
            child: Semantics(
              header: true,
              child: Text(title, style: AppType.lead.copyWith(color: c.ink)),
            ),
          ),
          Text(body, style: AppType.body.copyWith(color: c.ink2)),
        ],
      ),
    );
  }
}

/// Optional name; empty falls back to "You" on the profile.
class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: _fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: _fieldPadSide),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(Radii.inset)),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        cursorColor: c.ink,
        onSubmitted: onSubmitted,
        style: AppType.body.copyWith(color: c.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          hintText: 'Your name',
          hintStyle: AppType.body.copyWith(color: c.ink3),
        ),
      ),
    );
  }
}

/// The chosen amount, light and tabular, with what it is a fraction of.
class _Amount extends StatelessWidget {
  const _Amount({required this.value, required this.of, this.unit = ''});

  final String value, unit, of;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$value$unit $of',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit.isNotEmpty)
                  TextSpan(text: unit, style: AppType.subhead.copyWith(color: c.ink3)),
              ],
            ),
            style: AppType.display.copyWith(color: c.ink),
          ),
          Text(of, style: AppType.subhead.copyWith(color: c.ink2)),
        ],
      ),
    );
  }
}

/// One seed routine with its switch; the whole row toggles.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.routine, required this.on, required this.onToggle});

  final RitualRoutine routine;
  final bool on;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      // the switch below carries the row's semantics.
      excludeFromSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: _rowMinHeight),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hair, width: _hairline)),
        ),
        child: Row(
          spacing: _rowGap,
          children: [
            AppIcon(routine.icon, size: _rowIcon, color: c.ink2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: _rowTextGap,
                children: [
                  Text(routine.name,
                      style: AppType.callout.copyWith(color: c.ink)),
                  Text(
                    '${routine.time} · ${_stepCountLabel(routine.steps.length)}',
                    style: AppType.subhead.copyWith(
                        color: c.ink3, fontFeatures: _tabular),
                  ),
                ],
              ),
            ),
            MergeSemantics(
              child: Semantics(
                label: routine.name,
                child: CupertinoSwitch(
                  value: on,
                  onChanged: (_) => onToggle(),
                  activeTrackColor: c.ink,
                  inactiveTrackColor: c.track,
                  thumbColor: c.bg,
                  inactiveThumbColor: c.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoneOn extends StatelessWidget {
  const _NoneOn();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(top: _noneTop),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Text(_noneOn, style: AppType.subhead.copyWith(color: c.ink3)),
    );
  }
}

/// The screen's one primary pill. A null [onTap] draws it disabled.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    final pill = PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: _pillHeight,
        decoration: BoxDecoration(
          color: enabled ? c.ink : c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: AppType.headline.copyWith(color: enabled ? c.bg : c.ink3)),
      ),
    );
    if (enabled) return pill;
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      excludeSemantics: true,
      child: pill,
    );
  }
}
