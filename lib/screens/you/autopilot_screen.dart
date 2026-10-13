import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/autopilot_controller.dart';
import '../../controllers/pal_agenda_controller.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import 'sub_screen.dart';

const double _rowMinHeight = 64;
const double _hairline = 1;

/// What Pal handles quietly, each item with its switch. Pushed from You.
///
/// A switch flips [autopilotSwitchesProvider] for this session only: there is
/// no server endpoint yet, so it cannot stop the task itself.
class AutopilotScreen extends ConsumerWidget {
  const AutopilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final quiet = AppType.subhead.copyWith(color: c.ink3, height: 20 / 15);
    final agenda = ref.watch(palAgendaProvider);

    return SubScreen(
      eyebrow: 'Pal',
      title: 'Autopilot',
      children: [
        const SizedBox(height: Spacing.md),
        Text('What Pal handles quietly. Switch any of it off.', style: quiet),
        const SizedBox(height: Spacing.md + Spacing.sm),
        ...agenda.when(
          loading: () => const [],
          error: (e, _) {
            debugPrint('autopilot: loading the agenda failed: $e');
            return [Text("Couldn't load autopilot.", style: quiet)];
          },
          data: (a) => a.autopilot.isEmpty
              ? [Text('Nothing on autopilot yet.', style: quiet)]
              : [for (final item in a.autopilot) _AutopilotRow(item: item)],
        ),
      ],
    );
  }
}

/// One autopilot item under a hairline: its title and subtitle, then its
/// switch. The whole row takes the tap so the target is more than the track.
class _AutopilotRow extends ConsumerWidget {
  const _AutopilotRow({required this.item});

  final PalAutopilotItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    ref.watch(autopilotSwitchesProvider);
    final switches = ref.read(autopilotSwitchesProvider.notifier);
    final on = switches.isOn(item);
    void toggle() => switches.toggle(item);

    return GestureDetector(
      onTap: toggle,
      behavior: HitTestBehavior.opaque,
      // the switch below carries the row's semantics.
      excludeFromSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: _rowMinHeight),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hair, width: _hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: AppType.callout.copyWith(color: c.ink, height: 22 / 16)),
                    const SizedBox(height: Spacing.xxs),
                    Text(item.subtitle, style: AppType.subhead.copyWith(color: c.ink3)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            MergeSemantics(
              child: Semantics(
                label: item.title,
                child: CupertinoSwitch(
                  value: on,
                  onChanged: (_) => toggle(),
                  activeTrackColor: c.ink,
                  inactiveTrackColor: c.track,
                  thumbColor: c.bg,
                  inactiveThumbColor: c.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
