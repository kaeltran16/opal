import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/rituals_builder_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/failure_note.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

/// SF-symbol names offered in the icon pickers (routine glyph + step glyphs),
/// in grid order, with the word each cell announces.
const Map<String, String> _iconChoices = {
  'sparkles': 'Sparkles',
  'sunrise.fill': 'Sunrise',
  'sun.max.fill': 'Sun',
  'moon.stars.fill': 'Moon',
  'drop.fill': 'Drop',
  'bolt.fill': 'Bolt',
  'leaf.fill': 'Leaf',
  'figure.walk': 'Walk',
  'book.closed.fill': 'Book',
  'books.vertical.fill': 'Books',
  'character.book.closed.fill': 'Journal',
  'tray.fill': 'Tray',
  'cup.and.saucer.fill': 'Cup',
  'heart.fill': 'Heart',
};

/// Tone options for the editor's [Segmented], in display order.
const List<(RitualTone, String)> _toneOptions = [
  (RitualTone.morning, 'Morning'),
  (RitualTone.midday, 'Midday'),
  (RitualTone.evening, 'Evening'),
];

const double _tapTarget = 44;
const double _routineRowHeight = 64;
const double _stepRowHeight = 52;
const double _routineGlyph = 22;
const double _stepGlyph = 20;
const double _handleGlyph = 20;
const double _removeGlyph = 18;
const double _addGlyph = 16;
const double _routineGlyphGap = 14;
const double _addGlyphGap = 6;
const double _hairWidth = 1;
const double _fieldHeight = 52;
const double _footButtonHeight = 48;
const double _sheetBottomPadding = 34;
const double _grabberWidth = 36;
const double _grabberHeight = 5;
const double _iconRingWidth = 1.5;
const int _iconColumns = 7;
// bottom inset clearing the floating tab bar
const double _listBottomPadding = 110;

const String _deleteFailedCopy = "Couldn't delete. Try again.";

String _stepCount(int n) => n == 1 ? '1 step' : '$n steps';

/// Screen 13b (builder): manage time-of-day routines and their ordered steps.
///
/// Reachable from the Routines page's "Manage routines" (path
/// `/areas/routines/manage`). Lists every routine in a [ReorderableListView];
/// tap to edit, drag the handle to reorder. "+" opens the editor for a new
/// routine. All writes go through `ritualsBuilderControllerProvider`.
class RitualsBuilderScreen extends ConsumerStatefulWidget {
  const RitualsBuilderScreen({super.key});

  @override
  ConsumerState<RitualsBuilderScreen> createState() =>
      _RitualsBuilderScreenState();
}

class _RitualsBuilderScreenState extends ConsumerState<RitualsBuilderScreen> {
  bool _reorderFailed = false;

  void _wrote() {
    if (mounted && _reorderFailed) setState(() => _reorderFailed = false);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    try {
      await ref
          .read(ritualsBuilderControllerProvider.notifier)
          .reorder(oldIndex, newIndex);
      _wrote();
    } catch (e, st) {
      debugPrint('manage routines: reordering failed: $e\n$st');
      if (mounted) setState(() => _reorderFailed = true);
    }
  }

