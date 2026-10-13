import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/spend_habits.dart';
import '../../controllers/budget_alert_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/spend_habits_controller.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/keypad.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

const double _minTap = 44;
const double _pillHeight = 48;
const double _inputHeight = 52;
const double _hairline = 1;
const double _fieldIcon = 16;
const double _spinner = 15;
const double _spinnerStroke = 2;
const double _disabledOpacity = 0.4;

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
  const NewEntrySheet({super.key, this.initialKind, this.notice});

  /// Which tracker to open on, as a wire token ('expense' | 'workout' |
  /// 'ritual'). Lets deep links (e.g. the Quick Actions "Log workout" tile)
  /// preselect the segment. Null/unknown falls back to Expense.
  final String? initialKind;

  /// Optional notice token surfaced on open. 'pal-offline' means the user was
  /// routed here because Pal was unreachable, so we explain the handoff.
  final String? notice;

  @override
  ConsumerState<NewEntrySheet> createState() => _NewEntrySheetState();
}

/// Which tracker the sheet is logging. Maps to an [EntryType] on save.
enum _Kind { expense, workout, ritual }

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
  });

  final _Kind kind;
  final String icon;
  final String title;
  final String label; // shown on the tile, e.g. "$5"
  final double? amount; // positive magnitude; sign applied on save
  final int? minutes;
  final String? category;
}

class _NewEntrySheetState extends ConsumerState<NewEntrySheet> {
  _Kind _kind = _Kind.expense;

  /// Raw numeric buffer for money/move ("" means empty → shows 0).
  String _buffer = '';

