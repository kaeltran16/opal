import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'app_icon.dart';

const double _keyHeight = 52;
const double _deleteIcon = 22;
const Duration _pressFade = Duration(milliseconds: 120);

/// A custom 3×4 numeric keypad (digits 0–9, a decimal key, and a delete key).
///
/// Stateless and value-agnostic: it only emits *intents* and lets the caller
/// own the buffer. Callers wire [onDigit] (the tapped digit `'0'`..`'9'`),
/// [onDecimal] (the `.` key), and [onDelete] (backspace). The decimal key can
/// be hidden for integer-only inputs (e.g. minutes) via [showDecimal].
///
/// Shared widget introduced in U07; later units (e.g. workout weight/reps
/// entry) can reuse it as-is.
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.onDigit,
    required this.onDecimal,
    required this.onDelete,
    this.showDecimal = true,
  });

  /// Called with the tapped digit character, `'0'` through `'9'`.
  final ValueChanged<String> onDigit;

  /// Called when the decimal (`.`) key is tapped.
  final VoidCallback onDecimal;

  /// Called when the delete (backspace) key is tapped.
  final VoidCallback onDelete;

  /// When false the decimal key renders as an inert blank (integer inputs).
  final bool showDecimal;

  @override
  Widget build(BuildContext context) {
    // Layout: rows 1-2-3 / 4-5-6 / 7-8-9 / .  -  0  -  ⌫
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['.', '0', 'del'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                      child: _Key(
                        token: key,
                        showDecimal: showDecimal,
                        onDigit: onDigit,
                        onDecimal: onDecimal,
                        onDelete: onDelete,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    required this.token,
    required this.showDecimal,
    required this.onDigit,
    required this.onDecimal,
    required this.onDelete,
  });

  final String token; // '0'..'9' | '.' | 'del'
  final bool showDecimal;
  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onDelete;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  bool get _isDecimal => widget.token == '.';
  bool get _isDelete => widget.token == 'del';
  bool get _isInert => _isDecimal && !widget.showDecimal;

  void _tap() {
    if (_isDelete) {
      widget.onDelete();
    } else if (_isDecimal) {
      widget.onDecimal();
    } else {
      widget.onDigit(widget.token);
    }
  }

  void _set(bool down) => setState(() => _down = down);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_isInert) {
      // Keep the grid balanced but render nothing tappable.
      return const SizedBox(height: _keyHeight);
    }
    return Semantics(
      button: true,
      label: _isDelete ? 'delete' : widget.token,
      // the key's own text would read again after the label ("1 1"); the
      // exclusion drops the detector's tap too, so the node carries its own.
      excludeSemantics: true,
      onTap: _tap,
      child: GestureDetector(
        onTap: _tap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: _pressFade,
          height: _keyHeight,
          decoration: BoxDecoration(
            color: _down ? c.surface2 : null,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          alignment: Alignment.center,
          child: _isDelete
              ? AppIcon('delete.left.fill', size: _deleteIcon, color: c.ink)
              : Text(
                  widget.token,
                  style: AppType.title.copyWith(
                    color: c.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
      ),
    );
  }
}
