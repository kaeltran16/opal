import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opal/controllers/budget_alert_controller.dart';
import 'package:opal/controllers/notification_reconcile_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/settings/notifications_screen.dart';
import 'package:opal/services/notifications/notification_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every call by notification id so tests can assert what was
/// scheduled/cancelled without a device.
class _RecordingNotificationService implements NotificationService {
  final List<({int id, TimeOfDay time})> daily = [];
  final List<NotificationRequest> oneShots = [];
  final List<int> cancels = [];

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
  }) async =>
      daily.add((id: id, time: time));

  @override
  Future<void> cancel(int id) async => cancels.add(id);

  @override
  Future<void> cancelAll() async {}
}

Future<SharedPreferences> _prefs(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
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

  Entry expense(double magnitude) => Entry(
        id: '',
        timestamp: DateTime.now(),
        type: EntryType.money,
        title: 'Expense',
        amount: -magnitude,
        source: EntrySource.manual,
      );

  String today() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  group('reconcile on start', () {
    test('schedules the daily reminder at the configured time when ON',
        () async {
      final prefs = await _prefs({
        'settings.ritualReminders': true,
        'settings.reminderTimeMinutes': 7 * 60 + 30, // 07:30
      });
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);

      container.read(notificationReconcileControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.daily, hasLength(1));
      expect(service.daily.single.id, NotificationIds.ritualReminder);
      expect(service.daily.single.time, const TimeOfDay(hour: 7, minute: 30));
      expect(service.cancels, isEmpty);
    });

    test('cancels the daily reminder when OFF', () async {
      final prefs = await _prefs({'settings.ritualReminders': false});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);

      container.read(notificationReconcileControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.daily, isEmpty);
      expect(service.cancels, [NotificationIds.ritualReminder]);
    });

    test('defaults to 09:00 when no reminder time is persisted', () async {
      final prefs = await _prefs({'settings.ritualReminders': true});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);

      container.read(notificationReconcileControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.daily.single.time, kDefaultReminderTime);
    });
  });

  group('budget alert', () {
    // budget lives in Goals (drift), not prefs
    Future<void> seedBudget(double budget) =>
        GoalsRepository(db).upsert(Goals(dailyBudget: budget));

    test('fires once when a spend crosses the daily budget', () async {
      final prefs = await _prefs({'settings.budgetAlerts': true});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);
      await seedBudget(50);

      final entries = container.read(entryRepositoryProvider);
      final ctrl = container.read(budgetAlertControllerProvider.notifier);

      await entries.insert(expense(30)); // 30 — under
      await ctrl.checkAfterSpend();
      expect(service.oneShots, isEmpty);

      await entries.insert(expense(30)); // 60 — over
      await ctrl.checkAfterSpend();
      expect(service.oneShots, hasLength(1));
      expect(service.oneShots.single.id, NotificationIds.budgetAlert);
      expect(prefs.getString('settings.budgetAlertDate'), today());
    });

    test('does not fire twice the same day', () async {
      final prefs = await _prefs({'settings.budgetAlerts': true});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);
      await seedBudget(50);

      final entries = container.read(entryRepositoryProvider);
      final ctrl = container.read(budgetAlertControllerProvider.notifier);

      await entries.insert(expense(60));
      await ctrl.checkAfterSpend();
      await entries.insert(expense(10)); // still over
      await ctrl.checkAfterSpend();

      expect(service.oneShots, hasLength(1));
    });

    test('does not fire when the toggle is off', () async {
      final prefs = await _prefs({'settings.budgetAlerts': false});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);
      await seedBudget(50);

      final entries = container.read(entryRepositoryProvider);
      final ctrl = container.read(budgetAlertControllerProvider.notifier);

      await entries.insert(expense(60));
      await ctrl.checkAfterSpend();

      expect(service.oneShots, isEmpty);
    });

    test('does not fire while under budget', () async {
      final prefs = await _prefs({'settings.budgetAlerts': true});
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);
      await seedBudget(100);

      final entries = container.read(entryRepositoryProvider);
      final ctrl = container.read(budgetAlertControllerProvider.notifier);

      await entries.insert(expense(40));
      await ctrl.checkAfterSpend();

      expect(service.oneShots, isEmpty);
    });
  });

  group('settings screen toggle', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      SharedPreferences prefs,
      _RecordingNotificationService service,
    ) async {
      final colors = AppColors.light(AppAccent.indigo);
      final router = GoRouter(routes: [
        GoRoute(
            path: '/', builder: (context, state) => const NotificationsScreen()),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            notificationServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: true, extensions: [colors]),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('toggling ON schedules the daily reminder', (tester) async {
      final prefs = await _prefs({'settings.ritualReminders': false});
      final service = _RecordingNotificationService();
      await pumpScreen(tester, prefs, service);

      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pumpAndSettle();

      expect(service.daily, hasLength(1));
      expect(service.daily.single.id, NotificationIds.ritualReminder);
      expect(prefs.getBool('settings.ritualReminders'), isTrue);
    });

    testWidgets('toggling OFF cancels the daily reminder', (tester) async {
      final prefs = await _prefs({'settings.ritualReminders': true});
      final service = _RecordingNotificationService();
      await pumpScreen(tester, prefs, service);

      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pumpAndSettle();

      expect(service.cancels, [NotificationIds.ritualReminder]);
      expect(service.daily, isEmpty);
      expect(prefs.getBool('settings.ritualReminders'), isFalse);
    });

    testWidgets('the reminder-time row is shown only when reminders are ON',
        (tester) async {
      final prefs = await _prefs({'settings.ritualReminders': false});
      final service = _RecordingNotificationService();
      await pumpScreen(tester, prefs, service);

      expect(find.text('Reminder time'), findsNothing);

      await tester.tap(find.byType(CupertinoSwitch).first); // turn ON
      await tester.pumpAndSettle();

      expect(find.text('Reminder time'), findsOneWidget);
    });
  });

  // The screen's _pickReminderTime persists the new time then reschedules; on
  // the next launch the reconcile controller schedules at the stored time. This
  // covers "changing the time re-schedules" without driving the Material picker
  // internals (which belong to the framework, not this feature).
  group('changing the reminder time re-schedules', () {
    test('a changed time produces a new scheduleDaily at that time', () async {
      final prefs = await _prefs({
        'settings.ritualReminders': true,
        'settings.reminderTimeMinutes': 9 * 60,
      });
      final service = _RecordingNotificationService();
      final container = makeContainer(prefs, service);

      // user picks 10:15 (what _pickReminderTime persists), then reschedules.
      await container
          .read(settingsRepositoryProvider)
          .setReminderTime(const TimeOfDay(hour: 10, minute: 15));
      container.refresh(notificationReconcileControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.daily.last.time, const TimeOfDay(hour: 10, minute: 15));
    });
  });
}
