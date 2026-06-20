import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/rituals_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/press_scale.dart';

/// Screen 14 — Evening Close-Out.
///
/// A nighttime wind-down. This is the one screen that ignores the app theme:
/// always a dark purple gradient with white text and a `#BF5AF2` accent. The
/// checklist is the Evening wind-down routine's steps from
/// [ritualsControllerProvider] (closing the day is an evening-routine moment);
/// tapping a row toggles its completion. The first incomplete step gets a
/// purple highlight + "Now" pill — landing on Reflect last to close the ring.
/// The CTA stays disabled ("{n} to go") until every step is done, then turns
/// into an enabled purple "Good night".
class EveningCloseOutScreen extends ConsumerWidget {
  const EveningCloseOutScreen({super.key});

  static const _eveningRoutineId = 'evening';

  // This screen is theme-agnostic — always dark purple. Local constants instead
  // of context.colors so it renders identically in light and dark mode.
  static const _accent = Color(0xFFBF5AF2);
  static const _white = Color(0xFFFFFFFF);
  static const _white85 = Color(0xD9FFFFFF);
  static const _white65 = Color(0xA6FFFFFF);
  static const _white55 = Color(0x8CFFFFFF);
  static const _white50 = Color(0x80FFFFFF);
  static const _white40 = Color(0x66FFFFFF);
  static const _white14 = Color(0x24FFFFFF);
  static const _white12 = Color(0x1FFFFFFF);
  static const _white10 = Color(0x1AFFFFFF);
  static const _white08 = Color(0x14FFFFFF);
  static const _white06 = Color(0x0FFFFFFF);
  static const _accent22 = Color(0x38BF5AF2);
  static const _accent50 = Color(0x80BF5AF2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ritualsControllerProvider);
    final state = async.value;

    final now = DateTime.now();
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dayLabel = '$clock · ${kWeekdays[now.weekday - 1]}';

    // Drive the checklist from the Evening wind-down routine only.
    RitualRoutine? evening;
    for (final r in state?.routines ?? const <RitualRoutine>[]) {
      if (r.id == _eveningRoutineId) {
        evening = r;
        break;
      }
    }

    final total = evening?.steps.length ?? 0;
    final done = evening == null ? 0 : state!.doneCount(evening.id);
    final allDone = total > 0 && done == total;
    final remaining = total - done;
    final closeTail = switch (remaining) {
      0 => 'Ring closed — rest easy.',
      1 => 'One more to close the ring.',
      _ => '$remaining more to close the ring.',
    };
    final closeOutSummary = total == 0
        ? 'No wind-down steps yet.'
        : '$done of $total steps done. $closeTail';

