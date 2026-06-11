import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/routine_generator_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

const _white = Color(0xFFFFFFFF);

/// One quick-pick goal button (label + tinted SF Symbol). Tapping fills the
/// prompt and immediately generates.
class _QuickGoal {
  const _QuickGoal(this.label, this.icon, this.color);
  final String label;
  final String icon;
  final Color color;
}

/// Screen — AI Routine Generator (Handoff #2). Describes a goal in free text (or
/// taps a quick-pick), Pal builds an ordered routine drawn from the exercise
/// library, then the user reviews and saves it as a real [Routine]. All async +
/// the save path live in [RoutineGeneratorController]; this widget lays out the
/// hero pitch, prompt input, quick-picks, loading/error states, and the result
/// preview.
class RoutineGeneratorScreen extends ConsumerStatefulWidget {
  const RoutineGeneratorScreen({super.key});

  @override
  ConsumerState<RoutineGeneratorScreen> createState() =>
      _RoutineGeneratorScreenState();
}

class _RoutineGeneratorScreenState
    extends ConsumerState<RoutineGeneratorScreen> {
  final _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  List<_QuickGoal> _goals(AppColors c) => [
        _QuickGoal('45-min push for strength', 'flame.fill', c.move),
        _QuickGoal('Quick full-body, no barbell', 'figure.mixed.cardio', c.accent),
        _QuickGoal('Pull day focused on back', 'figure.pullup', c.rituals),
        _QuickGoal('Short HIIT cardio', 'bolt.fill', c.money),
        _QuickGoal('Legs — glutes and hams', 'figure.walk', const Color(0xFFFF9500)),
        _QuickGoal('Home workout, no gear', 'house.fill', c.red),
      ];

  void _generate(String goal) {
    if (goal.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    ref.read(routineGeneratorControllerProvider.notifier).generate(goal);
  }

  void _runQuickGoal(String label) {
    _promptController.text = label;
    _generate(label);
  }

  Future<void> _save() async {
    await ref.read(routineGeneratorControllerProvider.notifier).save();
    if (!mounted) return;
    // Back to the Start Workout picker so the new routine shows in the grid.
    context.go('/move/start');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(routineGeneratorControllerProvider);
    final isResult = state is RoutineGeneratorResult;
    final isLoading = state is RoutineGeneratorLoading;

    return Scaffold(
      backgroundColor: c.bg,
      body: LargeTitleScrollView(
        title: 'Generate with AI',
        leading: PressScale(
          onTap: () => context.pop(),
          semanticLabel: 'Cancel',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon('chevron.left', size: 20, color: c.accent),
              Text('Cancel',
                  style: AppFonts.sf(
                      size: 17, color: c.accent, letterSpacing: -0.43)),
            ],
          ),
        ),
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          if (!isResult) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: _HeroCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _PromptCard(
                controller: _promptController,
                enabled: !isLoading,
                onGenerate: () => _generate(_promptController.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _QuickPicks(
                goals: _goals(c),
                disabled: isLoading,
                onPick: _runQuickGoal,
              ),
            ),
          ],

          if (isLoading) const _LoadingPill(),

          if (state is RoutineGeneratorError)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _ErrorCard(message: state.message),
            ),

          if (state is RoutineGeneratorResult) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: _ResultHeader(draft: state.draft),
            ),
            _ExerciseSection(state: state),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ResultActions(
                onTryAgain:
                    ref.read(routineGeneratorControllerProvider.notifier).reset,
                onSave: _save,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dark hero card: the pitch shown before a result. Radial tints + sparkle
/// circle + headline + example prompt.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: c.ink)),
          Positioned(
            top: -50,
            right: -30,
            child: _RadialTint(size: 160, color: c.move, alpha: 0.27),
          ),
          Positioned(
            bottom: -40,
            left: 40,
            child: _RadialTint(size: 120, color: c.accent, alpha: 0.2),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: c.move),
                      alignment: Alignment.center,
                      child: const AppIcon('sparkles', size: 12, color: _white),
                    ),
                    const SizedBox(width: 8),
                    Text('PAL BUILDS YOUR ROUTINE',
                        style: AppFonts.sf(
                            size: 11,
                            weight: FontWeight.w700,
                            color: _white.withValues(alpha: 0.85),
                            letterSpacing: 1.2)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Describe what you want.\nPal picks the exercises.',
                    style: AppFonts.sfr(
                        size: 22,
                        weight: FontWeight.w700,
                        color: _white,
                        letterSpacing: -0.4,
                        height: 1.15)),
                const SizedBox(height: 6),
                Text('"A 30-min pull day I can do at the gym" or '
                    '"legs at home with dumbbells."',
                    style: AppFonts.sf(
                        size: 13,
                        color: _white.withValues(alpha: 0.75),
                        letterSpacing: -0.1,
                        height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft radial glow used behind the hero headline.
class _RadialTint extends StatelessWidget {
  const _RadialTint({required this.size, required this.color, required this.alpha});
  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

/// Prompt input card: multiline field + footer row (hint + Generate button).
class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.controller,
    required this.enabled,
    required this.onGenerate,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hair, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 3,
              maxLines: 6,
              cursorColor: c.accent,
              style: AppFonts.sf(
                  size: 15, color: c.ink, letterSpacing: -0.2, height: 1.4),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText:
                    'What kind of workout do you want? Goal, duration, equipment…',
                hintStyle: AppFonts.sf(
                    size: 15, color: c.ink3, letterSpacing: -0.2, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 0.5, color: c.hair),
          const SizedBox(height: 10),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canGenerate = enabled && value.text.trim().isNotEmpty;
              return Row(
                children: [
                  Expanded(
                    child: Text('Pal uses your exercise library & recent sessions',
                        style: AppFonts.sf(
                            size: 11, color: c.ink4, letterSpacing: -0.08)),
                  ),
                  const SizedBox(width: 10),
                  _GenerateButton(
                    enabled: canGenerate,
                    onTap: canGenerate ? onGenerate : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The "Generate" pill (sparkles + label). Move bg when enabled, fill when not.
class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.enabled, this.onTap});
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = enabled ? _white : c.ink4;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Generate',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? c.move : c.fill,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('sparkles', size: 11, color: fg),
            const SizedBox(width: 5),
            Text('Generate',
                style: AppFonts.sf(
                    size: 13,
                    weight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.1)),
          ],
        ),
      ),
    );
  }
}

