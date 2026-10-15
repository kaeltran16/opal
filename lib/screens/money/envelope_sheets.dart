import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/spend_alerts.dart';
import '../../controllers/budget_advisories_controller.dart';
import '../../controllers/budget_envelopes_controller.dart';
import '../../controllers/budgets_controller.dart';
import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/controls.dart';
import '../../widgets/failure_note.dart';
import '../../widgets/keypad.dart';
import '../../widgets/press_scale.dart';

/// Line glyph stems the new-envelope picker offers, in grid order, with the
/// word each cell announces.
const Map<String, String> _iconChoices = {
  'cup.and.saucer': 'Cup',
  'basket': 'Basket',
  'bolt': 'Bolt',
  'bag': 'Bag',
  'car': 'Car',
  'tv': 'TV',
  'heart': 'Heart',
  'house': 'House',
  'fork.knife': 'Fork and knife',
  'creditcard': 'Card',
  'gift': 'Gift',
  'airplane': 'Plane',
};

// the same bound Budgets & goals puts on a monthly budget, in whole units.
const int _maxCapBase = 100000;
const int _iconColumns = 6;
const double _tapTarget = 44;
const double _iconCellHeight = 48;
const double _iconGlyph = 22;
const double _pickRowHeight = 48;
const double _fieldHeight = 52;
const double _hairWidth = 1;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Opens the two-step new-envelope sheet (category and icon, then the cap) and
/// adds the envelope through [budgetEnvelopesControllerProvider]. [onEdit] runs
/// on every edit to the draft.
Future<void> showNewEnvelopeSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onEdit,
}) {
  final notifier = ref.read(budgetEnvelopesControllerProvider.notifier);
  return showAppSheet<void>(
    context,
    scrollable: true,
    builder: (_) => _EnvelopeSheet(
      envelope: null,
      onAdd: (category, icon, cap) =>
          notifier.add(category: category, icon: icon, cap: cap),
      onEdit: onEdit,
    ),
  );
}

/// Opens the cap keypad for [envelope], with its delete confirm, writing
/// through [budgetEnvelopesControllerProvider]. [onEdit] runs on every edit to
/// the draft.
Future<void> showEnvelopeCapSheet(
  BuildContext context,
  WidgetRef ref,
  BudgetEnvelope envelope, {
  VoidCallback? onEdit,
}) {
  final notifier = ref.read(budgetEnvelopesControllerProvider.notifier);
  return showAppSheet<void>(
    context,
    scrollable: true,
    builder: (_) => _EnvelopeSheet(
      envelope: envelope,
      onSave: (cap) => notifier.setCap(envelope.id, cap),
      onDelete: () => notifier.delete(envelope.id),
      onEdit: onEdit,
    ),
  );
}

enum _Step { cap, confirmDelete, name, addCap }

/// One sheet, four steps: an envelope's cap and its delete confirm, or a new
/// envelope's name and icon then its cap. A failed write keeps the sheet open
/// with the draft and a [FailureNote]; any edit to the draft clears the note.
class _EnvelopeSheet extends ConsumerStatefulWidget {
  const _EnvelopeSheet({
    required this.envelope,
    this.onSave,
    this.onDelete,
    this.onAdd,
    this.onEdit,
  });

  /// The envelope whose cap is edited; null adds a new one.
  final BudgetEnvelope? envelope;
  final Future<void> Function(double cap)? onSave;
  final Future<void> Function()? onDelete;
  final Future<void> Function(String category, String icon, double cap)? onAdd;

  /// Runs on every edit to the draft, so the opener can clear its own note.
  final VoidCallback? onEdit;

  @override
  ConsumerState<_EnvelopeSheet> createState() => _EnvelopeSheetState();
}

class _EnvelopeSheetState extends ConsumerState<_EnvelopeSheet> {
  late _Step _step;
  late int _draft;
  final _name = TextEditingController();
  String _icon = kDefaultEnvelopeIcon;
  String? _failure;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    final envelope = widget.envelope;
    _step = envelope == null ? _Step.name : _Step.cap;
    _draft = envelope?.cap.round() ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Currency get _currency => ref.read(appSettingsControllerProvider).currency;

  int get _max => _maxCapBase * _currency.budgetScale;

  /// Applies an edit to the draft; any edit clears a failure note.
  void _edit(VoidCallback change) {
    widget.onEdit?.call();
    setState(() {
      _failure = null;
      change();
    });
  }

  /// A digit past the max leaves the draft as it is, but is still an edit.
  void _digit(String d) {
    final next = _draft * 10 + int.parse(d);
    _edit(() {
      if (next <= _max) _draft = next;
    });
  }

  void _stepBy(int delta) => _edit(() => _draft = (_draft + delta).clamp(0, _max));

  void _go(_Step step) => setState(() {
        _failure = null;
        _step = step;
      });

