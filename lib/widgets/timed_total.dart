import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import '../util/format.dart';

/// The lead number of a timed session: its minutes in display type with the
/// unit beside it, and the distance after a dot when one was logged.
class TimedTotal extends StatelessWidget {
  const TimedTotal({super.key, required this.minutes, required this.km});

  final int minutes;
  final double km;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unit = AppType.subhead.copyWith(color: c.ink2);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: Spacing.sm,
      children: [
        Text('$minutes', maxLines: 1, style: AppType.display.copyWith(color: c.ink)),
        Text('min', style: unit),
        if (km > 0) Text('· ${formatKm(km)} km', style: unit),
      ],
    );
  }
}
