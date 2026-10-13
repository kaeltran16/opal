import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/workout_session_controller.dart';
import '../../router.dart';

/// Opens the workout session for [routineId], or resumes the one already
/// running. The single home of the one-session-at-a-time rule: every Start,
/// Resume and Start workout goes through here.
void openWorkoutSession(
  BuildContext context,
  WidgetRef ref,
  String routineId,
) {
  final running = ref.read(runningSessionProvider);
  final id = running ?? routineId;
  if (running == null) ref.read(runningSessionProvider.notifier).start(id);
  context.pushNamed(
    AppRoute.activeSession.name,
    pathParameters: {'routineId': id},
  );
}
