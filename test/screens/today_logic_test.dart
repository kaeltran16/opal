import 'package:flutter_test/flutter_test.dart';
import 'package:opal/screens/today/today_logic.dart';

void main() {
  group('dateLine', () {
    test('reads weekday, day, month and a 12-hour time', () {
      expect(dateLine(DateTime(2026, 9, 28, 9, 30)), 'MON 28 SEP · 9:30 AM');
      expect(dateLine(DateTime(2026, 10, 3, 18, 5)), 'SAT 3 OCT · 6:05 PM');
    });

    test('midnight and noon read as 12', () {
      expect(dateLine(DateTime(2026, 9, 28)), 'MON 28 SEP · 12:00 AM');
      expect(dateLine(DateTime(2026, 9, 28, 12)), 'MON 28 SEP · 12:00 PM');
    });
  });

  group('routineMinute', () {
    test('parses 12-hour display times', () {
      expect(routineMinute('7:00 AM'), 420);
      expect(routineMinute('1:00 PM'), 780);
      expect(routineMinute('9:30 pm'), 1290);
      expect(routineMinute('12:15 AM'), 15);
      expect(routineMinute('12:00 PM'), 720);
    });

    test('returns null for anything else', () {
      expect(routineMinute('Evening'), isNull);
      expect(routineMinute(''), isNull);
    });
  });
}