/// Quick-pick goals: "Or try one of these" + a 2-col grid of tappable goals.
class _QuickPicks extends StatelessWidget {
  const _QuickPicks({
    required this.goals,
    required this.disabled,
    required this.onPick,
  });
  final List<_QuickGoal> goals;
  final bool disabled;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text('OR TRY ONE OF THESE',
              style: AppFonts.sf(
                  size: 12,
                  weight: FontWeight.w700,
                  color: c.ink3,
                  letterSpacing: 0.8)),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: [
            for (final g in goals)
              _QuickGoalButton(
                goal: g,
                disabled: disabled,
                onTap: disabled ? null : () => onPick(g.label),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickGoalButton extends StatelessWidget {
  const _QuickGoalButton({
    required this.goal,
    required this.disabled,
    this.onTap,
  });
  final _QuickGoal goal;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: goal.label,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.hair, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: goal.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: AppIcon(goal.icon, size: 15, color: goal.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(goal.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sf(
                        size: 13,
                        weight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.1,
                        height: 1.2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered spinner pill shown while Pal builds the routine.
class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: c.hair, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(c.move),
                  backgroundColor: c.move.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 8),
              Text('Pal is building your routine…',
                  style: AppFonts.sf(
                      size: 13, color: c.ink2, letterSpacing: -0.1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red-tinted error card with the failure message.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.red.withValues(alpha: 0.27), width: 0.5),
      ),
      child: Text(message,
          style: AppFonts.sf(size: 13, color: c.red, letterSpacing: -0.1)),
    );
  }
}

/// Gradient (move → accent) result header: "Generated" badge + name + tag pill +
/// "{N} exercises · ~{estMin} min" + rationale.
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.draft});
  final GeneratedRoutineDraft draft;

  String get _tagLabel {
    final w = draft.tag.wire;
    return w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';
  }

