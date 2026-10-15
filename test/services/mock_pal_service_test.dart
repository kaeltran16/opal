import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/util/format.dart';

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

  test("the agenda's wind-down ritual proposal adds a ritual; the close-out one navigates",
      () async {
    final proposals = (await MockPalService(latency: fast).agenda()).proposals;
    final byId = {for (final p in proposals) p.id: p};
    expect(byId['add-wind-down-ritual']!.addsRitual, isTrue);
    expect(byId['close-out-tonight']!.navigatesToCloseOut, isTrue);
    expect(byId['close-out-tonight']!.addsRitual, isFalse);
  });

  test('agenda words one deterministic line per fact, keyed by fact.key', () async {
    PlanFact fact(String key, String status) => PlanFact(
        key: key, title: 'Morning', when: '7:00 AM', status: status, why: '');

    final agenda = await MockPalService(latency: fast).agenda(plan: [
      fact('a', PlanFact.due),
      fact('b', PlanFact.upcoming),
      fact('c', PlanFact.missed),
      fact('d', PlanFact.anytime),
    ]);

    expect(agenda.lines, {
      'a': 'Morning is due now.',
      'b': 'Morning is next, at 7:00 AM.',
      'c': 'Morning was missed. It is still open if you want it.',
      'd': 'Morning fits any time today.',
    });
  });

  test('every agenda proposal has a known action and its payload', () async {
    final proposals = (await MockPalService(latency: fast).agenda()).proposals;
    expect(proposals, isNotEmpty);
    for (final p in proposals) {
      expect(p.navigatesToCloseOut || p.addsRitual || p.reschedulesWorkout, isTrue,
          reason: p.id);
      if (p.addsRitual) expect(p.ritual, isNotNull, reason: p.id);
      if (p.reschedulesWorkout) expect(p.slot, isNotNull, reason: p.id);
    }
  });

  test('agenda copy follows the display currency', () async {
    final vnd = await MockPalService(latency: fast, currency: () => Currency.vnd)
        .agenda();
    final copy = [
      for (final p in vnd.proposals) ...[p.title, p.body, p.approveLabel, p.doneLabel],
      ...vnd.autopilotSubtitles.values,
    ];
    expect(copy.where((t) => t.contains('\$')), isEmpty);
  });

  test('agenda has a subtitle for each automation', () async {
    final agenda = await MockPalService(latency: fast).agenda();
    expect(agenda.autopilotSubtitles.keys,
        unorderedEquals(['spend_nudge', 'routine_reminders']));
    expect(agenda.autopilotSubtitles.values, everyElement(isNotEmpty));
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

    test('logged food (not just coffee) uses the canonical Food & Drink category',
        () async {
      final pal = MockPalService(latency: fast);
      // the chat path must categorize all food, so a Pal-logged "lunch" surfaces
      // as a meal candidate just like coffee does.
      for (final text in ['coffee \$5', 'lunch at Tartine \$14', 'dinner \$40']) {
        final a = onlyAction(await pal.chat(const [], text));
        expect(a.type, EntryType.money, reason: 'for "$text"');
        expect(a.category, 'Food & Drink', reason: 'for "$text"');
        expect(kSpendCategories, contains(a.category), reason: 'for "$text"');
      }
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

    test('a "k" magnitude scales the amount (50k -> 50000)', () async {
      final pal = MockPalService(latency: fast);
      final r = await pal.chat(const [], 'spent 50k on ramen');
      final a = onlyAction(r);
      expect(a.type, EntryType.money);
      expect(a.amount, -50000);
    });

    test('an "m" magnitude scales the amount (1.5m -> 1500000)', () async {
      final pal = MockPalService(latency: fast);
      final r = await pal.chat(const [], 'rent 1.5m');
      final a = onlyAction(r);
      expect(a.amount, -1500000);
    });

    test('a magnitude letter in a following word is not a suffix', () async {
      final pal = MockPalService(latency: fast);
      final r = await pal.chat(const [], 'spent 5 on milk');
      final a = onlyAction(r);
      expect(a.amount, -5);
    });
  });

  group('parse', () {
    test('scales a k amount and drops the suffix from the title', () async {
      final pal = MockPalService(latency: fast);
      final draft = await pal.parse('50k ramen');
      expect(draft.type, EntryType.money);
      expect(draft.amount, -50000);
      expect(draft.title?.toLowerCase(), isNot(contains('k')));
      expect(draft.title, isNot(contains('50')));
    });

    test('reads a move count as a bare number, not a magnitude', () async {
      final pal = MockPalService(latency: fast);
      final draft = await pal.parse('walk 5k');
      expect(draft.type, EntryType.move);
      expect(draft.durationMinutes, 5);
    });

    test('food expenses map to the canonical Food & Drink category', () async {
      final pal = MockPalService(latency: fast);
      for (final text in ['lunch \$14', 'coffee \$5', 'dinner at Tartine \$40']) {
        final draft = await pal.parse(text);
        expect(draft.type, EntryType.money);
        // must match the nutrition food gate and be a real kSpendCategories member.
        expect(draft.category, 'Food & Drink', reason: 'for "$text"');
        expect(kSpendCategories, contains(draft.category));
      }
    });
  });

  test('insights give every range the same depth (wins + patterns + one-thing)',
      () async {
    final pal = MockPalService(latency: Duration.zero);
    for (final range in InsightRange.values) {
      final i = await pal.insights(range);
      expect(i.wins, isNotEmpty, reason: '$range should surface wins');
      expect(i.patterns, isNotEmpty, reason: '$range should surface patterns');
      expect(i.suggestion, isNotNull,
          reason: '$range should offer a one-thing-to-try');
      expect(i.suggestion, isNotEmpty);
    }
  });

  test('insights correlationNarration defaults to null (no incoming context in mock)',
      () async {
    final svc = MockPalService();
    final res = await svc.insights(InsightRange.week);
    expect(res.correlationNarration, isNull);
  });

  test('mock memory: refresh seeds patterns, delete/clear mutate facts', () async {
    final pal = MockPalService(latency: Duration.zero);
    final seeded = await pal.refreshMemory();
    expect(seeded.patterns, isNotEmpty);

    final afterClear = await pal.clearMemory();
    expect(afterClear.isEmpty, isTrue);
  });
}
