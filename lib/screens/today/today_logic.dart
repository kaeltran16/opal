import '../../util/dates.dart';

/// Today's facts from the local providers, never from the model. A zero
/// budget or goal means "not set".
class GlanceNumbers {
  const GlanceNumbers({
    required this.spent,
    required this.budget,
    required this.moveKcal,
    required this.moveGoal,
    required this.routinesDone,
    required this.routinesTotal,
    required this.hasRoutines,
  });

  final double spent, budget;
  final int moveKcal, moveGoal, routinesDone, routinesTotal;

  /// Whether any routine exists, with steps or not.
  final bool hasRoutines;
}

/// Today's date line, "MON 28 SEP · 9:30 AM".
String dateLine(DateTime now) {
  final weekday = kWeekdaysShort[now.weekday - 1];
  final month = kMonthsShort[now.month - 1];
  return '${'$weekday ${now.day} $month'.toUpperCase()} · ${clockTime(now)}';
}

/// How long a passed timed item keeps leading. Past this it is missed: it
/// stays open but goes to the end, so a 7 AM routine does not lead all evening.
/// Today's plan and the Routines area both order by it.
const int overdueLeadMinutes = 4 * 60;

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
