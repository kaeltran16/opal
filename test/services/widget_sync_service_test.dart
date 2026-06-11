import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/widget_sync/widget_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> syncSample(WidgetSyncService service) => service.sync(
        moneyRing: 0.7,
        moveRing: 0.45,
        ritualsRing: 0.6,
        moneySpent: 42,
        dailyBudget: 60,
        moveMinutes: 18,
        dailyMoveMinutes: 40,
        ritualsDone: 3,
        dailyRitualTarget: 5,
      );

  test('sync invokes opal/widget_sync with the full payload', () async {
    const channel = MethodChannel('opal/widget_sync');
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await syncSample(const MethodChannelWidgetSyncService());

    expect(captured?.method, 'sync');
    final args = captured!.arguments as Map;
    expect(args['moneyRing'], closeTo(0.7, 1e-9));
    expect(args['moveRing'], closeTo(0.45, 1e-9));
    expect(args['ritualsRing'], closeTo(0.6, 1e-9));
    expect(args['moneySpent'], 42);
    expect(args['dailyBudget'], 60);
    expect(args['moveMinutes'], 18);
    expect(args['dailyMoveMinutes'], 40);
    expect(args['ritualsDone'], 3);
    expect(args['dailyRitualTarget'], 5);
  });

  test('sync swallows MissingPluginException (no native side)', () async {
    // No mock handler registered -> MissingPluginException; must not throw.
    await syncSample(const MethodChannelWidgetSyncService());
  });
}
