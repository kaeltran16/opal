import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../../widgets/nav_bar.dart';

/// iOS small-title nav header used by the Email Sync flow (Intro/Setup).
///
/// The leading slot is either a chevron+label (Intro/Dashboard back to Settings)
/// or a plain text button ("Cancel" on Setup); the trailing slot is an optional
/// text action ("Save"). Mirrors the handoff's `NavBar`; the shared
/// `LargeTitleNavBar` is used only where the design calls for a large title.
class EmailNavBar extends StatelessWidget {
  const EmailNavBar({
    super.key,
    required this.title,
    this.leadingLabel,
    this.onLeading,
    this.showLeadingChevron = true,
    this.trailingLabel,
    this.onTrailing,
    this.trailingEnabled = true,
  });

  final String title;
  final String? leadingLabel;
  final VoidCallback? onLeading;
  final bool showLeadingChevron;
  final String? trailingLabel;
  final VoidCallback? onTrailing;
  final bool trailingEnabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bg,
      padding: const EdgeInsets.fromLTRB(Spacing.xs, 48, Spacing.xs, Spacing.xs),
      child: SizedBox(
        height: 44, // tap-target height — keep literal
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              title,
              style: AppType.headline.copyWith(color: c.ink),
            ),
            if (leadingLabel != null)
              Align(
                alignment: Alignment.centerLeft,
                child: NavAction(
                  label: leadingLabel,
                  icon: showLeadingChevron ? 'chevron.left' : null,
                  onTap: onLeading,
                ),
              ),
            if (trailingLabel != null)
              Align(
                alignment: Alignment.centerRight,
                child: NavAction(
                  label: trailingLabel,
                  bold: true,
                  enabled: trailingEnabled,
                  onTap: onTrailing,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
