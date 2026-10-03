import 'package:flutter/widgets.dart';

import '../analysis/area_state.dart';
import '../theme/theme.dart';

/// How an [AreaState] is coloured. Neutral unless the state is off track.
extension AreaStateColors on AppColors {
  /// Fill for an arc or bar. A goal met stays neutral: its check carries the
  /// colour.
  Color arcFor(AreaState state) => switch (state) {
        AreaState.thriving || AreaState.good => ink,
        AreaState.watch => watch,
        AreaState.care => care,
      };

  /// Ink for the state word.
  Color wordInkFor(AreaState state) => switch (state) {
        AreaState.thriving => thrivingInk,
        AreaState.good => ink3,
        AreaState.watch => watchInk,
        AreaState.care => careInk,
      };
}
