import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/budget_alert_controller.dart';
import '../../controllers/pal_suggestions_controller.dart';
import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
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
          const SnackBar(content: Text("Pal's unreachable — log it here.")),
        );
      });
    }
  }

  static const _picks = <_QuickPick>[
    _QuickPick(
      kind: _Kind.expense,
      icon: 'cup.and.saucer.fill',
      title: 'Verve Coffee',
      label: '\$5',
      amount: 5,
      category: 'Food & Drink',
      detail: 'Coffee',
    ),
    _QuickPick(
      kind: _Kind.expense,
      icon: 'fork.knife',
      title: 'Lunch',
      label: '\$14',
      amount: 14,
      category: 'Food & Drink',
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
    _caloriesCtrl.dispose();
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
          if (p.detail != null) _noteCtrl.text = p.detail!;
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
    final typeColor = c.forType(_kind.typeColorKey());

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky nav: Cancel / New Entry / Add, with a hairline divider
            // below. SafeArea (top inset) keeps the row clear of the status bar
            // since the sheet fills the screen.
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.hair, width: 0.5)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xs, Spacing.xxs, Spacing.xs, Spacing.xxs),
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
                      style: AppType.headline.copyWith(color: c.ink),
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
                  _LogWithPalBox(
                    controller: _nlCtrl,
                    accent: c.accent,
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

                  // Amount hero: a tinted type pill above the big display. The
                  // display is scaled down so long amounts (e.g. large VND
                  // values) shrink to fit instead of overflowing the row.
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTypePill(c, typeColor),
                      const SizedBox(height: Spacing.md),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildDisplay(c, typeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),

                  Text(
                    'CATEGORY',
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.ink3,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  _buildQuickPicks(c),
                  const SizedBox(height: Spacing.xl),

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

            // Fixed bottom: keypad (money/move) or ritual title field.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.xs, Spacing.lg, Spacing.sm),
              child: _kind == _Kind.ritual
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
            ),
          ],
        ),
      ),
    );
  }

  /// SF Symbol shown in the amount-hero type pill, per active kind.
  String get _pillIcon => switch (_kind) {
        _Kind.expense => 'dollarsign.circle.fill',
        _Kind.workout => 'figure.run',
        _Kind.ritual => 'sparkles',
      };

  /// Pill label: the chosen category / title, or a "New …" type placeholder.
  String get _pillLabel {
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

  /// The tinted type pill above the big display (design AddSheet amount hero).
  Widget _buildTypePill(AppColors c, Color typeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: 6), // 6: no spacing token for pill
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(_pillIcon, size: 14, color: typeColor),
          const SizedBox(width: Spacing.sm),
          Text(
            _pillLabel,
            style: AppType.footnote.copyWith(
              fontWeight: FontWeight.w600,
              color: typeColor,
              letterSpacing: -0.08,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplay(AppColors c, Color typeColor) {
    if (_kind == _Kind.ritual) {
      return Text(
        _displayText,
        textAlign: TextAlign.center,
        style: AppType.large.copyWith(
          color: _titleCtrl.text.trim().isEmpty ? c.ink4 : c.ink,
          letterSpacing: -0.4,
        ),
      );
    }
    final currency = ref.read(appSettingsControllerProvider).currency;
    final empty = _numericValue == null;
    final numberColor = empty ? c.ink4 : c.ink;
    // Money: 46px ink4 currency glyph; Move: 20px ink3 "min" suffix. VND drops
    // cents and trails the glyph; USD keeps cents and leads with it.
    final number = _kind == _Kind.expense
        ? (empty
            ? (currency.decimals > 0 ? '0.00' : '0')
            : (currency.decimals > 0
                ? _formatMoney(_numericValue ?? 0)
                : groupThousands((_numericValue ?? 0).toStringAsFixed(0),
                    currency.groupSeparator)))
        : (_numericValue ?? 0).toStringAsFixed(0);
    final symbol = Text(
      currency.symbol,
      style: AppFonts.sfr(
        size: 46, // no sfr token for 46; keep inline
        weight: FontWeight.w300,
        color: c.ink4,
        letterSpacing: -1,
      ),
    );
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
        Text(
          number,
          style: AppFonts.sfr(
            size: 72, // hero display > 54; keep inline
            weight: FontWeight.w700,
            color: numberColor,
            letterSpacing: -2,
            height: 1,
          ),
        ),
        if (_kind == _Kind.expense && !currency.symbolBefore)
          Padding(
            padding: const EdgeInsets.only(left: Spacing.sm),
            child: symbol,
          ),
        if (_kind == _Kind.workout)
          Padding(
            padding: const EdgeInsets.only(left: Spacing.sm),
            child: Text(
              'min',
              style: AppType.title3.copyWith(color: c.ink3),
            ),
          ),
      ],
    );
  }

  _Kind _kindForEntryType(EntryType t) => switch (t) {
        EntryType.money => _Kind.expense,
        EntryType.move => _Kind.workout,
        EntryType.rituals => _Kind.ritual,
      };

  /// Maps a Pal suggestion's entry to the sheet's quick-pick tile. Suggestions
  /// without an entry can't pre-fill the form, so they are skipped.
  _QuickPick? _pickFromSuggestion(PalSuggestion s) {
    final e = s.entry;
    if (e == null) return null;
    final kind = _kindForEntryType(e.type);
    final currency = ref.read(appSettingsControllerProvider).currency;
    final label = switch (e.type) {
      EntryType.money when e.amount != null =>
        formatCurrency(e.amount!.abs(), currency),
      EntryType.move when e.durationMinutes != null => '${e.durationMinutes} min',
      _ => 'Routine',
    };
    return _QuickPick(
      kind: kind,
      icon: s.icon,
      title: e.title,
      label: label,
      amount: e.amount?.abs(),
      minutes: e.durationMinutes,
      category: e.category,
      detail: e.category,
    );
  }

  Widget _buildQuickPicks(AppColors c) {
    // Pal-generated picks when available; the static list is the fallback for
    // loading / offline / empty. Picks are filtered to the active kind tab.
    final palPicks = ref
        .watch(palSuggestionsProvider(SuggestionSurface.newEntry))
        .maybeWhen(
          data: (list) {
            final mapped = list.map(_pickFromSuggestion).whereType<_QuickPick>().toList();
            return mapped.isEmpty ? null : mapped;
          },
          orElse: () => null,
        );
    final picks = palPicks ?? _picks;
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final p in picks.where((p) => p.kind == _kind))
          _QuickPickTile(
            pick: p,
            currency: ref.read(appSettingsControllerProvider).currency,
            color: c.forType(p.kind.entryType.wire),
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
                () => _categoryCtrl.text = selected == cat ? '' : cat),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: selected == cat ? c.money : c.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(
                    color: selected == cat ? c.money : c.hair, width: 0.5),
              ),
              child: Text(
                cat,
                style: AppType.footnote.copyWith(
                  fontWeight: FontWeight.w500,
                  color: selected == cat ? c.onAccent : c.ink2,
                  letterSpacing: -0.08,
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
    required this.color,
    required this.onTap,
  });

  final _QuickPick pick;
  final Currency currency;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
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
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              alignment: Alignment.center,
              child: AppIcon(pick.icon, size: 14, color: c.onAccent),
            ),
            const SizedBox(width: Spacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pick.title,
                  style: AppType.subhead.copyWith(
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.24,
                  ),
                ),
                Text(
                  pick.kind == _Kind.expense && pick.amount != null
                      ? formatCurrency(pick.amount!, currency)
                      : pick.label,
                  style: AppType.caption.copyWith(
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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final String icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.hair, width: 0.5),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 16, color: c.ink3),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: AppType.subhead
                  .copyWith(color: c.ink, letterSpacing: -0.24),
              cursorColor: c.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppType.subhead
                    .copyWith(color: c.ink4, letterSpacing: -0.24),
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
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.hair, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: AppType.body.copyWith(color: c.ink),
        cursorColor: c.rituals,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Routine title',
          hintStyle: AppType.body.copyWith(color: c.ink4),
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
    required this.currency,
    required this.parsing,
    required this.onParse,
  });

  final TextEditingController controller;
  final Color accent;
  final Currency currency;
  final bool parsing;
  final VoidCallback onParse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: accent.withValues(alpha: 0.33), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon('sparkles', size: 14, color: accent),
              const SizedBox(width: Spacing.sm),
              Text(
                'LOG WITH PAL',
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: c.hair, width: 0.5),
                  ),
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onParse(),
                    cursorColor: accent,
                    style: AppType.subhead
                        .copyWith(color: c.ink, letterSpacing: -0.24),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: currency == Currency.usd
                          ? 'spent \$14 on ramen'
                          : 'spent 50k on ramen',
                      hintStyle: AppType.subhead
                          .copyWith(color: c.ink4, letterSpacing: -0.24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final enabled = value.text.trim().isNotEmpty && !parsing;
                  return GestureDetector(
                    onTap: enabled ? onParse : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.lg, vertical: Spacing.md),
                      decoration: BoxDecoration(
                        color: enabled ? accent : c.fill,
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: parsing
                          ? SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: c.onAccent),
                            )
                          : Text(
                              'Parse',
                              style: AppType.subhead.copyWith(
                                fontWeight: FontWeight.w600,
                                color: enabled ? c.onAccent : c.ink3,
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
