import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/budget_alert_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/notifications/notification_service.dart';
import 'package:opal/util/dates.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records one-shot schedules so tests can assert per notification id.
class _RecordingNotificationService implements NotificationService {
  final List<NotificationRequest> oneShots = [];

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(NotificationRequest request) async =>
      oneShots.add(request);

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

Future<SharedPreferences> _prefs(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

String _formatDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoopDatabase db;

  setUp(() => db = LoopDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer makeContainer(
    SharedPreferences prefs,
    _RecordingNotificationService service,
  ) {
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  final now = DateTime.now();

  /// An expense [daysAgo] days back. A null [category] keeps it invisible to the
  /// spike detector, so a velocity case can't trip a spike notification too.
  Entry expense(double magnitude, {required int daysAgo, String? category}) =>
      Entry(
        id: '',
        timestamp: now.subtract(Duration(days: daysAgo)),
        type: EntryType.money,
        title: 'Expense',
        amount: -magnitude,
        category: category,
        source: EntrySource.manual,
      );

  /// An expense dated mid-way through last month, safely inside the window.
  Entry lastMonthExpense(double magnitude, String category) => Entry(
        id: '',
        timestamp: DateTime(now.year, now.month - 1, 15, 12),
        type: EntryType.money,
        title: 'Expense',
        amount: -magnitude,
        category: category,
        source: EntrySource.manual,
      );

  List<NotificationRequest> withId(
          _RecordingNotificationService s, int id) =>
      s.oneShots.where((r) => r.id == id).toList();

  group('spending pace', () {
    test('fires when this week runs well ahead of last week', () async {
      final prefs = await _prefs({'settings.budgetAlerts': true});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);
      final entries = container.read(entryRepositoryProvider);

      await entries.insert(expense(100, daysAgo: 9));
      await entries.insert(expense(300, daysAgo: 2));

      await container.read(budgetAlertControllerProvider.notifier).checkPeriodic();

      expect(withId(service, NotificationIds.spendVelocity), hasLength(1));
      expect(prefs.getString('settings.velocityAlertWeek'),
          _formatDate(startOfWeek(now)));
    });

    test('does not fire twice in the same week', () async {
      final prefs = await _prefs({'settings.budgetAlerts': true});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);
      final entries = container.read(entryRepositoryProvider);

      await entries.insert(expense(100, daysAgo: 9));
      await entries.insert(expense(300, daysAgo: 2));

      final ctrl = container.read(budgetAlertControllerProvider.notifier);
      await ctrl.checkPeriodic();
      await ctrl.checkPeriodic();

      expect(withId(service, NotificationIds.spendVelocity), hasLength(1));
    });

    test('stays quiet when spending slowed down', () async {
      final prefs = await _prefs({'settings.budgetAlerts': true});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);
      final entries = container.read(entryRepositoryProvider);

      await entries.insert(expense(300, daysAgo: 9));
      await entries.insert(expense(100, daysAgo: 2));

      await container.read(budgetAlertControllerProvider.notifier).checkPeriodic();

      expect(withId(service, NotificationIds.spendVelocity), isEmpty);
    });
  });

  group('category spike', () {
    test('fires once for the steepest riser and stamps the month', () async {
      final prefs = await _prefs({'settings.budgetAlerts': true});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);
      final entries = container.read(entryRepositoryProvider);

      await entries.insert(lastMonthExpense(100, 'Food & Drink'));
      await entries.insert(expense(400, daysAgo: 0, category: 'Food & Drink'));

      final ctrl = container.read(budgetAlertControllerProvider.notifier);
      await ctrl.checkPeriodic();
      await ctrl.checkPeriodic();

      final fired = withId(service, NotificationIds.categorySpike);
      expect(fired, hasLength(1));
      expect(fired.single.title, contains('Food & Drink'));
      expect(prefs.getString('settings.spikeAlertMonth'),
          '${now.year}-${now.month.toString().padLeft(2, '0')}');
    });
  });

  test('nothing fires while the budget-alerts toggle is off', () async {
    final prefs = await _prefs({'settings.budgetAlerts': false});
    final service = _RecordingNotificationService();
    final container = makeContainer(prefs, service);
    final entries = container.read(entryRepositoryProvider);

    await entries.insert(expense(100, daysAgo: 9));
    await entries.insert(expense(300, daysAgo: 2));

    await container.read(budgetAlertControllerProvider.notifier).checkPeriodic();

    expect(service.oneShots, isEmpty);
  });
}
