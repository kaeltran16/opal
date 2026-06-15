import 'package:flutter/widgets.dart';
import '../theme/theme.dart';
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
///
/// The check scales down while pressed (matching [PressScale]'s tactile feel)
/// and fills its colour over 180ms on toggle. Haptics are fired by the calling
/// controller (ritual toggle / set complete), not here, to avoid double-firing.
class CheckButton extends StatefulWidget {
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
  State<CheckButton> createState() => _CheckButtonState();
}

class _CheckButtonState extends State<CheckButton> {
  bool _down = false;

  void _set(bool down) => setState(() => _down = down);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fillColor = widget.typeColor ?? c.rituals;
    final enabled = widget.onTap != null;
    return Semantics(
      button: enabled,
      checked: widget.checked,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.checked ? fillColor : c.fill,
              borderRadius: BorderRadius.circular(Radii.sm),
              border:
                  widget.checked ? null : Border.all(color: c.ink3, width: 1.5),
            ),
            alignment: Alignment.center,
            child: widget.checked
                ? AppIcon('checkmark', size: 16, color: c.onAccent)
                : null,
          ),
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
      padding: const EdgeInsets.all(Spacing.xxs),
      decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(Radii.sm)),
      child: Row(
        children: [
          for (final (val, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(val),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.md),
                  decoration: BoxDecoration(
                    color: val == value ? selectedBg : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(Radii.sm),
                    boxShadow: val == value ? Elevation.sm(c.shadow) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: AppType.footnote.copyWith(
                      fontWeight: val == value ? FontWeight.w600 : FontWeight.w500,
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
