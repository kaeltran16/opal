import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';

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
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
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

class _Key extends StatelessWidget {
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

  bool get _isDecimal => token == '.';
  bool get _isDelete => token == 'del';
  bool get _isInert => _isDecimal && !showDecimal;

  void _tap() {
    if (_isDelete) {
      onDelete();
    } else if (_isDecimal) {
      onDecimal();
    } else {
      onDigit(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_isInert) {
      // Keep the grid balanced but render nothing tappable.
      return const SizedBox(height: 52);
    }
    return Semantics(
      button: true,
      label: _isDelete ? 'delete' : token,
      child: GestureDetector(
        onTap: _tap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.hair, width: 0.5),
          ),
          alignment: Alignment.center,
          child: _isDelete
              ? AppIcon('delete.left.fill', size: 22, color: c.ink2)
              : Text(
                  token,
                  style: AppFonts.sfr(
                    size: 26,
                    weight: FontWeight.w500,
                    color: c.ink,
                  ),
                ),
        ),
      ),
    );
  }
}
