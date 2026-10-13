import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/pal/pal_service.dart';

part 'autopilot_controller.g.dart';

/// The user's autopilot switches for this app session, as overrides of each
/// item's server default by item id.
///
/// Kept alive so a switch survives leaving and reopening Autopilot. Not
/// persisted: there is no server endpoint yet, so a switch cannot stop the
/// task, and a stored value would claim more than it does.
@Riverpod(keepAlive: true)
class AutopilotSwitches extends _$AutopilotSwitches {
  @override
  Map<String, bool> build() => const {};

  bool isOn(PalAutopilotItem item) => state[item.id] ?? item.enabled;

  void toggle(PalAutopilotItem item) =>
      state = {...state, item.id: !isOn(item)};
}
