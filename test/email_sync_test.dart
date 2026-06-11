import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/email_sync_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/email/email_intro_screen.dart';
import 'package:opal/screens/email/email_nav.dart';
import 'package:opal/screens/email/email_setup_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/app_colors.dart';

/// A no-op [HapticsService] for container-only controller tests.
class _NoHaptics implements HapticsService {
  @override
  Future<void> light() async {}
  @override
  Future<void> medium() async {}
  @override
  Future<void> success() async {}
}

/// Returns a fixed import list on every [syncNow] so the dedup-on-re-sync path
/// is exercised. Other members are inert.
class _StubSyncService implements EmailSyncService {
  _StubSyncService(this._items);
  final List<EmailImportItem> _items;
  final _controller = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get status => _controller.stream;
  @override
  bool get isConnected => true;
  @override
  EmailAccount? get account => const EmailAccount(
      address: 'me@gmail.com', provider: Provider.gmail, appPasswordRef: '');
  @override
  Future<bool> testConnection(EmailAccount a, String p) async => true;
  @override
  Future<void> connect(EmailAccount a, String p) async {}
  @override
  Future<List<EmailImportItem>> syncNow() async => _items;
  @override
  Future<void> disconnect() async {}
}

/// Pumps a screen inside a minimal GoRouter + ProviderScope harness with the
/// standard overrides (db, prefs, the real mock email service). Uses a local
/// router so the render assertions don't depend on the central route wiring
/// (the orchestrator repoints `/email` → Intro and adds setup/dashboard).
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required SharedPreferences prefs,
  required LoopDatabase db,
}) async {
  final router = GoRouter(
    initialLocation: '/email',
    routes: [
      GoRoute(path: '/email', builder: (_, _) => screen),
      // Targets for pushNamed from the Intro CTA; bodies are inert.
      GoRoute(
          path: '/email/setup',
          name: 'emailSetup',
          builder: (_, _) => const SizedBox()),
      GoRoute(
          path: '/email/dashboard',
          name: 'emailDashboard',
          builder: (_, _) => const SizedBox()),
    ],
  );
  final colors = AppColors.light(AppAccent.blue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        emailSyncServiceProvider.overrideWithValue(MockEmailSyncService()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [colors]),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // --- Pure: 16-char app-password auto-formats into 4-char groups -----------
  test('AppPasswordFormatter groups 16 chars into four 4-char blocks', () {
    expect(AppPasswordFormatter.format('abcdefghijklmnop'),
        'abcd efgh ijkl mnop');
    // Spaces are normalized regardless of where they were typed.
    expect(AppPasswordFormatter.format('abcd efgh ijkl mnop'),
        'abcd efgh ijkl mnop');
    // Over-length input is capped at 16 chars (four groups).
    expect(AppPasswordFormatter.format('abcdefghijklmnopqrstuv'),
        'abcd efgh ijkl mnop');
    // Partial input groups as far as it can.
    expect(AppPasswordFormatter.format('abcdef'), 'abcd ef');
  });

  test('AppPasswordFormatter formats live edits via the TextInputFormatter', () {
    const formatter = AppPasswordFormatter();
    final out = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: 'abcdefghijklmnop'),
    );
    expect(out.text, 'abcd efgh ijkl mnop');
    // Caret sits at the end so subsequent typing appends cleanly.
    expect(out.selection.baseOffset, out.text.length);
  });

  // --- Widget: Intro renders the value prop + "How it works" list -----------
  testWidgets('Email Intro renders value prop and provider/how-it-works list',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _pump(tester, const EmailIntroScreen(), prefs: prefs, db: db);

    // Value prop headline + read-only app-password pitch.
    expect(find.text('Stop logging card\ncharges by hand.'), findsOneWidget);

    // "How it works" section + its three steps.
    expect(find.text('HOW IT WORKS'), findsOneWidget);
    expect(find.text('Your bank sends alerts'), findsOneWidget);
    expect(find.text('Pal reads only those'), findsOneWidget);
    expect(find.text('It lands on Today'), findsOneWidget);

    // Primary CTA + provider/IMAP affordance (below the fold — scroll each in).
    await tester.scrollUntilVisible(find.text('Set up Gmail sync'), 200);
    expect(find.text('Set up Gmail sync'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('iCloud, Outlook, any IMAP coming'), 200);
    expect(find.text('iCloud, Outlook, any IMAP coming'), findsOneWidget);
  });

  // --- Widget: Setup renders its credential form without crashing -----------
  // Regression: the screen's root was a bare ColoredBox, so its TextFields had
  // no Material ancestor and the form threw "No Material widget found".
  testWidgets('Email Setup renders the credential form under a Material',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _pump(tester, const EmailSetupScreen(), prefs: prefs, db: db);

    expect(tester.takeException(), isNull);
    expect(find.text('Gmail setup'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  // --- Container: syncNow materialises imports as Entries, deduped by ref -----
  test('Dashboard syncNow writes imports as Entries and dedupes on re-sync',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final items = [
      EmailImportItem(
          id: 'msg-1',
          merchant: 'Amazon',
          amount: -42.99,
          receivedAt: DateTime(2026, 6, 9, 10),
          category: 'Shopping'),
      EmailImportItem(
          id: 'msg-2',
          merchant: 'Uber',
          amount: -18.40,
          receivedAt: DateTime(2026, 6, 9, 5),
          category: 'Transport'),
    ];

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
      emailSyncServiceProvider.overrideWithValue(_StubSyncService(items)),
      hapticsServiceProvider.overrideWithValue(_NoHaptics()),
    ]);
    addTearDown(container.dispose);
    // pin the autoDispose controller so it survives the awaits below
    container.listen(emailDashboardControllerProvider, (_, _) {});

    final dash = container.read(emailDashboardControllerProvider.notifier);
    final entries = EntryRepository(db);

    await dash.syncNow();
    var all = await entries.getAll();
    expect(all, hasLength(2));
    final amazon = all.firstWhere((e) => e.title == 'Amazon');
    expect(amazon.type, EntryType.money);
    expect(amazon.source, EntrySource.email);
    expect(amazon.sourceRef, 'msg-1');

    // Re-syncing the same message-ids must not create duplicate entries.
    await dash.syncNow();
    all = await entries.getAll();
    expect(all, hasLength(2));
  });

  // --- Container: import counts come from email-sourced entries -------------
  test('Dashboard counts only email-sourced entries; month vs all-time', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final entries = EntryRepository(db);
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 5);
    final lastMonth = DateTime(now.year, now.month - 1, 20);

    // Two email entries this month, one email entry a prior month, and a manual
    // entry this month that must NOT be counted.
    await entries.insert(Entry(
        id: '', timestamp: thisMonth, type: EntryType.money, title: 'A',
        amount: -1, source: EntrySource.email, sourceRef: 'e1'));
    await entries.insert(Entry(
        id: '', timestamp: thisMonth, type: EntryType.money, title: 'B',
        amount: -2, source: EntrySource.email, sourceRef: 'e2'));
    await entries.insert(Entry(
        id: '', timestamp: lastMonth, type: EntryType.money, title: 'C',
        amount: -3, source: EntrySource.email, sourceRef: 'e3'));
    await entries.insert(Entry(
        id: '', timestamp: thisMonth, type: EntryType.money, title: 'manual',
        amount: -4, source: EntrySource.manual));

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
      emailSyncServiceProvider.overrideWithValue(_StubSyncService(const [])),
      hapticsServiceProvider.overrideWithValue(_NoHaptics()),
    ]);
    addTearDown(container.dispose);
    container.listen(emailDashboardControllerProvider, (_, _) {});

    // build() fires the async count refresh; let the DB query + microtask land.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(emailDashboardControllerProvider);
    expect(state.importsAllTime, 3); // three email entries
    expect(state.importsThisMonth, 2); // two of them this month
  });

  // --- Container: sync prefs read from and write back to SettingsRepository -
  test('Dashboard sync prefs reflect and persist via SettingsRepository', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
      emailSyncServiceProvider.overrideWithValue(_StubSyncService(const [])),
      hapticsServiceProvider.overrideWithValue(_NoHaptics()),
    ]);
    addTearDown(container.dispose);
    container.listen(emailDashboardControllerProvider, (_, _) {});

    final notifier = container.read(emailDashboardControllerProvider.notifier);

    // Defaults mirror the repository.
    expect(container.read(emailDashboardControllerProvider).syncCadence,
        SyncCadence.every15min);
    expect(container.read(emailDashboardControllerProvider).autoCategorize,
        isTrue);

    await notifier.setSyncCadence(SyncCadence.hourly);
    await notifier.setImportNotifications(true);
    await notifier.setAutoCategorize(false);

    final state = container.read(emailDashboardControllerProvider);
    expect(state.syncCadence, SyncCadence.hourly);
    expect(state.importNotifications, isTrue);
    expect(state.autoCategorize, isFalse);

    // Persisted: a fresh repository over the same prefs sees the new values.
    final settings = SettingsRepository(prefs);
    expect(settings.syncCadence, SyncCadence.hourly);
    expect(settings.importNotifications, isTrue);
    expect(settings.autoCategorize, isFalse);
  });
}
