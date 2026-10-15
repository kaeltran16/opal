// Calendar helpers — the single source for week/day boundaries and the
// weekday/month name tables that were duplicated across controllers and
// screens. All name lists are Monday-/January-first; index with
// `weekday - 1` and `month - 1`.

/// Midnight (00:00) on the calendar day of [d].
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Midnight on the Monday of [d]'s week.
DateTime startOfWeek(DateTime d) {
  final day = startOfDay(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Full weekday names ('Monday' … 'Sunday').
const kWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Three-letter weekday abbreviations ('Mon' … 'Sun').
const kWeekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Single-letter weekday labels ('M' … 'S'), Monday-first.
const kWeekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Full month names ('January' … 'December').
const kMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Three-letter month abbreviations ('Jan' … 'Dec').
const kMonthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Relative-date label for a session start: "Today", "Yesterday", or "Nd ago"
/// (calendar-day difference, not 24h windows). Pure so it is unit-testable.
String relativeDateLabel(DateTime startedAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(startedAt.year, startedAt.month, startedAt.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '${days}d ago';
}

/// "9:00 PM" for minutes after midnight: the app's one clock format, used on
/// screen and in what Pal reads so its replies quote times the way the app does.
String clockLabel(int minuteOfDay) {
  final hour = minuteOfDay ~/ 60 % 24;
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$hour12:$minute ${hour < 12 ? 'AM' : 'PM'}';
}

/// [clockLabel] for the time of day of [t].
String clockTime(DateTime t) => clockLabel(t.hour * 60 + t.minute);
