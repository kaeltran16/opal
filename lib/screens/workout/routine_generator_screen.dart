import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/pal_suggestions_controller.dart';
import '../../controllers/routine_generator_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/exercise_row.dart';
import '../../widgets/failure_note.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/pal_lead.dart';
import '../../widgets/press_scale.dart';
import '../shell/loop_shell.dart' show shellBottomInset;

const double _sectionGap = Spacing.xl;
const double _textButtonHeight = 48;
const int _promptMinLines = 3;
const int _promptMaxLines = 6;
const String _exerciseIcon = 'dumbbell';
const String _lead = 'Describe the workout you want.';
const String _placeholder =
    'What kind of workout do you want? Goal, duration, equipment…';

/// The fallback quick goals when Pal has none to offer.
const List<String> _staticGoals = [
  '45-min push for strength',
  'Quick full-body, no barbell',
  'Pull day focused on back',
  'Short HIIT cardio',
  'Legs — glutes and hams',
  'Home workout, no gear',
];

/// Generate with Pal: describe a goal in free text (or tap a quick goal), Pal
/// builds an ordered routine from the exercise library, then the user reviews
/// and saves it as a real [Routine]. All async and the save path live in
/// [RoutineGeneratorController]; this widget lays out.
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
    try {
      await ref.read(routineGeneratorControllerProvider.notifier).save();
      if (!mounted) return;
      // back to the picker so the new routine shows in its list.
      context.go('/move/start');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(saveFailedCopy)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(routineGeneratorControllerProvider);
    final isLoading = state is RoutineGeneratorLoading;

    // Pal's goals when available; the static list covers loading, offline and
    // empty.
    final palGoals = ref
        .watch(palSuggestionsProvider(SuggestionSurface.routineGoal))
        .maybeWhen(
          data: (list) => list.isEmpty ? null : [for (final s in list) s.label],
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: c.bg,
      body: LargeTitleScrollView(
        title: 'Generate with Pal',
        leading: NavAction(
          icon: 'chevron.left',
          label: 'Cancel',
          onTap: () => context.pop(),
        ),
        padding: EdgeInsets.only(bottom: shellBottomInset(context)),
        children: [
          if (state is RoutineGeneratorResult)
            ..._result(state)
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.xs, Spacing.lg, 0),
              child: _Form(
                controller: _promptController,
                loading: isLoading,
                error: state is RoutineGeneratorError,
                goals: palGoals ?? _staticGoals,
                onGenerate: () => _generate(_promptController.text),
                onPick: _runQuickGoal,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _result(RoutineGeneratorResult state) {
    final exercises = state.draft.exercises;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.xs, Spacing.lg, _sectionGap),
        child: _ResultHeader(draft: state.draft),
      ),
      InsetSection(
        header: 'Exercises',
        children: [
          for (var i = 0; i < exercises.length; i++)
            ExerciseRow(
              name: state.exerciseFor(exercises[i].exerciseId)?.name ??
                  'Unknown exercise',
              detail: _setsDetail(exercises[i].sets),
              icon: _exerciseIcon,
              first: i == 0,
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Row(
          spacing: Spacing.sm,
          children: [
            Expanded(
              child: PillButton(
                label: 'Try again',
                primary: false,
                onTap: ref.read(routineGeneratorControllerProvider.notifier).reset,
              ),
            ),
            Expanded(child: PillButton(label: 'Save routine', onTap: _save)),
          ],
        ),
      ),
    ];
  }

  /// "{sets} × {reps}", or minutes for timed work.
  static String _setsDetail(List<GeneratedSetDraft> sets) {
    final n = sets.length;
    final first = sets.isEmpty ? null : sets.first;
    final reps = first?.reps;
    if (reps != null) return '$n × $reps';
    final minutes = first?.durationMinutes;
    if (minutes != null) return '$n × $minutes min';
    return '$n ${n == 1 ? 'set' : 'sets'}';
  }
}

/// Pal's lead, the prompt, Generate, a failure line, then the quick goals.
class _Form extends StatelessWidget {
  const _Form({
    required this.controller,
    required this.loading,
    required this.error,
    required this.goals,
    required this.onGenerate,
    required this.onPick,
  });

  final TextEditingController controller;
  final bool loading;
  final bool error;
  final List<String> goals;
  final VoidCallback onGenerate;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PalLead(text: _lead),
        const SizedBox(height: _sectionGap),
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: TextField(
            controller: controller,
            enabled: !loading,
            minLines: _promptMinLines,
            maxLines: _promptMaxLines,
            cursorColor: c.ink,
            style: AppType.body.copyWith(color: c.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: _placeholder,
              hintStyle: AppType.body.copyWith(color: c.ink3),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canGenerate = !loading && value.text.trim().isNotEmpty;
            return PillButton(
              label: loading ? 'Generating…' : 'Generate',
              onTap: canGenerate ? onGenerate : null,
            );
          },
        ),
        if (error) ...[
          const SizedBox(height: Spacing.md),
          _ErrorLine(onRetry: onGenerate),
        ],
        const SizedBox(height: _sectionGap),
        Text('Or try one of these',
            style: AppType.headline.copyWith(color: c.ink)),
        const SizedBox(height: Spacing.xs),
        // a goal generates at once, so none starts while Pal is building.
        IgnorePointer(
          ignoring: loading,
          child: Wrap(
            spacing: Spacing.sm,
            children: [
              for (final g in goals)
                AppChip(label: g, selected: false, onTap: () => onPick(g)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The failed generation: the state word first, then Try again.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text("Couldn't generate this routine.",
              style: AppType.subhead.copyWith(color: c.careInk)),
        ),
        PressScale(
          onTap: onRetry,
          semanticLabel: 'Try again',
          child: Container(
            constraints: const BoxConstraints(minHeight: _textButtonHeight),
            padding: const EdgeInsets.only(left: Spacing.lg),
            alignment: Alignment.center,
            child: Text('Try again',
                maxLines: 1,
                style: AppType.headline.copyWith(color: c.ink2)),
          ),
        ),
      ],
    );
  }
}

/// The generated routine's name, its meta and Pal's reason for it.
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.draft});
  final GeneratedRoutineDraft draft;

  String get _meta {
    final w = draft.tag.wire;
    final tag = w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';
    final n = draft.exercises.length;
    final min = draft.estimatedMinutes;
    return [
      if (tag.isNotEmpty) tag,
      '$n ${n == 1 ? 'exercise' : 'exercises'}',
      if (min != null) '~$min min',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rationale = draft.rationale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.xxs,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(draft.name, style: AppType.title.copyWith(color: c.ink)),
        ),
        // the meta and why read as one stop after the name, not inside it
        Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Spacing.xxs,
            children: [
              Text(_meta, style: AppType.label.copyWith(color: c.ink3)),
              if (rationale != null && rationale.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(rationale,
                      style: AppType.subhead.copyWith(color: c.ink2)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
