import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/rituals_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/press_scale.dart';
import '../today/today_logic.dart' show dateLine;

const String _palSeed = 'Give me a reflection prompt for tonight';
const String _loadError = "Couldn't load your routines. Try again in a moment.";

const double _topPad = 52;
const double _bottomPad = 48;
const double _minTap = 44;
const double _backGlyph = 24;
// the chevron's box hangs past the gutter so the glyph lines up with the text.
const double _backHang = 10;
const double _leadTop = 12;
const double _dateTracking = 1.2;
const double _barTop = 16;
const double _cardTop = 20;
const double _cardGap = 14;
const double _pillHeight = 48;
const double _listTop = 32;
const double _rowMin = 56;
const double _disc = 28;
const double _discBorder = 1.5;
const double _check = 14;
const double _palRowMin = 52;
const double _palGlyph = 22;
const double _palGlyphInset = 3;
const double _chevron = 16;
// full-width rows barely shrink, or the press reads as a jump.
const double _rowPress = 0.99;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// The evening close-out: the Evening wind-down routine's steps as one card for
/// the step that is up now and a checklist of the whole night.
class EveningCloseOutScreen extends ConsumerWidget {
  const EveningCloseOutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final safe = MediaQuery.paddingOf(context);
    final children = ref.watch(ritualsControllerProvider).when(
          skipLoadingOnReload: true,
          loading: () => [_Lead(summary: '…', summaryColor: c.ink3)],
          error: (e, _) {
            debugPrint('close-out: routines failed to load: $e');
            return [_Lead(summary: _loadError, summaryColor: c.ink3)];
          },
          data: (state) => _content(context, ref, state),
        );

    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(Spacing.lg, math.max(_topPad, safe.top), Spacing.lg,
            _bottomPad + safe.bottom),
        children: [const _Header(), ...children],
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, RitualsState state) {
    final c = context.colors;
    final evening = state.evening;
    final steps = evening?.steps ?? const <RitualStep>[];
    if (evening == null || steps.isEmpty) {
      return [
        _Lead(summary: 'No wind-down steps yet.', summaryColor: c.ink2),
        const _Card(label: 'Nothing to close', title: 'Rest easy'),
      ];
    }

    final routine = evening;
    final total = steps.length;
    final done = state.doneCount(routine.id);
    final remaining = total - done;
    final tail = switch (remaining) {
      <= 0 => 'The ring is closed.',
      1 => 'One more to close the ring.',
      _ => '$remaining more to close the ring.',
    };
    final next = state.firstIncompleteStep(routine);
    final controller = ref.read(ritualsControllerProvider.notifier);

    return [
      _Lead(summary: '$done of $total steps done. $tail', summaryColor: c.ink2),
      const SizedBox(height: _barTop),
      ProgressBar(value: done / total),
      if (next < total)
        _Card(
          label: 'Now',
          title: steps[next].title,
          note: steps[next].note,
          pill: 'Mark done',
          onPill: () => controller.completeStep(routine, next),
        )
      else
        const _Card(label: 'All done', title: 'Rest easy'),
      const SizedBox(height: _listTop),
      Padding(
        padding: const EdgeInsets.only(bottom: Spacing.xs),
        child: Text('Tonight', style: AppType.headline.copyWith(color: c.ink)),
      ),
      for (var i = 0; i < total; i++)
        _StepRow(
          step: steps[i],
          done: state.isStepDone(routine.id, i),
          onTap: () => controller.toggleStep(routine, i),
        ),
      const _PalRow(),
    ];
  }
}

void _leave(BuildContext context) =>
    Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/today');

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: const Offset(-_backHang, 0),
        child: PressScale(
          onTap: () => _leave(context),
          semanticLabel: 'Back to Today',
          child: SizedBox.square(
            dimension: _minTap,
            child: Center(
              child: AppIcon('chevron.left', size: _backGlyph, color: context.colors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// The date line, the serif heading and the summary, the same in every state.
class _Lead extends StatelessWidget {
  const _Lead({required this.summary, required this.summaryColor});

  final String summary;
  final Color summaryColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: _leadTop),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spacing.sm,
        children: [
          Text(dateLine(clock.now()),
              style: AppType.label.copyWith(
                  color: c.ink3, letterSpacing: _dateTracking, fontFeatures: _tabular)),
          Text('Close out your day.', style: AppType.lead.copyWith(color: c.ink)),
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(summary,
                style: AppType.subhead.copyWith(color: summaryColor, fontFeatures: _tabular)),
          ),
        ],
      ),
    );
  }
}

/// The one card: the step that is up now, or the night's end with Good night.
class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.title,
    this.note = '',
    this.pill = 'Good night',
    this.onPill,
  });

  final String label, title, note, pill;

  /// Null means Good night, which leaves the close-out.
  final VoidCallback? onPill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: _cardTop),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _cardGap,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Spacing.xxs,
            children: [
              Text(label, style: AppType.label.copyWith(color: c.ink3)),
              Text(title, style: AppType.title.copyWith(color: c.ink)),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Text(note, style: AppType.subhead.copyWith(color: c.ink2)),
                ),
            ],
          ),
          // its own node, or the pill merges with the card's text above it.
          Semantics(
            container: true,
            child: PressScale(
              onTap: onPill ?? () => _leave(context),
              semanticLabel: pill,
              child: Container(
                height: _pillHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(pill, style: AppType.headline.copyWith(color: c.bg)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.done, required this.onTap});

  final RitualStep step;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // merged, so the checked flag, the label and the tap sit on one node.
    return MergeSemantics(
      child: Semantics(
        checked: done,
        button: true,
        child: PressScale(
          onTap: onTap,
          semanticLabel: step.title,
          pressedScale: _rowPress,
          child: Container(
            constraints: const BoxConstraints(minHeight: _rowMin),
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hair))),
            child: Row(
              spacing: Spacing.md,
              children: [
                Container(
                  width: _disc,
                  height: _disc,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? c.ink : null,
                    border: done ? null : Border.all(color: c.ink3, width: _discBorder),
                  ),
                  child: done ? AppIcon('checkmark', size: _check, color: c.bg) : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Spacing.xxs,
                    children: [
                      Text(step.title,
                          style: AppType.callout.copyWith(color: done ? c.ink3 : c.ink)),
                      if (step.note.isNotEmpty)
                        Text(step.note, style: AppType.subhead.copyWith(color: c.ink3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PalRow extends StatelessWidget {
  const _PalRow();

  static const _label = 'Ask Pal for a reflection prompt';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: () => context.go('/pal-composer?seed=${Uri.encodeComponent(_palSeed)}'),
      semanticLabel: _label,
      pressedScale: _rowPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: _palRowMin),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hair))),
        child: Row(
          spacing: Spacing.md,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: _palGlyphInset),
              child: AppIcon('sparkles', size: _palGlyph, color: c.ink2),
            ),
            Expanded(child: Text(_label, style: AppType.callout.copyWith(color: c.ink))),
            AppIcon('chevron.right', size: _chevron, color: c.ink3),
          ],
        ),
      ),
    );
  }
}
