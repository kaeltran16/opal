import '../../controllers/rituals_controller.dart';
import '../../controllers/spending_controller.dart' show DetailTracker;
import '../../controllers/weekly_plan_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart' show PalAgenda, PalProposal, PlanFact;
import '../../util/dates.dart';
import '../../util/mood_scale.dart' show moodWord;
import 'today_logic.dart';

enum PlanKind { proposal, routine, workout, mood, meal, closeOut }

/// When the evening close-out is due, in minutes after midnight.
const int closeOutMinute = 21 * 60 + 30;

/// How long a passed timed item keeps leading. Past this it is missed: it
/// stays open but goes to the end, so a 7 AM routine does not lead all evening.
const int overdueLeadMinutes = 4 * 60;
const String _overdueLeadSpan = 'four hours';

const String _notToday = 'Not today';
const String _notNow = 'Not now';
const String _start = 'Start';
const String _restLine = 'Nothing is left. Rest up.';
const String _palSuggests = 'Pal suggests';
const String _missedLabel = 'Missed';
const String _putOff = 'Put off until tomorrow';
const String _done = 'Done';
const String _bringBack = 'Bring back';
const String _checkInAgain = 'Check in again';
const String _anyTime = 'any time';

/// One thing in the day: something to do, or something already done.
class PlanItem {
  const PlanItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.icon,
    this.minuteOfDay,
    this.detail,
    this.doneDetail,
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

  /// What the item reads once done, when that is more than `Done`.
  final String? doneDetail;

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

enum PlanRowState { open, missed, done, putOff }

/// One item in Today's list of the whole day, as it stands now.
class PlanRow {
  const PlanRow({required this.item, required this.state});

  final PlanItem item;
  final PlanRowState state;

  /// The line under the title.
  String? get detail => switch (state) {
        PlanRowState.open => item.kind == PlanKind.proposal ? _palSuggests : item.detail,
        PlanRowState.missed => item.detail == null ? _missedLabel : '$_missedLabel · ${item.detail}',
        PlanRowState.putOff => _putOff,
        PlanRowState.done => item.doneDetail ?? _done,
      };

  /// What a tap does, or null when the row is inert.
  String? get verb => switch (state) {
        PlanRowState.open || PlanRowState.missed => item.actionLabel,
        PlanRowState.putOff => _bringBack,
        PlanRowState.done => item.kind == PlanKind.mood ? _checkInAgain : null,
      };

  bool get tappable => verb != null;

  String get semanticLabel {
    final d = detail;
    final v = verb;
    final what = d == null ? item.title : '${item.title}, $d';
    return v == null ? what : '$v: $what';
  }
}

/// One change made in place on the plan, named for the toast that undoes it.
class PlanChange {
  const PlanChange({required this.id, required this.label});

  final String id, label;
}

/// What the toast says about the last change, and whether it offers Undo.
class PlanNotice {
  const PlanNotice({required this.label, required this.undoable});

  final String label;
  final bool undoable;
}

/// What the user did with the plan on [day]. In [settled], true is done and
/// false is put off.
class PlanSession {
  const PlanSession({
    required this.day,
    this.settled = const {},
    this.history = const [],
    this.notice,
  });

  /// The start of the local day the session belongs to.
  final DateTime day;
  final Map<String, bool> settled;
  final List<PlanChange> history;

  /// A new instance per change, so the toast restarts.
  final PlanNotice? notice;

  PlanSession settle(String id, {required bool done, required String label}) =>
      PlanSession(
        day: day,
        settled: {...settled, id: done},
        history: [...history, PlanChange(id: id, label: label)],
        notice: PlanNotice(label: label, undoable: true),
      );

  /// Reverses the last change and clears the notice.
  PlanSession undo() {
    if (history.isEmpty) return this;
    return PlanSession(
      day: day,
      settled: {...settled}..remove(history.last.id),
      history: history.sublist(0, history.length - 1),
    );
  }

  /// Reopens [id]. Its change leaves the history, so a later undo does not
  /// reach past it, and the notice offers no Undo.
  PlanSession bringBack(String id, {required String label}) => PlanSession(
        day: day,
        settled: {...settled}..remove(id),
        history: [for (final c in history) if (c.id != id) c],
        notice: PlanNotice(label: label, undoable: false),
      );

