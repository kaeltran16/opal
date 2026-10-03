import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/today/today_logic.dart';

Entry _entry(DateTime at, EntrySource source) => Entry(
      id: 'e',
      timestamp: at,
      type: EntryType.money,
      title: 'Coffee',
      amount: -4,
      source: source,
    );

void main() {
  group('GlanceNumbers', () {
    GlanceNumbers numbers({
      double spent = 0,
      double budget = 0,
      int moveKcal = 0,
      int moveGoal = 0,
      int routinesDone = 0,
      int routinesTotal = 0,
    }) =>
        GlanceNumbers(
          spent: spent,
          budget: budget,
          moveKcal: moveKcal,
          moveGoal: moveGoal,
          routinesDone: routinesDone,
          routinesTotal: routinesTotal,
        );

    test('moneyLeft never goes negative when over budget', () {
      expect(numbers(spent: 70, budget: 60).moneyLeft, 0);
    });

    test('moneyLeft is 0 with no budget', () {
      expect(numbers(spent: 38).moneyLeft, 0);
    });

    test('moneyLeft is the remaining budget', () {
      expect(numbers(spent: 38, budget: 60).moneyLeft, 22);
    });

    test('kcalToGo is 0 with no move goal and past the goal', () {
      expect(numbers(moveKcal: 412).kcalToGo, 0);
      expect(numbers(moveKcal: 612, moveGoal: 500).kcalToGo, 0);
      expect(numbers(moveKcal: 412, moveGoal: 500).kcalToGo, 88);
    });

    test('routinesLeft is 0 with no routines', () {
      expect(numbers().routinesLeft, 0);
      expect(numbers(routinesDone: 4, routinesTotal: 5).routinesLeft, 1);
    });
  });

  group('isDoneByPal', () {
    final now = DateTime(2026, 9, 28, 14);

    test('an email entry today is done by pal', () {
      expect(isDoneByPal(_entry(DateTime(2026, 9, 28, 8), EntrySource.email), now), isTrue);
    });

    test('an email entry yesterday is not', () {
      expect(isDoneByPal(_entry(DateTime(2026, 9, 27, 23), EntrySource.email), now), isFalse);
    });

    test('a manual entry today is not', () {
      expect(isDoneByPal(_entry(DateTime(2026, 9, 28, 8), EntrySource.manual), now), isFalse);
    });
  });

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