    // The evening steps as ordered rows, tracking the first incomplete one for
    // the "Now" highlight (lands on Reflect last — the step that closes the ring).
    final rows = <_StepRow>[];
    if (evening != null && state != null) {
      final firstIncomplete = state.firstIncompleteStep(evening);
      for (var i = 0; i < evening.steps.length; i++) {
        rows.add(_StepRow(
          routine: evening,
          index: i,
          done: state.isStepDone(evening.id, i),
          active: i == firstIncomplete,
        ));
      }
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1340), Color(0xFF2D1F5C), Color(0xFF3D2A73)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // --- Nav: glass back + centered time -----------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, 56, Spacing.lg, Spacing.sm),
            child: Row(
              children: [
                PressScale(
                  onTap: () => Navigator.of(context).canPop()
                      ? Navigator.of(context).pop()
                      : context.go('/today'),
                  semanticLabel: 'Back',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: _white12,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child:
                            const AppIcon('chevron.left', size: 16, color: _white),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    dayLabel,
                    textAlign: TextAlign.center,
                    style: AppType.footnote
                        .copyWith(color: _white65, letterSpacing: -0.15),
                  ),
                ),
                const SizedBox(width: 32),
              ],
            ),
          ),

          // --- Hero --------------------------------------------------------
          Padding(
            // top 28 has no spacing token (mid-grid) — kept literal for hero rhythm
            padding: const EdgeInsets.fromLTRB(Spacing.xxl, 28, Spacing.xxl, Spacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIcon('sparkles', size: 40, color: _white),
                const SizedBox(height: Spacing.sm),
                Text('Close out\nyour day.',
                    style: AppFonts.sfr(
                        size: 32,
                        weight: FontWeight.w700,
                        color: _white,
                        letterSpacing: -0.5,
                        height: 1.15)),
                const SizedBox(height: Spacing.md),
                Text(
                  closeOutSummary,
                  style: AppType.subhead
                      .copyWith(color: _white65, height: 1.5),
                ),
              ],
            ),
          ),

          // --- Progress bar ------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xxl, 0, Spacing.xxl, Spacing.xxl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xs),
              child: Stack(
                children: [
                  Container(height: 6, color: _white14),
                  FractionallySizedBox(
                    widthFactor: total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      height: 6,
                      color: _accent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Checklist ---------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: _ChecklistRow(
                      row: row,
                      onTap: () => ref
                          .read(ritualsControllerProvider.notifier)
                          .toggleStep(row.routine, row.index),
                    ),
                  ),
              ],
            ),
          ),

          // --- Pal nudge ---------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
            child: PressScale(
              onTap: () => context.go(
                  '/pal-composer?seed=${Uri.encodeComponent("Give me a reflection prompt for tonight")}'),
              child: _DashedButton(
                child: Row(
                  children: [
                    const AppIcon('sparkles', size: 14, color: _accent),
                    const SizedBox(width: Spacing.md),
                    Text('Ask Pal for a reflection prompt',
                        style: AppType.footnote
                            .copyWith(color: _white85, letterSpacing: -0.15)),
                    const Spacer(),
                    const AppIcon('chevron.right', size: 12, color: _white40),
                  ],
                ),
              ),
            ),
          ),

          // --- CTA ---------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xl, Spacing.lg, Spacing.xl, 0),
            child: PressScale(
              onTap: allDone
                  ? () => Navigator.of(context).canPop()
                      ? Navigator.of(context).pop()
                      : context.go('/today')
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: Spacing.lg, horizontal: Spacing.lg),
                decoration: BoxDecoration(
                  color: allDone ? _accent : _white12,
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                alignment: Alignment.center,
                child: Text(
                  allDone ? 'Good night' : '${total - done} to go',
                  style: AppType.callout.copyWith(
                      fontWeight: FontWeight.w600,
                      color: allDone ? _white : _white40,
                      letterSpacing: -0.24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A flattened checklist entry: one step of one routine, with its completion and
/// "active" (first-incomplete) state pre-computed by the screen.
class _StepRow {
  const _StepRow({
    required this.routine,
    required this.index,
    required this.done,
    required this.active,
  });

  final RitualRoutine routine;
  final int index;
  final bool done;
  final bool active;

  RitualStep get step => routine.steps[index];

  /// The step's note (falling back to the routine time if it has none).
  String get subtitle => step.note.isNotEmpty ? step.note : routine.time;
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.row, required this.onTap});

  final _StepRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checked = row.done;
    final active = row.active;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.lg),
        decoration: BoxDecoration(
          color: active
              ? EveningCloseOutScreen._accent22
              : EveningCloseOutScreen._white08,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: active
                ? EveningCloseOutScreen._accent50
                : EveningCloseOutScreen._white08,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Circular checkbox.
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked
                    ? EveningCloseOutScreen._accent
                    : const Color(0x00000000),
                border: checked
                    ? null
                    : Border.all(
                        color: EveningCloseOutScreen._white40, width: 1.5),
              ),
              alignment: Alignment.center,
              child: checked
                  ? const AppIcon('checkmark',
                      size: 12, color: EveningCloseOutScreen._white)
                  : null,
            ),
            const SizedBox(width: Spacing.lg),
            // Icon tile.
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: EveningCloseOutScreen._white10,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              alignment: Alignment.center,
              child: AppIcon(row.step.icon,
                  size: 15, color: EveningCloseOutScreen._white85),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.step.title,
                    style: AppType.subhead.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.24,
                      color: checked
                          ? EveningCloseOutScreen._white55
                          : EveningCloseOutScreen._white,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                      decorationColor: EveningCloseOutScreen._white55,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    row.subtitle,
                    style: AppType.caption.copyWith(
                        color: EveningCloseOutScreen._white50,
                        letterSpacing: -0.08),
                  ),
                ],
              ),
            ),
            if (active) ...[
              const SizedBox(width: Spacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm, vertical: Spacing.xs),
                decoration: BoxDecoration(
                  color: EveningCloseOutScreen._accent,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text('Now',
                    style: AppType.caption2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: EveningCloseOutScreen._white,
                        letterSpacing: 0.1)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Translucent dashed-border container for the Pal nudge button.
class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DottedBorderBox(
      color: const Color(0x40FFFFFF),
      fillColor: EveningCloseOutScreen._white06,
      strokeWidth: 0.5,
      radius: Radii.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.md),
        child: child,
      ),
    );
  }
}
