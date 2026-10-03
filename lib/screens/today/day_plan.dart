import '../../controllers/rituals_controller.dart';
import '../../controllers/weekly_plan_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart' show PalAgenda;
import '../../util/dates.dart';
import '../../util/entry_glyph.dart';
import '../../util/mood_scale.dart' show hm;
import 'today_logic.dart';

enum PlanKind { proposal, routine, workout, mood, meal, closeOut, sleep, receipt }

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
  });

  final String id;
  final PlanKind kind;
  final String title;

  /// An `AppIcon` name.
  final String icon;

  /// When it is due (or, for a done row, when it happened), in minutes after
  /// midnight. Null when it has no time.
  final int? minuteOfDay;
  final String? detail;

  /// Pal's sentence for the item, the lead when there is no brief.
  final String? said;
  final String actionLabel;
  final String skipLabel;
  final bool done;

  /// The proposal, routine or entry id the screen needs to act.
  final String? ref;

  /// Whether the user can act on it. A logged meal is a record, not a task.
  bool get actionable => switch (kind) {
        PlanKind.proposal ||
        PlanKind.routine ||
        PlanKind.workout ||
        PlanKind.mood ||
        PlanKind.closeOut =>
          true,
        PlanKind.meal => !done,
        PlanKind.sleep || PlanKind.receipt => false,
      };
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

/// The day as one list: Today's action card and timeline both read it.
class DayPlan {
  const DayPlan(this.items);

  final List<PlanItem> items;

  /// What is still to do: overdue timed items, then untimed, then upcoming.
  List<PlanItem> open(PlanSession session, DateTime now) {
    final nowMinute = now.hour * 60 + now.minute;
    final pending = items
        .where((i) => i.actionable && !i.done && !session.settled.containsKey(i.id))
        .toList();
    bool timed(PlanItem i) => i.minuteOfDay != null;
    bool passed(PlanItem i) => timed(i) && i.minuteOfDay! <= nowMinute;
    return [
      ..._byMinute(pending.where(passed)),
      ...pending.where((i) => !timed(i)),
      ..._byMinute(pending.where((i) => timed(i) && !passed(i))),
    ];
  }

  PlanItem? current(PlanSession session, DateTime now) {
    final items = open(session, now);
    for (final i in items) {
      if (i.id == session.selected) return i;
    }
    return items.isEmpty ? null : items.first;
  }

  List<PlanItem> later(PlanSession session, DateTime now) {
    final cur = current(session, now);
    return [
      for (final i in open(session, now))
        if (i != cur) i,
    ];
  }

  /// Done and informational rows, newest first; rows without a time last.
  List<PlanItem> get doneRows {
    final rows = items.where((i) => i.done || !i.actionable).toList();
    return [
      ..._byMinute(rows.where((i) => i.minuteOfDay != null)).reversed,
      ...rows.where((i) => i.minuteOfDay == null),
    ];
  }

  /// A skip settles an item without counting it.
  int doneCount(PlanSession session) => items
      .where((i) => i.actionable && (i.done || session.settled[i.id] == true))
      .length;

  int get total => items.where((i) => i.actionable).length;

  String whenLabel(PlanItem item, PlanSession session, DateTime now) {
    final first = open(session, now).firstOrNull;
    final minute = item.minuteOfDay;
    final when = item == first
        ? 'Now'
        : minute != null
            ? 'At ${clockLabel(minute)}'
            : 'Any time';
    return item.detail == null ? when : '$when · ${item.detail}';
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

bool _isToday(DateTime at, DateTime now) =>
    startOfDay(at.toLocal()) == startOfDay(now.toLocal());

int _minuteOf(DateTime at) {
  final local = at.toLocal();
  return local.hour * 60 + local.minute;
}

/// Builds the day from local data and Pal's pending proposals. Nothing here
/// calls the model, so the plan stands when Pal is offline.
DayPlan buildDayPlan({
  required PalAgenda agenda,
  required RitualsState? rituals,
  required WeekPlanDay? workout,
  required SleepNight? lastNight,
  required MoodCheckin? lastCheckin,
  required List<NutritionMeal> meals,
  required List<Entry> entries,
  required DateTime now,
}) {
  final routines = rituals?.routines ?? const <RitualRoutine>[];
  final checkedIn = lastCheckin != null && _isToday(lastCheckin.timestamp, now);
  final mealsToday = meals.where((m) => _isToday(m.timestamp, now)).toList();

  return DayPlan([
    for (final p in agenda.proposals)
      PlanItem(
        id: 'proposal:${p.id}',
        kind: PlanKind.proposal,
        title: p.title,
        icon: p.icon,
        said: p.body,
        actionLabel: p.approveLabel,
        skipLabel: _notNow,
        ref: p.id,
      ),
    for (final r in routines)
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
      ),
    PlanItem(
      id: 'mood',
      kind: PlanKind.mood,
      title: 'Mood check-in',
      icon: 'heart.fill',
      minuteOfDay: checkedIn ? _minuteOf(lastCheckin.timestamp) : null,
      actionLabel: 'Check in',
      done: checkedIn,
      ref: checkedIn ? lastCheckin.id : null,
    ),
    if (mealsToday.isEmpty)
      const PlanItem(
        id: 'meal',
        kind: PlanKind.meal,
        title: 'Log a meal',
        icon: 'fork.knife',
        actionLabel: 'Log a meal',
      ),
    for (final m in mealsToday)
      PlanItem(
        id: 'meal:${m.id}',
        kind: PlanKind.meal,
        title: m.name,
        icon: m.icon,
        minuteOfDay: _minuteOf(m.timestamp),
        done: true,
        ref: m.id,
      ),
    if (routines.isNotEmpty)
      const PlanItem(
        id: 'closeOut',
        kind: PlanKind.closeOut,
        title: 'Close-out',
        icon: 'moon.stars.fill',
        minuteOfDay: closeOutMinute,
        actionLabel: _start,
      ),
    // a night is dated by the morning the user woke on.
    if (lastNight != null && startOfDay(lastNight.night) == startOfDay(now))
      PlanItem(
        id: 'sleep',
        kind: PlanKind.sleep,
        title: 'Sleep',
        icon: 'moon.stars.fill',
        detail: hm(lastNight.asleepMinutes),
        done: true,
        ref: lastNight.id,
      ),
    for (final e in entries)
      if (isDoneByPal(e, now))
        PlanItem(
          id: 'receipt:${e.id}',
          kind: PlanKind.receipt,
          title: e.title,
          icon: entryGlyph(e.type, category: e.category, isWorkout: e.workoutId != null),
          minuteOfDay: _minuteOf(e.timestamp),
          done: true,
          ref: e.id,
        ),
  ]);
}
