import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/autopilot_controller.dart';
import '../../controllers/pal_agenda_controller.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';

// kept literal: the shell overlay under the content, tab bar gap 8 + bar 62 +
// gap 10 + ask bar 52.
const double _shellOverlay = 132;
// kept literal: where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _minTap = 44;
const double _backIcon = 24;
// the chevron hangs into the gutter so its stroke lines up with the text edge.
const double _backHang = Spacing.sm;
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
    final safe = MediaQuery.paddingOf(context);
    final quiet = AppType.subhead.copyWith(color: c.ink3, height: 20 / 15);
    final agenda = ref.watch(palAgendaProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.lg,
          math.max(_contentTop, safe.top + Spacing.xs),
          Spacing.lg,
          _shellOverlay + Spacing.xxl + safe.bottom,
        ),
        children: [
          const _BackHeader(),
          const SizedBox(height: Spacing.md + Spacing.sm),
          Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pal', style: AppType.label.copyWith(color: c.ink3)),
                const SizedBox(height: Spacing.xxs),
                Text('Autopilot', style: AppType.title.copyWith(color: c.ink)),
              ],
            ),
          ),
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
      ),
    );
  }
}

/// Back to You at the left.
class _BackHeader extends StatelessWidget {
  const _BackHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Transform.translate(
        offset: const Offset(-_backHang, 0),
        child: PressScale(
          onTap: () => Navigator.of(context).pop(),
          semanticLabel: 'Back to You',
          child: Container(
            constraints: const BoxConstraints(minHeight: _minTap),
            padding: const EdgeInsets.only(right: Spacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon('chevron.left', size: _backIcon, color: c.ink),
                const SizedBox(width: Spacing.xxs),
                Text('You', style: AppType.headline.copyWith(color: c.ink)),
              ],
            ),
          ),
        ),
      ),
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
                    Text(item.subtitle,
                        style: AppType.footnote.copyWith(color: c.ink3, height: 18 / 13)),
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
