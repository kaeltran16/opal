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
