import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/move_controller.dart';
import 'package:opal/models/models.dart';

void main() {
  // A Wednesday — Monday of its week is 2026-06-08, Sunday is 2026-06-14.
  final wednesday = DateTime(2026, 6, 10, 9, 0);
  final monday = DateTime(2026, 6, 8);

  Workout workoutOn(DateTime startedAt, {bool complete = true}) => Workout(
    id: 'w-${startedAt.toIso8601String()}',
    name: 'Session',
    startedAt: startedAt,
    endedAt: complete ? startedAt.add(const Duration(minutes: 45)) : null,
  );

  group('relativeDateLabel', () {
    test('same calendar day reads "Today"', () {
      final now = DateTime(2026, 6, 10, 18, 0);
      final startedAt = DateTime(2026, 6, 10, 7, 0);
      expect(relativeDateLabel(startedAt, now), 'Today');
    });

    test('previous calendar day reads "Yesterday"', () {
      final now = DateTime(2026, 6, 10, 9, 0);
      final startedAt = DateTime(2026, 6, 9, 9, 0);
      expect(relativeDateLabel(startedAt, now), 'Yesterday');
    });

    test('three calendar days back reads "3d ago"', () {
      final now = DateTime(2026, 6, 10, 9, 0);
      final startedAt = DateTime(2026, 6, 7, 9, 0);
      expect(relativeDateLabel(startedAt, now), '3d ago');
    });

    test('uses calendar-day boundaries, not 24h windows', () {
      // 23:00 yesterday vs 01:00 today is ~2h apart but spans a calendar day,
      // so it must read "Yesterday", not "Today".
      final now = DateTime(2026, 6, 10, 1, 0);
      final startedAt = DateTime(2026, 6, 9, 23, 0);
      expect(relativeDateLabel(startedAt, now), 'Yesterday');
    });
  });

  group('buildWeekDays', () {
    test('returns 7 Mon-first days with the weekday letters', () {
      final days = buildWeekDays(const [], wednesday);
      expect(days, hasLength(7));
      expect(days.map((d) => d.letter), ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
    });

    test('a complete workout marks its weekday done', () {
      // Tuesday of this week (offset 1).
      final days = buildWeekDays([
        workoutOn(monday.add(const Duration(days: 1, hours: 8))),
      ], wednesday);
      expect(days[1].done, isTrue);
      // Other days stay undone.
      expect(days[0].done, isFalse);
      expect(days[2].done, isFalse);
    });

    test('an incomplete workout does not mark its weekday done', () {
      final days = buildWeekDays([
        workoutOn(
          monday.add(const Duration(days: 1, hours: 8)),
          complete: false,
        ),
      ], wednesday);
      expect(days[1].done, isFalse);
    });

    test('today flag matches now\'s weekday', () {
      final days = buildWeekDays(const [], wednesday);
      // Wednesday is offset 2.
      expect(days[2].today, isTrue);
      expect(days.where((d) => d.today), hasLength(1));
    });

    test('a prior-week workout does not mark this week', () {
      final days = buildWeekDays(
        // Same weekday (Monday) but one week earlier.
        [
          workoutOn(
            monday
                .subtract(const Duration(days: 7))
                .add(const Duration(hours: 8)),
          ),
        ],
        wednesday,
      );
      expect(days.any((d) => d.done), isFalse);
    });
  });
}
