import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/autopilot_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/screens/settings/about_screen.dart';
import 'package:opal/screens/settings/appearance_screen.dart';
import 'package:opal/screens/settings/export_data_screen.dart';
import 'package:opal/screens/settings/notifications_screen.dart';
import 'package:opal/screens/settings/privacy_screen.dart';
import 'package:opal/services/notifications/notification_service.dart';
import 'package:opal/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reports a fixed permission and records the daily schedules.
class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({this.granted = true});

  final bool granted;
  final List<int> daily = [];

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermissions() async => granted;

  @override
  Future<void> schedule(NotificationRequest request) async {}

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async =>
      daily.add(id);

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  late LoopDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'settings.brightness': 'dark',
      'settings.ritualReminders': false,
      'settings.budgetAlerts': false,
    });
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    _FakeNotificationService? notifications,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loopDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider
              .overrideWithValue(notifications ?? _FakeNotificationService()),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester, Type screen) =>
      ProviderScope.containerOf(tester.element(find.byType(screen)));

  group('chrome', () {
    final screens = <String, Widget>{
      'Notifications': const NotificationsScreen(),
      'Data and privacy': const PrivacyScreen(),
      'About': const AboutScreen(),
      'Appearance': const AppearanceScreen(),
      'Export data': const ExportDataScreen(),
    };
    for (final MapEntry(key: title, value: screen) in screens.entries) {
      testWidgets('$title has its title and a back to You', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, screen);

        expect(find.text(title), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.bySemanticsLabel('Back to You'), findsOneWidget);
        semantics.dispose();
      });
    }
  });

  testWidgets('About shows the app name as a title', (tester) async {
    await pump(tester, const AboutScreen());

    final style = tester.widget<Text>(find.text('Opal')).style!;
    expect(style.fontSize, AppType.title.fontSize);
    expect(style.fontWeight, AppType.title.fontWeight);
  });

  testWidgets('Appearance: tapping Light switches the theme', (tester) async {
    await pump(tester, const AppearanceScreen());
    final container = containerOf(tester, AppearanceScreen);
    expect(container.read(appSettingsControllerProvider).brightness, Brightness.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsControllerProvider).brightness, Brightness.light);
    expect(prefs.getString('settings.brightness'), 'light');
  });

  group('Export', () {
    MethodCall? copied;

    void mockClipboard(WidgetTester tester, {required bool fails}) {
      copied = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method != 'Clipboard.setData') return null;
          if (fails) throw PlatformException(code: 'clipboard');
          copied = call;
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
    }

    testWidgets('the primary pill copies the entries and says so', (tester) async {
      mockClipboard(tester, fails: false);
      await pump(tester, const ExportDataScreen());

      await tester.tap(find.text('Copy 0 entries as JSON'));
      await tester.pumpAndSettle();

      expect((copied!.arguments as Map)['text'], '[]');
      expect(find.text('Copied 0 entries to the clipboard.'), findsOneWidget);
    });

    testWidgets('a failing copy shows the error', (tester) async {
      mockClipboard(tester, fails: true);
      await pump(tester, const ExportDataScreen());

      await tester.tap(find.text('Copy 0 entries as JSON'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't copy. Try again."), findsOneWidget);
      expect(find.textContaining('Copied'), findsNothing);
    });
  });

  group('Notifications', () {
    bool switchValue(WidgetTester tester, String title) => tester
        .widget<CupertinoSwitch>(find.descendant(
          of: find.ancestor(of: find.text(title), matching: find.byType(GestureDetector)).first,
          matching: find.byType(CupertinoSwitch),
        ))
        .value;

    testWidgets('both toggles flip and persist', (tester) async {
      final service = _FakeNotificationService();
      await pump(tester, const NotificationsScreen(), notifications: service);
      expect(switchValue(tester, 'Routine reminders'), isFalse);
      expect(switchValue(tester, 'Budget alerts'), isFalse);
      expect(find.text('Reminder time'), findsNothing);

      await tester.tap(find.text('Routine reminders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budget alerts'));
      await tester.pumpAndSettle();

      expect(switchValue(tester, 'Routine reminders'), isTrue);
      expect(switchValue(tester, 'Budget alerts'), isTrue);
      expect(prefs.getBool('settings.ritualReminders'), isTrue);
      expect(prefs.getBool('settings.budgetAlerts'), isTrue);
      expect(find.text('Reminder time'), findsOneWidget);
      expect(service.daily, [NotificationIds.ritualReminder]);
    });

    testWidgets('the toggles are the Autopilot switches', (tester) async {
      await pump(tester, const NotificationsScreen());
      final container = containerOf(tester, NotificationsScreen);
      expect(container.read(automationsProvider)[Automation.spendNudge], isFalse);

      await tester.tap(find.text('Budget alerts'));
      await tester.pumpAndSettle();

      final automations = container.read(automationsProvider);
      expect(automations[Automation.spendNudge], isTrue);
      expect(automations[Automation.routineReminders], isFalse);
    });

    testWidgets('without permission an on toggle shows the not-allowed row',
        (tester) async {
      await prefs.setBool('settings.budgetAlerts', true);
      await pump(tester, const NotificationsScreen(),
          notifications: _FakeNotificationService(granted: false));

      expect(find.text('Not allowed yet'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);

      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Denied'), findsOneWidget);
    });
  });
}
