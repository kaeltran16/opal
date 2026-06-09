import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/keypad.dart';

/// Screen 04 — New Entry sheet (manual logging).
///
/// A modal sheet for logging one [Entry] by hand: pick a tracker via the
/// [Segmented] control (Expense → money, Workout → move, Ritual → rituals),
/// type a value on the custom [Keypad] (or pick a quick-pick tile), then tap
/// **Add** to write through the [EntryRepository] with `source: manual`.
///
/// Money entries store a **negative** amount (expense). Move entries store the
/// typed number as [Entry.duration] minutes. Ritual entries use the typed title.
class NewEntrySheet extends ConsumerStatefulWidget {
  const NewEntrySheet({super.key});

  @override
  ConsumerState<NewEntrySheet> createState() => _NewEntrySheetState();
}

/// Which tracker the sheet is logging. Maps to an [EntryType] on save.
enum _Kind { expense, workout, ritual }

extension on _Kind {
  EntryType get entryType => switch (this) {
        _Kind.expense => EntryType.money,
        _Kind.workout => EntryType.move,
        _Kind.ritual => EntryType.rituals,
      };

  String typeColorKey() => entryType.wire;
}

/// A recent / common preset shown as a quick-pick tile.
class _QuickPick {
  const _QuickPick({
    required this.kind,
    required this.icon,
    required this.title,
    required this.label,
    this.amount,
    this.minutes,
    this.category,
    this.detail,
  });

  final _Kind kind;
  final String icon;
  final String title;
  final String label; // shown on the tile, e.g. "$5"
  final double? amount; // positive magnitude; sign applied on save
  final int? minutes;
  final String? category;
  final String? detail;
}

class _NewEntrySheetState extends ConsumerState<NewEntrySheet> {
  _Kind _kind = _Kind.expense;

  /// Raw numeric buffer for money/move ("" means empty → shows 0).
  String _buffer = '';

  /// Title for ritual entries (also reused as the title for quick picks).
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  bool _saving = false;

