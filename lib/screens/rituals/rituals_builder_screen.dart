import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/rituals_builder_controller.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/nav_bar.dart';

/// SF-symbol names offered in the icon pickers (routine glyph + step glyphs).
const List<String> _iconChoices = [
  'sparkles',
  'sunrise.fill',
  'sun.max.fill',
  'moon.stars.fill',
  'drop.fill',
  'bolt.fill',
  'leaf.fill',
  'figure.walk',
  'book.closed.fill',
  'books.vertical.fill',
  'character.book.closed.fill',
  'tray.fill',
  'cup.and.saucer.fill',
  'heart.fill',
];

/// Tone options for the editor's [Segmented], in display order.
const List<(RitualTone, String)> _toneOptions = [
  (RitualTone.morning, 'Morning'),
  (RitualTone.midday, 'Midday'),
  (RitualTone.evening, 'Evening'),
];

/// Screen 13b (builder) — manage time-of-day routines and their ordered steps.
///
/// Reachable from the Rituals tab's "+" / "New routine" (path `/rituals/manage`).
/// Lists every routine in a [ReorderableListView]; tap to edit, drag to reorder,
/// trailing button to delete. "+" opens the editor for a new routine. All writes
/// go through `ritualsBuilderControllerProvider`.
class RitualsBuilderScreen extends ConsumerWidget {
  const RitualsBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(ritualsBuilderControllerProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LargeTitleNavBar(
            title: 'Manage',
            subtitle: 'Drag to reorder · tap to edit',
            leading: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.go('/rituals'),
              child: AppIcon('chevron.left', size: 22, color: c.accent),
            ),
            trailing: NavIconButton(
              name: 'plus',
              semanticLabel: 'New routine',
              onTap: () => _openEditor(context, ref, null),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => Center(
                child: Text('…',
                    style: AppFonts.sf(
                        size: 17, color: c.ink3, letterSpacing: -0.43)),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text("Couldn't load routines.\n$e",
                      textAlign: TextAlign.center,
                      style: AppFonts.sf(
                          size: 15, color: c.ink3, letterSpacing: -0.24)),
                ),
              ),
              data: (routines) => _List(routines: routines),
            ),
          ),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.routines});
  final List<RitualRoutine> routines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    if (routines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No routines yet. Tap + to add one.',
              textAlign: TextAlign.center,
              style:
                  AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      itemCount: routines.length,
      onReorderItem: (oldIndex, newIndex) => ref
          .read(ritualsBuilderControllerProvider.notifier)
          .reorder(oldIndex, newIndex),
      itemBuilder: (context, i) {
        final r = routines[i];
        return _RoutineRow(
          key: ValueKey(r.id),
          routine: r,
          onTap: () => _openEditor(context, ref, r),
          onDelete: () => ref
              .read(ritualsBuilderControllerProvider.notifier)
              .delete(r.id),
        );
      },
    );
  }
}

