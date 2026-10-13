import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/area.dart';
import '../../analysis/area_state.dart';
import '../../controllers/areas_controller.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/day_scene.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/state_colors.dart';

// kept literal: the shell overlay under the content, tab bar gap 8 + bar 62 +
// gap 10 + ask bar 52.
const double _shellOverlay = 132;
// kept literal: where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _minTap = 44;
const double _headerGap = Spacing.sm;

const double _ringsTop = Spacing.md;
const double _ringsGap = Spacing.xl;
const double _ringsSize = 152;
const double _ringStroke = 16;
const List<double> _ringRadii = [68, 48];
const double _legendMinHeight = 48;
const double _legendPadding = Spacing.xs;
const double _legendLineGap = Spacing.xxs;
const double _swatch = 8;
const double _labelGap = 6;

const double _palTop = Spacing.sm;
const double _palIcon = 16;
// lines the icon up with the first line of the text beside it.
const double _palIconTop = 2;
const double _palLineHeight = 20 / 15;
const double _alsoTrackedTop = Spacing.xl;

const double _cardPadding = 14;
const double _cardLineGap = Spacing.xs;
const double _cardIcon = 16;
const double _cardNumberSize = 28;
const double _cardNumberLine = 34;
const double _cardNumberTracking = -0.6;
const double _cardWordLine = 16 / 12;
const double _hairline = 1;

const double _barTop = 6;
const double _barHeight = 10;
const double _barTrack = 4;
const double _barDot = 10;
const double _dotRing = 2;
const double _captionTracking = 0.3;
const double _captionLineHeight = 16 / 12;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// The ruled areas drawn as rings, outer first. The rest are `Also tracked`.
const List<Area> _ringAreas = [Area.move, Area.routines];

const String _title = 'Areas';
const String _caption = 'Dot is today. Band is where you usually are by this hour.';

/// The Areas tab: Move and Routines as rings, Pal's line on what is off, the
/// other areas as cards against where they usually are by this hour.
///
/// Everything shown is computed by [buildAreasSummary]; this widget only lays
/// out.
class AreasScreen extends ConsumerWidget {
  const AreasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final safe = MediaQuery.paddingOf(context);
    final padding = EdgeInsets.fromLTRB(
      Spacing.lg,
      math.max(_contentTop, safe.top + Spacing.xs),
      Spacing.lg,
      _shellOverlay + Spacing.xxl + safe.bottom,
    );
    final scene = Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DayScene(phase: phaseFor(clock.now())),
    );
    Widget message(String text, TextStyle style) => Stack(
          children: [
            scene,
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(count: null),
                  Expanded(
                    child: Center(
                      child: Text(text,
                          textAlign: TextAlign.center,
                          style: style.copyWith(color: c.ink3)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

    return Scaffold(
      backgroundColor: c.bg,
      body: ref.watch(areasSummaryProvider).when(
            skipLoadingOnReload: true,
            loading: () => message('…', AppType.body),
            error: (e, _) {
              debugPrint('areas load failed: $e');
              return message("Couldn't load your areas.", AppType.subhead);
            },
            data: (summary) => SingleChildScrollView(
              child: Stack(
                children: [
                  scene,
                  Padding(padding: padding, child: _AreasBody(summary: summary)),
                ],
              ),
            ),
          ),
    );
  }
}

/// `Areas` at the left, the on-track count at the right once it is known.
class _Header extends StatelessWidget {
  const _Header({required this.count});

  final String? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = this.count;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(_title, style: AppType.title.copyWith(color: c.ink)),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: _headerGap),
            Text(count, style: AppType.label.copyWith(color: c.ink2, fontFeatures: _tabular)),
          ],
        ],
      ),
    );
  }
}

class _AreasBody extends StatelessWidget {
  const _AreasBody({required this.summary});

  final AreasSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rings = [for (final area in _ringAreas) summary.of(area)];
    final ringColors = [c.move, c.rituals];
    final vitals = summary.areas.where((a) => !_ringAreas.contains(a.area));
    final goals = [for (final a in rings) '${a.area.title} ${_value(a)}'].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.md,
      children: [
        _Header(count: summary.countLabel),
        Semantics(
          container: true,
          label: 'Daily goals: $goals',
          child: Padding(
            padding: const EdgeInsets.only(top: _ringsTop),
            child: Row(
              children: [
                ActivityRings(
                  rings: [
                    for (final (i, a) in rings.indexed)
                      ActivityRing(fraction: a.progress ?? 0, color: ringColors[i]),
                  ],
                  size: _ringsSize,
                  strokeWidth: _ringStroke,
                  radii: _ringRadii,
                ),
                const SizedBox(width: _ringsGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, a) in rings.indexed)
                        _LegendRow(summary: a, swatch: ringColors[i]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: _palTop),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: _palIconTop),
                child: AppIcon('sparkles', size: _palIcon, color: c.ink2),
              ),
              const SizedBox(width: _labelGap),
              Expanded(
                child: Text(summary.palLine,
                    style: AppType.subhead.copyWith(color: c.ink2, height: _palLineHeight)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: _alsoTrackedTop),
          child: Semantics(
            header: true,
            child: Text('Also tracked', style: AppType.headline.copyWith(color: c.ink)),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final a in vitals) _VitalCard(summary: a)],
        ),
        Text(_caption,
            style: AppType.caption.copyWith(
                color: c.ink3, letterSpacing: _captionTracking, height: _captionLineHeight)),
      ],
    );
  }
}