  static const _picks = <_QuickPick>[
    _QuickPick(
      kind: _Kind.expense,
      icon: 'cup.and.saucer.fill',
      title: 'Verve Coffee',
      label: '\$5',
      amount: 5,
      category: 'Coffee',
      detail: 'Coffee',
    ),
    _QuickPick(
      kind: _Kind.expense,
      icon: 'fork.knife',
      title: 'Lunch',
      label: '\$14',
      amount: 14,
      category: 'Dining',
    ),
    _QuickPick(
      kind: _Kind.workout,
      icon: 'figure.run',
      title: 'Run',
      label: '30 min',
      minutes: 30,
    ),
    _QuickPick(
      kind: _Kind.workout,
      icon: 'figure.walk',
      title: 'Walk',
      label: '20 min',
      minutes: 20,
    ),
    _QuickPick(
      kind: _Kind.ritual,
      icon: 'sparkles',
      title: 'Morning pages',
      label: 'Ritual',
    ),
    _QuickPick(
      kind: _Kind.ritual,
      icon: 'book.closed.fill',
      title: 'Read 20 min',
      label: 'Ritual',
    ),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // --- buffer math -----------------------------------------------------------

  double? get _numericValue {
    if (_buffer.isEmpty || _buffer == '.') return null;
    return double.tryParse(_buffer);
  }

  /// The big display string for the current kind.
  String get _displayText {
    switch (_kind) {
      case _Kind.expense:
        final v = _numericValue ?? 0;
        return '\$${_formatMoney(v)}';
      case _Kind.workout:
        final v = _numericValue ?? 0;
        // Move is whole minutes.
        return '${v.toStringAsFixed(0)} min';
      case _Kind.ritual:
        final t = _titleCtrl.text.trim();
        return t.isEmpty ? 'New ritual' : t;
    }
  }

  String _formatMoney(double v) {
    // Mirror what the user typed for the fractional part while still showing a
    // sensible default. If they typed a decimal point keep their digits.
    if (_buffer.contains('.')) {
      final parts = _buffer.split('.');
      final cents = parts.length > 1 ? parts[1] : '';
      final whole = parts[0].isEmpty ? '0' : parts[0];
      return '$whole.${cents.padRight(2, '0').substring(0, cents.length.clamp(0, 2))}';
    }
    return v.toStringAsFixed(2);
  }

  bool get _canAdd {
    if (_saving) return false;
    switch (_kind) {
      case _Kind.expense:
        final v = _numericValue;
        return v != null && v > 0;
      case _Kind.workout:
        final v = _numericValue;
        return v != null && v > 0;
      case _Kind.ritual:
        return _titleCtrl.text.trim().isNotEmpty;
    }
  }

  // --- keypad handlers -------------------------------------------------------

  void _onDigit(String d) {
    setState(() {
      // Cap fractional digits at 2 for money.
      if (_kind == _Kind.expense && _buffer.contains('.')) {
        final cents = _buffer.split('.')[1];
        if (cents.length >= 2) return;
      }
      // Avoid runaway leading zeros like "0005".
      if (_buffer == '0') {
        _buffer = d;
      } else {
        _buffer += d;
      }
    });
  }

  void _onDecimal() {
    if (_kind != _Kind.expense) return; // minutes are integers
    setState(() {
      if (!_buffer.contains('.')) {
        _buffer = _buffer.isEmpty ? '0.' : '$_buffer.';
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_buffer.isNotEmpty) {
        _buffer = _buffer.substring(0, _buffer.length - 1);
      }
    });
  }

  void _selectKind(_Kind k) {
    setState(() {
      _kind = k;
      _buffer = '';
    });
  }

  void _applyPick(_QuickPick p) {
    setState(() {
      _kind = p.kind;
      switch (p.kind) {
        case _Kind.expense:
          _buffer = (p.amount ?? 0).toStringAsFixed(
              (p.amount ?? 0) % 1 == 0 ? 0 : 2);
          _categoryCtrl.text = p.category ?? '';
          _titleCtrl.text = p.title;
          if (p.detail != null) _noteCtrl.text = '';
        case _Kind.workout:
          _buffer = (p.minutes ?? 0).toString();
          _titleCtrl.text = p.title;
        case _Kind.ritual:
          _buffer = '';
          _titleCtrl.text = p.title;
      }
    });
  }

  // --- save ------------------------------------------------------------------

  Future<void> _add() async {
    if (!_canAdd) return;
    setState(() => _saving = true);

    final repo = ref.read(entryRepositoryProvider);
    final now = DateTime.now();
    final title = _titleCtrl.text.trim();
    final category = _categoryCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    late final Entry entry;
    switch (_kind) {
      case _Kind.expense:
        final v = _numericValue ?? 0;
        entry = Entry(
          id: '',
          timestamp: now,
          type: EntryType.money,
          title: title.isEmpty ? 'Expense' : title,
          amount: -v, // negative = expense
          category: category.isEmpty ? null : category,
          note: note.isEmpty ? null : note,
          source: EntrySource.manual,
        );
      case _Kind.workout:
        final v = _numericValue ?? 0;
        entry = Entry(
          id: '',
          timestamp: now,
          type: EntryType.move,
          title: title.isEmpty ? 'Workout' : title,
          duration: v.round(), // minutes
          note: note.isEmpty ? null : note,
          source: EntrySource.manual,
        );
      case _Kind.ritual:
        entry = Entry(
          id: '',
          timestamp: now,
          type: EntryType.rituals,
          title: title,
          note: note.isEmpty ? null : note,
          source: EntrySource.manual,
        );
    }

    await repo.insert(entry);
    if (!mounted) return;
    context.pop();
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final typeColor = c.forType(_kind.typeColorKey());

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Grabber.
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: c.ink4,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            // Header: Cancel / New Entry / Add.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: Row(
                children: [
                  _HeaderButton(
                    label: 'Cancel',
                    color: c.accent,
                    onTap: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'New Entry',
                      textAlign: TextAlign.center,
                      style: AppFonts.sf(
                        size: 17,
                        weight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.43,
                      ),
                    ),
                  ),
                  _HeaderButton(
                    label: 'Add',
                    color: c.accent,
                    bold: true,
                    enabled: _canAdd,
                    onTap: _add,
                  ),
                ],
              ),
            ),
            // Fixed top: segmented type picker.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Segmented<_Kind>(
                options: const [
                  (_Kind.expense, 'Expense'),
                  (_Kind.workout, 'Workout'),
                  (_Kind.ritual, 'Ritual'),
                ],
                value: _kind,
                onChanged: _selectKind,
              ),
            ),
            const SizedBox(height: 20),

            // Fixed big display.
            Center(child: _buildDisplay(c, typeColor)),
            const SizedBox(height: 16),

            // Scrollable middle: quick picks + optional fields + Type it.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                children: [
                  Text(
                    'QUICK PICKS',
                    style: AppFonts.sf(
                      size: 12,
                      weight: FontWeight.w600,
                      color: c.ink3,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildQuickPicks(c),
                  const SizedBox(height: 18),

                  // Optional category / note.
                  if (_kind == _Kind.expense) ...[
                    _OptionalField(
                      controller: _categoryCtrl,
                      hint: 'Category (optional)',
                      icon: 'tray.fill',
                    ),
                    const SizedBox(height: 8),
                  ],
                  _OptionalField(
                    controller: _noteCtrl,
                    hint: 'Note (optional)',
                    icon: 'character.book.closed.fill',
                  ),
                  const SizedBox(height: 16),

                  // "✨ Type it" — disabled until U16 (NL parse).
                  _TypeItButton(accent: c.accent),
                ],
              ),
            ),

            // Fixed bottom: keypad (money/move) or ritual title field.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _kind == _Kind.ritual
                  ? _RitualTitleField(
                      controller: _titleCtrl,
                      onChanged: (_) => setState(() {}),
                    )
                  : Keypad(
                      onDigit: _onDigit,
                      onDecimal: _onDecimal,
                      onDelete: _onDelete,
                      showDecimal: _kind == _Kind.expense,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplay(AppColors c, Color typeColor) {
    if (_kind == _Kind.ritual) {
      return Text(
        _displayText,
        textAlign: TextAlign.center,
        style: AppFonts.sf(
          size: 34,
          weight: FontWeight.w700,
          color: _titleCtrl.text.trim().isEmpty ? c.ink4 : c.ink,
          letterSpacing: -0.4,
        ),
      );
    }
    final empty = _numericValue == null;
    return Text(
      _displayText,
      style: AppFonts.sfr(
        size: 56,
        weight: FontWeight.w700,
        color: empty ? c.ink4 : typeColor,
        letterSpacing: -1,
      ),
    );
  }

  Widget _buildQuickPicks(AppColors c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in _picks)
          _QuickPickTile(
            pick: p,
            color: c.forType(p.kind.entryType.wire),
            onTap: () => _applyPick(p),
          ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
    this.enabled = true,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool bold;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          label,
          style: AppFonts.sf(
            size: 17,
            weight: bold ? FontWeight.w600 : FontWeight.w400,
            color: enabled ? color : c.ink4,
            letterSpacing: -0.43,
          ),
        ),
      ),
    );
  }
}