  String get _meta {
    final n = draft.exercises.length;
    final count = '$n ${n == 1 ? 'exercise' : 'exercises'}';
    final min = draft.estimatedMinutes;
    return min == null ? count : '$count · ~$min min';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.move, c.accent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon('sparkles', size: 9, color: _white),
                const SizedBox(width: 5),
                Text('GENERATED',
                    style: AppFonts.sf(
                        size: 10,
                        weight: FontWeight.w700,
                        color: _white,
                        letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(draft.name,
              style: AppFonts.sfr(
                  size: 24,
                  weight: FontWeight.w700,
                  color: _white,
                  letterSpacing: -0.5,
                  height: 1.1)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(_tagLabel,
                    style: AppFonts.sf(
                        size: 11,
                        weight: FontWeight.w600,
                        color: _white,
                        letterSpacing: -0.08)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(_meta,
                    style: AppFonts.sf(
                        size: 12,
                        color: _white.withValues(alpha: 0.85),
                        letterSpacing: -0.08)),
              ),
            ],
          ),
          if (draft.rationale != null && draft.rationale!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 0.5, color: _white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(draft.rationale!,
                style: AppFonts.sf(
                    size: 13,
                    color: _white.withValues(alpha: 0.9),
                    letterSpacing: -0.1,
                    height: 1.45)),
          ],
        ],
      ),
    );
  }
}

/// "Exercises" inset section — one row per generated exercise: icon tile + name
/// + "{group} · {equipment}" + set chips.
class _ExerciseSection extends StatelessWidget {
  const _ExerciseSection({required this.state});
  final RoutineGeneratorResult state;

  @override
  Widget build(BuildContext context) {
    final exercises = state.draft.exercises;
    return InsetSection(
      header: 'Exercises',
      children: [
        for (var i = 0; i < exercises.length; i++)
          _ExerciseRow(
            generated: exercises[i],
            exercise: state.exerciseFor(exercises[i].exerciseId),
            last: i == exercises.length - 1,
          ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.generated,
    required this.exercise,
    required this.last,
  });
  final GeneratedExerciseDraft generated;
  final Exercise? exercise;
  final bool last;

  String get _subtitle {
    final muscle = exercise?.muscle ?? '';
    final equip = exercise?.equipment;
    final parts = <String>[
      if (muscle.isNotEmpty) muscle,
      if (equip != null && equip.isNotEmpty) equip,
    ];
    return parts.join(' · ');
  }

  static String _setLabel(GeneratedSetDraft s) {
    final w = s.weightKg;
    if (w != null && w > 0) {
      final weight = w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();
      return '$weight×${s.reps ?? '—'}';
    }
    if (s.durationMinutes != null) return '${s.durationMinutes}min';
    if (s.reps != null) return '${s.reps} reps';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final subtitle = _subtitle;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.move.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: AppIcon(exercise?.icon ?? 'dumbbell.fill',
                        size: 16, color: c.move),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise?.name ?? 'Unknown exercise',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sf(
                                size: 15,
                                weight: FontWeight.w600,
                                color: c.ink,
                                letterSpacing: -0.24)),
                        if (subtitle.isNotEmpty)
                          Text(subtitle,
                              style: AppFonts.sf(
                                  size: 12,
                                  color: c.ink3,
                                  letterSpacing: -0.08)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final s in generated.sets)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_setLabel(s),
                            style: AppFonts.sfr(
                                size: 11,
                                weight: FontWeight.w600,
                                color: c.ink2,
                                letterSpacing: -0.08)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Positioned(
            left: 14,
            right: 0,
            bottom: 0,
            child: Container(height: 0.5, color: c.hair),
          ),
      ],
    );
  }
}

/// Result actions: "Try again" (bordered, flex 1) + "Save routine" (move, flex 2).
class _ResultActions extends StatelessWidget {
  const _ResultActions({required this.onTryAgain, required this.onSave});
  final VoidCallback onTryAgain;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: PressScale(
            onTap: onTryAgain,
            semanticLabel: 'Try again',
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.hair, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon('arrow.clockwise', size: 12, color: c.ink2),
                  const SizedBox(width: 5),
                  Text('Try again',
                      style: AppFonts.sf(
                          size: 14,
                          weight: FontWeight.w600,
                          color: c.ink2,
                          letterSpacing: -0.2)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: PressScale(
            onTap: onSave,
            semanticLabel: 'Save routine',
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: c.move,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text('Save routine',
                  style: AppFonts.sf(
                      size: 15,
                      weight: FontWeight.w700,
                      color: _white,
                      letterSpacing: -0.24)),
            ),
          ),
        ),
      ],
    );
  }
}
