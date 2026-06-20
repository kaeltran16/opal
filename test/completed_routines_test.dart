import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/recap_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart' show InsightRange;

RitualRoutine _routine(String id, List<String> stepIds) => RitualRoutine(
      id: id, name: id, time: '7:00 AM', tone: RitualTone.morning,
      icon: 'x', blurb: '',
      steps: [
        for (final s in stepIds) RitualStep(id: s, title: s, note: '', icon: 'x'),
      ],
    );

Entry _step(String ritualId, DateTime at) => Entry(
      id: 'e-$ritualId-${at.day}',
      timestamp: at,
      type: EntryType.rituals,
      title: ritualId,
      ritualId: ritualId,
      source: EntrySource.manual,
    );

void main() {
  final morning = _routine('morning', ['m0', 'm1', 'm2', 'm3', 'm4']); // 5 steps

  group('completedRoutines', () {
    test('a partly-done routine does not count (the Recap 3/3 bug)', () {
      // 3 of 5 morning steps done today → 0 completed routines, not 3 entries.
      final day = DateTime(2026, 6, 20);
      final entries = [
        _step('m0', day.add(const Duration(hours: 6))),
        _step('m1', day.add(const Duration(hours: 7))),
        _step('m2', day.add(const Duration(hours: 8))),
      ];
      expect(completedRoutines(entries, [morning], day: day), 0);
    });

    test('counts a routine once all its steps are done that day', () {
      final day = DateTime(2026, 6, 20);
      final entries = [for (var i = 0; i < 5; i++) _step('m$i', day)];
      expect(completedRoutines(entries, [morning], day: day), 1);
    });

    test('day-scoping: steps done yesterday do not complete today', () {
      final yesterday = DateTime(2026, 6, 19);
      final entries = [for (var i = 0; i < 5; i++) _step('m$i', yesterday)];
      expect(completedRoutines(entries, [morning], day: DateTime(2026, 6, 20)), 0);
      // but they do complete the day they were done
      expect(completedRoutines(entries, [morning], day: yesterday), 1);
    });
  });

  group('completedRoutinesInPeriod', () {
    final start = DateTime(2026, 6, 15); // Monday
    final solo = _routine('r', ['s0']);

    test('sums per-day completions across the period', () {
      final entries = [
        _step('s0', DateTime(2026, 6, 15)), // Mon
        _step('s0', DateTime(2026, 6, 17)), // Wed
      ];
      expect(completedRoutinesInPeriod(entries, [solo], start: start, days: 7), 2);
    });

    test('a routine split across days never completes', () {
      // m0..m2 Monday, m3..m4 Friday — all 5 steps appear in the week but never
      // on the same day, so the routine completes on no day.
      final entries = [
        _step('m0', DateTime(2026, 6, 15)),
        _step('m1', DateTime(2026, 6, 15)),
        _step('m2', DateTime(2026, 6, 15)),
        _step('m3', DateTime(2026, 6, 19)),
        _step('m4', DateTime(2026, 6, 19)),
      ];
      expect(completedRoutinesInPeriod(entries, [morning], start: start, days: 7), 0);
    });
  });

  test('buildRecapData(day) counts completed routines, not step entries', () {
    final day = DateTime(2026, 6, 20);
    final entries = [
      _step('m0', day),
      _step('m1', day),
      _step('m2', day), // 3 of 5 → routine not complete
    ];
    final recap = buildRecapData(InsightRange.day, entries, const Goals(),
        routines: [morning], now: day);
    expect(recap.ritualsKept, 0); // not 3 (the old step-entry count)
    expect(recap.ritualsTarget, 1); // one routine for the day
  });
}
