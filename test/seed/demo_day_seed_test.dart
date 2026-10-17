import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/util/dates.dart';

void main() {
  final justAfterMidnight = DateTime(2026, 10, 17, 0, 10);
  final morning = DateTime(2026, 10, 17, 9, 30);
  final lateEvening = DateTime(2026, 10, 17, 22);

  List<DateTime> checkins() => [for (final c in SeedData.moodCheckins()) c.timestamp];
  List<DateTime> meals() => [for (final m in SeedData.nutritionMeals()) m.timestamp];
  int today(List<DateTime> at, DateTime now) =>
      at.where((t) => startOfDay(t) == startOfDay(now)).length;

  for (final now in [justAfterMidnight, morning, lateEvening]) {
    test('no demo check-in or meal sits after $now', () {
      withClock(Clock.fixed(now), () {
        expect(checkins().where((t) => t.isAfter(now)), isEmpty);
        expect(meals().where((t) => t.isAfter(now)), isEmpty);
      });
    });
  }

  test('just after midnight the demo day is not checked in or eaten', () {
    withClock(Clock.fixed(justAfterMidnight), () {
      expect(today(checkins(), justAfterMidnight), 0);
      expect(today(meals(), justAfterMidnight), 0);
    });
  });

  test('the day so far keeps what has happened, and the rest moves to the day before', () {
    withClock(Clock.fixed(morning), () {
      // 8:05 has passed; 1:40 PM and 9:12 PM have not.
      expect(today(checkins(), morning), 1);
      // breakfast and the cortado have passed; lunch and dinner have not.
      expect(today(meals(), morning), 2);
      expect(meals(), hasLength(4));
    });
    withClock(Clock.fixed(lateEvening), () {
      expect(today(checkins(), lateEvening), 3);
      expect(today(meals(), lateEvening), 4);
    });
  });
}
