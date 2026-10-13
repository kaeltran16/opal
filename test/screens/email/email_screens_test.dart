import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/email_sync_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/email/email_dashboard_screen.dart';
import 'package:opal/screens/email/email_intro_screen.dart';
import 'package:opal/screens/email/email_setup_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/app_colors.dart';

const _connected = EmailAccount(
  address: 'me@gmail.com',
  provider: Provider.gmail,
  appPasswordRef: '',
);

/// An [EmailSyncService] that records calls: connected when [account] is set,
/// and [testResult] decides Test connection.
class _FakeSyncService implements EmailSyncService {
  _FakeSyncService({this.account, this.testResult = true});

  @override
  EmailAccount? account;
  final bool testResult;
  int syncCalls = 0;
  final _status = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get status => _status.stream;
  @override
  bool get isConnected => account != null;
  @override
  Future<bool> testConnection(EmailAccount a, String p) async => testResult;
  @override
  Future<void> connect(EmailAccount a, String p) async => account = a;
  @override
  Future<void> updateSenderFilters(List<String> f) async {}
  @override
  Future<List<EmailImportItem>> syncNow() async {
    syncCalls++;
    return const [];
  }

  @override
  Future<void> disconnect() async => account = null;
  @override
  void dispose() => _status.close();
}

final _colors = AppColors.light();

/// Pumps the email routes as the app nests them, starting at [location].
Future<void> _pump(
  WidgetTester tester,
  _FakeSyncService service, {
  String location = '/email',
  Stream<SyncStatus>? status,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  // tall enough that the whole form is laid out without scrolling.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/email',
        builder: (_, _) => const EmailIntroScreen(),
        routes: [
          GoRoute(
            path: 'setup',
            name: 'emailSetup',
            builder: (_, _) => const EmailSetupScreen(),
          ),
          GoRoute(
            path: 'dashboard',
            name: 'emailDashboard',
            builder: (_, _) => const EmailDashboardScreen(),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        emailSyncServiceProvider.overrideWithValue(service),
        if (status != null) syncStatusProvider.overrideWith((ref) => status),
      ],
      child: MaterialApp.router(
        theme: ThemeData(extensions: [_colors]),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The fill of the pill that holds [label].
Color? _pillFill(WidgetTester tester, String label) {
  final box = tester
      .widgetList<Container>(find.ancestor(of: find.text(label), matching: find.byType(Container)))
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.color != null);
  return box.color;
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

bool _switchValue(WidgetTester tester, String title) => tester
    .widget<CupertinoSwitch>(find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
        matching: find.byType(CupertinoSwitch)))
    .value;

void main() {
  testWidgets('the intro shows the steps and a Connect primary pill that opens setup',
      (tester) async {
    await _pump(tester, _FakeSyncService());

    expect(find.text('Email sync'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    for (final step in [
      'Your bank sends alerts',
      'Pal reads only those',
      'It lands on Today',
    ]) {
      expect(find.text(step), findsOneWidget);
    }
    expect(_pillFill(tester, 'Connect'), _colors.ink);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.byType(EmailSetupScreen), findsOneWidget);
    expect(find.text('Gmail setup'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Email sync'), findsOneWidget);
  });

  testWidgets('setup Save stays inert until a test passes, then connects',
      (tester) async {
    final service = _FakeSyncService();
    await _pump(tester, service, location: '/email/setup');

    expect(_pillFill(tester, 'Save'), _colors.surface2);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(service.account, isNull);
    expect(find.byType(EmailSetupScreen), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'me@gmail.com');
    await tester.enterText(fields.at(1), 'abcdefghijklmnop');
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connected to imap.gmail.com'), findsOneWidget);
    expect(_pillFill(tester, 'Save'), _colors.ink);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(service.account?.address, 'me@gmail.com');
    expect(find.byType(EmailDashboardScreen), findsOneWidget);
  });

  testWidgets('a failed test connection says so in care ink', (tester) async {
    await _pump(tester, _FakeSyncService(testResult: false), location: '/email/setup');

    await tester.enterText(find.byType(TextField).at(1), 'abcdefghijklmnop');
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();

    const failed = 'Connection failed. Check the password.';
    expect(find.text(failed), findsOneWidget);
    expect(_textColor(tester, failed), _colors.careInk);
    expect(_pillFill(tester, 'Save'), _colors.surface2);
  });

  testWidgets('the connected dashboard shows its status and its toggles flip',
      (tester) async {
    await _pump(tester, _FakeSyncService(account: _connected));

    expect(find.byType(EmailDashboardScreen), findsOneWidget);
    expect(find.text('me@gmail.com'), findsOneWidget);
    expect(find.text('Connected · Never synced'), findsOneWidget);
    expect(_textColor(tester, 'Connected · Never synced'), _colors.ink2);
    expect(_pillFill(tester, 'Sync now'), _colors.surface2);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(_textColor(tester, 'Disconnect'), _colors.careInk);

    expect(_switchValue(tester, 'Notify on new detection'), isFalse);
    await tester.tap(find.text('Notify on new detection'));
    await tester.pumpAndSettle();
    expect(_switchValue(tester, 'Notify on new detection'), isTrue);

    expect(_switchValue(tester, 'Pal auto-categorize'), isTrue);
    await tester.tap(find.byType(CupertinoSwitch).last);
    await tester.pumpAndSettle();
    expect(_switchValue(tester, 'Pal auto-categorize'), isFalse);

    final cadence = find.ancestor(
        of: find.text('Background sync'), matching: find.byType(GestureDetector)).first;
    final before = tester
        .widget<Text>(find.descendant(of: cadence, matching: find.byType(Text)).last)
        .data;
    await tester.tap(find.text('Background sync'));
    await tester.pumpAndSettle();
    final after = tester
        .widget<Text>(find.descendant(of: cadence, matching: find.byType(Text)).last)
        .data;
    expect(after, isNot(before));
  });

  testWidgets('a failed sync reads in care ink, beside its words', (tester) async {
    await _pump(
      tester,
      _FakeSyncService(account: _connected),
      status: Stream.value(SyncStatus.error),
    );

    const failed = 'Sync failed. Try again.';
    expect(find.text(failed), findsOneWidget);
    expect(_textColor(tester, failed), _colors.careInk);
  });

  testWidgets('Sync now calls the sync service', (tester) async {
    final service = _FakeSyncService(account: _connected);
    await _pump(tester, service);

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();
    expect(service.syncCalls, 1);
  });

  testWidgets('Disconnect on the email entry turns it back into the intro',
      (tester) async {
    final service = _FakeSyncService(account: _connected);
    await _pump(tester, service);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(service.account, isNull);
    expect(find.byType(EmailDashboardScreen), findsNothing);
    expect(find.text('Stop logging card charges by hand.'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('Disconnect on the pushed dashboard pops back to the intro',
      (tester) async {
    final service = _FakeSyncService(account: _connected);
    await _pump(tester, service, location: '/email/dashboard');
    expect(find.byType(EmailDashboardScreen), findsOneWidget);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(service.account, isNull);
    expect(find.byType(EmailDashboardScreen), findsNothing);
    expect(find.byType(EmailIntroScreen), findsOneWidget);
    expect(find.text('Stop logging card charges by hand.'), findsOneWidget);
  });
}
