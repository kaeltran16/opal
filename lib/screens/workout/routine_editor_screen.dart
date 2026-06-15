import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/routine_editor_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

/// Common rest presets (seconds) offered by the rest segmented control.
const List<int> _restPresets = [60, 90, 120, 180];

/// Screen — Routine Editor (U21b). Creates a new routine ([routineId] null) or
/// edits an existing one. Name field + tag/rest segmented controls + warmup and
/// auto-progress toggles, then a reorderable list of exercise slots with an
/// "Add exercise" picker over the catalog. Save persists via
/// [RoutineEditorController] and pops.
class RoutineEditorScreen extends ConsumerWidget {
  const RoutineEditorScreen({super.key, this.routineId});

  /// Existing routine to edit, or null to create a new one.
  final String? routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final provider = routineEditorControllerProvider(routineId);
    final async = ref.watch(provider);

    return Scaffold(
      backgroundColor: c.bg,
      body: async.when(
        loading: () => Center(
          child: Text('…',
              style: AppType.body.copyWith(color: c.ink3)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Text("Couldn't load workout.\n$e",
                textAlign: TextAlign.center,
                style: AppType.subhead.copyWith(
                    color: c.ink3, letterSpacing: -0.24)),
          ),
        ),
        data: (state) => _Body(routineId: routineId, state: state),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.routineId, required this.state});

  final String? routineId;
  final RoutineEditorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller =
        ref.read(routineEditorControllerProvider(routineId).notifier);
    final draft = state.draft;
    final canSave = draft.name.trim().isNotEmpty;

    Future<void> onSave() async {
      await controller.save();
      if (context.mounted) context.pop();
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LargeTitleNavBar(
            title: state.isEditing ? 'Edit routine' : 'New routine',
            subtitle: state.isEditing ? draft.name : 'Build from scratch',
            leading: NavAction(
              icon: 'chevron.left',
              onTap: () => context.pop(),
              semanticLabel: 'Back',
            ),
            trailing: _SaveButton(enabled: canSave, onTap: canSave ? onSave : null),
          ),
          Expanded(
            child: ListView(
              // 40 off-grid, kept literal as the list's bottom inset
              padding: const EdgeInsets.only(top: Spacing.sm, bottom: 40),
              children: [
                _NameField(
                  value: draft.name,
                  onChanged: controller.setName,
                ),
                const SizedBox(height: Spacing.xl),
                _TagSection(
                  tag: draft.tag,
                  onChanged: controller.setTag,
                ),
                _RestSection(
                  rest: draft.restSeconds,
                  onChanged: controller.setRest,
                ),
                _TogglesSection(
                  warmup: draft.warmupReminder,
                  autoProgress: draft.autoProgress,
                  onWarmup: controller.toggleWarmup,
                  onAutoProgress: controller.toggleAutoProgress,
                ),
                _ExerciseList(
                  state: state,
                  onReorder: controller.reorder,
                  onRemove: controller.removeExercise,
                  onEdit: (slot) => _showTargetsSheet(
                    context,
                    slot: slot,
                    onSave: (sets, reps, weight) =>
                        controller.updateExerciseTargets(
                      slot.id,
                      sets: sets,
                      reps: reps,
                      weight: weight,
                    ),
                  ),
                ),
                _AddExerciseRow(
                  onTap: () => _showExercisePicker(
                    context,
                    catalog: state.catalog,
                    onPick: controller.addExercise,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White-pill Save CTA in the nav trailing slot.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, this.onTap});
  final bool enabled;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Text('Save',
              style: AppType.subhead.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.onAccent,
                  letterSpacing: -0.2)),
        ),
      ),
    );
  }
}

/// Routine name field in a fill-bg pill.
class _NameField extends StatefulWidget {
  const _NameField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_NameField old) {
    super.didUpdateWidget(old);
    // sync external changes (e.g. a reset draft) without clobbering in-progress
    // typing; clamp the cursor to the end of the new text.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 0),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          cursorColor: c.accent,
          style: AppType.body.copyWith(color: c.ink),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'Workout name',
            hintStyle: AppType.body.copyWith(color: c.ink3),
          ),
        ),
      ),
    );
  }
}

/// Section eyebrow used between groups.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.sm),
      child: Text(text.toUpperCase(),
          style: AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.08)),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.tag, required this.onChanged});
  final RoutineTag tag;
  final ValueChanged<RoutineTag> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Tag'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: Segmented<RoutineTag>(
            value: tag,
            onChanged: onChanged,
            options: const [
              (RoutineTag.upper, 'Upper'),
              (RoutineTag.lower, 'Lower'),
              (RoutineTag.full, 'Full'),
              (RoutineTag.cardio, 'Cardio'),
              (RoutineTag.custom, 'Custom'),
            ],
          ),
        ),
      ],
    );
  }
}