  /// Opens the add/edit editor. [existing] null = add.
  Future<void> _openEditor(RitualRoutine? existing) {
    final notifier = ref.read(ritualsBuilderControllerProvider.notifier);
    return _showSheet<void>(
      context,
      (sheetContext) => _RoutineEditor(
        existing: existing,
        onSave: (routine) async {
          await notifier.addOrUpdate(routine);
          _wrote();
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        },
        onDelete: (id) async {
          await notifier.delete(id);
          _wrote();
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(ritualsBuilderControllerProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LargeTitleNavBar(
            title: 'Manage routines',
            subtitle: 'Drag to reorder · tap to edit',
            leading: NavAction(
              icon: 'chevron.left',
              onTap: () => context.go('/rituals'),
              semanticLabel: 'Back',
            ),
            trailing: NavIconButton(
              name: 'plus',
              semanticLabel: 'New routine',
              onTap: () => _openEditor(null),
            ),
          ),
          if (_reorderFailed)
            const Padding(
              padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
              child: FailureNote(),
            ),
          Expanded(
            child: async.when(
              loading: () => const _Note('…'),
              error: (e, st) {
                debugPrint("rituals builder: couldn't load routines: $e\n$st");
                return const _Note("Couldn't load routines. Try again in a moment.");
              },
              data: (routines) => _List(
                routines: routines,
                onReorder: _reorder,
                onEdit: _openEditor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A calm one-line message under the title, for loading, empty and error.
class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, 0),
      child: Text(text,
          style: AppType.subhead.copyWith(color: context.colors.ink3)),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.routines,
    required this.onReorder,
    required this.onEdit,
  });

  final List<RitualRoutine> routines;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<RitualRoutine> onEdit;

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) {
      return const _Note('No routines yet. Tap + to add one.');
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.md, Spacing.lg, _listBottomPadding),
      buildDefaultDragHandles: false,
      itemCount: routines.length,
      onReorderItem: onReorder,
      itemBuilder: (context, i) {
        final r = routines[i];
        return _RoutineRow(
          key: ValueKey(r.id),
          index: i,
          routine: r,
          onTap: () => onEdit(r),
        );
      },
    );
  }
}

/// A 1px hairline above [child], the list separator.
class _HairTop extends StatelessWidget {
  const _HairTop({required this.minHeight, required this.child});
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: context.colors.hair, width: _hairWidth)),
      ),
      child: child,
    );
  }
}

/// The labelled 44 drag handle that starts a reorder of item [index].
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.index, required this.label});
  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: ReorderableDragStartListener(
        index: index,
        child: SizedBox(
          width: _tapTarget,
          height: _tapTarget,
          child: Center(
            child: AppIcon('line.3.horizontal',
                size: _handleGlyph, color: context.colors.ink3),
          ),
        ),
      ),
    );
  }
}

/// A routine row: glyph, name and time · steps, then the drag handle.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    super.key,
    required this.index,
    required this.routine,
    required this.onTap,
  });

  final int index;
  final RitualRoutine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = _stepCount(routine.steps.length);
    final time = routine.time.isEmpty ? null : routine.time;
    return _HairTop(
      minHeight: _routineRowHeight,
      child: Row(
        children: [
          Expanded(
            child: PressScale(
              onTap: onTap,
              semanticLabel:
                  '${routine.name}, ${time ?? 'any time'}, $count. Edit',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _routineRowHeight),
                child: Row(
                  children: [
                    AppIcon.line(routine.icon, size: _routineGlyph, color: c.ink2),
                    const SizedBox(width: _routineGlyphGap),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            style: AppType.body.copyWith(color: c.ink),
                          ),
                          const SizedBox(height: Spacing.xxs),
                          Text(
                            '${time ?? 'Any time'} · $count',
                            style: AppType.subhead.copyWith(
                              color: c.ink3,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.xs),
          _DragHandle(index: index, label: 'Reorder ${routine.name}'),
        ],
      ),
    );
  }
}

/// Presents [builder] in the shared sheet chrome: surface fill, card radius,
/// over the tab bar.
Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    // present over the shell so the sheet covers the tab bar, as the mood
    // logger does.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
    ),
    builder: builder,
  );
}