  /// Title for ritual entries (also reused as the title for quick picks).
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  /// Calories (kcal) for move entries. Nullable — empty means unset.
  final TextEditingController _caloriesCtrl = TextEditingController();

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
    if (widget.notice == 'pal-offline') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pal's unreachable. Log it here.")),
        );
      });
    }
  }

  /// Defaults for the kinds with no mined equivalent. Expense picks are not
  /// listed here: an invented merchant is worse than no chip at all, so that
  /// tab shows only what [spendHabitsProvider] found in the user's own history.
  static const _picks = <_QuickPick>[
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
    _caloriesCtrl.dispose();
    _nlCtrl.dispose();
    super.dispose();
  }

  // --- buffer math -----------------------------------------------------------

  double? get _numericValue {
    if (_buffer.isEmpty || _buffer == '.') return null;
    return double.tryParse(_buffer);
  }

  /// The big display string for a ritual: its typed title.
  String get _ritualText {
    final t = _titleCtrl.text.trim();
    return t.isEmpty ? 'New routine' : t;
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

  /// The canonical [kSpendCategories] entry matching [raw] (case/space-
  /// insensitive), or null when it isn't one. Keeps the logged category aligned
  /// with budget envelopes — a quick-pick or Pal parse can't smuggle in a label
  /// that no envelope recognizes.
  static String? _canonicalCategory(String? raw) {
    final key = normalizeCategory(raw);
    if (key.isEmpty) return null;
    for (final cat in kSpendCategories) {
      if (normalizeCategory(cat) == key) return cat;
    }
    return null;
  }

  void _applyPick(_QuickPick p) {
    setState(() {
      _kind = p.kind;
      switch (p.kind) {
        case _Kind.expense:
          _buffer = (p.amount ?? 0).toStringAsFixed(
              (p.amount ?? 0) % 1 == 0 ? 0 : 2);
          _categoryCtrl.text = _canonicalCategory(p.category) ?? '';
          _titleCtrl.text = p.title;
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
        const SnackBar(content: Text("Couldn't parse that. Try again or enter it by hand.")),
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
        _categoryCtrl.text = _canonicalCategory(draft.category) ?? '';
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
    final now = clock.now();
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
          calories: int.tryParse(_caloriesCtrl.text.trim()),
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

    try {
      await repo.insert(entry);
      // A new expense may have pushed today over budget — let the controller
      // decide whether to alert (gated on the toggle, deduped to once/day).
      if (_kind == _Kind.expense) {
        await ref.read(budgetAlertControllerProvider.notifier).checkAfterSpend();
      }
      if (!mounted) return;
      context.pop();
    } finally {
      // pop() unmounts on a normal push; the guard handles the deep-link case
      // (nothing to pop) so the sheet re-enables instead of locking up.
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final picks = _currentPicks();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky header: Cancel and the title, with a hairline below.
            // SafeArea (top inset) keeps the row clear of the status bar since
            // the sheet fills the screen. Add is the primary pill at the bottom.
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.hair, width: _hairline)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xs, Spacing.xxs, Spacing.xs, Spacing.xxs),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text('New entry', style: AppType.headline.copyWith(color: c.ink)),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: NavAction(
                      label: 'Cancel',
                      bold: true,
                      color: c.ink,
                      onTap: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),
            // Scrolling body, in design order: Log with Pal → type picker →
            // amount hero → category quick-picks → optional fields. The keypad
            // stays pinned below so it is always reachable while typing.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
                children: [
                  // "Log with Pal" — inline natural-language entry (U16). Parses
                  // free text via PalService and pre-fills the form.
                  _LogWithPalRow(
                    controller: _nlCtrl,
                    currency: ref.read(appSettingsControllerProvider).currency,
                    parsing: _parsing,
                    onParse: _parseNl,
                  ),
                  const SizedBox(height: Spacing.lg),
                  Segmented<_Kind>(
                    options: const [
                      (_Kind.expense, 'Expense'),
                      (_Kind.workout, 'Workout'),
                      (_Kind.ritual, 'Routine'),
                    ],
                    value: _kind,
                    onChanged: _selectKind,
                  ),
                  const SizedBox(height: Spacing.xxl),

                  // Amount hero: what is being logged above the big display. The
                  // display is scaled down so long amounts (e.g. large VND
                  // values) shrink to fit instead of overflowing the row.
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_heroLabel,
                          textAlign: TextAlign.center,
                          style: AppType.label.copyWith(color: c.ink2)),
                      const SizedBox(height: Spacing.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildDisplay(c),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),

                  if (picks.isNotEmpty) ...[
                    Text('Category', style: AppType.label.copyWith(color: c.ink3)),
                    const SizedBox(height: Spacing.sm),
                    _buildQuickPicks(picks),
                    const SizedBox(height: Spacing.xl),
                  ],

                  // Category picker (expense) + optional calories / note.
                  if (_kind == _Kind.expense) ...[
                    _buildCategoryChips(c),
                    const SizedBox(height: Spacing.sm),
                  ],
                  if (_kind == _Kind.workout) ...[
                    _OptionalField(
                      controller: _caloriesCtrl,
                      hint: 'Calories (optional)',
                      icon: 'flame.fill',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: Spacing.sm),
                  ],
                  _OptionalField(
                    controller: _noteCtrl,
                    hint: 'Note (optional)',
                    icon: 'character.book.closed.fill',
                  ),
                ],
              ),
            ),

            // Fixed bottom: keypad (money/move) or ritual title field, then
            // Add, the sheet's one primary pill.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.xs, Spacing.lg, Spacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _kind == _Kind.ritual
                      ? _RitualTitleField(
                          controller: _titleCtrl,
                          onChanged: (_) => setState(() {}),
                        )
                      : Keypad(
                          onDigit: _onDigit,
                          onDecimal: _onDecimal,
                          onDelete: _onDelete,
                          showDecimal: _kind == _Kind.expense &&
                              ref
                                      .read(appSettingsControllerProvider)
                                      .currency
                                      .decimals >
                                  0,
                        ),
                  const SizedBox(height: Spacing.sm),
                  _AddPill(enabled: _canAdd, onTap: _add),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero label: the chosen category / title, or a "New …" type placeholder.
  String get _heroLabel {
    final picked = switch (_kind) {
      _Kind.expense => _categoryCtrl.text.trim(),
      _Kind.workout || _Kind.ritual => _titleCtrl.text.trim(),
    };
    if (picked.isNotEmpty) return picked;
    return switch (_kind) {
      _Kind.expense => 'New expense',
      _Kind.workout => 'New workout',
      _Kind.ritual => 'New routine',
    };
  }

  Widget _buildDisplay(AppColors c) {
    if (_kind == _Kind.ritual) {
      return Text(
        _ritualText,
        textAlign: TextAlign.center,
        style: AppType.title.copyWith(
          color: _titleCtrl.text.trim().isEmpty ? c.ink3 : c.ink,
        ),
      );
    }
    final currency = ref.read(appSettingsControllerProvider).currency;
    final empty = _numericValue == null;
    final numberColor = empty ? c.ink3 : c.ink;
    // Money: an ink3 currency glyph; Move: an ink3 "min" suffix. VND drops
    // cents and trails the glyph; USD keeps cents and leads with it.
    final number = _kind == _Kind.expense
        ? (empty
            ? (currency.decimals > 0 ? '0.00' : '0')
            : (currency.decimals > 0
                ? _formatMoney(_numericValue ?? 0)
                : groupThousands((_numericValue ?? 0).toStringAsFixed(0),
                    currency.groupSeparator)))
        : (_numericValue ?? 0).toStringAsFixed(0);
    final symbol = Text(currency.symbol, style: AppType.display.copyWith(color: c.ink3));
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (_kind == _Kind.expense && currency.symbolBefore)
          Padding(
            padding: const EdgeInsets.only(right: Spacing.xs),
            child: symbol,
          ),
        Text(number, style: AppType.display.copyWith(color: numberColor)),
        if (_kind == _Kind.expense && !currency.symbolBefore)
          Padding(
            padding: const EdgeInsets.only(left: Spacing.sm),
            child: symbol,
          ),
        if (_kind == _Kind.workout)
          Padding(
            padding: const EdgeInsets.only(left: Spacing.sm),
            child: Text('min', style: AppType.title.copyWith(color: c.ink3)),
          ),
      ],
    );
  }

  /// Maps a mined habit to the sheet's quick-pick tile.
  _QuickPick _pickFromHabit(HabitPick h) {
    final currency = ref.read(appSettingsControllerProvider).currency;
    return _QuickPick(
      kind: _Kind.expense,
      icon: kHabitPickIcon,
      title: h.title,
      label: formatCurrency(h.averageAmount, currency),
      amount: h.averageAmount,
      category: h.category,
    );
  }

  /// Picks for the active kind: expenses are mined from what the user actually
  /// logs in this daypart, the other kinds use the static defaults. Empty on
  /// the expense tab until the history holds a habit, and the caller drops the
  /// whole section rather than showing a bare heading.
  List<_QuickPick> _currentPicks() {
    final habits = ref.watch(spendHabitsProvider).maybeWhen(
          data: (list) => list.map(_pickFromHabit).toList(),
          orElse: () => const <_QuickPick>[],
        );
    return _kind == _Kind.expense
        ? habits
        : _picks.where((p) => p.kind == _kind).toList();
  }

  Widget _buildQuickPicks(List<_QuickPick> picks) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final p in picks)
          _QuickPickTile(
            pick: p,
            currency: ref.read(appSettingsControllerProvider).currency,
            onTap: () => _applyPick(p),
          ),
      ],
    );
  }

  /// Single-select chips over the canonical [kSpendCategories] — the only
  /// categories an expense can carry, so every logged amount lines up with a
  /// budget envelope. Optional: tapping the selected chip clears it.
  Widget _buildCategoryChips(AppColors c) {
    final selected = _categoryCtrl.text.trim();
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final cat in kSpendCategories)
          Semantics(
            selected: selected == cat,
            child: PressScale(
              onTap: () => setState(
                  () => _categoryCtrl.text = selected == cat ? '' : cat),
              semanticLabel: cat,
              child: Container(
                constraints: const BoxConstraints(minHeight: _minTap),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                decoration: BoxDecoration(
                  color: selected == cat ? c.surface2 : null,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: selected == cat
                      ? null
                      : Border.all(color: c.hair, width: _hairline),
                ),
                child: Align(
                  widthFactor: 1,
                  child: Text(
                    cat,
                    style: AppType.subhead.copyWith(
                        color: selected == cat ? c.ink : c.ink2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickPickTile extends StatelessWidget {
  const _QuickPickTile({
    required this.pick,
    required this.currency,
    required this.onTap,
  });

  final _QuickPick pick;
  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final detail = pick.kind == _Kind.expense && pick.amount != null
        ? formatCurrency(pick.amount!, currency)
        : pick.label;
    return PressScale(
      onTap: onTap,
      semanticLabel: '${pick.title}, $detail',
      child: Container(
        constraints: const BoxConstraints(minHeight: _minTap),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(pick.icon, size: _fieldIcon, color: c.ink2),
            const SizedBox(width: Spacing.sm),
            Flexible(
              child: Text(pick.title, style: AppType.subhead.copyWith(color: c.ink)),
            ),
            const SizedBox(width: Spacing.sm),
            Text(detail, style: AppType.subhead.copyWith(color: c.ink2)),
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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final String icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _InputPill(
      child: Row(
        children: [
          AppIcon(icon, size: _fieldIcon, color: c.ink2),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: AppType.subhead.copyWith(color: c.ink),
              cursorColor: c.ink,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppType.subhead.copyWith(color: c.ink3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A `surface2` pill that holds an input row.
class _InputPill extends StatelessWidget {
  const _InputPill({required this.child, this.minHeight = _minTap});

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface2,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: child,
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
    return _InputPill(
      minHeight: _inputHeight,
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: AppType.body.copyWith(color: c.ink),
        cursorColor: c.ink,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Routine title',
          hintStyle: AppType.body.copyWith(color: c.ink3),
        ),
      ),
    );
  }
}

/// "Log with Pal" — inline natural-language entry (U16). A `label` over a
/// `surface2` input row with a Parse text button; the text is parsed by
/// [PalService.parse] and pre-fills the sheet.
class _LogWithPalRow extends StatelessWidget {
  const _LogWithPalRow({
    required this.controller,
    required this.currency,
    required this.parsing,
    required this.onParse,
  });

  final TextEditingController controller;
  final Currency currency;
  final bool parsing;
  final VoidCallback onParse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Log with Pal', style: AppType.label.copyWith(color: c.ink3)),
        const SizedBox(height: Spacing.sm),
        _InputPill(
          minHeight: _inputHeight,
          child: Row(
            children: [
              AppIcon('sparkles', size: _fieldIcon, color: c.ink2),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onParse(),
                  cursorColor: c.ink,
                  style: AppType.subhead.copyWith(color: c.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: currency == Currency.usd
                        ? 'spent \$14 on ramen'
                        : 'spent 50k on ramen',
                    hintStyle: AppType.subhead.copyWith(color: c.ink3),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final enabled = value.text.trim().isNotEmpty && !parsing;
                  return PressScale(
                    onTap: enabled ? onParse : null,
                    semanticLabel: 'Parse',
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: _minTap, minWidth: _minTap),
                      child: Padding(
                        padding: const EdgeInsets.only(left: Spacing.sm),
                        child: Align(
                          widthFactor: 1,
                          child: parsing
                              ? SizedBox(
                                  width: _spinner,
                                  height: _spinner,
                                  child: CircularProgressIndicator(
                                      strokeWidth: _spinnerStroke, color: c.ink),
                                )
                              : Text('Parse',
                                  style: AppType.headline
                                      .copyWith(color: enabled ? c.ink : c.ink3)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Add: the sheet's one primary pill, dimmed until the entry is valid.
class _AddPill extends StatelessWidget {
  const _AddPill({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Add',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: PressScale(
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: _pillHeight),
            decoration: BoxDecoration(
              color: c.ink,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            alignment: Alignment.center,
            child: Text('Add', style: AppType.headline.copyWith(color: c.bg)),
          ),
        ),
      ),
    );
  }
}
