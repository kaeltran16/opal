import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'app_icon.dart';
import 'glass_surface.dart';
import 'press_scale.dart';

/// Glass capsule on every tab that opens the Pal composer. It looks like a
/// field but is a button: typing happens in the composer sheet it opens.
class PalAskBar extends StatelessWidget {
  const PalAskBar({super.key, required this.onAsk, required this.onMic});

  static const String _placeholder = 'Tell Pal anything';
  static const double _height = 52;
  static const double _micSize = 44;
  static const double _micGlyph = 20;
  static const double _inset = Spacing.xs;

  final VoidCallback onAsk;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassSurface(
      child: SizedBox(
        height: _height,
        child: Row(
          spacing: Spacing.sm,
          children: [
            Expanded(
              child: PressScale(
                onTap: onAsk,
                semanticLabel: _placeholder,
                child: Container(
                  height: _height,
                  padding: const EdgeInsets.only(left: Spacing.xl),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.callout.copyWith(color: c.ink3),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: _inset),
              child: PressScale(
                onTap: onMic,
                semanticLabel: 'Dictate',
                child: Container(
                  width: _micSize,
                  height: _micSize,
                  decoration: BoxDecoration(
                    color: c.ink,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppIcon('mic', size: _micGlyph, color: c.bg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