/// The sheet body: grabber, then [children], padded and scrollable above the
/// keyboard.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, _sheetBottomPadding + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: _grabberWidth,
                height: _grabberHeight,
                decoration: BoxDecoration(
                  color: context.colors.track,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A plain text button, 44 tall. Null [onTap] shows it disabled.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.style, this.onTap});
  final String label;
  final TextStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        height: _tapTarget,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Center(child: Text(label, style: style)),
        ),
      ),
    );
    if (onTap != null) return button;
    // press scale only announces enabled buttons; say this one is off.
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// Cancel, the centred [title], and Save (off unless [canSave]).
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.canSave,
    required this.onSave,
  });

  final String title;
  final bool canSave;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: SizedBox(
        height: _tapTarget,
        child: Row(
          children: [
            _TextAction(
              label: 'Cancel',
              style: AppType.body.copyWith(color: c.ink2),
              onTap: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: AppType.headline.copyWith(color: c.ink)),
            ),
            _TextAction(
              label: 'Save',
              style: AppType.headline.copyWith(color: canSave ? c.ink : c.ink3),
              onTap: canSave ? onSave : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The add/edit form: name field, time, tone segmented, icon grid, blurb, and a
/// reorderable list of steps (each with title/note/icon). Pre-filled from
/// [existing] (id/order/streak preserved) or defaulted for a new routine.
class _RoutineEditor extends StatefulWidget {
  const _RoutineEditor({
    required this.existing,
    required this.onSave,
    required this.onDelete,
  });

  final RitualRoutine? existing;

  /// Writes the routine and closes the sheet; throws if the write fails.
  final Future<void> Function(RitualRoutine) onSave;

  /// Deletes the routine and closes the sheet; throws if the write fails.
  final Future<void> Function(String id) onDelete;

  @override
  State<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<_RoutineEditor> {
  late final TextEditingController _name;
  late final TextEditingController _time;
  late final TextEditingController _blurb;
  late String _icon;
  late RitualTone _tone;
  late List<RitualStep> _steps;
  bool _writing = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _name = TextEditingController(text: r?.name ?? '');
    _time = TextEditingController(text: r?.time ?? '');
    _blurb = TextEditingController(text: r?.blurb ?? '');
    _icon = r?.icon ?? _iconChoices.keys.first;
    _tone = r?.tone ?? RitualTone.morning;
    _steps = List.of(r?.steps ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    _time.dispose();
    _blurb.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_writing && _name.text.trim().isNotEmpty && _steps.isNotEmpty;

  /// Applies an edit to the draft; any edit clears a failure note.
  void _edit(VoidCallback change) => setState(() {
        _failure = null;
        change();
      });

  /// Runs [write] once at a time, keeping the sheet open with the draft and
  /// [failure] showing if it throws.
  Future<void> _attempt(
    Future<void> Function() write, {
    required String action,
    required String failure,
  }) async {
    if (_writing) return;
    setState(() {
      _writing = true;
      _failure = null;
    });
    try {
      await write();
    } catch (e, st) {
      debugPrint('manage routines: $action failed: $e\n$st');
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _save() {
    final r = widget.existing;
    final routine = RitualRoutine(
      id: r?.id ?? '',
      name: _name.text.trim(),
      time: _time.text.trim(),
      tone: _tone,
      icon: _icon,
      blurb: _blurb.text.trim(),
      streak: r?.streak ?? 0,
      order: r?.order ?? 0,
      steps: _steps,
    );
    return _attempt(
      () => widget.onSave(routine),
      action: 'saving ${routine.name}',
      failure: saveFailedCopy,
    );
  }

  static const _defaultTime = TimeOfDay(hour: 7, minute: 0);

  /// Parses "7:00 AM" / "19:30" into a [TimeOfDay], falling back to 7:00 AM.
  TimeOfDay _parseTime(String raw) {
    final text = raw.trim();
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})\s*([APap][Mm])?$').firstMatch(text);
    if (match == null) return _defaultTime;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)?.toUpperCase();
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return _defaultTime;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Formats a [TimeOfDay] back to "h:mm AM/PM".
  String _formatTime(TimeOfDay t) {
    final period = t.hour < 12 ? 'AM' : 'PM';
    final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(_time.text),
    );
    if (picked == null) return;
    _edit(() => _time.text = _formatTime(picked));
  }

  Future<void> _editStep(int? index) async {
    final result = await _showSheet<RitualStep>(
      context,
      (_) => _StepEditor(existing: index == null ? null : _steps[index]),
    );
    if (result == null) return;
    _edit(() {
      if (index == null) {
        _steps.add(result);
      } else {
        _steps[index] = result;
      }
    });
  }

  Future<void> _confirmDelete() async {
    if (_writing) return;
    final name = _name.text.trim();
    final delete = await _showSheet<bool>(
      context,
      (_) => _ConfirmDelete(
        name: name.isEmpty ? 'this routine' : name,
        stepCount: _steps.length,
      ),
    );
    if (delete != true) return;
    final existing = widget.existing!;
    await _attempt(
      () => widget.onDelete(existing.id),
      action: 'deleting ${existing.name}',
      failure: _deleteFailedCopy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isEdit = widget.existing != null;

    return _SheetBody(
      children: [
        _SheetHeader(
          title: isEdit ? 'Edit routine' : 'New routine',
          canSave: _canSave,
          onSave: _save,
        ),
        const SizedBox(height: Spacing.lg),
        _Field(
          controller: _name,
          hint: 'Routine name',
          autofocus: !isEdit,
          onChanged: () => _edit(() {}),
        ),
        const SizedBox(height: Spacing.md),
        _Field(
          controller: _time,
          hint: 'Time (e.g. 7:00 AM)',
          readOnly: true,
          onTap: _pickTime,
        ),
        const SizedBox(height: Spacing.lg),
        const _Label('Tone'),
        const SizedBox(height: Spacing.sm),
        Segmented<RitualTone>(
          options: _toneOptions,
          value: _tone,
          onChanged: (v) => _edit(() => _tone = v),
        ),
        const SizedBox(height: Spacing.lg),
        const _Label('Icon'),
        const SizedBox(height: Spacing.sm),
        _IconGrid(
          selected: _icon,
          onSelect: (name) => _edit(() => _icon = name),
        ),
        const SizedBox(height: Spacing.lg),
        _Field(
          controller: _blurb,
          hint: 'Subtitle (e.g. Ease into the day)',
          onChanged: () => _edit(() {}),
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            const Expanded(child: _Label('Steps')),
            PressScale(
              onTap: () => _editStep(null),
              semanticLabel: 'Add step',
              child: SizedBox(
                height: _tapTarget,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon('plus', size: _addGlyph, color: c.ink),
                    const SizedBox(width: _addGlyphGap),
                    Text('Add step',
                        style: AppType.subhead
                            .copyWith(color: c.ink, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_steps.isEmpty)
          _HairTop(
            minHeight: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Text('Add at least one step.',
                  style: AppType.subhead.copyWith(color: c.ink3)),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _steps.length,
            onReorderItem: (oldIndex, newIndex) => _edit(() {
              final moved = _steps.removeAt(oldIndex);
              _steps.insert(newIndex, moved);
            }),
            itemBuilder: (context, i) {
              final step = _steps[i];
              return _StepRow(
                key: ValueKey('${step.id}-$i'),
                index: i,
                step: step,
                onTap: () => _editStep(i),
                onRemove: () => _edit(() => _steps.removeAt(i)),
              );
            },
          ),
        if (_failure case final failure?) ...[
          const SizedBox(height: Spacing.lg),
          FailureNote(failure),
        ],
        if (isEdit) ...[
          const SizedBox(height: Spacing.lg),
          _HairTop(
            minHeight: 0,
            child: PressScale(
              onTap: _confirmDelete,
              semanticLabel: 'Delete routine',
              child: SizedBox(
                height: _footButtonHeight,
                child: Center(
                  child: Text('Delete routine',
                      style: AppType.headline.copyWith(color: c.careInk)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A step row: glyph and title (tap to edit), remove, then the drag handle.
class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.index,
    required this.step,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final RitualStep step;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _HairTop(
      minHeight: _stepRowHeight,
      child: Row(
        children: [
          Expanded(
            child: PressScale(
              onTap: onTap,
              semanticLabel: '${step.title}. Edit step',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _stepRowHeight),
                child: Row(
                  children: [
                    AppIcon.line(step.icon, size: _stepGlyph, color: c.ink2),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Text(
                        step.title,
                        style: AppType.callout.copyWith(color: c.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.xs),
          PressScale(
            onTap: onRemove,
            semanticLabel: 'Remove ${step.title}',
            child: SizedBox(
              width: _tapTarget,
              height: _tapTarget,
              child: Center(
                child: AppIcon('xmark', size: _removeGlyph, color: c.ink3),
              ),
            ),
          ),
          _DragHandle(index: index, label: 'Reorder ${step.title}'),
        ],
      ),
    );
  }
}

/// Asks before deleting a routine. Pops true to delete, false to keep it.
class _ConfirmDelete extends StatelessWidget {
  const _ConfirmDelete({required this.name, required this.stepCount});
  final String name;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _SheetBody(
      children: [
        const SizedBox(height: Spacing.lg),
        Text('Delete $name?', style: AppType.title.copyWith(color: c.ink)),
        const SizedBox(height: Spacing.xs),
        Text(
          'This removes the routine and its ${_stepCount(stepCount)}. '
          'What you checked off before stays in your history.',
          style: AppType.subhead.copyWith(color: c.ink2),
        ),
        const SizedBox(height: Spacing.lg),
        PressScale(
          onTap: () => Navigator.pop(context, true),
          semanticLabel: 'Delete',
          child: Container(
            height: _footButtonHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text('Delete',
                style: AppType.headline.copyWith(color: c.careInk)),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        PressScale(
          onTap: () => Navigator.pop(context, false),
          semanticLabel: 'Keep it',
          child: SizedBox(
            height: _footButtonHeight,
            child: Center(
              child: Text('Keep it',
                  style: AppType.headline.copyWith(color: c.ink)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Add/edit one step: title field, note field, icon grid.
class _StepEditor extends StatefulWidget {
  const _StepEditor({required this.existing});
  final RitualStep? existing;

  @override
  State<_StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<_StepEditor> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late String _icon;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _title = TextEditingController(text: s?.title ?? '');
    _note = TextEditingController(text: s?.note ?? '');
    _icon = s?.icon ?? _iconChoices.keys.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty;

  void _save() {
    final s = widget.existing;
    Navigator.pop(
      context,
      RitualStep(
        id: s?.id ?? '',
        title: _title.text.trim(),
        note: _note.text.trim(),
        icon: _icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return _SheetBody(
      children: [
        _SheetHeader(
          title: isEdit ? 'Edit step' : 'New step',
          canSave: _canSave,
          onSave: _save,
        ),
        const SizedBox(height: Spacing.lg),
        _Field(
          controller: _title,
          hint: 'Step title',
          autofocus: !isEdit,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: Spacing.md),
        _Field(controller: _note, hint: 'Note (optional)'),
        const SizedBox(height: Spacing.lg),
        const _Label('Icon'),
        const SizedBox(height: Spacing.sm),
        _IconGrid(
          selected: _icon,
          onSelect: (name) => setState(() => _icon = name),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final VoidCallback? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: _fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
          color: c.surface2, borderRadius: BorderRadius.circular(Radii.inset)),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
        style: AppType.body.copyWith(color: c.ink),
        cursorColor: c.ink,
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          hintText: hint,
          hintStyle: AppType.body.copyWith(color: c.ink3),
        ),
      ),
    );
  }
}

/// Seven columns of 44 circles; the selected one has an ink ring.
class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final names = _iconChoices.keys.toList();
    return Column(
      children: [
        for (var row = 0; row < names.length; row += _iconColumns) ...[
          if (row > 0) const SizedBox(height: Spacing.xs),
          Row(
            children: [
              for (var i = row; i < row + _iconColumns; i++)
                Expanded(
                  child: Center(
                    child: i < names.length ? _iconCell(context, names[i]) : null,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _iconCell(BuildContext context, String name) {
    final c = context.colors;
    final on = name == selected;
    // a container node, so the selected flag and the label sit on one node.
    return Semantics(
      container: true,
      selected: on,
      child: PressScale(
        onTap: () => onSelect(name),
        semanticLabel: _iconChoices[name],
        child: Container(
          width: _tapTarget,
          height: _tapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: on ? Border.all(color: c.ink, width: _iconRingWidth) : null,
          ),
          child: AppIcon.line(name, size: _routineGlyph, color: on ? c.ink : c.ink2),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppType.label.copyWith(color: context.colors.ink3));
  }
}
