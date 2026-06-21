import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';

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
    // the add field is a TextField, which needs a Material ancestor; provide a
    // transparent one so this works on any host (the dashboard has no Material).
    return Material(
      type: MaterialType.transparency,
      child: InsetSection(
        header: 'Only scan senders',
        footer: 'Pal reads receipts only from these senders — fewer emails '
            'scanned means lower cost. Leave empty to scan the whole inbox.',
        children: [
          for (final s in widget.senders)
            _SenderRow(address: s, onRemove: () => _remove(s)),
          _AddSenderRow(controller: _newSender, onAdd: _add),
        ],
      ),
    );
  }
}

/// One sender in the allowlist: the address plus a tap-to-remove control.
class _SenderRow extends StatelessWidget {
  const _SenderRow({required this.address, required this.onRemove});
  final String address;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.hair, width: 0.5))),
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Text(
              address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.subhead.copyWith(color: c.ink, letterSpacing: -0.24),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.only(left: Spacing.sm),
              child: AppIcon('xmark', size: 15, color: c.ink4),
            ),
          ),
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
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
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
                  hintStyle: AppType.subhead
                      .copyWith(color: c.ink4, letterSpacing: -0.24),
                ),
                style:
                    AppType.subhead.copyWith(color: c.ink, letterSpacing: -0.24),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAdd,
              child: Padding(
                padding: const EdgeInsets.only(left: Spacing.sm),
                child: AppIcon('plus', size: 17, color: c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
