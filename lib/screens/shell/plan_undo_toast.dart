import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/plan_session_controller.dart';
import '../today/day_plan.dart';
import '../../theme/theme.dart';
import '../../widgets/failure_note.dart' show saveFailedCopy;
import '../../widgets/pal_ask_bar.dart';
import '../../widgets/press_scale.dart';

const Key planUndoToastKey = ValueKey('plan.undoToast');

/// How long a change's toast stays before it leaves on its own.
const Duration planToastDuration = Duration(seconds: 6);

const double _minTap = 44;
const double _border = 1;

/// Names the last change made in place on today's plan, with `Undo` when it
/// can be undone. Today and You both settle the plan, so the shell holds it.
class PlanUndoToast extends ConsumerStatefulWidget {
  const PlanUndoToast({super.key});

  @override
  ConsumerState<PlanUndoToast> createState() => _PlanUndoToastState();
}

class _PlanUndoToastState extends ConsumerState<PlanUndoToast> {
  Timer? _timer;

  PlanSessionController get _plan => ref.read(planSessionControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // a notice is a new instance per change, so each change restarts the timer.
    ref.listenManual(planSessionControllerProvider.select((s) => s.notice), (_, notice) {
      _timer?.cancel();
      if (notice != null) _timer = Timer(planToastDuration, _plan.dismissNotice);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _undo() async {
    try {
      await _plan.undo();
    } catch (e) {
      debugPrint("plan undo toast: couldn't undo: $e");
      if (mounted) _showUndoFailed();
    }
  }

  /// Floats just above the toast, which stays to offer Undo again.
  void _showUndoFailed() {
    final box = context.findRenderObject() as RenderBox?;
    final top = box == null ? 0.0 : box.localToGlobal(Offset.zero).dy;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(saveFailedCopy),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg,
          MediaQuery.sizeOf(context).height - top + Spacing.sm),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(planSessionControllerProvider.select((s) => s.notice));
    if (notice == null) return const SizedBox.shrink();
    return _Pill(key: planUndoToastKey, notice: notice, onUndo: notice.undoable ? _undo : null);
  }
}

/// The label, then `Undo` when [onUndo] is set. Announced as it appears.
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.notice, required this.onUndo});

  final PlanNotice notice;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final undo = onUndo;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: PalAskBar.height),
        padding: EdgeInsets.only(
            left: Spacing.xl, right: undo == null ? Spacing.xl : Spacing.xs),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.hair, width: _border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                child: Text(notice.label, style: AppType.subhead.copyWith(color: c.ink)),
              ),
            ),
            if (undo != null)
              // its own node, so the region reads the label and Undo stays a button.
              Semantics(
                container: true,
                child: PressScale(
                  onTap: undo,
                  semanticLabel: 'Undo',
                  child: Container(
                    constraints: const BoxConstraints(minHeight: _minTap, minWidth: _minTap),
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                    alignment: Alignment.center,
                    child: Text('Undo', style: AppType.headline.copyWith(color: c.ink)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
