import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_context_builder.dart';
import 'package:opal/util/format.dart';

void main() {
  test('buildChatContext includes hourOfDay and weekday from now', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: const Goals(dailyBudget: 50, dailyMoveKcal: 400, dailyRitualTarget: 3),
      todayEntries: const [],
      weekEntries: const [],
      moveStreakDays: 0,
      now: DateTime(2026, 6, 20, 8), // Saturday 08:00
    );
    expect(ctx['hourOfDay'], 8);
    expect(ctx['weekday'], DateTime.saturday); // 6
  });

  test('buildChatContext carries the currency descriptor and formats entries with it', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: const Goals(dailyBudget: 50, dailyMoveKcal: 400, dailyRitualTarget: 3),
      todayEntries: [
        Entry(id: '1', timestamp: DateTime(2026, 6, 20, 8), type: EntryType.money,
            title: 'Coffee', amount: -5, source: EntrySource.manual),
      ],
      weekEntries: const [],
      moveStreakDays: 0,
      currency: Currency.vnd,
      now: DateTime(2026, 6, 20, 8),
    );
    expect(ctx['currency'], Currency.vnd.toWire());
    expect((ctx['todayEntries'] as List).single, contains('₫'));
  });
}
