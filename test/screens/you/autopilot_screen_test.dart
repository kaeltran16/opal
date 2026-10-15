import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/pal_agenda_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/screens/settings/notifications_screen.dart';
import 'package:opal/screens/you/autopilot_screen.dart';
import 'package:opal/services/notifications/noop_notification_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';

const _spend = 'Spend nudge';
const _reminders = 'Routine reminders';
const _spendFallback = "Alerts you when today's spending passes your budget.";
const _remindersFallback = 'A daily nudge at 9:00 AM.';

/// Opens Autopilot, or Notifications, from a launcher page, as You pushes them.
Future<void> _pump(WidgetTester tester, Future<PalAgenda> Function() agenda) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Widget launch(BuildContext context, String label, Widget screen) => TextButton(
        onPressed: () => Navigator.of(context)
            .push(CupertinoPageRoute<void>(builder: (_) => screen)),
        child: Text(label),
      );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      palAgendaProvider.overrideWith((ref) => agenda()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(const NoopNotificationService()),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
      home: Builder(
        builder: (context) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            launch(context, 'Open autopilot', const AutopilotScreen()),
            launch(context, 'Open notifications', const NotificationsScreen()),
          ],
        ),
      ),
    ),
  ));
  await _open(tester, 'Open autopilot');
}

Future<void> _open(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Finder _switchOf(String title) =>
    find.descendant(of: find.bySemanticsLabel(title), matching: find.byType(CupertinoSwitch));

bool _isOn(WidgetTester tester, String title) =>
    tester.widget<CupertinoSwitch>(_switchOf(title)).value;

void main() {
  testWidgets('both rows show with the fallback lines when the agenda fails',
      (tester) async {
    await _pump(tester, () => Future.error(Exception('pal offline')));

    expect(find.text('Pal'), findsOneWidget);
    expect(find.text('Autopilot'), findsOneWidget);
    expect(find.text(_spend), findsOneWidget);
    expect(find.text(_spendFallback), findsOneWidget);
    expect(find.text(_reminders), findsOneWidget);
    expect(find.text(_remindersFallback), findsOneWidget);
    expect(_isOn(tester, _spend), isTrue);
    expect(_isOn(tester, _reminders), isTrue);
    expect(find.text("Couldn't load autopilot."), findsNothing);
  });

  testWidgets("a row shows the model's line when the agenda has one",
      (tester) async {
    await _pump(
        tester,
        () async => const PalAgenda(
            autopilotSubtitles: {'spend_nudge': 'Watching \$12 left today.'}));

    expect(find.text('Watching \$12 left today.'), findsOneWidget);
    expect(find.text(_spendFallback), findsNothing);
    expect(find.text(_remindersFallback), findsOneWidget);
  });

  testWidgets('tapping a switch flips it and its semantics report it',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, () async => const PalAgenda());

    await tester.tap(_switchOf(_reminders));
    await tester.pumpAndSettle();

    expect(_isOn(tester, _reminders), isFalse);
    expect(
      tester.getSemantics(_switchOf(_reminders)),
      isSemantics(label: _reminders, hasToggledState: true, isToggled: false),
    );
    expect(_isOn(tester, _spend), isTrue);
    handle.dispose();
  });

  testWidgets("flipping Spend nudge off shows off on Notifications' Budget alerts",
      (tester) async {
    await _pump(tester, () async => const PalAgenda());

    await tester.tap(find.text(_spendFallback));
    await tester.pumpAndSettle();
    expect(_isOn(tester, _spend), isFalse);

    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await _open(tester, 'Open notifications');

    expect(_isOn(tester, 'Budget alerts'), isFalse);
    expect(_isOn(tester, _reminders), isTrue);
  });
}
