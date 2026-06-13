import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/controllers/widget_sync_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/widget_sync/widget_sync_service.dart';

/// Records the args of the most recent [sync] call.
class _RecordingWidgetSync implements WidgetSyncService {
  Map<String, Object>? last;

  @override
  Future<void> sync({
    required double moneyRing,
    required double moveRing,
    required double ritualsRing,
    required double moneySpent,
    required double dailyBudget,
    required int moveKcal,
    required int dailyMoveKcal,
    required int ritualsDone,
    required int dailyRitualTarget,
  }) async {
    last = {
      'moneyRing': moneyRing,
      'moveRing': moveRing,
      'ritualsRing': ritualsRing,
      'moneySpent': moneySpent,
      'moveKcal': moveKcal,
      'ritualsDone': ritualsDone,
    };
  }
}

TodayState _sampleState() => TodayState(
      entries: [
        Entry(id: '1', timestamp: DateTime(2026, 6, 11, 9), type: EntryType.money, title: 'Coffee', amount: -42.0, source: EntrySource.manual),
        Entry(id: '2', timestamp: DateTime(2026, 6, 11, 10), type: EntryType.move, title: 'Walk', duration: 30, calories: 18, source: EntrySource.manual),
        Entry(id: '3', timestamp: DateTime(2026, 6, 11, 8), type: EntryType.rituals, title: 'Meditate', source: EntrySource.manual),
        Entry(id: '4', timestamp: DateTime(2026, 6, 11, 8), type: EntryType.rituals, title: 'Journal', source: EntrySource.manual),
        Entry(id: '5', timestamp: DateTime(2026, 6, 11, 8), type: EntryType.rituals, title: 'Stretch', source: EntrySource.manual),
      ],
      goals: const Goals(dailyBudget: 60, dailyMoveKcal: 40, dailyRitualTarget: 5),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('maps each todayState emission onto a sync call', () async {
    final recorder = _RecordingWidgetSync();
    final state = _sampleState();
    final container = ProviderContainer(overrides: [
      widgetSyncServiceProvider.overrideWithValue(recorder),
      todayStateProvider.overrideWith((ref) => Stream.value(state)),
    ]);
    addTearDown(container.dispose);

    // Explicit listener keeps the auto-dispose stream provider alive while it
    // emits; the controller's own listener then drives the sync call.
    final sub = container.listen(todayStateProvider, (_, __) {});
    addTearDown(sub.close);
    container.read(widgetSyncControllerProvider); // instantiate -> sets listener
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(recorder.last, isNotNull);
    expect(recorder.last!['moneyRing'], closeTo(0.7, 1e-9));
    expect(recorder.last!['moveRing'], closeTo(0.45, 1e-9));
    expect(recorder.last!['ritualsRing'], closeTo(0.6, 1e-9));
    expect(recorder.last!['moneySpent'], 42.0);
    expect(recorder.last!['moveKcal'], 18);
    expect(recorder.last!['ritualsDone'], 3);
  });
}
