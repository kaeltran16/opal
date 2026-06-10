import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/rituals_controller.dart';
import '../../models/models.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';

/// Screen 14 — Evening Close-Out.
///
/// A nighttime wind-down. This is the one screen that ignores the app theme:
/// always a dark purple gradient with white text and a `#BF5AF2` accent. The
/// checklist flattens every routine step from [ritualsControllerProvider] into
/// rows; tapping a row toggles its completion. The first incomplete step gets a
/// purple highlight + "Now" pill. The CTA stays disabled ("{n} to go") until
/// every step is done, then turns into an enabled purple "Good night".
class EveningCloseOutScreen extends ConsumerWidget {
  const EveningCloseOutScreen({super.key});

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

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ritualsControllerProvider);
    final state = async.value;

    final now = DateTime.now();
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dayLabel = '$clock · ${_days[now.weekday - 1]}';

    final done = state?.doneSteps ?? 0;
    final total = state?.totalSteps ?? 0;
    final allDone = total > 0 && done == total;

    // Flatten every routine step into ordered (routine, index) rows, tracking
    // the first incomplete one for the "Now" highlight.
    final rows = <_StepRow>[];
    var firstIncompleteSeen = false;
    if (state != null) {
      for (final routine in state.routines) {
        for (var i = 0; i < routine.steps.length; i++) {
          final isDone = state.isStepDone(routine.id, i);
          final isActive = !isDone && !firstIncompleteSeen;
          if (isActive) firstIncompleteSeen = true;
          rows.add(_StepRow(
            routine: routine,
            index: i,
            done: isDone,
            active: isActive,
          ));
        }
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
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
            child: Row(
              children: [
                PressScale(
                  onTap: () => Navigator.of(context).canPop()
                      ? Navigator.of(context).pop()
                      : context.go('/today'),
                  semanticLabel: 'Back',
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: _white12,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const AppIcon('chevron.left', size: 16, color: _white),
                  ),
                ),
                Expanded(
                  child: Text(
                    dayLabel,
                    textAlign: TextAlign.center,
                    style: AppFonts.sf(
                        size: 14, color: _white65, letterSpacing: -0.15),
                  ),
                ),
                const SizedBox(width: 32),
              ],
            ),
          ),

          // --- Hero --------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✦',
                    style: TextStyle(fontSize: 40, color: _white)),
                const SizedBox(height: 8),
                Text('Close out\nyour day.',
                    style: AppFonts.sfr(
                        size: 32,
                        weight: FontWeight.w700,
                        color: _white,
                        letterSpacing: -0.5,
                        height: 1.15)),
                const SizedBox(height: 10),
                Text(
                  '$done of $total rituals done. One more to close the ring.',
                  style: AppFonts.sf(
                      size: 15,
                      color: _white65,
                      letterSpacing: -0.24,
                      height: 1.5),
                ),
              ],
            ),
          ),

          // --- Progress bar ------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: PressScale(
              onTap: () => context.go(
                  '/pal-composer?seed=${Uri.encodeComponent("Give me a reflection prompt for tonight")}'),
              child: _DashedButton(
                child: Row(
                  children: [
                    const AppIcon('sparkles', size: 14, color: _accent),
                    const SizedBox(width: 10),
                    Text('Ask Pal for a reflection prompt',
                        style: AppFonts.sf(
                            size: 14, color: _white85, letterSpacing: -0.15)),
                    const Spacer(),
                    const AppIcon('chevron.right', size: 12, color: _white40),
                  ],
                ),
              ),
            ),
          ),

          // --- CTA ---------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: PressScale(
              onTap: allDone
                  ? () => Navigator.of(context).canPop()
                      ? Navigator.of(context).pop()
                      : context.go('/today')
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                decoration: BoxDecoration(
                  color: allDone ? _accent : _white12,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  allDone ? 'Good night' : '${total - done} to go',
                  style: AppFonts.sf(
                      size: 16,
                      weight: FontWeight.w600,
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

  /// "{routine} · {step note or time}".
  String get subtitle {
    final detail = step.note.isNotEmpty ? step.note : routine.time;
    return '${routine.name} · $detail';
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active
              ? EveningCloseOutScreen._accent22
              : EveningCloseOutScreen._white08,
          borderRadius: BorderRadius.circular(14),
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
            const SizedBox(width: 14),
            // Icon tile.
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: EveningCloseOutScreen._white10,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: AppIcon(row.step.icon,
                  size: 15, color: EveningCloseOutScreen._white85),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.step.title,
                    style: AppFonts.sf(
                      size: 15,
                      weight: FontWeight.w600,
                      color: checked
                          ? EveningCloseOutScreen._white55
                          : EveningCloseOutScreen._white,
                      letterSpacing: -0.24,
                    ).copyWith(
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                      decorationColor: EveningCloseOutScreen._white55,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    row.subtitle,
                    style: AppFonts.sf(
                        size: 12,
                        color: EveningCloseOutScreen._white50,
                        letterSpacing: -0.08),
                  ),
                ],
              ),
            ),
            if (active) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: EveningCloseOutScreen._accent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('Now',
                    style: AppFonts.sf(
                        size: 11,
                        weight: FontWeight.w600,
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
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: EveningCloseOutScreen._white06,
        borderColor: const Color(0x40FFFFFF),
        radius: 14,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: child,
      ),
    );
  }
}

/// Paints a rounded rect with a fill + a dashed stroke. Flutter has no built-in
/// dashed border, so a small painter mirrors the prototype's dashed CSS edge.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.borderColor,
    required this.radius,
  });

  final Color color;
  final Color borderColor;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = color);

    final path = Path()..addRRect(rrect);
    final dash = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const dashWidth = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          dash,
        );
        distance += dashWidth + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.borderColor != borderColor ||
      old.radius != radius;
}
