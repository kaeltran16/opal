import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'app_icon.dart';

/// Pal's avatar: a 135° gradient (accent → rituals) circle with a white
/// sparkles glyph. [glow] adds an accent halo behind the circle (inbox title).
class PalAvatar extends StatelessWidget {
  const PalAvatar({
    super.key,
    required this.size,
    required this.glyphSize,
    this.glow = false,
  });

  final double size;
  final double glyphSize;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent, c.rituals],
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.33),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: AppIcon('sparkles', size: glyphSize, color: c.onAccent),
    );
  }
}
