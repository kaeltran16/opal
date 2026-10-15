import '../../controllers/rituals_controller.dart';
import '../../controllers/spending_controller.dart' show DetailTracker;
import '../../controllers/weekly_plan_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart' show PalAgenda, PalProposal;
import '../../util/dates.dart';
import 'today_logic.dart';

enum PlanKind { proposal, routine, workout, mood, meal, closeOut }

/// When the evening close-out is due, in minutes after midnight.
const int closeOutMinute = 21 * 60 + 30;

const String _notToday = 'Not today';
const String _notNow = 'Not now';
const String _start = 'Start';

/// One thing in the day: something to do, or something already done.
class PlanItem {
  const PlanItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.icon,
    this.minuteOfDay,
    this.detail,
    this.said,
    this.actionLabel = '',
    this.skipLabel = _notToday,
    this.done = false,
    this.ref,
    this.area,
  });

  final String id;
  final PlanKind kind;
  final String title;

  /// An `AppIcon` name.
  final String icon;

  /// When it is due, in minutes after midnight. Null when it has no time.
  final int? minuteOfDay;
  final String? detail;

  /// Pal's sentence for the item, the lead when there is no brief.
  final String? said;
  final String actionLabel;
  final String skipLabel;
  final bool done;

  /// The proposal or routine id the screen needs to act.
  final String? ref;

  /// The area a Needs care state can force this item to lead for.
  final DetailTracker? area;

  /// The card's when line: "At 9:30 PM" or "Any time", then the detail.
  String get whenLabel {
    final minute = minuteOfDay;
    final when = minute == null ? 'Any time' : 'At ${clockLabel(minute)}';
    return detail == null ? when : '$when · $detail';
  }
}

/// What the user did with the plan this session. In [settled], true is done
/// and false is skipped.
class PlanSession {
  const PlanSession({
    this.settled = const {},
    this.history = const [],
    this.selected,
  });

  final Map<String, bool> settled;
  final List<String> history;
  final String? selected;

  PlanSession settle(String id, {required bool done}) => PlanSession(
        settled: {...settled, id: done},
        history: [...history, id],
      );

  PlanSession undo() {
    if (history.isEmpty) return this;
    final last = history.last;
    return PlanSession(
      settled: {...settled}..remove(last),
      history: history.sublist(0, history.length - 1),
      selected: last,
    );
  }

  PlanSession select(String id) =>
      PlanSession(settled: settled, history: history, selected: id);

  bool get canUndo => history.isNotEmpty;
}

/// What decides the lead beyond the clock. The default is the clock alone.
class LeadRules {
  const LeadRules({this.palOnline = false, this.care = const []});

  /// Whether Pal's proposals lead, in the order Pal sent them.
  final bool palOnline;

  /// The areas in Needs care, in rule order (Money, Move, Routines).
  final List<DetailTracker> care;
}

/// The day as one list: Today's action card and timeline both read it.
class DayPlan {
  const DayPlan(this.items);

  final List<PlanItem> items;

  /// What is still to do, in lead order: items forced by a Needs care area,
  /// then Pal's proposals when Pal is online, then the clock (overdue timed
  /// items, then untimed, then upcoming).
  List<PlanItem> open(PlanSession session, DateTime now,
      [LeadRules rules = const LeadRules()]) {
    final clock = _clockOrder(session, now);
    final lead = <PlanItem>{
      for (final area in rules.care) ?_careLead(area, clock),
      if (rules.palOnline) ...clock.where((i) => i.kind == PlanKind.proposal),
    };
    return [...lead, ...clock.where((i) => !lead.contains(i))];
  }

  List<PlanItem> _clockOrder(PlanSession session, DateTime now) {
    final nowMinute = now.hour * 60 + now.minute;
    final pending = items
        .where((i) => !i.done && !session.settled.containsKey(i.id))
        .toList();
    bool timed(PlanItem i) => i.minuteOfDay != null;
    bool passed(PlanItem i) => timed(i) && i.minuteOfDay! <= nowMinute;
    return [
      ..._byMinute(pending.where(passed)),
      ...pending.where((i) => !timed(i)),
      ..._byMinute(pending.where((i) => timed(i) && !passed(i))),
    ];
  }

  /// The open item a Needs care area forces to lead, or null when it has none.
  PlanItem? _careLead(DetailTracker area, List<PlanItem> open) {
    final candidates = open.where((i) => i.area == area);
    return switch (area) {
      DetailTracker.money =>
        candidates.where((i) => i.kind == PlanKind.proposal).firstOrNull,
      DetailTracker.move =>
        candidates.where((i) => i.kind == PlanKind.workout).firstOrNull,
      DetailTracker.rituals => _timeOrder(
          candidates.where((i) => i.kind == PlanKind.routine || i.kind == PlanKind.closeOut),
          untimedFirst: false,
        ).firstOrNull,
    };
  }

  /// The lead Pal's order gives, whatever the user tapped.
  PlanItem? palPick(PlanSession session, DateTime now,
          [LeadRules rules = const LeadRules()]) =>
      open(session, now, rules).firstOrNull;

  PlanItem? current(PlanSession session, DateTime now,
      [LeadRules rules = const LeadRules()]) {
    final items = open(session, now, rules);
    for (final i in items) {
      if (i.id == session.selected) return i;
    }
    return items.firstOrNull;
  }

  bool isPalPick(PlanSession session, DateTime now,
      [LeadRules rules = const LeadRules()]) {
    final cur = current(session, now, rules);
    return cur != null && cur == palPick(session, now, rules);
  }