  /// Runs [write] once at a time; closes the sheet when it lands, or keeps it
  /// open with [failure] showing when it throws.
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
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('envelopes: $action failed: $e\n$st');
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelope = widget.envelope;
    final name = _name.text.trim();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (_step) {
          _Step.cap => _capStep(
              title: envelope!.category,
              left: _TextAction.cancel(context),
              right: _saveAction('Save', () => _attempt(
                    () => widget.onSave!(_draft.toDouble()),
                    action: 'saving the ${envelope.category} cap',
                    failure: saveFailedCopy,
                  )),
              note: _spentNote(envelope),
              onDelete: () => _go(_Step.confirmDelete),
            ),
          _Step.confirmDelete => _confirmStep(envelope!),
          _Step.name => _nameStep(name),
          _Step.addCap => _capStep(
              title: name,
              left: _TextAction(label: 'Back', onTap: () => _go(_Step.name)),
              right: _saveAction('Add', () => _attempt(
                    () => widget.onAdd!(name, _icon, _draft.toDouble()),
                    action: 'adding $name',
                    failure: saveFailedCopy,
                  )),
              note: 'A month, from the 1st',
            ),
        },
      ),
    );
  }

  Widget _saveAction(String label, VoidCallback onTap) => _TextAction(
        label: label,
        strong: true,
        onTap: _draft > 0 && !_writing ? onTap : null,
      );

  /// `<spent> spent so far this month`, or null while Budgets has no data.
  String? _spentNote(BudgetEnvelope envelope) {
    final spends = ref.watch(budgetsDataProvider).asData?.value.envelopes;
    final spend = spends?.where((s) => s.envelope.id == envelope.id).firstOrNull;
    if (spend == null) return null;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    return '${formatCurrency(spend.spent, currency)} spent so far this month';
  }

  List<Widget> _capStep({
    required String title,
    required Widget left,
    required Widget right,
    required String? note,
    VoidCallback? onDelete,
  }) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final step = (kBudgetRoundingBaseUnit * currency.budgetScale).round();
    final stepLabel = formatCurrency(step, currency);
    return [
      _Header(left: left, title: title, right: right),
      const SizedBox(height: Spacing.lg),
      Semantics(
        liveRegion: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            formatCurrency(_draft, currency),
            maxLines: 1,
            style: AppType.display.copyWith(
              color: _draft > 0 ? c.ink : c.ink3,
              fontFeatures: _tabular,
            ),
          ),
        ),
      ),
      if (note != null) ...[
        const SizedBox(height: Spacing.xs),
        Text(note, style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular)),
      ],
      const SizedBox(height: Spacing.lg),
      Row(
        spacing: Spacing.sm,
        children: [
          Expanded(
            child: PillButton(
              label: '− $stepLabel',
              primary: false,
              onTap: () => _stepBy(-step),
            ),
          ),
          Expanded(
            child: PillButton(
              label: '+ $stepLabel',
              primary: false,
              onTap: () => _stepBy(step),
            ),
          ),
        ],
      ),
      if (_failure case final failure?) ...[
        const SizedBox(height: Spacing.lg),
        FailureNote(failure),
      ],
      const SizedBox(height: Spacing.md),
      Keypad(
        showDecimal: false,
        onDigit: _digit,
        onDecimal: () {},
        onDelete: () => _edit(() => _draft ~/= 10),
      ),
      if (onDelete != null) ...[
        const SizedBox(height: Spacing.sm),
        Center(
          child: _TextAction(
            label: 'Delete envelope',
            strong: true,
            color: c.careInk,
            onTap: onDelete,
          ),
        ),
      ],
    ];
  }

  List<Widget> _confirmStep(BudgetEnvelope envelope) {
    final c = context.colors;
    final name = envelope.category;
    return [
      const SizedBox(height: Spacing.sm),
      Text('Delete $name?', style: AppType.title.copyWith(color: c.ink)),
      const SizedBox(height: Spacing.lg),
      Text('Spending logged as $name stays. It just has no cap.',
          style: AppType.subhead.copyWith(color: c.ink2)),
      if (_failure case final failure?) ...[
        const SizedBox(height: Spacing.lg),
        FailureNote(failure),
      ],
      const SizedBox(height: Spacing.lg),
      _DeletePill(
        onTap: _writing
            ? null
            : () => _attempt(
                  widget.onDelete!,
                  action: 'deleting $name',
                  failure: deleteFailedCopy,
                ),
      ),
      const SizedBox(height: Spacing.sm),
      Center(
        child: _TextAction(
          label: 'Cancel',
          strong: true,
          color: c.ink,
          onTap: () => _go(_Step.cap),
        ),
      ),
    ];
  }

  List<Widget> _nameStep(String name) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final envelopes =
        ref.watch(budgetEnvelopesControllerProvider).asData?.value ?? const [];
    final duplicate = name.isNotEmpty && isDuplicateEnvelope(envelopes, name);
    final picks = [
      for (final u in ref.watch(budgetAdvisoriesProvider).asData?.value.unbudgeted ??
          const <UnbudgetedCategory>[])
        if (u.category != name) u,
    ];
    final canNext = name.isNotEmpty && !duplicate;

    return [
      _Header(
        left: _TextAction.cancel(context),
        title: 'New envelope',
        // keeps the title centred over the sheet.
        right: const _Spacer(_TextAction(label: 'Cancel')),
      ),
      const SizedBox(height: Spacing.lg),
      const _Label('Category'),
      const SizedBox(height: Spacing.sm),
      Container(
        height: _fieldHeight,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
            color: c.surface2, borderRadius: BorderRadius.circular(Radii.inset)),
        child: TextField(
          controller: _name,
          autofocus: true,
          inputFormatters: [LengthLimitingTextInputFormatter(kMaxEnvelopeNameLength)],
          onChanged: (_) => _edit(() {}),
          style: AppType.body.copyWith(color: c.ink),
          cursorColor: c.ink,
          decoration: InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            hintText: 'Name it as you log it',
            hintStyle: AppType.body.copyWith(color: c.ink3),
          ),
        ),
      ),
      if (duplicate) ...[
        const SizedBox(height: Spacing.sm),
        Text('You already have a $name envelope.',
            style: AppType.subhead.copyWith(color: c.ink2)),
      ],
      if (picks.isNotEmpty) ...[
        const SizedBox(height: Spacing.lg),
        const _Label('You spend on these without a cap'),
        const SizedBox(height: Spacing.sm),
        for (final pick in picks)
          _PickRow(
            category: pick.category,
            spent: '${formatCurrency(pick.monthSpend, currency)} this month',
            onTap: () => _edit(() => _name.text = pick.category),
          ),
      ],
      const SizedBox(height: Spacing.lg),
      const _Label('Icon'),
      const SizedBox(height: Spacing.sm),
      _IconGrid(selected: _icon, onSelect: (icon) => _edit(() => _icon = icon)),
      const SizedBox(height: Spacing.lg),
      PillButton(label: 'Next', onTap: canNext ? _next : null),
    ];
  }

  /// Step two starts the cap at 0; the name and icon stay for Back.
  void _next() => setState(() {
        _failure = null;
        _draft = 0;
        _step = _Step.addCap;
      });
}