String _value(AreaSummary a) => a.number == null ? a.unit : '${a.number} ${a.unit}';

/// The state word a ring's legend shows: none while simply on track.
String? _legendWord(AreaState? state) =>
    state == null || state == AreaState.good ? null : state.word;

/// Opens [area]'s page. go, not push: the page sits under /areas, so back
/// pops here.
void _open(BuildContext context, Area area) => context.goNamed(areaRoute(area).name);

/// A ring's legend: swatch, title, the state word when not on track, value.
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.summary, required this.swatch});

  final AreaSummary summary;
  final Color swatch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = summary.area.title;
    final value = _value(summary);
    final word = _legendWord(summary.state);
    final label = AppType.label.copyWith(color: c.ink2);
    return PressScale(
      onTap: () => _open(context, summary.area),
      semanticLabel: '$title, $value${word == null ? '' : ', $word'}. Open $title',
      child: Container(
        constraints: const BoxConstraints(minHeight: _legendMinHeight),
        padding: const EdgeInsets.symmetric(vertical: _legendPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: _legendLineGap,
          children: [
            Row(
              children: [
                Container(
                  width: _swatch,
                  height: _swatch,
                  decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
                ),
                const SizedBox(width: _labelGap),
                Flexible(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: label),
                ),
                if (word != null) ...[
                  const SizedBox(width: _labelGap),
                  Flexible(
                    child: Text(word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label.copyWith(color: c.wordInkFor(summary.state!))),
                  ),
                ],
              ],
            ),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(color: c.ink, fontFeatures: _tabular)),
          ],
        ),
      ),
    );
  }
}

/// One `Also tracked` area: icon, title and state word; the number and its
/// unit; and today's dot against the usual band.
class _VitalCard extends StatelessWidget {
  const _VitalCard({required this.summary});

  final AreaSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = summary.state;
    final number = summary.number;
    final progress = summary.progress;
    final label = AppType.label.copyWith(color: c.ink2);
    final unit = AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular);
    return PressScale(
      onTap: () => _open(context, summary.area),
      semanticLabel: summary.semanticLabel,
      child: Container(
        constraints: const BoxConstraints(minHeight: _minTap),
        padding: const EdgeInsets.symmetric(vertical: _cardPadding),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hair, width: _hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: _cardLineGap,
          children: [
            Row(
              children: [
                AppIcon(summary.area.glyph, size: _cardIcon, color: c.ink2),
                const SizedBox(width: _labelGap),
                Expanded(child: Text(summary.area.title, style: label)),
                if (state != null)
                  Text(state.word,
                      style: AppType.caption.copyWith(
                          color: c.wordInkFor(state), height: _cardWordLine)),
              ],
            ),
            if (number == null)
              Text(summary.unit, style: unit)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(number,
                      maxLines: 1,
                      style: AppType.score.copyWith(
                        color: c.ink,
                        fontSize: _cardNumberSize,
                        height: _cardNumberLine / _cardNumberSize,
                        letterSpacing: _cardNumberTracking,
                      )),
                  const SizedBox(width: Spacing.sm),
                  Flexible(child: Text(summary.unit, style: unit)),
                ],
              ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(top: _barTop),
                child: _RangeBar(
                  at: progress,
                  usual: summary.usual,
                  dot: state == null ? c.ink : c.arcFor(state),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The track, the usual band when there is enough history, and today's dot.
class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.at, required this.usual, required this.dot});

  /// 0..1 positions along the bar.
  final double at;
  final UsualBand? usual;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final usual = this.usual;
    const trackTop = (_barHeight - _barTrack) / 2;
    Widget pill(Color color) => DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(_barTrack)),
        );
    return SizedBox(
      height: _barHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 0, right: 0, top: trackTop, height: _barTrack, child: pill(c.track)),
              if (usual != null)
                Positioned(
                  key: const ValueKey('usualBand'),
                  left: w * usual.low,
                  width: w * (usual.high - usual.low),
                  top: trackTop,
                  height: _barTrack,
                  child: pill(c.ink3),
                ),
              Positioned(
                key: const ValueKey('todayDot'),
                left: w * at.clamp(0.0, 1.0) - _barDot / 2,
                top: 0,
                width: _barDot,
                height: _barDot,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: c.bg, width: _dotRing, strokeAlign: BorderSide.strokeAlignOutside),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
