import '../../models/models.dart';
import '../../util/dates.dart';

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

/// Email-sourced entries logged today are the ones Pal did for the user.
bool isDoneByPal(Entry e, DateTime now) =>
    e.source == EntrySource.email &&
    startOfDay(e.timestamp.toLocal()) == startOfDay(now.toLocal());

/// Today's date line, "MON 28 SEP · 9:30 AM".
String dateLine(DateTime now) {
  final weekday = kWeekdaysShort[now.weekday - 1];
  final month = kMonthsShort[now.month - 1];
  final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  return '${'$weekday ${now.day} $month'.toUpperCase()} · '
      '$hour12:$minute ${now.hour < 12 ? 'AM' : 'PM'}';
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
