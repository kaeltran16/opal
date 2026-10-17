import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/spend_habits.dart';
import 'package:opal/models/models.dart';

// Wednesday 24 Jun 2026, 08:00 — the morning daypart on a weekday. A 30-day
// window ending here reaches back to Thursday 26 May.
final _now = DateTime(2026, 6, 24, 8);

var _seq = 0;
Entry _expense(
  DateTime ts,
  double amount, {
  String title = 'Verve Coffee',
  String? category = 'Food & Drink',
}) =>
    Entry(
      id: 'e${_seq++}',
      timestamp: ts,
      type: EntryType.money,
      title: title,
      amount: -amount,
      category: category,
      source: EntrySource.manual,
    );

/// [count] mornings running back from the day before [_now].
List<DateTime> _recentMornings(int count, {int hour = 8}) => [
      for (var i = 1; i <= count; i++)
        DateTime(2026, 6, 24 - i, hour),
    ];

List<HabitPick> _picks(List<Entry> entries) =>
    habitPicksForNow(entries, now: _now);

void main() {
  group('habitPicksForNow', () {
    test('surfaces a repeated title with its average amount', () {
      final entries = [
        for (final d in _recentMornings(3)) _expense(d, 5),
      ];

      final picks = _picks(entries);

      expect(picks, hasLength(1));
      expect(picks.single.title, 'Verve Coffee');
      expect(picks.single.averageAmount, 5);
      expect(picks.single.occurrences, 3);
      expect(picks.single.category, 'Food & Drink');
    });

    test('ignores a title logged only once, however large', () {
      final entries = [_expense(_recentMornings(1).single, 500)];

      expect(_picks(entries), isEmpty);
    });

    test('a single weekend-matching expense does not clear the bar', () {
      // Saturday 20 Jun is a weekend day and _now is not, so this entry is
      // weighted 1 — but even a same-kind day (weight 2) must not qualify a
      // title on one log. The gate counts real occurrences, not weight.
      final entries = [
        _expense(DateTime(2026, 6, 20, 8), 5, title: 'Saturday market'),
      ];

      expect(_picks(entries), isEmpty);
    });

    test('only counts expenses in the current daypart', () {
      // 20:00 is the evening daypart; _now is morning.
      final entries = [
        for (var i = 1; i <= 4; i++)
          _expense(DateTime(2026, 6, 24 - i, 20), 12, title: 'Dinner'),
      ];

      expect(_picks(entries), isEmpty);
    });

    test('skips income and non-money entries', () {
      final entries = [
        for (final d in _recentMornings(3))
          Entry(
            id: 'i${_seq++}',
            timestamp: d,
            type: EntryType.money,
            title: 'Payday',
            amount: 2000, // positive = income
            source: EntrySource.manual,
          ),
        for (final d in _recentMornings(3))
          Entry(
            id: 'm${_seq++}',
            timestamp: d,
            type: EntryType.move,
            title: 'Run',
            duration: 30,
            source: EntrySource.manual,
          ),
      ];

      expect(_picks(entries), isEmpty);
    });

    test('drops anything outside the window', () {
      final entries = [
        for (var i = 0; i < 4; i++)
          _expense(DateTime(2026, 4, 10 + i, 8), 5),
      ];

      expect(_picks(entries), isEmpty);
    });

    test('ranks a same-day-kind habit above an equally frequent other-kind one',
        () {
      // _now is a Wednesday. Weekday mornings outrank weekend mornings at the
      // same real frequency.
      final entries = [
        // Mon 22 + Tue 23 Jun — weekdays, like today.
        _expense(DateTime(2026, 6, 22, 8), 5, title: 'Weekday cart'),
        _expense(DateTime(2026, 6, 23, 8), 5, title: 'Weekday cart'),
        // Sat 20 + Sun 21 Jun — weekend.
        _expense(DateTime(2026, 6, 20, 8), 5, title: 'Weekend cart'),
        _expense(DateTime(2026, 6, 21, 8), 5, title: 'Weekend cart'),
      ];

      final picks = _picks(entries);

      expect(picks.map((p) => p.title), ['Weekday cart', 'Weekend cart']);
    });

    test('caps the list at maxPicks, best first', () {
      final entries = [
        for (var i = 0; i < 5; i++)
          for (final d in _recentMornings(i + 2))
            _expense(d, 5, title: 'Habit $i'),
      ];

      final picks = _picks(entries);

      expect(picks, hasLength(kMaxHabitPicks));
      expect(picks.first.title, 'Habit 4'); // most occurrences
    });

    test('groups case-insensitively and reports the latest spelling', () {
      final mornings = _recentMornings(3);
      final entries = [
        _expense(mornings[2], 5, title: 'verve coffee'),
        _expense(mornings[1], 5, title: 'VERVE COFFEE'),
        _expense(mornings[0], 5, title: 'Verve Coffee'),
      ];

      final picks = _picks(entries);

      expect(picks, hasLength(1));
      expect(picks.single.occurrences, 3);
      expect(picks.single.title, 'Verve Coffee');
    });

    test('reports the modal category, not the most recent one', () {
      final mornings = _recentMornings(3);
      final entries = [
        _expense(mornings[2], 5, category: 'Food & Drink'),
        _expense(mornings[1], 5, category: 'Food & Drink'),
        _expense(mornings[0], 5, category: 'Shopping'),
      ];

      expect(_picks(entries).single.category, 'Food & Drink');
    });

    test('leaves category null when none was ever set', () {
      final entries = [
        for (final d in _recentMornings(2)) _expense(d, 5, category: null),
      ];

      expect(_picks(entries).single.category, isNull);
    });

    test('rounds the average to cents', () {
      final mornings = _recentMornings(3);
      final entries = [
        _expense(mornings[0], 5),
        _expense(mornings[1], 5),
        _expense(mornings[2], 6),
      ];

      expect(_picks(entries).single.averageAmount, 5.33);
    });
  });

  group('titlesLoggedThisDaypart', () {
    test('holds what was logged today in this daypart, of any kind', () {
      final entries = [
        _expense(DateTime(2026, 6, 24, 7), 5, title: ' Bread '),
        Entry(
          id: 'r1',
          timestamp: DateTime(2026, 6, 24, 6),
          type: EntryType.rituals,
          title: 'Morning pages',
          source: EntrySource.manual,
        ),
      ];

      expect(titlesLoggedThisDaypart(entries, now: _now), {'bread', 'morning pages'});
    });

    test('ignores yesterday and another daypart today', () {
      final entries = [
        _expense(DateTime(2026, 6, 23, 8), 5, title: 'Bread'),
        // 23:00 the night before is the night daypart, a day earlier.
        _expense(DateTime(2026, 6, 23, 23), 5, title: 'Late snack'),
        _expense(DateTime(2026, 6, 24, 12), 9, title: 'Lunch'),
      ];

      expect(titlesLoggedThisDaypart(entries, now: _now), isEmpty);
    });
  });
}
