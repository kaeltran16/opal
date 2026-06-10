import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';

/// Thin progress bar (sync, budget, rituals). Track + animated fill.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 4,
    this.gradient,
  });

  final double value; // 0..1
  final Color? color;
  final double height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(height: height, color: c.fill),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              height: height,
              decoration: BoxDecoration(
                color: gradient == null ? (color ?? c.accent) : null,
                gradient: gradient,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 28×28 rounded-square check used by rituals and workout sets.
class CheckButton extends StatelessWidget {
  const CheckButton({
    super.key,
    required this.checked,
    this.typeColor,
    this.onTap,
  });

  final bool checked;
  final Color? typeColor; // completed fill color
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fillColor = typeColor ?? c.rituals;
    return Semantics(
      button: onTap != null,
      checked: checked,
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: checked ? fillColor : c.fill,
          borderRadius: BorderRadius.circular(8),
          border: checked ? null : Border.all(color: c.ink3, width: 1.5),
        ),
        alignment: Alignment.center,
        child: checked
            ? const AppIcon('checkmark', size: 16, color: Color(0xFFFFFFFF))
            : null,
      ),
      ),
    );
  }
}

/// iOS sliding segmented control.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T value, String label)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selectedBg =
        c.brightness == Brightness.dark ? const Color(0xFF636366) : const Color(0xFFFFFFFF);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(9)),
      child: Row(
        children: [
          for (final (val, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(val),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: val == value ? selectedBg : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: val == value
                        ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 3))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: AppFonts.sf(
                      size: 13,
                      weight: val == value ? FontWeight.w600 : FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -0.08,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
