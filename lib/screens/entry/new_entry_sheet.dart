import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/keypad.dart';
import '../../widgets/nav_bar.dart';

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
  const NewEntrySheet({super.key, this.initialKind});

  /// Which tracker to open on, as a wire token ('expense' | 'workout' |
  /// 'ritual'). Lets deep links (e.g. the Quick Actions "Log workout" tile)
  /// preselect the segment. Null/unknown falls back to Expense.
  final String? initialKind;

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

  /// Natural-language "Log with Pal" input (inline at top of the sheet).
  final TextEditingController _nlCtrl = TextEditingController();

  bool _saving = false;

  /// True while a "Log with Pal" natural-language parse is in flight.
  bool _parsing = false;

  @override
  void initState() {
    super.initState();
    _kind = switch (widget.initialKind) {
      'workout' => _Kind.workout,
      'ritual' => _Kind.ritual,
      _ => _Kind.expense,
    };
  }

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
      label: 'Routine',
    ),
    _QuickPick(
      kind: _Kind.ritual,
      icon: 'book.closed.fill',
      title: 'Read 20 min',
      label: 'Routine',
    ),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    _nlCtrl.dispose();
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
        return t.isEmpty ? 'New routine' : t;
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

  // --- "Log with Pal" natural-language parse (U16) ---------------------------

  /// Parses the inline "Log with Pal" text via [PalService.parse] and pre-fills
  /// the sheet's type/amount/category/title.
  Future<void> _parseNl() async {
    if (_parsing) return;
    final text = _nlCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _parsing = true);
    try {
      final draft = await ref.read(palServiceProvider).parse(text);
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _nlCtrl.clear();
        _applyParsed(draft);
      });
    } catch (_) {
      // surface the failure instead of spinning forever
      if (!mounted) return;
      setState(() => _parsing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't parse that — try again or enter it by hand.")),
      );
    }
  }

  /// Maps a [ParsedEntryDraft] onto the sheet's fields. Money amounts are
  /// stored as a positive buffer (the sign is applied on save).
  void _applyParsed(ParsedEntryDraft draft) {
    switch (draft.type) {
      case EntryType.money:
        _kind = _Kind.expense;
        final amount = draft.amount;
        _buffer = amount == null
            ? ''
            : () {
                final mag = amount.abs();
                return mag % 1 == 0
                    ? mag.toStringAsFixed(0)
                    : mag.toStringAsFixed(2);
              }();
        _categoryCtrl.text = draft.category ?? '';
        if (draft.title != null) _titleCtrl.text = draft.title!;
      case EntryType.move:
        _kind = _Kind.workout;
        final mins = draft.durationMinutes;
        _buffer = mins == null ? '' : mins.toString();
        if (draft.title != null) _titleCtrl.text = draft.title!;
      case EntryType.rituals:
        _kind = _Kind.ritual;
        _buffer = '';
        if (draft.title != null) _titleCtrl.text = draft.title!;
    }
    if (draft.note != null) _noteCtrl.text = draft.note!;
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
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
              child: Row(
                children: [
                  NavAction(
                    label: 'Cancel',
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
                  NavAction(
                    label: 'Add',
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
                  (_Kind.ritual, 'Routine'),
                ],
                value: _kind,
                onChanged: _selectKind,
              ),
            ),
            const SizedBox(height: 20),

            // Fixed big display.
            Center(child: _buildDisplay(c, typeColor)),
            const SizedBox(height: 16),

            // Scrollable middle: Log with Pal + quick picks + optional fields.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                children: [
                  // "Log with Pal" — inline natural-language entry (U16). Parses
                  // free text via PalService and pre-fills the form.
                  _LogWithPalBox(
                    controller: _nlCtrl,
                    accent: c.accent,
                    parsing: _parsing,
                    onParse: _parseNl,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CATEGORY',
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
    final numberColor = empty ? c.ink4 : c.ink;
    // Money: 46px ink4 "$" prefix; Move: 20px ink3 "min" suffix (design AddSheet).
    final number = _kind == _Kind.expense
        ? (empty ? '0' : _formatMoney(_numericValue ?? 0))
        : (_numericValue ?? 0).toStringAsFixed(0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (_kind == _Kind.expense)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              '\$',
              style: AppFonts.sfr(
                size: 46,
                weight: FontWeight.w300,
                color: c.ink4,
                letterSpacing: -1,
              ),
            ),
          ),
        Text(
          number,
          style: AppFonts.sfr(
            size: 72,
            weight: FontWeight.w700,
            color: numberColor,
            letterSpacing: -2,
            height: 1,
          ),
        ),
        if (_kind == _Kind.workout)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              'min',
              style: AppFonts.sf(
                size: 20,
                weight: FontWeight.w600,
                color: c.ink3,
              ),
            ),
          ),
      ],
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
          hintText: 'Routine title',
          hintStyle:
              AppFonts.sf(size: 17, color: c.ink4, letterSpacing: -0.43),
        ),
      ),
    );
  }
}

/// "Log with Pal" — inline natural-language entry (U16). An accent-tinted box
/// with a "LOG WITH PAL" eyebrow, a free-text field, and a Parse button; the
/// text is parsed by [PalService.parse] and pre-fills the sheet.
class _LogWithPalBox extends StatelessWidget {
  const _LogWithPalBox({
    required this.controller,
    required this.accent,
    required this.parsing,
    required this.onParse,
  });

  final TextEditingController controller;
  final Color accent;
  final bool parsing;
  final VoidCallback onParse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.33), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon('sparkles', size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                'LOG WITH PAL',
                style: AppFonts.sf(
                  size: 12,
                  weight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.hair, width: 0.5),
                  ),
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onParse(),
                    cursorColor: accent,
                    style: AppFonts.sf(
                        size: 15, color: c.ink, letterSpacing: -0.24),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'spent \$14 on ramen',
                      hintStyle: AppFonts.sf(
                          size: 15, color: c.ink4, letterSpacing: -0.24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final enabled = value.text.trim().isNotEmpty && !parsing;
                  return GestureDetector(
                    onTap: enabled ? onParse : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: enabled ? accent : c.fill,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: parsing
                          ? SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: const Color(0xFFFFFFFF)),
                            )
                          : Text(
                              'Parse',
                              style: AppFonts.sf(
                                size: 14,
                                weight: FontWeight.w600,
                                color: enabled
                                    ? const Color(0xFFFFFFFF)
                                    : c.ink3,
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