  /// The open items besides the lead, untimed first, then by time.
  List<PlanItem> later(PlanSession session, DateTime now,
      [LeadRules rules = const LeadRules()]) {
    final cur = current(session, now, rules);
    return _timeOrder(open(session, now, rules).where((i) => i != cur),
        untimedFirst: true);
  }

  /// [from] by minute, untimed items first or last; ties keep build order.
  List<PlanItem> _timeOrder(Iterable<PlanItem> from, {required bool untimedFirst}) {
    final picked = from.toSet();
    final inBuildOrder = items.where(picked.contains);
    final untimed = inBuildOrder.where((i) => i.minuteOfDay == null);
    final timed = _byMinute(inBuildOrder.where((i) => i.minuteOfDay != null));
    return untimedFirst ? [...untimed, ...timed] : [...timed, ...untimed];
  }
}

/// "9:00 PM" for minutes after midnight.
String clockLabel(int minuteOfDay) {
  final hour = minuteOfDay ~/ 60 % 24;
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$hour12:$minute ${hour < 12 ? 'AM' : 'PM'}';
}

// List.sort is not stable, so ties keep their build order by index.
List<PlanItem> _byMinute(Iterable<PlanItem> items) {
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final byMinute = a.$2.minuteOfDay!.compareTo(b.$2.minuteOfDay!);
      return byMinute != 0 ? byMinute : a.$1.compareTo(b.$1);
    });
  return [for (final (_, item) in indexed) item];
}

/// Pal's proposal [p] as a plan item. A close-out proposal acts as the
/// close-out row does: it opens the close-out.
PlanItem proposalItem(PalProposal p) => PlanItem(
      id: 'proposal:${p.id}',
      kind: p.navigatesToCloseOut ? PlanKind.closeOut : PlanKind.proposal,
      title: p.title,
      icon: p.icon,
      said: p.body,
      actionLabel: p.approveLabel,
      skipLabel: _notNow,
      ref: p.id,
      area: DetailTracker.values.asNameMap()[p.colorToken],
    );

/// Every proposal in [agenda] not yet approved or put off in [session], in
/// the order Pal sent them. Unlike the day plan, nothing is folded or hidden.
List<PlanItem> pendingProposals(PalAgenda agenda, PlanSession session) => [
      for (final p in agenda.proposals)
        if (!session.settled.containsKey(proposalItem(p).id)) proposalItem(p),
    ];

bool _isToday(DateTime at, DateTime now) =>
    startOfDay(at.toLocal()) == startOfDay(now.toLocal());

/// Builds the day from local data and Pal's pending proposals. Nothing here
/// calls the model, so the plan stands when Pal is offline. The evening
/// routine is the close-out row, and Pal's close-out proposal only lends it
/// a sentence. Beside the close-out row, Pal's add-ritual proposals are left
/// out; without one they are ordinary proposal rows.
DayPlan buildDayPlan({
  required PalAgenda agenda,
  required RitualsState? rituals,
  required WeekPlanDay? workout,
  required MoodCheckin? lastCheckin,
  required List<NutritionMeal> meals,
  required DateTime now,
}) {
  final routines = rituals?.routines ?? const <RitualRoutine>[];
  final evening = rituals?.evening;
  final closeOut = evening != null && evening.steps.isNotEmpty ? evening : null;
  final closeOutSaid = agenda.proposals.where((p) => p.navigatesToCloseOut).firstOrNull?.body;
  final checkedIn = lastCheckin != null && _isToday(lastCheckin.timestamp, now);
  final ateToday = meals.any((m) => _isToday(m.timestamp, now));

  return DayPlan([
    for (final p in agenda.proposals)
      if (!p.navigatesToCloseOut && !(closeOut != null && p.addsRitual))
        proposalItem(p),
    for (final r in trackedRoutines(routines))
      if (r.id != eveningRoutineId)
        PlanItem(
          id: 'routine:${r.id}',
          kind: PlanKind.routine,
          title: r.name,
          icon: r.icon,
          minuteOfDay: routineMinute(r.time),
          said: r.blurb,
          actionLabel: _start,
          done: rituals!.isComplete(r),
          ref: r.id,
          area: DetailTracker.rituals,
        ),
    if (workout != null && !workout.isRest)
      PlanItem(
        id: 'workout',
        kind: PlanKind.workout,
        title: workout.routine ?? workout.type,
        icon: workout.icon,
        detail: workout.est == null ? null : '${workout.est} min',
        actionLabel: _start,
        done: workout.done,
        area: DetailTracker.move,
      ),
    PlanItem(
      id: 'mood',
      kind: PlanKind.mood,
      title: 'Mood check-in',
      icon: 'heart.fill',
      actionLabel: 'Check in',
      done: checkedIn,
    ),
    if (!ateToday)
      const PlanItem(
        id: 'meal',
        kind: PlanKind.meal,
        title: 'Log a meal',
        icon: 'fork.knife',
        actionLabel: 'Log a meal',
      ),
    if (closeOut != null)
      PlanItem(
        id: 'closeOut',
        kind: PlanKind.closeOut,
        title: 'Close-out',
        icon: 'moon.stars.fill',
        minuteOfDay: routineMinute(closeOut.time) ?? closeOutMinute,
        said: closeOutSaid ?? closeOut.blurb,
        actionLabel: _start,
        done: rituals!.isComplete(closeOut),
        ref: closeOut.id,
        area: DetailTracker.rituals,
      ),
  ]);
}
