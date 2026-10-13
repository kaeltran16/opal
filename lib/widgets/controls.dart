import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart' show InputDecoration, TextField;
import 'package:flutter/widgets.dart';
import '../theme/theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

const double _minTap = 44;
const double _pillHeight = 48;
const double _pillIcon = 18;
const double _chipHeight = 32;
const double _searchIcon = 16;
const Duration _fillDuration = Duration(milliseconds: 240);
const Duration _thumbDuration = Duration(milliseconds: 150);

/// Thin progress bar: `ink` on `track`.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 4,
  });

  final double value; // 0..1
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(height: height, color: c.track),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: _fillDuration,
              curve: Curves.easeOut,
              height: height,
              decoration: BoxDecoration(color: color ?? c.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 48 pill button: primary is `ink` with `bg` text, secondary `surface2`
/// with `ink` text. A null [onTap] renders disabled.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = true,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final String? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    // a disabled pill drops to surface2 either way, so ink4 text never sits on ink.
    final fill = primary && enabled ? c.ink : c.surface2;
    final ink = !enabled ? c.ink4 : (primary ? c.bg : c.ink);
    final icon = this.icon;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: _pillHeight),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Spacing.sm,
          children: [
            if (icon != null) AppIcon(icon, size: _pillIcon, color: ink),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headline.copyWith(color: ink)),
            ),
          ],
        ),
      ),
    );
    if (!enabled) {
      return Semantics(
        button: true,
        enabled: false,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: pill,
      );
    }
    return PressScale(onTap: onTap, semanticLabel: semanticLabel, child: pill);
  }
}

/// The app's switch: `ink` track when on, `track` when off.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Semantics(
        label: semanticLabel,
        child: CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: c.ink,
          inactiveTrackColor: c.track,
          thumbColor: c.bg,
          inactiveThumbColor: c.ink3,
        ),
      ),
    );
  }
}

/// A filter chip: 32 visible inside a 44 tap target.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      child: PressScale(
        onTap: onTap,
        semanticLabel: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTap),
          child: Center(
            widthFactor: 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: _chipHeight),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              decoration: BoxDecoration(
                color: selected ? c.ink : c.surface2,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: selected ? c.bg : c.ink2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 44 search field on a `surface2` pill.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.controller,
    this.placeholder = 'Search',
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _minTap),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        spacing: Spacing.sm,
        children: [
          AppIcon('magnifyingglass', size: _searchIcon, color: c.ink3),
          Expanded(
            child: Semantics(
              label: placeholder,
              textField: true,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: c.ink,
                style: AppType.body.copyWith(color: c.ink),
                decoration: InputDecoration.collapsed(
                  hintText: placeholder,
                  hintStyle: AppType.body.copyWith(color: c.ink3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sliding segmented control: a `surface` thumb on a `surface2` pill.
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
    return Container(
      padding: const EdgeInsets.all(Spacing.xxs),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        children: [
          for (final (val, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: val == value,
                child: GestureDetector(
                  onTap: () => onChanged(val),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: _thumbDuration,
                    constraints: const BoxConstraints(minHeight: _minTap),
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                    decoration: BoxDecoration(
                      color: val == value ? c.surface : AppColors.clear,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Center(
                      heightFactor: 1,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.label.copyWith(color: val == value ? c.ink : c.ink2),
                      ),
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