class _RestSection extends StatelessWidget {
  const _RestSection({required this.rest, required this.onChanged});
  final int rest;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // pass the raw value: an off-preset rest (e.g. a seeded 150s) matches no
    // preset, so no chip shows selected rather than mislabeling the stored value.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Rest between sets'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: Segmented<int>(
            value: rest,
            onChanged: onChanged,
            options: [for (final s in _restPresets) (s, '${s}s')],
          ),
        ),
      ],
    );
  }
}

class _TogglesSection extends StatelessWidget {
  const _TogglesSection({
    required this.warmup,
    required this.autoProgress,
    required this.onWarmup,
    required this.onAutoProgress,
  });
  final bool warmup;
  final bool autoProgress;
  final ValueChanged<bool> onWarmup;
  final ValueChanged<bool> onAutoProgress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InsetSection(
      children: [
        _SwitchRow(
          icon: 'bell.fill',
          iconBg: c.money,
          title: 'Warmup reminder',
          value: warmup,
          onChanged: onWarmup,
        ),
        _SwitchRow(
          icon: 'arrow.triangle.2.circlepath',
          iconBg: c.move,
          title: 'Auto-progress weights',
          value: autoProgress,
          onChanged: onAutoProgress,
          last: true,
        ),
      ],
    );
  }
}

/// A [ListRow]-styled row whose trailing control is a [Switch].
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.onChanged,
    this.last = false,
  });
  final String icon;
  final Color iconBg;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(icon, size: 17, color: c.onAccent),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(title,
                      style: AppType.body.copyWith(color: c.ink)),
                ),
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: c.move,
                ),
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

