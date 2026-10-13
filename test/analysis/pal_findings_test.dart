import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/analysis/pal_findings.dart';
import 'package:opal/analysis/spend_patterns.dart';
import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/util/format.dart';

PalFinding _finding(List<String> areas) =>
    PalFinding(id: 'x', areas: areas, line: 'l', evidence: 'e', question: 'q');

NutritionPattern _nutrition(String tracker, List<int> spark) =>
    NutritionPattern(
      tracker: tracker,
      icon: 'creditcard.fill',
      title: 'Takeout vs. home',
      body: 'You spent about \$42 on 3 takeout meals this week.',
      spark: spark,
      emph: const [0],
    );

void main() {
  group('findingsFromCorrelations', () {
    test('a breakdown becomes a comparison of the two groups', () {
      final f = findingsFromCorrelations(const [
        Correlation(
          a: Dimension.money,
          b: Dimension.move,
          r: -0.55,
          n: 30,
          breakdown: GroupBreakdown(
            binaryDim: Dimension.move,
            continuousDim: Dimension.money,
            meanWhenActive: 20,
            meanWhenInactive: 60,
            countActive: 10,
            countInactive: 20,
          ),
        ),
      ]).single;

      expect(f.id, 'corr:money-move:-');
      expect(f.areas, ['Money', 'Move']);
      expect(f.line, 'Money runs lower on workout days.');
      expect(f.evidence, '10 workout days, 20 rest days');
      expect(f.question, 'Tell me more: Money runs lower on workout days.');
      expect(f.hasComparison, isTrue);
      expect(f.a!.label, 'Workout days');
      expect(f.a!.value, '\$20');
      expect(f.a!.fraction, closeTo(20 / 60, 1e-9));
      expect(f.b!.label, 'Rest days');
      expect(f.b!.value, '\$60');
      expect(f.b!.fraction, 1.0);
    });

    test('without a breakdown it states the direction and has no bars', () {
      final f = findingsFromCorrelations(const [
        Correlation(a: Dimension.nutrition, b: Dimension.mood, r: 0.5, n: 40),
      ]).single;

      expect(f.id, 'corr:nutrition-mood:+');
      expect(f.areas, ['Nutrition', 'Mood']);
      expect(f.line, 'More calories goes with more mood.');
      expect(f.evidence, 'Over 40 days');
      expect(f.hasComparison, isFalse);
    });

    test('a negative r gets a minus id and says less', () {
      final f = findingsFromCorrelations(const [
        Correlation(a: Dimension.money, b: Dimension.mood, r: -0.45, n: 25),
      ]).single;

      expect(f.id, 'corr:money-mood:-');
      expect(f.line, 'More spending goes with less mood.');
    });
  });

  group('findingsFromSpendPatterns', () {
    const usd = Currency.usd;

    test('biggestDay compares the peak and quiet weekdays', () {
      final f = findingsFromSpendPatterns(
        const SpendPatterns(
          biggestDay: BiggestDay(
            peakWeekday: DateTime.friday,
            quietWeekday: DateTime.tuesday,
            peakAverage: 71.4,
            quietAverage: 35.6,
          ),
        ),
        usd,
      ).single;

      expect(f.id, 'money:biggest-day:5');
      expect(f.areas, ['Money']);
      expect(f.line, 'You spend most on Fridays.');
      expect(f.evidence, 'Last 30 days');
      expect(f.a!.label, 'Friday');
      expect(f.a!.value, '\$71 a day');
      expect(f.a!.fraction, 1.0);
      expect(f.b!.label, 'Tuesday');
      expect(f.b!.value, '\$36 a day');
      expect(f.b!.fraction, closeTo(35.6 / 71.4, 1e-9));
    });

    test('weekendSplit names the heavier side in line and id', () {
      final weekend = findingsFromSpendPatterns(
        const SpendPatterns(
          weekendSplit: WeekendSplit(weekendAverage: 80, weekdayAverage: 40),
        ),
        usd,
      ).single;
      expect(weekend.id, 'money:weekend-split:weekend');
      expect(weekend.line, 'Weekends cost more than weekdays.');
      expect(weekend.evidence, 'Last 30 days');
      expect(weekend.a!.label, 'Weekend days');
      expect(weekend.a!.value, '\$80 a day');
      expect(weekend.b!.label, 'Weekdays');
      expect(weekend.b!.value, '\$40 a day');
      expect(weekend.b!.fraction, 0.5);

      final weekday = findingsFromSpendPatterns(
        const SpendPatterns(
          weekendSplit: WeekendSplit(weekendAverage: 20, weekdayAverage: 40),
        ),
        usd,
      ).single;
      expect(weekday.id, 'money:weekend-split:weekday');
      expect(weekday.line, 'Weekdays cost more than weekends.');
    });

    test('daypartPeak compares the daypart with the rest of the day', () {
      final f = findingsFromSpendPatterns(
        const SpendPatterns(
          daypartPeak: DaypartPeak(
            daypart: SpendDaypart.evening,
            total: 300,
            share: 0.6,
          ),
        ),
        usd,
      ).single;

      expect(f.id, 'money:daypart-peak:evening');
      expect(f.areas, ['Money']);
      expect(f.line, 'Evening takes 60% of your spending.');
      expect(f.a!.label, 'Evening');
      expect(f.a!.value, '\$300');
      expect(f.b!.label, 'Rest of the day');
      expect(f.b!.value, '\$200');
      expect(f.b!.fraction, closeTo(200 / 300, 1e-9));
    });

    test('noSpendStreak is a line and evidence with no bars', () {
      final f = findingsFromSpendPatterns(
        const SpendPatterns(noSpendStreakDays: 9),
        usd,
      ).single;

      expect(f.id, 'money:no-spend-streak');
      expect(f.areas, ['Money']);
      expect(f.line, '9 days without spending.');
      expect(f.evidence, 'Ending yesterday');
      expect(f.hasComparison, isFalse);
    });

    test('unusual compares the expense with the usual one', () {
      final f = findingsFromSpendPatterns(
        SpendPatterns(
          unusual: [
            UnusualExpense(
              entry: Entry(
                id: 'e1',
                timestamp: DateTime(2026, 10, 3, 12),
                type: EntryType.money,
                title: 'Concert tickets',
                amount: -150,
                source: EntrySource.manual,
              ),
              multipleOfMean: 3.0,
            ),
          ],
        ),
        usd,
      ).single;

      expect(f.id, 'money:unusual:e1');
      expect(f.areas, ['Money']);
      expect(f.line, 'Concert tickets was 3x your usual expense.');
      expect(f.evidence, 'Oct 3');
      expect(f.a!.label, 'Concert tickets');
      expect(f.a!.value, '\$150');
      expect(f.b!.label, 'Your usual expense');
      expect(f.b!.value, '\$50');
      expect(f.b!.fraction, closeTo(1 / 3, 1e-9));
    });

    test('nothing found yields no findings', () {
      expect(findingsFromSpendPatterns(const SpendPatterns(), usd), isEmpty);
    });
  });

  group('findingsFromNutritionPatterns', () {
    test('takeout becomes a takeout vs cooked comparison', () {
      final f = findingsFromNutritionPatterns([
        _nutrition('money', [3, 5]),
      ]).single;

      expect(f.id, 'nutrition:Takeout vs. home');
      expect(f.areas, ['Nutrition', 'Money']);
      expect(f.line, 'You spent about \$42 on 3 takeout meals this week.');
      expect(f.evidence, 'This week');
      expect(f.a!.label, 'Takeout meals');
      expect(f.a!.value, '3');
      expect(f.a!.fraction, closeTo(0.6, 1e-9));
      expect(f.b!.label, 'Cooked at home');
      expect(f.b!.value, '5');
      expect(f.b!.fraction, 1.0);
    });

    test('a nutrition tracker is not listed twice', () {
      final f = findingsFromNutritionPatterns([
        _nutrition('nutrition', [2, 1]),
      ]).single;
      expect(f.areas, ['Nutrition']);
    });

    test('no takeout or an empty spark yields nothing', () {
      expect(
        findingsFromNutritionPatterns([
          _nutrition('money', [0, 5]),
        ]),
        isEmpty,
      );
      expect(findingsFromNutritionPatterns([_nutrition('money', [])]), isEmpty);
    });
  });

  group('findingsFromPalPatterns', () {
    test('a server pattern is its title and detail, no bars', () {
      final f = findingsFromPalPatterns(const [
        InsightPattern(
          colorToken: 'rituals',
          title: 'Mornings go better after a walk',
          detail: 'Seen on 8 of 10 mornings',
        ),
      ]).single;

      expect(f.id, 'pal:Mornings go better after a walk');
      expect(f.areas, ['Routines']);
      expect(f.line, 'Mornings go better after a walk');
      expect(f.evidence, 'Seen on 8 of 10 mornings');
      expect(f.question, 'Tell me more: Mornings go better after a walk');
      expect(f.hasComparison, isFalse);
    });

    test('an unknown colorToken gives no area', () {
      final f = findingsFromPalPatterns(const [
        InsightPattern(colorToken: 'teal', title: 't', detail: 'd'),
      ]).single;
      expect(f.areas, isEmpty);
    });
  });

  test('areasLabel joins one, two and three areas', () {
    expect(_finding(['Sleep']).areasLabel, 'Sleep');
    expect(_finding(['Sleep', 'Money']).areasLabel, 'Sleep and Money');
    expect(_finding(['A', 'B', 'C']).areasLabel, 'A, B and C');
  });
}
