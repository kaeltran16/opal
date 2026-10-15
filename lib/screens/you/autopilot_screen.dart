import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/autopilot_controller.dart';
import '../../controllers/pal_agenda_controller.dart';
import '../../controllers/providers.dart';
import '../../theme/theme.dart';
import 'sub_screen.dart';

const double _rowMinHeight = 64;
const double _hairline = 1;

/// What Pal handles quietly: every [Automation] with its switch, whether or not
/// the agenda loaded, since the list is the app's own. Pushed from You.
class AutopilotScreen extends ConsumerWidget {
  const AutopilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final quiet = AppType.subhead.copyWith(color: c.ink3, height: 20 / 15);
    final agenda = ref.watch(palAgendaProvider).asData?.value;
    final reminderTime = ref.watch(settingsRepositoryProvider).reminderTime;

    return SubScreen(
      eyebrow: 'Pal',
      title: 'Autopilot',
      children: [
        const SizedBox(height: Spacing.md),
        Text('What Pal handles quietly. Switch any of it off.', style: quiet),
        const SizedBox(height: Spacing.md + Spacing.sm),
        for (final a in Automation.values)
          _AutopilotRow(
            automation: a,
            subtitle: subtitleFor(a, agenda, reminderTime),
          ),
      ],
    );
  }
}

/// One automation under a hairline: its title and subtitle, then its switch.
/// The whole row takes the tap so the target is more than the track.
class _AutopilotRow extends ConsumerWidget {
  const _AutopilotRow({required this.automation, required this.subtitle});

  final Automation automation;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final on = ref.watch(automationsProvider)[automation] ?? false;
    void toggle() => ref.read(automationsProvider.notifier).set(automation, !on);

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
                    Text(automation.title,
                        style: AppType.callout.copyWith(color: c.ink, height: 22 / 16)),
                    const SizedBox(height: Spacing.xxs),
                    Text(subtitle, style: AppType.subhead.copyWith(color: c.ink3)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            MergeSemantics(
              child: Semantics(
                label: automation.title,
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