/// Reorderable list of exercise slots. Each tile shows the resolved name +
/// "sets × reps × weight" target, an edit affordance (tap), and a delete button.
class _ExerciseList extends StatelessWidget {
  const _ExerciseList({
    required this.state,
    required this.onReorder,
    required this.onRemove,
    required this.onEdit,
  });
  final RoutineEditorState state;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<String> onRemove;
  final ValueChanged<RoutineExercise> onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final slots = state.draft.orderedExercises;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader('Exercises · ${slots.length}'),
        if (slots.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.md),
            child: Text('No exercises yet — add one below.',
                style: AppType.subhead.copyWith(
                    color: c.ink3, letterSpacing: -0.24)),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.md),
            onReorderItem: onReorder,
            children: [
              for (final slot in slots)
                _ExerciseTile(
                  key: ValueKey(slot.id),
                  slot: slot,
                  exercise: state.exerciseFor(slot.exerciseId),
                  onEdit: () => onEdit(slot),
                  onRemove: () => onRemove(slot.id),
                ),
            ],
          ),
        if (slots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.md),
            child: Text(
              'Drag to reorder · tap ✕ to remove · tap a set to edit targets',
              style: AppType.caption.copyWith(color: c.ink3, letterSpacing: -0.08),
            ),
          ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    super.key,
    required this.slot,
    required this.exercise,
    required this.onEdit,
    required this.onRemove,
  });
  final RoutineExercise slot;
  final Exercise? exercise;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  String get _targets {
    final parts = <String>[
      if (exercise?.muscle case final m? when m.isNotEmpty) m,
      '${slot.targetSets}×${slot.targetReps ?? '—'}',
    ];
    final w = slot.targetWeightKg;
    if (w != null && w > 0) {
      parts.add('${formatWeight(w)} kg');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: GestureDetector(
          onTap: onEdit,
          behavior: HitTestBehavior.opaque,
          child: ColoredBox(
            color: c.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: c.move,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    alignment: Alignment.center,
                    child: AppIcon(exercise?.icon ?? 'dumbbell.fill',
                        size: 17, color: c.onAccent),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise?.name ?? 'Unknown exercise',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body.copyWith(color: c.ink)),
                        Padding(
                          // 1px nudge, kept literal (below smallest token)
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(_targets,
                              style: AppType.footnote.copyWith(
                                  color: c.ink3, letterSpacing: -0.08)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.sm),
                      child: AppIcon('xmark', size: 15, color: c.ink3),
                    ),
                  ),
                  const SizedBox(width: Spacing.xxs),
                  AppIcon('slider.horizontal.3', size: 16, color: c.ink4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add exercise" action row (opens the catalog picker sheet).
class _AddExerciseRow extends StatelessWidget {
  const _AddExerciseRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InsetSection(
      children: [
        ListRow(
          icon: 'plus',
          iconBg: c.accent,
          title: 'Add exercise',
          subtitle: 'Pick from the library',
          chevron: false,
          last: true,
          onTap: onTap,
        ),
      ],
    );
  }
}

/// Opens a searchable catalog picker; calls [onPick] with the chosen id.
Future<void> _showExercisePicker(
  BuildContext context, {
  required List<Exercise> catalog,
  required ValueChanged<String> onPick,
}) {
  final c = context.colors;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bg,
    isScrollControlled: true,
    builder: (context) => _ExercisePickerSheet(catalog: catalog, onPick: onPick),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({required this.catalog, required this.onPick});
  final List<Exercise> catalog;
  final ValueChanged<String> onPick;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Exercise> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.catalog;
    return widget.catalog
        .where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.muscle.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final results = _filtered;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.lg, Spacing.lg, Spacing.xs),
              child: Row(
                children: [
                  Text('Add exercise',
                      style: AppType.title3.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                          letterSpacing: -0.4)),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: AppIcon('xmark', size: 18, color: c.ink3),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                decoration: BoxDecoration(
                  color: c.fill,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Row(
                  children: [
                    AppIcon('magnifyingglass', size: 16, color: c.ink3),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (v) => setState(() => _query = v),
                        cursorColor: c.accent,
                        style: AppType.body.copyWith(color: c.ink),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Search exercises',
                          hintStyle: AppType.body.copyWith(color: c.ink3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text('No exercises match "$_query".',
                          style: AppType.subhead.copyWith(
                              color: c.ink3, letterSpacing: -0.24)),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(top: Spacing.xs, bottom: Spacing.xxl),
                      children: [
                        InsetSection(
                          children: [
                            for (var i = 0; i < results.length; i++)
                              ListRow(
                                icon: results[i].icon,
                                iconBg: c.move,
                                title: results[i].name,
                                subtitle: results[i].muscle,
                                chevron: false,
                                last: i == results.length - 1,
                                onTap: () {
                                  widget.onPick(results[i].id);
                                  Navigator.of(context).pop();
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a sheet to adjust a slot's sets/reps/weight targets.
Future<void> _showTargetsSheet(
  BuildContext context, {
  required RoutineExercise slot,
  required void Function(int sets, int reps, double weight) onSave,
}) {
  final c = context.colors;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bg,
    isScrollControlled: true,
    builder: (context) => _TargetsSheet(slot: slot, onSave: onSave),
  );
}

class _TargetsSheet extends StatefulWidget {
  const _TargetsSheet({required this.slot, required this.onSave});
  final RoutineExercise slot;
  final void Function(int sets, int reps, double weight) onSave;

  @override
  State<_TargetsSheet> createState() => _TargetsSheetState();
}

class _TargetsSheetState extends State<_TargetsSheet> {
  late int _sets = widget.slot.targetSets;
  late int _reps = widget.slot.targetReps ?? 8;
  late double _weight = widget.slot.targetWeightKg ?? 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.lg, Spacing.lg, Spacing.md),
              child: Text('Targets',
                  style: AppType.title3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.4)),
            ),
            _StepperRow(
              label: 'Sets',
              value: '$_sets',
              onDec: () => setState(() => _sets = (_sets - 1).clamp(1, 99)),
              onInc: () => setState(() => _sets = (_sets + 1).clamp(1, 99)),
            ),
            _StepperRow(
              label: 'Reps',
              value: '$_reps',
              onDec: () => setState(() => _reps = (_reps - 1).clamp(1, 99)),
              onInc: () => setState(() => _reps = (_reps + 1).clamp(1, 99)),
            ),
            _StepperRow(
              label: 'Weight',
              value: '${_weight.toStringAsFixed(0)} kg',
              onDec: () =>
                  setState(() => _weight = (_weight - 2.5).clamp(0, 999)),
              onInc: () =>
                  setState(() => _weight = (_weight + 2.5).clamp(0, 999)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.lg, Spacing.lg, Spacing.lg),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.onSave(_sets, _reps, _weight);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  alignment: Alignment.center,
                  child: Text('Done',
                      style: AppType.headline.copyWith(
                          color: c.onAccent, letterSpacing: -0.4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label + value with -/+ stepper buttons, used in the targets sheet.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onDec,
    required this.onInc,
  });
  final String label;
  final String value;
  final VoidCallback onDec;
  final VoidCallback onInc;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppType.body.copyWith(color: c.ink)),
          ),
          _StepButton(icon: 'chevron.down', onTap: onDec),
          SizedBox(
            width: 72,
            child: Text(value,
                textAlign: TextAlign.center,
                style: AppFonts.sfr(
                    size: 17, weight: FontWeight.w600, color: c.ink)),
          ),
          _StepButton(icon: 'chevron.up', onTap: onInc),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: c.fill, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: AppIcon(icon, size: 15, color: c.accent),
      ),
    );
  }
}
