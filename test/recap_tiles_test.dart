import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/recap_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart' show InsightRange;
import 'package:opal/util/format.dart';

void main() {
  test('Recap tiles group kcal and counts the way Areas and money do', () {
    final now = DateTime(2026, 6, 20, 20);
    final entries = [
      for (var d = 1; d <= 3; d++)
        Entry(
          id: 'run-$d',
          timestamp: DateTime(2026, 6, d, 7),
          type: EntryType.move,
          title: 'Run',
          duration: 60,
          calories: 1006,
          source: EntrySource.manual,
        ),
    ];
    final recap = buildRecapData(
      InsightRange.month,
      entries,
      const Goals(dailyMoveKcal: 500),
      now: now,
    );

    final moved = recap.tiles(Currency.usd)[1];
    expect(moved.value, '3,018');
    expect(moved.sub, 'of 15,000 kcal');
  });
}
