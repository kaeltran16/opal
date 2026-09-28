import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../util/dates.dart';

/// The areas Today's "Your day" section shows, in their fallback order.
enum TodayArea { routines, sleep, mood, money, move, nutrition }

/// Where an area stands today, used to order the "Your day" cards.
class AreaStatus {
  const AreaStatus({required this.area, required this.complete, required this.minuteOfDay});

  final TodayArea area;
  final bool complete;

  /// When the area is naturally due, in minutes after midnight (sleep 0, mood 480, ...).
  final int minuteOfDay;
}

/// Incomplete first, then by [AreaStatus.minuteOfDay], then by enum index, so
/// the order is stable and needs no model call.
List<TodayArea> orderAreas(List<AreaStatus> statuses) {
  final sorted = [...statuses]..sort((a, b) {
      if (a.complete != b.complete) return a.complete ? 1 : -1;
      final byMinute = a.minuteOfDay.compareTo(b.minuteOfDay);
      if (byMinute != 0) return byMinute;
      return a.area.index.compareTo(b.area.index);
    });
  return [for (final s in sorted) s.area];
}

/// Today's facts from the local providers, never from the model. A zero
/// budget or goal means "not set"; the left-over getters never go negative.
class GlanceNumbers {
  const GlanceNumbers({
    required this.spent,
    required this.budget,
    required this.moveKcal,
    required this.moveGoal,
    required this.routinesDone,
    required this.routinesTotal,
  });

  final double spent, budget;
  final int moveKcal, moveGoal, routinesDone, routinesTotal;

  double get moneyLeft => (budget - spent).clamp(0.0, double.infinity);
  int get kcalToGo => (moveGoal - moveKcal).clamp(0, 1 << 31);
  int get routinesLeft => (routinesTotal - routinesDone).clamp(0, 1 << 31);
}

enum BriefMode { brief, fallback }

/// Brief iff a non-empty headline is available, including a previous value
/// carried through a reload.
BriefMode briefMode(AsyncValue<String?> brief) =>
    (brief.value?.isNotEmpty ?? false) ? BriefMode.brief : BriefMode.fallback;

/// Email-sourced entries logged today are the ones Pal did for the user.
bool isDoneByPal(Entry e, DateTime now) =>
    e.source == EntrySource.email &&
    startOfDay(e.timestamp.toLocal()) == startOfDay(now.toLocal());

/// The greeting for [now]: morning before noon, afternoon before 18:00.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// When the evening routines are due, used when no routine is left or its
/// time doesn't parse.
const int eveningMinute = 21 * 60;

/// Minutes after midnight for a routine's display time ("7:00 AM",
/// "9:30 PM"), or null when it doesn't parse.
int? routineMinute(String time) {
  final m = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])\s*$').firstMatch(time);
  if (m == null) return null;
  final hour = int.parse(m.group(1)!) % 12;
  final pm = m.group(3)!.toLowerCase() == 'pm';
  return (pm ? hour + 12 : hour) * 60 + int.parse(m.group(2)!);
}
