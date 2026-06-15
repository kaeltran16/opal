import 'package:flutter_test/flutter_test.dart';
import 'package:opal/util/dates.dart';

void main() {
  group('startOfDay', () {
    test('strips the time component', () {
      expect(startOfDay(DateTime(2026, 6, 10, 14, 37, 9)), DateTime(2026, 6, 10));
    });
  });

  group('startOfWeek', () {
    test('a midweek day resolves to that week\'s Monday at midnight', () {
      // 2026-06-10 is a Wednesday; its Monday is 2026-06-08.
      expect(startOfWeek(DateTime(2026, 6, 10, 9)), DateTime(2026, 6, 8));
    });

    test('a Monday resolves to itself at midnight', () {
      expect(startOfWeek(DateTime(2026, 6, 8, 23, 59)), DateTime(2026, 6, 8));
    });

    test('a Sunday resolves back to the preceding Monday', () {
      // 2026-06-14 is a Sunday; its Monday is 2026-06-08 (6 days earlier).
      expect(startOfWeek(DateTime(2026, 6, 14)), DateTime(2026, 6, 8));
    });
  });

  group('name tables', () {
    test('are Monday-/January-first and complete', () {
      expect(kWeekdays.length, 7);
      expect(kWeekdays.first, 'Monday');
      expect(kWeekdays.last, 'Sunday');
      expect(kWeekdaysShort[DateTime.wednesday - 1], 'Wed');
      expect(kWeekdayLetters.length, 7);
      expect(kMonths.length, 12);
      expect(kMonths[DateTime.june - 1], 'June');
      expect(kMonthsShort.length, 12);
      expect(kMonthsShort.first, 'Jan');
      expect(kMonthsShort.last, 'Dec');
    });
  });
}
