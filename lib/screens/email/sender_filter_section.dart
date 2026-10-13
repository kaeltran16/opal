import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';

const double _minTap = 44;
const double _hairline = 1;
const double _actionIcon = 17;

/// The "Only scan senders" allowlist editor, shared by the Email Setup and
/// Dashboard screens. Renders the current [senders] as removable rows plus a
/// trailing add field, and emits the full updated list via [onChanged]. It owns
/// only the add-field text; the list itself is owned by the caller.
class SenderFilterSection extends StatefulWidget {
  const SenderFilterSection({
    super.key,
    required this.senders,
    required this.onChanged,
  });

  final List<String> senders;

  /// Called with the new full list whenever a sender is added or removed.
  final ValueChanged<List<String>> onChanged;

  @override
  State<SenderFilterSection> createState() => _SenderFilterSectionState();
}

class _SenderFilterSectionState extends State<SenderFilterSection> {
  final _newSender = TextEditingController();

  @override
  void dispose() {
    _newSender.dispose();
    super.dispose();
  }

  void _add() {
    final v = _newSender.text.trim();
    // ignore blanks and duplicates; the field clears either way
    if (v.isNotEmpty && !widget.senders.contains(v)) {
      widget.onChanged([...widget.senders, v]);
    }
    _newSender.clear();
  }

  void _remove(String sender) =>
      widget.onChanged(widget.senders.where((s) => s != sender).toList());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Only scan senders',
              style: AppType.headline.copyWith(color: c.ink)),
        ),
        const SizedBox(height: Spacing.sm),
        for (final s in widget.senders)
          _SenderRow(address: s, onRemove: () => _remove(s)),
        _AddSenderRow(controller: _newSender, onAdd: _add),
        const SizedBox(height: Spacing.sm),
        Text(
          'Pal reads receipts only from these senders — fewer emails scanned '
          'means lower cost. Leave empty to scan the whole inbox.',
          style: AppType.subhead.copyWith(color: c.ink3),
        ),
      ],
    );
  }
}

/// A row under a hairline, at least a touch target tall.
class _HairlineRow extends StatelessWidget {
  const _HairlineRow({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: _minTap),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.hair, width: _hairline)),
        ),
        child: child,
      );
}

/// A square touch target holding one icon.
class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: _minTap,
            child: Center(
              child: AppIcon(icon, size: _actionIcon, color: context.colors.ink2),
            ),
          ),
        ),
      );
}

/// One sender in the allowlist: the address plus a tap-to-remove control.
class _SenderRow extends StatelessWidget {
  const _SenderRow({required this.address, required this.onRemove});
  final String address;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _HairlineRow(
      child: Row(
        children: [
          Expanded(
            child: Text(
              address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.callout.copyWith(color: c.ink),
            ),
          ),
          _IconAction(icon: 'xmark', label: 'Remove $address', onTap: onRemove),
        ],
      ),
    );
  }
}

/// The trailing add-row: type a sender, then tap + (or submit) to append it.
class _AddSenderRow extends StatelessWidget {
  const _AddSenderRow({required this.controller, required this.onAdd});
  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _HairlineRow(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onAdd(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Add sender email',
                hintStyle: AppType.callout.copyWith(color: c.ink3),
              ),
              style: AppType.callout.copyWith(color: c.ink),
            ),
          ),
          _IconAction(icon: 'plus', label: 'Add sender', onTap: onAdd),
        ],
      ),
    );
  }
}
