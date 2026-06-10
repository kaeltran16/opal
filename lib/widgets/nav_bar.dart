import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';
import 'press_scale.dart';

/// iOS large-title navigation header (static, non-collapsing variant used by the
/// prototype). A scroll-collapsing version can wrap this in a SliverPersistentHeader later.
class LargeTitleNavBar extends StatelessWidget {
  const LargeTitleNavBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bg,
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [leading ?? const SizedBox.shrink(), trailing ?? const SizedBox.shrink()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: AppFonts.sf(
              size: 34,
              weight: FontWeight.w700,
              color: c.ink,
              letterSpacing: 0.37,
              height: 41 / 34,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24),
              ),
            ),
        ],
      ),
    );
  }
}

/// 32×32 circular tinted icon button used in nav trailing slots.
class NavIconButton extends StatelessWidget {
  const NavIconButton({super.key, required this.name, this.onTap, this.semanticLabel});

  final String name;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: c.fill, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: AppIcon(name, size: 17, color: c.accent),
      ),
    );
  }
}
