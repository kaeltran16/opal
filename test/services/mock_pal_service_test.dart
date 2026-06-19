import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  final fast = const Duration(milliseconds: 1);

  test('suggestWorkout advances past the excluded routine', () async {
    final pal = MockPalService(latency: fast);

    // first canned pick is Push Day A (routineId seed-routine-push-a).
    final first = await pal.suggestWorkout();
    expect(first.routineId, 'seed-routine-push-a');

    // excluding it skips to the next pick instead of repeating.
    final next = await pal.suggestWorkout(excludeRoutineId: 'seed-routine-push-a');
    expect(next.routineId, isNot('seed-routine-push-a'));
  });

  group('chat logging', () {
    LogEntryAction onlyAction(PalChatResult r) =>
        r.actions.single as LogEntryAction;

    test('a money phrase logs an expense and the reply does not restate it',
        () async {
      final pal = MockPalService(latency: fast);
      final r = await pal.chat(const [], 'coffee \$25');
      final a = onlyAction(r);
      expect(a.type, EntryType.money);
      expect(a.amount, -25);
      // the card shows the amount — the reply must not repeat it.
      expect(r.reply, isNot(contains('Logged')));
      expect(r.reply, isNot(contains('\$')));
    });

    test('a move phrase carries calories so the live ring advances', () async {
      final pal = MockPalService(latency: fast);
      final r = await pal.chat(const [], 'ran 30 min');
      final a = onlyAction(r);
      expect(a.type, EntryType.move);
      expect(a.durationMinutes, 30);
      expect(a.calories, greaterThan(0));
    });

    test('a completion phrase with no amount logs a ritual', () async {
      final pal = MockPalService(latency: fast);
      final r = await pal.chat(const [], 'finished morning pages');
      final a = onlyAction(r);
      expect(a.type, EntryType.rituals);
      expect(a.title, 'Morning pages');
    });

    test('a question stays conversational (no action)', () async {
      final pal = MockPalService(latency: fast);
      final r = await pal.chat(const [], 'how am I doing this week?');
      expect(r.actions, isEmpty);
    });
  });
}
