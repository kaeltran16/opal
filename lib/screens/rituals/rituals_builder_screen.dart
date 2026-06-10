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

/// SF-symbol names offered in the icon picker. All resolve in `app_icon.dart`.
const List<String> _iconChoices = [
  'sparkles',
  'book.closed.fill',
  'books.vertical.fill',
  'figure.run',
  'figure.walk',
  'cup.and.saucer.fill',
  'heart.fill',
  'bell.fill',
];

/// Cadence options for the editor's [Segmented], in display order.
const List<(Cadence, String)> _cadenceOptions = [
  (Cadence.daily, 'Daily'),
  (Cadence.weekdays, 'Weekdays'),
  (Cadence.weekends, 'Weekends'),
  (Cadence.weekly, 'Weekly'),
];

String cadenceLabel(Cadence c) => switch (c) {
      Cadence.daily => 'Every day',
      Cadence.weekdays => 'Weekdays',
      Cadence.weekends => 'Weekends',
      Cadence.weekly => 'Weekly',
      Cadence.custom => 'Custom',
    };

/// Screen 13b — Rituals Builder.
///
/// Reachable from the Rituals tab's "Manage rituals" button (route
/// `manageRituals`, path `/rituals/manage`). Lists every ritual in a
/// [ReorderableListView]; tap a row to edit, swipe/trailing button to delete,
/// drag to reorder. The "+" nav action opens the editor sheet for a new ritual.
/// All writes go through `ritualsBuilderControllerProvider`.
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
              onTap: () => context.pop(),
              child: AppIcon('chevron.left', size: 22, color: c.accent),
            ),
            trailing: NavIconButton(
              name: 'plus',
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
                  child: Text("Couldn't load rituals.\n$e",
                      textAlign: TextAlign.center,
                      style: AppFonts.sf(
                          size: 15, color: c.ink3, letterSpacing: -0.24)),
                ),
              ),
              data: (rituals) => _List(rituals: rituals),
            ),
          ),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.rituals});
  final List<Ritual> rituals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    if (rituals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No rituals yet. Tap + to add one.',
              textAlign: TextAlign.center,
              style:
                  AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      itemCount: rituals.length,
      onReorderItem: (oldIndex, newIndex) => ref
          .read(ritualsBuilderControllerProvider.notifier)
          .reorder(oldIndex, newIndex),
      itemBuilder: (context, i) {
        final r = rituals[i];
        return _RitualRow(
          key: ValueKey(r.id),
          ritual: r,
          onTap: () => _openEditor(context, ref, r),
          onDelete: () =>
              ref.read(ritualsBuilderControllerProvider.notifier).delete(r.id),
        );
      },
    );
  }
}

/// A reorderable row: drag handle + tinted icon + title/cadence + delete button.
class _RitualRow extends StatelessWidget {
  const _RitualRow({
    super.key,
    required this.ritual,
    required this.onTap,
    required this.onDelete,
  });

  final Ritual ritual;
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Container(
                      width: 29,
                      height: 29,
                      decoration: BoxDecoration(
                        color: c.rituals,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(ritual.icon,
                          size: 17, color: const Color(0xFFFFFFFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ritual.title,
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
                              cadenceLabel(ritual.cadence),
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: _DeleteGlyph(),
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

class _DeleteGlyph extends StatelessWidget {
  const _DeleteGlyph();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppIcon('xmark', size: 16, color: c.red);
  }
}

/// Opens the add/edit editor as a modal bottom sheet. [existing] null = add.
Future<void> _openEditor(
  BuildContext context,
  WidgetRef ref,
  Ritual? existing,
) {
  final c = context.colors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _RitualEditor(
      existing: existing,
      onSave: (ritual) {
        ref.read(ritualsBuilderControllerProvider.notifier).addOrUpdate(ritual);
        Navigator.of(context).pop();
      },
    ),
  );
}

/// The add/edit form: title field, icon grid, cadence segmented, optional
/// reminder time. Pre-filled from [existing] (which preserves id/order/streak
/// on save) or defaulted for a new ritual.
class _RitualEditor extends StatefulWidget {
  const _RitualEditor({required this.existing, required this.onSave});

  final Ritual? existing;
  final ValueChanged<Ritual> onSave;

  @override
  State<_RitualEditor> createState() => _RitualEditorState();
}

class _RitualEditorState extends State<_RitualEditor> {
  late final TextEditingController _title;
  late String _icon;
  late Cadence _cadence;
  TimeOfDay? _reminder;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _title = TextEditingController(text: r?.title ?? '');
    _icon = r?.icon ?? _iconChoices.first;
    _cadence = r?.cadence ?? Cadence.daily;
    final t = r?.reminderTime;
    _reminder = t == null ? null : TimeOfDay(hour: t.hour, minute: t.minute);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty;

  void _save() {
    final r = widget.existing;
    // map reminder TimeOfDay back to a DateTime (date component unused).
    final reminderTime = _reminder == null
        ? null
        : DateTime(2000, 1, 1, _reminder!.hour, _reminder!.minute);
    // build fresh (not copyWith) so clearing the reminder can pass null —
    // copyWith treats null as "unchanged". id/order/streak preserved on edit.
    widget.onSave(Ritual(
      id: r?.id ?? '',
      title: _title.text.trim(),
      icon: _icon,
      cadence: _cadence,
      reminderTime: reminderTime,
      order: r?.order ?? 0,
      streak: r?.streak ?? 0,
    ));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminder ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => _reminder = picked);
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
            // header row: Cancel · title · Save.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TextAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
                Text(isEdit ? 'Edit ritual' : 'New ritual',
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

            // title field.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                autofocus: !isEdit,
                style: AppFonts.sf(size: 17, color: c.ink, letterSpacing: -0.43),
                cursorColor: c.accent,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Ritual name',
                  hintStyle:
                      AppFonts.sf(size: 17, color: c.ink4, letterSpacing: -0.43),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 18),

            _Label('ICON'),
            const SizedBox(height: 8),
            _IconGrid(
              selected: _icon,
              onSelect: (name) => setState(() => _icon = name),
            ),
            const SizedBox(height: 18),

            _Label('CADENCE'),
            const SizedBox(height: 8),
            Segmented<Cadence>(
              options: _cadenceOptions,
              value: _cadence,
              onChanged: (v) => setState(() => _cadence = v),
            ),
            const SizedBox(height: 18),

            // reminder toggle + time.
            Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
              decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Reminder',
                        style: AppFonts.sf(
                            size: 17, color: c.ink, letterSpacing: -0.43)),
                  ),
                  if (_reminder != null)
                    _TextAction(
                      label: _reminder!.format(context),
                      onTap: _pickTime,
                    ),
                  Switch.adaptive(
                    value: _reminder != null,
                    activeTrackColor: c.rituals,
                    onChanged: (on) async {
                      if (on) {
                        await _pickTime();
                      } else {
                        setState(() => _reminder = null);
                      }
                    },
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

class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

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
                color: name == selected ? c.rituals : c.fill,
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