/// Left action, the centred [title], and the right action, 44 tall.
class _Header extends StatelessWidget {
  const _Header({required this.left, required this.title, required this.right});

  final Widget left;
  final String title;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _tapTarget,
      child: Row(
        children: [
          left,
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.headline.copyWith(color: context.colors.ink),
              ),
            ),
          ),
          right,
        ],
      ),
    );
  }
}

/// Holds [child]'s width without drawing or announcing it.
class _Spacer extends StatelessWidget {
  const _Spacer(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(child: Opacity(opacity: 0, child: child)),
    );
  }
}

/// A plain text button, 44 tall. Null [onTap] shows it disabled in `ink3`.
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    this.onTap,
    this.strong = false,
    this.color,
  });

  /// Cancel: closes the sheet without writing.
  factory _TextAction.cancel(BuildContext context) =>
      _TextAction(label: 'Cancel', onTap: () => Navigator.of(context).pop());

  final String label;
  final VoidCallback? onTap;

  /// Headline weight, for the action that writes; otherwise body in `ink2`.
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = strong
        ? AppType.headline.copyWith(color: onTap == null ? c.ink3 : (color ?? c.ink))
        : AppType.body.copyWith(color: color ?? c.ink2);
    final button = PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        height: _tapTarget,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Center(widthFactor: 1, child: Text(label, style: style)),
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

/// The delete confirm's pill: `surface2` with `careInk` text.
class _DeletePill extends StatelessWidget {
  const _DeletePill({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Delete',
      child: Container(
        height: _iconCellHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: c.surface2, borderRadius: BorderRadius.circular(Radii.pill)),
        child: Text('Delete', style: AppType.headline.copyWith(color: c.careInk)),
      ),
    );
  }
}

/// A category spent on without a cap: tap to fill the name with it.
class _PickRow extends StatelessWidget {
  const _PickRow({required this.category, required this.spent, required this.onTap});

  final String category;
  final String spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: '$category, $spent',
      child: Container(
        constraints: const BoxConstraints(minHeight: _pickRowHeight),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hair, width: _hairWidth)),
        ),
        child: Row(
          spacing: Spacing.md,
          children: [
            Expanded(child: Text(category, style: AppType.callout.copyWith(color: c.ink))),
            Text(spent,
                style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular)),
          ],
        ),
      ),
    );
  }
}

/// The icon picker: six columns of pill cells, one group; the chosen cell has
/// a `surface2` fill and an `ink` glyph.
class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final names = _iconChoices.keys.toList();
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Icon',
      child: Column(
        spacing: Spacing.xs,
        children: [
          for (var row = 0; row < names.length; row += _iconColumns)
            Row(
              spacing: Spacing.xs,
              children: [
                for (final name in names.skip(row).take(_iconColumns))
                  Expanded(child: _cell(context, name)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String name) {
    final c = context.colors;
    final on = name == selected;
    // a container node, so the radio flags and the label sit on one node.
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      selected: on,
      checked: on,
      child: PressScale(
        onTap: () => onSelect(name),
        semanticLabel: _iconChoices[name],
        child: Container(
          height: _iconCellHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.surface2 : null,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: AppIcon.line(name, size: _iconGlyph, color: on ? c.ink : c.ink2),
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
