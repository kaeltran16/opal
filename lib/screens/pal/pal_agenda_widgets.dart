import 'package:flutter/material.dart';

import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';

const double _minTap = 44;
const double _rowTile = 32;
const double _rowMinHeight = 60;
// kept literal: the iOS switch track and knob.
const double _toggleWidth = 51;
const double _toggleHeight = 31;
const double _knob = 27;

/// The tint behind an agenda token's icon; unknown tokens use the accent.
Color _tint(AppColors c, String token) => switch (token) {
      'money' => c.moneyTint,
      'move' => c.moveTint,
      'rituals' => c.ritualsTint,
      _ => c.accentTint,
    };

BoxDecoration _groupCard(AppColors c) => BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.xxl),
      boxShadow: [BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5)],
    );

Border? _topHair(AppColors c, bool show) =>
    show ? Border(top: BorderSide(color: c.hair, width: 0.5)) : null;

/// A 32 pt icon tile: the area tint under its ink.
Widget _tile(AppColors c, String icon, String token) => Container(
      width: _rowTile,
      height: _rowTile,
      decoration: BoxDecoration(
          color: _tint(c, token), borderRadius: BorderRadius.circular(Radii.md)),
      alignment: Alignment.center,
      child: AppIcon(icon, size: 16, color: c.inkForType(token)),
    );

/// "What Pal remembers": user-authored [PalMemoryDigest.facts] (each deletable)
/// and Pal-derived [PalMemoryDigest.patterns] (dismissable). The footer row
/// wipes all stored memory.
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.memory,
    required this.onDeleteFact,
    required this.onDismissPattern,
    required this.onWipe,
  });

  final PalMemoryDigest memory;
  final void Function(PalFact) onDeleteFact;
  final void Function(InsightPattern) onDismissPattern;
  final VoidCallback onWipe;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      decoration: _groupCard(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowMinHeight),
            child: Row(
              children: [
                _tile(c, 'sparkles', 'accent'),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('What Pal remembers',
                          style: AppType.callout
                              .copyWith(fontWeight: FontWeight.w500, color: c.ink)),
                      Text('Facts and preferences Pal uses',
                          style: AppType.footnote.copyWith(color: c.ink3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (memory.isEmpty)
            _indented(
              c,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                child: Text(
                  "As we talk, I'll note facts you mention and patterns I "
                  'learn here — you can delete anything.',
                  style: AppType.footnote.copyWith(color: c.ink3, height: 1.35),
                ),
              ),
            )
          else ...[
            for (final f in memory.facts)
              _row(c,
                  text: f.text,
                  onDelete: () => onDeleteFact(f),
                  deleteLabel: 'Forget this fact'),
            for (final p in memory.patterns)
              _row(c,
                  text: p.title,
                  meta: p.detail,
                  onDelete: () => onDismissPattern(p),
                  deleteLabel: 'Dismiss this pattern'),
            // destructive: danger ink on the surface, never a tinted fill.
            _indented(
              c,
              PressScale(
                onTap: onWipe,
                semanticLabel: 'Clear all Pal memory',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _minTap),
                  child: Row(
                    children: [
                      AppIcon('trash.fill', size: 14, color: c.dangerInk),
                      const SizedBox(width: Spacing.sm),
                      Text('Clear what Pal remembers',
                          style: AppType.subhead.copyWith(
                              fontWeight: FontWeight.w600, color: c.dangerInk)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Rows sit under the header title, with the hairline inset past the tile.
  Widget _indented(AppColors c, Widget child) => Container(
        margin: const EdgeInsets.only(left: _rowTile + Spacing.md),
        decoration: BoxDecoration(border: _topHair(c, true)),
        child: child,
      );

  Widget _row(AppColors c,
      {required String text,
      String? meta,
      required VoidCallback onDelete,
      required String deleteLabel}) {
    return _indented(
      c,
      Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: AppType.subhead
                          .copyWith(fontWeight: FontWeight.w500, color: c.ink)),
                  if (meta != null)
                    Text(meta, style: AppType.footnote.copyWith(color: c.ink3)),
                ],
              ),
            ),
          ),
          PressScale(
            onTap: onDelete,
            semanticLabel: deleteLabel,
            child: SizedBox(
              width: _minTap,
              height: _minTap,
              child: Center(child: AppIcon('xmark', size: 13, color: c.ink3)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "On autopilot" group: what Pal handles quietly, each with its switch.
class AutopilotCard extends StatelessWidget {
  const AutopilotCard({
    super.key,
    required this.items,
    required this.isOn,
    required this.onToggle,
  });

  final List<PalAutopilotItem> items;
  final bool Function(PalAutopilotItem) isOn;
  final void Function(PalAutopilotItem) onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      decoration: _groupCard(c),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            AutopilotRow(
              item: items[i],
              on: isOn(items[i]),
              first: i == 0,
              onToggle: () => onToggle(items[i]),
            ),
        ],
      ),
    );
  }
}

/// One autopilot item. The whole row is the switch.
class AutopilotRow extends StatelessWidget {
  const AutopilotRow({
    super.key,
    required this.item,
    required this.on,
    required this.first,
    required this.onToggle,
  });

  final PalAutopilotItem item;
  final bool on;
  final bool first;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      toggled: on,
      label: item.title,
      hint: item.subtitle,
      onTap: onToggle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            _tile(c, item.icon, item.colorToken),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: _rowMinHeight),
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                decoration: BoxDecoration(border: _topHair(c, !first)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.title,
                              style: AppType.callout.copyWith(
                                  fontWeight: FontWeight.w500, color: c.ink)),
                          Text(item.subtitle,
                              style: AppType.footnote.copyWith(color: c.ink3)),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    _Toggle(on: on),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS-style switch track, move green when on. Visual only: its row handles
/// the tap and the semantics.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _toggleWidth,
      height: _toggleHeight,
      padding: const EdgeInsets.all(Spacing.xxs),
      decoration: BoxDecoration(
          color: on ? c.move : c.fill,
          borderRadius: BorderRadius.circular(Radii.pill)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: _knob,
          height: _knob,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            // kept literal: the knob is white in both themes, like iOS.
            color: Color(0xFFFFFFFF),
            boxShadow: [
              // kept literal: the knob shadow is fixed in both themes, like iOS.
              BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );
  }
}
