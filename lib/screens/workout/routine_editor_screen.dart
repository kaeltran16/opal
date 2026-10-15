import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/routine_editor_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/controls.dart';
import '../../widgets/exercise_row.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../shell/loop_shell.dart' show shellBottomInset;

/// Common rest presets (seconds) offered by the rest segmented control.
const List<int> _restPresets = [60, 90, 120, 180];

const double _minTap = 44;
const double _toggleRowHeight = 52;
const double _hairline = 1;
const double _rowIcon = 20;
const double _stepperGap = Spacing.sm;
const int _minSets = 1;
const int _maxSets = 99;
const int _minReps = 1;
const int _maxReps = 99;
const int _defaultReps = 8;
const double _minWeight = 0;
const double _maxWeight = 999;
const double _weightStep = 2.5;

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
          child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Text(
              "Couldn't load workout.\n$e",
              textAlign: TextAlign.center,
              style: AppType.subhead.copyWith(color: c.ink3),
            ),
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
    final controller = ref.read(routineEditorControllerProvider(routineId).notifier);
    final draft = state.draft;
    // a routine with no exercises has nothing to start a session from.
    final canSave = draft.name.trim().isNotEmpty && draft.exercises.isNotEmpty;

    Future<void> onSave() async {
      await controller.save();
      if (context.mounted) context.pop();
    }

    return LargeTitleScrollView(
      title: state.isEditing ? 'Edit routine' : 'New routine',
      subtitle: state.isEditing ? draft.name : 'Build from scratch',
      leading: NavAction(icon: 'chevron.left', onTap: () => context.pop(), semanticLabel: 'Back'),
      padding: EdgeInsets.only(
        top: Spacing.sm,
        bottom: shellBottomInset(context),
      ),
      children: [
        _NameField(value: draft.name, onChanged: controller.setName),
        InsetSection(
          header: 'Tag',
          children: [
            Segmented<RoutineTag>(
              value: draft.tag,
              onChanged: controller.setTag,
              options: const [
                (RoutineTag.upper, 'Upper'),
                (RoutineTag.lower, 'Lower'),
                (RoutineTag.full, 'Full'),
                (RoutineTag.cardio, 'Cardio'),
                (RoutineTag.custom, 'Custom'),
              ],
            ),
          ],
        ),
        // pass the raw value: an off-preset rest (e.g. a seeded 150s) matches no
        // preset, so no segment shows selected rather than mislabeling it.
        InsetSection(
          header: 'Rest between sets',
          children: [
            Segmented<int>(
              value: draft.restSeconds,
              onChanged: controller.setRest,
              options: [for (final s in _restPresets) (s, '${s}s')],
            ),
          ],
        ),
        InsetSection(
          children: [
            _ToggleRow(
              title: 'Warmup reminder',
              value: draft.warmupReminder,
              onChanged: controller.toggleWarmup,
            ),
            _ToggleRow(
              title: 'Auto-progress weights',
              value: draft.autoProgress,
              onChanged: controller.toggleAutoProgress,
              last: true,
            ),
          ],
        ),
        _ExerciseList(
          state: state,
          onReorder: controller.reorder,
          onRemove: controller.removeExercise,
          onEdit: (slot) => _showTargetsSheet(
            context,
            slot: slot,
            onSave: (sets, reps, weight) =>
                controller.updateExerciseTargets(slot.id, sets: sets, reps: reps, weight: weight),
          ),
        ),
        InsetSection(
          children: [
            ListRow(
              icon: 'plus',
              title: 'Add exercise',
              subtitle: 'Pick from the library',
              chevron: false,
              last: true,
              onTap: () => _showExercisePicker(
                context,
                catalog: state.catalog,
                onPick: controller.addExercise,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: PillButton(label: 'Save', semanticLabel: 'Save', onTap: canSave ? onSave : null),
        ),
      ],
    );
  }
}

/// Borderless routine name in the title size, on a hairline.
class _NameField extends StatefulWidget {
  const _NameField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

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
    final underline = UnderlineInputBorder(
      borderSide: BorderSide(color: c.hair, width: _hairline),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        cursorColor: c.ink,
        style: AppType.title.copyWith(color: c.ink),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          border: underline,
          enabledBorder: underline,
          focusedBorder: underline,
          hintText: 'Workout name',
          hintStyle: AppType.title.copyWith(color: c.ink3),
        ),
      ),
    );
  }
}

/// A hairline row with its title and an [AppSwitch] at the right.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.last = false,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _toggleRowHeight),
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: c.hair, width: _hairline),
              ),
            ),
      child: Row(
        spacing: Spacing.md,
        children: [
          // the switch carries the same label, so the text stays out of semantics
          Expanded(
            child: ExcludeSemantics(
              child: Text(title, style: AppType.body.copyWith(color: c.ink)),
            ),
          ),
          AppSwitch(value: value, onChanged: onChanged, semanticLabel: title),
        ],
      ),
    );
  }
}

