import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  group('orderAreas', () {
    test('puts incomplete areas before complete ones', () {
      final order = orderAreas(const [
        AreaStatus(area: TodayArea.sleep, complete: true, minuteOfDay: 0),
        AreaStatus(area: TodayArea.money, complete: false, minuteOfDay: 720),
        AreaStatus(area: TodayArea.mood, complete: false, minuteOfDay: 480),
      ]);
      expect(order, [TodayArea.mood, TodayArea.money, TodayArea.sleep]);
    });

    test('breaks minuteOfDay ties by enum index', () {
      final order = orderAreas(const [
        AreaStatus(area: TodayArea.nutrition, complete: false, minuteOfDay: 600),
        AreaStatus(area: TodayArea.move, complete: false, minuteOfDay: 600),
        AreaStatus(area: TodayArea.routines, complete: false, minuteOfDay: 600),
      ]);
      expect(order, [TodayArea.routines, TodayArea.move, TodayArea.nutrition]);
    });

    test('an empty list gives an empty list', () {
      expect(orderAreas(const []), isEmpty);
    });
  });

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

  group('briefMode', () {
    test('a non-empty headline gives brief', () {
      expect(briefMode(const AsyncData('x')), BriefMode.brief);
    });

    test('null or empty headlines give fallback', () {
      expect(briefMode(const AsyncData(null)), BriefMode.fallback);
      expect(briefMode(const AsyncData('')), BriefMode.fallback);
    });

    test('loading gives fallback', () {
      expect(briefMode(const AsyncLoading()), BriefMode.fallback);
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

  group('greetingFor', () {
    test('switches at noon and 18:00', () {
      expect(greetingFor(DateTime(2026, 9, 28, 11, 59)), 'Good morning');
      expect(greetingFor(DateTime(2026, 9, 28, 12)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 9, 28, 17, 59)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 9, 28, 18)), 'Good evening');
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