/// A reorderable routine row: tinted glyph + name/time·steps + delete + handle.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    super.key,
    required this.routine,
    required this.onTap,
    required this.onDelete,
  });

  final RitualRoutine routine;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = c.forType(routine.colorKey);
    final n = routine.steps.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: c.surface,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Container(
                      width: 29,
                      height: 29,
                      decoration: BoxDecoration(
                        color: tone,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(routine.icon,
                          size: 17, color: const Color(0xFFFFFFFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sf(
                                size: 17,
                                color: c.ink,
                                letterSpacing: -0.43,
                                height: 22 / 17),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              '${routine.time} · $n ${n == 1 ? 'step' : 'steps'}',
                              style: AppFonts.sf(
                                  size: 13,
                                  color: c.ink3,
                                  letterSpacing: -0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AppIcon('xmark', size: 16, color: c.red),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: AppIcon('slider.horizontal.3',
                          size: 16, color: c.ink4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the add/edit editor as a modal bottom sheet. [existing] null = add.
Future<void> _openEditor(
  BuildContext context,
  WidgetRef ref,
  RitualRoutine? existing,
) {
  final c = context.colors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _RoutineEditor(
      existing: existing,
      onSave: (routine) {
        ref
            .read(ritualsBuilderControllerProvider.notifier)
            .addOrUpdate(routine);
        Navigator.of(context).pop();
      },
    ),
  );
}

/// The add/edit form: name field, time, tone segmented, icon grid, blurb, and a
/// reorderable list of steps (each with title/note/icon). Pre-filled from
/// [existing] (id/order/streak preserved) or defaulted for a new routine.
class _RoutineEditor extends StatefulWidget {
  const _RoutineEditor({required this.existing, required this.onSave});

  final RitualRoutine? existing;
  final ValueChanged<RitualRoutine> onSave;

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

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _name = TextEditingController(text: r?.name ?? '');
    _time = TextEditingController(text: r?.time ?? '');
    _blurb = TextEditingController(text: r?.blurb ?? '');
    _icon = r?.icon ?? _iconChoices.first;
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

  bool get _canSave => _name.text.trim().isNotEmpty && _steps.isNotEmpty;

  void _save() {
    final r = widget.existing;
    widget.onSave(RitualRoutine(
      id: r?.id ?? '',
      name: _name.text.trim(),
      time: _time.text.trim(),
      tone: _tone,
      icon: _icon,
      blurb: _blurb.text.trim(),
      streak: r?.streak ?? 0,
      order: r?.order ?? 0,
      steps: _steps,
    ));
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
    setState(() => _time.text = _formatTime(picked));
  }

  Future<void> _editStep(int? index) async {
    final result = await showModalBottomSheet<RitualStep>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StepEditor(existing: index == null ? null : _steps[index]),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _steps.add(result);
      } else {
        _steps[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.existing != null;
    final tone = c.forType(_tone.colorKey);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom + 100),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TextAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
                Text(isEdit ? 'Edit routine' : 'New routine',
                    style: AppFonts.sf(
                        size: 17, weight: FontWeight.w600, color: c.ink)),
                _TextAction(
                  label: 'Save',
                  bold: true,
                  enabled: _canSave,
                  onTap: _canSave ? _save : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            _Field(
              controller: _name,
              hint: 'Routine name',
              autofocus: !isEdit,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _time,
              hint: 'Time (e.g. 7:00 AM)',
              readOnly: true,
              onTap: _pickTime,
            ),
            const SizedBox(height: 18),

            _Label('TONE'),
            const SizedBox(height: 8),
            Segmented<RitualTone>(
              options: _toneOptions,
              value: _tone,
              onChanged: (v) => setState(() => _tone = v),
            ),
            const SizedBox(height: 18),

            _Label('ICON'),
            const SizedBox(height: 8),
            _IconGrid(
              selected: _icon,
              tone: tone,
              onSelect: (name) => setState(() => _icon = name),
            ),
            const SizedBox(height: 18),

            _Field(controller: _blurb, hint: 'Subtitle (e.g. Ease into the day)'),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(child: _Label('STEPS')),
                _TextAction(
                  label: '+ Add step',
                  bold: true,
                  onTap: () => _editStep(null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_steps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Add at least one step.',
                    style: AppFonts.sf(
                        size: 13, color: c.ink3, letterSpacing: -0.08)),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                onReorderItem: (oldIndex, newIndex) => setState(() {
                  final moved = _steps.removeAt(oldIndex);
                  _steps.insert(newIndex, moved);
                }),
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  return _StepRow(
                    key: ValueKey('${step.id}-$i'),
                    step: step,
                    tone: tone,
                    onTap: () => _editStep(i),
                    onDelete: () => setState(() => _steps.removeAt(i)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.step,
    required this.tone,
    required this.onTap,
    required this.onDelete,
  });

  final RitualStep step;
  final Color tone;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: c.surface,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: AppIcon(step.icon, size: 15, color: tone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.sf(
                          size: 15, color: c.ink, letterSpacing: -0.24),
                    ),
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AppIcon('xmark', size: 15, color: c.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    _icon = s?.icon ?? _iconChoices.first;
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
    final c = context.colors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TextAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
                Text(isEdit ? 'Edit step' : 'New step',
                    style: AppFonts.sf(
                        size: 17, weight: FontWeight.w600, color: c.ink)),
                _TextAction(
                  label: 'Save',
                  bold: true,
                  enabled: _canSave,
                  onTap: _canSave ? _save : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _title,
              hint: 'Step title',
              autofocus: !isEdit,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            _Field(controller: _note, hint: 'Note (optional)'),
            const SizedBox(height: 18),
            _Label('ICON'),
            const SizedBox(height: 8),
            _IconGrid(
              selected: _icon,
              tone: c.accent,
              onSelect: (name) => setState(() => _icon = name),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
        style: AppFonts.sf(size: 17, color: c.ink, letterSpacing: -0.43),
        cursorColor: c.accent,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle:
              AppFonts.sf(size: 17, color: c.ink4, letterSpacing: -0.43),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.selected,
    required this.onSelect,
    required this.tone,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final name in _iconChoices)
          GestureDetector(
            onTap: () => onSelect(name),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: name == selected ? tone : c.fill,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: AppIcon(name,
                  size: 20,
                  color: name == selected ? const Color(0xFFFFFFFF) : c.ink2),
            ),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
          style: AppFonts.sf(size: 13, color: c.ink3, letterSpacing: -0.08)),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    this.onTap,
    this.bold = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool bold;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: AppFonts.sf(
          size: 17,
          weight: bold ? FontWeight.w600 : FontWeight.w400,
          color: enabled ? c.accent : c.ink4,
          letterSpacing: -0.43,
        ),
      ),
    );
  }
}