  PlanSession dismissNotice() => PlanSession(day: day, settled: settled, history: history);

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
  /// then Pal's proposals when Pal is online, then the clock (timed items due
  /// in the last [overdueLeadMinutes], then untimed, then upcoming, then the
  /// missed ones).
  List<PlanItem> open(PlanSession session, DateTime now,
      [LeadRules rules = const LeadRules()]) {
    final clock = _clockOrder(session, now);
    final nowMinute = now.hour * 60 + now.minute;
    final lead = <PlanItem>{
      for (final area in rules.care) ?_careLead(area, clock, nowMinute),
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
    bool missed(PlanItem i) => _missed(i, nowMinute);
    return [
      ..._byMinute(pending.where((i) => passed(i) && !missed(i))),
      ...pending.where((i) => !timed(i)),
      ..._byMinute(pending.where((i) => timed(i) && !passed(i))),
      ..._byMinute(pending.where(missed)),
    ];
  }

  static bool _missed(PlanItem i, int nowMinute) =>
      i.minuteOfDay != null && nowMinute - i.minuteOfDay! > overdueLeadMinutes;

  /// The open item a Needs care area forces to lead, or null when it has none.
  PlanItem? _careLead(DetailTracker area, List<PlanItem> open, int nowMinute) {
    final candidates = open.where((i) => i.area == area);
    return switch (area) {
      DetailTracker.money =>
        candidates.where((i) => i.kind == PlanKind.proposal).firstOrNull,
      DetailTracker.move =>
        candidates.where((i) => i.kind == PlanKind.workout).firstOrNull,
      DetailTracker.rituals => _earliestRoutine(
          candidates.where((i) => i.kind == PlanKind.routine || i.kind == PlanKind.closeOut),
          nowMinute,
        ),
    };
  }

  /// The earliest routine still worth doing, untimed after timed, a missed
  /// one only when nothing else is open.
  PlanItem? _earliestRoutine(Iterable<PlanItem> routines, int nowMinute) => [
        ..._timeOrder(routines.where((i) => !_missed(i, nowMinute)), untimedFirst: false),
        ...routines.where((i) => _missed(i, nowMinute)),
      ].firstOrNull;

  /// Why [item] leads, by the same rules as [open], so Pal explains the
  /// order instead of guessing.
  String reasonFor(PlanItem item, PlanSession session, DateTime now,
      [LeadRules rules = const LeadRules()]) {
    final nowMinute = now.hour * 60 + now.minute;
    final clock = _clockOrder(session, now);
    final care = rules.care
        .where((area) => _careLead(area, clock, nowMinute) == item)
        .firstOrNull;
    return switch (item.minuteOfDay) {
      _ when care != null =>
        '${_areaNames[care]} needs care, and an area in Needs care always leads.',
      _ when rules.palOnline && item.kind == PlanKind.proposal =>
        "Pal proposed it, and Pal's proposals lead while Pal is online.",
      null => 'It has no set time, and nothing timed was due in the last $_overdueLeadSpan.',
      final m when m > nowMinute => 'It is the next thing on the clock, at ${clockLabel(m)}.',
      final m when _missed(item, nowMinute) =>
        'It was due at ${clockLabel(m)} and nothing else is open.',
      final m => 'It was due at ${clockLabel(m)}, under $_overdueLeadSpan ago, and is still open.',
    };
  }

  /// Why [item] leads and what else is open, for Pal's Why thread.
  String whyNote(PlanItem item, PlanSession session, DateTime now,
      [LeadRules rules = const LeadRules()]) {
    final nowMinute = now.hour * 60 + now.minute;
    final reason = reasonFor(item, session, now, rules);
    final rest = [
      for (final i in open(session, now, rules))
        if (i != item) '${i.title} (${_whenNote(i, nowMinute)})',
    ];
    return [
      'Today shows ${item.title} first. $reason',
      if (rest.isNotEmpty) 'Still open after it: ${rest.join(', ')}.',
      "Today's order: an area in Needs care, then Pal's proposals while Pal is "
          'online, then the clock: items due in the last $_overdueLeadSpan, untimed '
          'items, upcoming items, then missed ones.',
    ].join(' ');
  }

  static String _whenNote(PlanItem i, int nowMinute) => switch (i.minuteOfDay) {
        null => 'any time',
        final m when _missed(i, nowMinute) => 'missed, was at ${clockLabel(m)}',
        final m => 'at ${clockLabel(m)}',
      };

  static const _areaNames = {
    DetailTracker.money: 'Money',
    DetailTracker.move: 'Move',
    DetailTracker.rituals: 'Routines',
  };

  PlanItem? current(PlanSession session, DateTime now,
          [LeadRules rules = const LeadRules()]) =>
      open(session, now, rules).firstOrNull;

  /// The open items besides the lead, untimed first, then by time.
  List<PlanItem> later(PlanSession session, DateTime now,
      [LeadRules rules = const LeadRules()]) {
    final cur = current(session, now, rules);
    return _timeOrder(open(session, now, rules).where((i) => i != cur),
        untimedFirst: true);
  }

  /// Every item of the day, done and put off included: timed ones by minute,
  /// then untimed ones in build order.
  List<PlanRow> rows(PlanSession session, DateTime now) {
    final nowMinute = now.hour * 60 + now.minute;
    return [
      for (final i in _timeOrder(items, untimedFirst: false))
        PlanRow(item: i, state: switch (session.settled[i.id]) {
          _ when _isDone(i, session) => PlanRowState.done,
          false => PlanRowState.putOff,
          _ when _missed(i, nowMinute) => PlanRowState.missed,
          _ => PlanRowState.open,
        }),
    ];
  }

  /// How many of the day's items are done or approved, of all of them.
  ({int done, int total}) progress(PlanSession session) =>
      (done: items.where((i) => _isDone(i, session)).length, total: items.length);

  static bool _isDone(PlanItem i, PlanSession session) =>
      i.done || session.settled[i.id] == true;

  /// [item] as Pal's line call sees it. The key holds the status and the
  /// detail, so a line worded before a step was logged or the item was missed
  /// no longer matches.
  PlanFact factFor(PlanItem item, PlanSession session, DateTime now,
      [LeadRules rules = const LeadRules()]) {
    final nowMinute = now.hour * 60 + now.minute;
    final minute = item.minuteOfDay;
    final status = switch (minute) {
      null => PlanFact.anytime,
      _ when _missed(item, nowMinute) => PlanFact.missed,
      final m when m <= nowMinute => PlanFact.due,
      _ => PlanFact.upcoming,
    };
    return PlanFact(
      key: '${item.id}|$status|${item.detail ?? ''}',
      title: item.title,
      when: minute == null ? _anyTime : clockLabel(minute),
      status: status,
      steps: item.detail,
      why: reasonFor(item, session, now, rules),
    );
  }

  /// The open local items as facts, in lead order. Proposals carry Pal's own
  /// body, so they need no line.
  List<PlanFact> planFacts(PlanSession session, DateTime now,
          [LeadRules rules = const LeadRules()]) =>
      [
        for (final i in open(session, now, rules))
          if (i.kind != PlanKind.proposal) factFor(i, session, now, rules),
      ];

  /// [from] by minute, untimed items first or last; ties keep build order.
  List<PlanItem> _timeOrder(Iterable<PlanItem> from, {required bool untimedFirst}) {
    final picked = from.toSet();
    final inBuildOrder = items.where(picked.contains);
    final untimed = inBuildOrder.where((i) => i.minuteOfDay == null);
    final timed = _byMinute(inBuildOrder.where((i) => i.minuteOfDay != null));
    return untimedFirst ? [...untimed, ...timed] : [...timed, ...untimed];
  }
}

/// The sentence under Today's lead. Pal's line shows only while Pal is online
/// and [leadKey] still matches the facts it was worded from; otherwise the
/// item's own sentence, which needs no model.
String leadLine({
  required PlanItem? lead,
  required PalAgenda agenda,
  required bool online,
  required String? leadKey,
}) {
  if (lead == null) return _restLine;
  final palLine = online && lead.kind != PlanKind.proposal ? agenda.lines[leadKey] : null;
  return palLine ?? lead.said ?? lead.title;
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
      doneDetail: p.doneLabel,
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

/// "3 steps" before any is done, then "2 of 4 steps".
String _stepsDetail(int done, int total) => switch (done) {
      0 when total == 1 => '1 step',
      0 => '$total steps',
      _ => '$done of $total steps',
    };

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
          detail: _stepsDetail(rituals!.doneCount(r.id), r.steps.length),
          said: r.blurb,
          actionLabel: _start,
          done: rituals.isComplete(r),
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
      doneDetail: checkedIn ? moodWord(lastCheckin.pleasantness) : null,
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
        detail: _stepsDetail(rituals!.doneCount(closeOut.id), closeOut.steps.length),
        said: closeOutSaid ?? closeOut.blurb,
        actionLabel: _start,
        done: rituals.isComplete(closeOut),
        ref: closeOut.id,
        area: DetailTracker.rituals,
      ),
  ]);
}
