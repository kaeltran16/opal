import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analysis/area_state.dart';
import '../screens/today/day_plan.dart';
import '../services/pal/pal_service.dart';
import 'mood_controller.dart';
import 'nutrition_controller.dart';
import 'plan_session_controller.dart';
import 'providers.dart';
import 'rituals_controller.dart';
import 'today_controller.dart';
import 'weekly_plan_controller.dart';

part 'pal_agenda_controller.g.dart';

/// The Pal Home hub payload (proposals to approve, autopilot list, memory,
/// streak) from the `/agenda` seam. One-shot, not a stream — it's fetched when
/// the hub opens, not on every entry edit.
///
/// A failed fetch is left as an error, not an empty agenda: Today reads the
/// error as Pal being offline and falls back to the clock. A failed refresh
/// keeps the last proposals as the error's value, so callers read
/// `.value ?? const PalAgenda()`.
///
/// No retry: a failure held as loading reads as online on Today. Pull to
/// refresh and resume build it again.
///
/// A plain rebuild (first open, resume) may serve the service's cached reply
/// for the day; [PalAgendaRefresh.fetchFresh] makes the next one fetch past it.
@Riverpod(retry: noRetry)
Future<PalAgenda> palAgenda(Ref ref) async {
  final fresh = ref.read(palAgendaRefreshProvider)._take();
  final pal = ref.watch(palServiceProvider);
  return pal.agenda(plan: await _planFacts(ref), fresh: fresh);
}

/// Refetches [palAgenda] past the cache, for when the cached reply is known
/// stale: pull to refresh, a finished ritual.
class PalAgendaRefresh {
  PalAgendaRefresh(this._ref);
  final Ref _ref;
  // a plain field, not provider state: the build it triggers clears it, and a
  // provider may not change another's state while building.
  bool _pending = false;

  void fetchFresh() {
    _pending = true;
    _ref.invalidate(palAgendaProvider);
  }

  bool _take() {
    final pending = _pending;
    _pending = false;
    return pending;
  }
}

@Riverpod(keepAlive: true)
PalAgendaRefresh palAgendaRefresh(Ref ref) => PalAgendaRefresh(ref);

/// The day's open local items, for Pal to word a line about each. Read, not
/// watched, so logging a step does not call the model again; the line's key
/// goes stale instead and Today shows the item's own sentence.
Future<List<PlanFact>> _planFacts(Ref ref) async {
  try {
    final now = clock.now();
    final session = ref.read(planSessionControllerProvider);
    final (rituals, week, mood, nutrition, today) = await (
      _readOnce(ref, ritualsControllerProvider.future),
      _readOnce(ref, weeklyPlanControllerProvider.future),
      _readOnce(ref, moodControllerProvider.future),
      _readOnce(ref, nutritionControllerProvider.future),
      _readOnce(ref, todayStateProvider.future),
    ).wait;
    final plan = buildDayPlan(
      agenda: const PalAgenda(),
      rituals: rituals,
      workout: week.today,
      lastCheckin: mood.lastCheckin,
      meals: nutrition.meals,
      now: now,
    );
    return plan.planFacts(session, now, LeadRules(care: careAreas(today.glance, now)));
  } catch (e) {
    // the agenda still loads; Today shows each item's own sentence.
    debugPrint("pal agenda: couldn't read the day's plan: $e");
    return const [];
  }
}

/// [future]'s value, kept alive until it settles: an auto-dispose provider
/// read with no listener is disposed while still loading.
Future<T> _readOnce<T>(Ref ref, ProviderListenable<Future<T>> future) async {
  final sub = ref.listen(future, (_, _) {});
  try {
    return await sub.read();
  } finally {
    sub.close();
  }
}
