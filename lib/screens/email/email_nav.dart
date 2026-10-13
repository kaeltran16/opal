import 'package:flutter/services.dart';

/// Auto-formats a 16-char app password into four space-separated groups of 4
/// (e.g. `abcd efgh ijkl mnop`) as the user types. Caret is pushed to the end —
/// acceptable for this paste-then-done field. Used by the Setup screen and
/// exercised directly by the widget test.
class AppPasswordFormatter extends TextInputFormatter {
  const AppPasswordFormatter();

  static const _maxChars = 16;

  /// Strips spaces, caps at 16 chars, regroups in 4s. Exposed for unit reuse.
  static String format(String raw) {
    final stripped = raw.replaceAll(RegExp(r'\s+'), '');
    final capped = stripped.length > _maxChars
        ? stripped.substring(0, _maxChars)
        : stripped;
    final groups = <String>[];
    for (var i = 0; i < capped.length; i += 4) {
      final end = (i + 4 < capped.length) ? i + 4 : capped.length;
      groups.add(capped.substring(i, end));
    }
    return groups.join(' ');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
