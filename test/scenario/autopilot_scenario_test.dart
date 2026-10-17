@Tags(['scenario'])
library;

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/profile/profile_screen.dart';
import 'package:opal/screens/settings/notifications_screen.dart';
import 'package:opal/screens/you/autopilot_screen.dart';
import 'package:opal/services/notifications/noop_notification_service.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _spend = 'Spend nudge';
const _reminders = 'Routine reminders';
const _spendFallback = "Alerts you when today's spending passes your budget.";
const _remindersFallback = 'A daily nudge at 9:00 AM.';
const _remindersModel = 'Your evening routine is still open tonight.';

/// The mock with an agenda that fails, as when Pal is offline.
class _OfflinePal extends MockPalService {
  _OfflinePal() : super(latency: Duration.zero, seed: 0);

  @override
  Future<PalAgenda> agenda({List<PlanFact> plan = const [], bool fresh = false}) async =>
      throw StateError('scenario');
}

String _theme(bool dark) => dark ? 'dark' : 'light';

/// Boots the seeded app on [prefs], or on fresh ones, and returns the prefs so
/// a later boot can relaunch on them.
Future<SharedPreferences> _boot(
  WidgetTester tester,
  bool dark, {
  MockPalService? pal,
  SharedPreferences? prefs,
}) async {
  ignoreOverflowErrors();
  if (prefs == null) {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
      'settings.brightness': dark ? 'dark' : 'light',
    });
  }
  final sp = prefs ?? await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  addTearDown(db.close);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider
          .overrideWithValue(pal ?? MockPalService(latency: Duration.zero, seed: 0)),
      notificationServiceProvider.overrideWithValue(const NoopNotificationService()),
      hapticsServiceProvider.overrideWithValue(const NoHaptics()),
    ],
    child: const LoopApp(),
  ));
  await tester.pumpAndSettle();
  return sp;
}

Finder _youList() => find
    .descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable))
    .first;

Finder _switch(String title) => find.descendant(
    of: find.bySemanticsLabel(title), matching: find.byType(CupertinoSwitch));

bool _isOn(WidgetTester tester, String title) =>
    tester.widget<CupertinoSwitch>(_switch(title)).value;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _toYou(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(GlassTabBar), matching: find.text('You')));
  await tester.pumpAndSettle();
}

/// Scrolls You's Autopilot row into view.
Future<void> _toAutopilotRow(WidgetTester tester) async {
  await tester.scrollUntilVisible(
      find.descendant(of: find.byType(ProfileScreen), matching: find.text('Autopilot')).hitTestable(),
      200,
      scrollable: _youList());
  await tester.pumpAndSettle();
}

/// Opens Autopilot from You, switching to You first.
Future<void> _openAutopilot(WidgetTester tester) async {
  await _toYou(tester);
  await _toAutopilotRow(tester);
  await _tap(tester,
      find.descendant(of: find.byType(ProfileScreen), matching: find.text('Autopilot')));
  expect(find.byType(AutopilotScreen), findsOneWidget);
}

Future<void> _backToYou(WidgetTester tester) => _tap(tester,
    find.descendant(of: find.byType(AutopilotScreen), matching: find.text('You')));

void main() {
  scenarioTest('autopilot with model subtitles', (tester, dark) async {
    await _boot(tester, dark);
    await _openAutopilot(tester);

    expect(find.text(_spend), findsOneWidget);
    expect(find.textContaining("Watching today's spend"), findsOneWidget);
    expect(find.text(_reminders), findsOneWidget);
    expect(find.text(_remindersModel), findsOneWidget);
    expect(find.text(_spendFallback), findsNothing);
    expect(_isOn(tester, _spend), isTrue);
    expect(_isOn(tester, _reminders), isTrue);
    await shot(tester, 'autopilot_model_subtitles_${_theme(dark)}');
  });

  scenarioTest('autopilot offline', (tester, dark) async {
    await _boot(tester, dark, pal: _OfflinePal());
    await _openAutopilot(tester);

    expect(find.text(_spend), findsOneWidget);
    expect(find.text(_spendFallback), findsOneWidget);
    expect(find.text(_reminders), findsOneWidget);
    expect(find.text(_remindersFallback), findsOneWidget);
    expect(find.text("Couldn't load autopilot."), findsNothing);
    await shot(tester, 'autopilot_offline_${_theme(dark)}');
  });

  scenarioTest('spend nudge mirrors notifications', (tester, dark) async {
    await _boot(tester, dark);
    await _openAutopilot(tester);
    await _tap(tester, _switch(_spend));
    expect(_isOn(tester, _spend), isFalse);
    await _backToYou(tester);

    appRouter(tester).go('/you/notifications');
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(_isOn(tester, 'Budget alerts'), isFalse);
    expect(_isOn(tester, _reminders), isTrue);
    await shot(tester, 'autopilot_spend_nudge_mirrors_notifications_${_theme(dark)}');
  });

  scenarioTest('you autopilot value', (tester, dark) async {
    await _boot(tester, dark);
    await _toYou(tester);
    await _toAutopilotRow(tester);
    expect(find.bySemanticsLabel('Autopilot, 2 on'), findsOneWidget);

    await _tap(tester,
        find.descendant(of: find.byType(ProfileScreen), matching: find.text('Autopilot')));
    await _tap(tester, _switch(_reminders));
    await _backToYou(tester);
    await _toAutopilotRow(tester);
    expect(find.bySemanticsLabel('Autopilot, 1 on'), findsOneWidget);
    await shot(tester, 'autopilot_you_value_${_theme(dark)}');
  });

  scenarioTest('autopilot after relaunch', (tester, dark) async {
    final prefs = await _boot(tester, dark);
    await _openAutopilot(tester);
    await _tap(tester, _switch(_reminders));
    expect(_isOn(tester, _reminders), isFalse);

    // a fresh scope over the same prefs, as a relaunch reads them.
    await tester.pumpWidget(const SizedBox.shrink());
    await _boot(tester, dark, prefs: prefs);
    await _openAutopilot(tester);

    expect(_isOn(tester, _reminders), isFalse);
    expect(_isOn(tester, _spend), isTrue);
    await shot(tester, 'autopilot_after_relaunch_${_theme(dark)}');
  });
}
