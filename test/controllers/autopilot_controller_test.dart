import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/autopilot_controller.dart';
import 'package:opal/controllers/budget_alert_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/notifications/notification_service.dart';
import 'package:opal/services/pal/pal_service.dart';

/// Records the daily schedules, one-shots and cancels by notification id.
class _FakeNotificationService implements NotificationService {
  final List<({int id, TimeOfDay time})> daily = [];
  final List<NotificationRequest> oneShots = [];
  final List<int> cancels = [];

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(NotificationRequest request) async => oneShots.add(request);

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

const _reminderMinutes = 7 * 60 + 30;
const _reminderTime = TimeOfDay(hour: 7, minute: 30);

void main() {
  late LoopDatabase db;
  late SharedPreferences prefs;
  late _FakeNotificationService notifications;

  setUp(() async {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'settings.ritualReminders': true,
      'settings.budgetAlerts': true,
      'settings.reminderTimeMinutes': _reminderMinutes,
    });
    prefs = await SharedPreferences.getInstance();
    notifications = _FakeNotificationService();
  });
  tearDown(() => db.close());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(notifications),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('both switches start from the saved settings', () {
    final container = makeContainer();
    expect(container.read(automationsProvider), {
      Automation.spendNudge: true,
      Automation.routineReminders: true,
    });
  });

  test('switching routine reminders off saves it and cancels the reminder',
      () async {
    final container = makeContainer();
    await container
        .read(automationsProvider.notifier)
        .set(Automation.routineReminders, false);

    expect(container.read(automationsProvider)[Automation.routineReminders], isFalse);
    expect(prefs.getBool('settings.ritualReminders'), isFalse);
    expect(notifications.cancels, [NotificationIds.ritualReminder]);
    expect(notifications.daily, isEmpty);
  });

  test('switching routine reminders on schedules it at the saved time', () async {
    await prefs.setBool('settings.ritualReminders', false);
    final container = makeContainer();
    await container
        .read(automationsProvider.notifier)
        .set(Automation.routineReminders, true);

    expect(prefs.getBool('settings.ritualReminders'), isTrue);
    expect(notifications.daily, [(id: NotificationIds.ritualReminder, time: _reminderTime)]);
  });

  test('a new container reads the saved values', () async {
    final first = makeContainer();
    await first.read(automationsProvider.notifier).set(Automation.spendNudge, false);
    await first
        .read(automationsProvider.notifier)
        .set(Automation.routineReminders, false);

    final second = makeContainer();
    expect(second.read(automationsProvider), {
      Automation.spendNudge: false,
      Automation.routineReminders: false,
    });
  });

  test('spend nudge off keeps the over-budget alert quiet past the budget',
      () async {
    final container = makeContainer();
    await GoalsRepository(db).upsert(Goals(dailyBudget: 50));
    await container.read(automationsProvider.notifier).set(Automation.spendNudge, false);

    await container.read(entryRepositoryProvider).insert(Entry(
          id: '',
          timestamp: DateTime.now(),
          type: EntryType.money,
          title: 'Dinner',
          amount: -60,
          source: EntrySource.manual,
        ));
    await container.read(budgetAlertControllerProvider.notifier).checkAfterSpend();

    expect(prefs.getBool('settings.budgetAlerts'), isFalse);
    expect(notifications.oneShots, isEmpty);
  });

  group('subtitleFor', () {
    test('falls back to the app line without an agenda subtitle', () {
      expect(subtitleFor(Automation.spendNudge, null, _reminderTime),
          "Alerts you when today's spending passes your budget.");
      expect(subtitleFor(Automation.routineReminders, const PalAgenda(), _reminderTime),
          'A daily nudge at 7:30 AM.');
    });

    test("uses the model's line for its id", () {
      const agenda = PalAgenda(autopilotSubtitles: {'spend_nudge': 'Watching \$12 left today.'});
      expect(subtitleFor(Automation.spendNudge, agenda, _reminderTime),
          'Watching \$12 left today.');
      expect(subtitleFor(Automation.routineReminders, agenda, _reminderTime),
          'A daily nudge at 7:30 AM.');
    });
  });
}
