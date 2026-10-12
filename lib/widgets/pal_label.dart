import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'app_icon.dart';

const double _iconSize = 16;
const double _gap = 6;

/// Marks the line beneath it as Pal's.
class PalLabel extends StatelessWidget {
  const PalLabel({super.key, this.text = 'Pal'});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon('sparkles', size: _iconSize, color: c.ink2),
        const SizedBox(width: _gap),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(color: c.ink2)),
        ),
      ],
    );
  }
}