/// Reorderable list of exercise slots: each row shows the resolved name and
/// its targets, with edit, remove and drag controls.
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
    return InsetSection(
      header: 'Exercises · ${slots.length}',
      children: [
        if (slots.isEmpty)
          Text('No exercises yet — add one below.', style: AppType.subhead.copyWith(color: c.ink3))
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // the default proxy lifts the row on an elevated material; keep it flat
            proxyDecorator: (child, _, _) => ColoredBox(color: c.bg, child: child),
            onReorderItem: onReorder,
            children: [
              for (var i = 0; i < slots.length; i++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey(slots[i].id),
                  index: i,
                  child: _ExerciseSlotRow(
                    index: i,
                    slot: slots[i],
                    exercise: state.exerciseFor(slots[i].exerciseId),
                    onEdit: () => onEdit(slots[i]),
                    onRemove: () => onRemove(slots[i].id),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ExerciseSlotRow extends StatelessWidget {
  const _ExerciseSlotRow({
    required this.index,
    required this.slot,
    required this.exercise,
    required this.onEdit,
    required this.onRemove,
  });
  final int index;
  final RoutineExercise slot;
  final Exercise? exercise;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  String get _targets {
    final minutes = slot.targetDurationMin;
    final each = slot.targetReps?.toString() ?? (minutes != null ? '$minutes min' : '—');
    final reps = '${slot.targetSets} × $each';
    final w = slot.targetWeightKg;
    return w != null && w > 0 ? '$reps · ${formatWeight(w)} kg' : reps;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = exercise?.name ?? 'Unknown exercise';
    return ExerciseRow(
      name: name,
      detail: _targets,
      first: index == 0,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RowButton(icon: 'pencil', label: 'Edit targets for $name', onTap: onEdit),
          _RowButton(icon: 'xmark', label: 'Remove $name', onTap: onRemove),
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: 'Reorder $name',
              child: SizedBox.square(
                dimension: _minTap,
                child: Center(
                  child: AppIcon('slider.horizontal.3', size: _rowIcon, color: c.ink3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 44 line-icon control in `ink2` with no fill.
class _RowButton extends StatelessWidget {
  const _RowButton({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: _minTap,
          child: Center(
            child: AppIcon(icon, size: _rowIcon, color: c.ink2),
          ),
        ),
      ),
    );
  }
}

/// Opens a searchable catalog picker; calls [onPick] with the chosen id.
Future<void> _showExercisePicker(
  BuildContext context, {
  required List<Exercise> catalog,
  required ValueChanged<String> onPick,
}) {
  return showAppSheet<void>(
    context,
    scrollable: true,
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
        .where((e) => e.name.toLowerCase().contains(q) || e.muscle.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final results = _filtered;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.md,
      children: [
        Row(
          spacing: Spacing.md,
          children: [
            Expanded(
              child: Text(
                'Add exercise',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.title.copyWith(color: c.ink),
              ),
            ),
            NavIconButton(
              name: 'xmark',
              semanticLabel: 'Close',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SearchPill(
          controller: _controller,
          placeholder: 'Search exercises',
          onChanged: (v) => setState(() => _query = v),
        ),
        Flexible(
          child: results.isEmpty
              ? Text(
                  'No exercises match "$_query".',
                  style: AppType.subhead.copyWith(color: c.ink3),
                )
              : ListView(
                  children: [
                    for (var i = 0; i < results.length; i++)
                      ExerciseRow(
                        name: results[i].name,
                        detail: [results[i].muscle, ?results[i].equipment].join(' · '),
                        first: i == 0,
                        onTap: () {
                          widget.onPick(results[i].id);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Opens a sheet to adjust a slot's sets/reps/weight targets.
Future<void> _showTargetsSheet(
  BuildContext context, {
  required RoutineExercise slot,
  required void Function(int sets, int reps, double weight) onSave,
}) {
  // scrollable: three large steppers outgrow the default 9/16 sheet at large text.
  return showAppSheet<void>(
    context,
    scrollable: true,
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
  late int _reps = widget.slot.targetReps ?? _defaultReps;
  late double _weight = widget.slot.targetWeightKg ?? _minWeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Targets', style: AppType.title.copyWith(color: c.ink)),
          const SizedBox(height: Spacing.sm),
          _StepperRow(
            label: 'Sets',
            value: '$_sets',
            first: true,
            onDec: () => setState(() => _sets = (_sets - 1).clamp(_minSets, _maxSets)),
            onInc: () => setState(() => _sets = (_sets + 1).clamp(_minSets, _maxSets)),
          ),
          _StepperRow(
            label: 'Reps',
            value: '$_reps',
            onDec: () => setState(() => _reps = (_reps - 1).clamp(_minReps, _maxReps)),
            onInc: () => setState(() => _reps = (_reps + 1).clamp(_minReps, _maxReps)),
          ),
          _StepperRow(
            label: 'Weight',
            value: formatWeight(_weight),
            unit: 'kg',
            onDec: () =>
                setState(() => _weight = (_weight - _weightStep).clamp(_minWeight, _maxWeight)),
            onInc: () =>
                setState(() => _weight = (_weight + _weightStep).clamp(_minWeight, _maxWeight)),
          ),
          const SizedBox(height: Spacing.lg),
          PillButton(
            label: 'Done',
            semanticLabel: 'Done',
            onTap: () {
              widget.onSave(_sets, _reps, _weight);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

/// A label over a large value, with − and + circles, on a hairline.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onDec,
    required this.onInc,
    this.unit,
    this.first = false,
  });
  final String label;
  final String value;
  final String? unit;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unit = this.unit;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(
                top: BorderSide(color: c.hair, width: _hairline),
              ),
            ),
      child: Row(
        spacing: _stepperGap,
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: '$label, $value${unit == null ? '' : ' $unit'}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppType.label.copyWith(color: c.ink3)),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: AppType.score.copyWith(color: c.ink),
                        ),
                        if (unit != null)
                          TextSpan(
                            text: ' $unit',
                            style: AppType.subhead.copyWith(color: c.ink3),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          NavIconButton(name: 'minus', semanticLabel: 'Decrease $label', onTap: onDec),
          NavIconButton(name: 'plus', semanticLabel: 'Increase $label', onTap: onInc),
        ],
      ),
    );
  }
}