class _QuickPickTile extends StatelessWidget {
  const _QuickPickTile({
    required this.pick,
    required this.color,
    required this.onTap,
  });

  final _QuickPick pick;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: AppIcon(pick.icon, size: 14, color: const Color(0xFFFFFFFF)),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pick.title,
                  style: AppFonts.sf(
                    size: 14,
                    weight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.24,
                  ),
                ),
                Text(
                  pick.label,
                  style: AppFonts.sf(
                    size: 12,
                    color: c.ink3,
                    letterSpacing: -0.08,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionalField extends StatelessWidget {
  const _OptionalField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String hint;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.hair, width: 0.5),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 16, color: c.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppFonts.sf(size: 15, color: c.ink, letterSpacing: -0.24),
              cursorColor: c.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle:
                    AppFonts.sf(size: 15, color: c.ink4, letterSpacing: -0.24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RitualTitleField extends StatelessWidget {
  const _RitualTitleField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.hair, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: AppFonts.sf(size: 17, color: c.ink, letterSpacing: -0.43),
        cursorColor: c.rituals,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Ritual title',
          hintStyle:
              AppFonts.sf(size: 17, color: c.ink4, letterSpacing: -0.43),
        ),
      ),
    );
  }
}

/// The "✨ Type it" natural-language entry button — present but disabled.
// TODO U16 (NL parse): wire to PalService.parse() and enable.
class _TypeItButton extends StatelessWidget {
  const _TypeItButton({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon('sparkles', size: 15),
            const SizedBox(width: 6),
            Text(
              'Type it',
              style: AppFonts.sf(
                size: 15,
                weight: FontWeight.w500,
                color: c.ink2,
                letterSpacing: -0.24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
