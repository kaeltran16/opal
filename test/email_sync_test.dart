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
import 'package:opal/widgets/app_icon.dart';

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
    address: 'me@gmail.com',
    provider: Provider.gmail,
    appPasswordRef: '',
  );
  @override
  Future<bool> testConnection(EmailAccount a, String p) async => true;
  @override
  Future<void> connect(EmailAccount a, String p) async {}
  @override
  Future<void> updateSenderFilters(List<String> f) async {}
  @override
  Future<List<EmailImportItem>> syncNow() async => _items;
  @override
  Future<void> disconnect() async {}
  @override
  void dispose() => _controller.close();
}

/// A configurable [EmailSyncService] for the setup controller's test-connection
/// lifecycle. [testConnection] either returns [result], throws [error] (if set),
/// or — when [gate] is provided — awaits it first so a second concurrent call
/// can be issued while the first is still in flight (re-entrancy guard test).
class _SetupSyncService implements EmailSyncService {
  _SetupSyncService({this.result = true, this.error, this.gate});

  final bool result;
  final Object? error;
  final Future<void>? gate;
  int testCalls = 0;

  @override
  Future<bool> testConnection(EmailAccount a, String p) async {
    testCalls++;
    if (gate != null) await gate;
    if (error != null) throw error!;
    return result;
  }

  @override
  Stream<SyncStatus> get status => const Stream.empty();
  @override
  bool get isConnected => false;
  @override
  EmailAccount? get account => null;
  @override
  Future<void> connect(EmailAccount a, String p) async {}
  @override
  Future<void> updateSenderFilters(List<String> f) async {}
  @override
  Future<List<EmailImportItem>> syncNow() async => const [];
  @override
  Future<void> disconnect() async {}
  @override
  void dispose() {}
}

const _setupAccount = EmailAccount(
  address: 'me@gmail.com',
  provider: Provider.gmail,
  appPasswordRef: '',
);

/// Pumps a screen inside a minimal GoRouter + ProviderScope harness with the
/// standard overrides (db, prefs, the real mock email service). Uses a local
/// router so the render assertions don't depend on the central route wiring
/// (the orchestrator repoints `/email` → Intro and adds setup/dashboard).
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required SharedPreferences prefs,
  required LoopDatabase db,
  EmailSyncService? service,
}) async {
  final router = GoRouter(
    initialLocation: '/email',
    routes: [
      GoRoute(path: '/email', builder: (_, _) => screen),
      // Targets for pushNamed from the Intro CTA; bodies are inert.
      GoRoute(
        path: '/email/setup',
        name: 'emailSetup',
        builder: (_, _) => const SizedBox(),
      ),
      GoRoute(
        path: '/email/dashboard',
        name: 'emailDashboard',
        builder: (_, _) => const SizedBox(),
      ),
    ],
  );
  final colors = AppColors.light(AppAccent.blue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        emailSyncServiceProvider
            .overrideWithValue(service ?? MockEmailSyncService()),
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
    expect(
      AppPasswordFormatter.format('abcdefghijklmnop'),
      'abcd efgh ijkl mnop',
    );
    // Spaces are normalized regardless of where they were typed.
    expect(
      AppPasswordFormatter.format('abcd efgh ijkl mnop'),
      'abcd efgh ijkl mnop',
    );
    // Over-length input is capped at 16 chars (four groups).
    expect(
      AppPasswordFormatter.format('abcdefghijklmnopqrstuv'),
      'abcd efgh ijkl mnop',
    );
    // Partial input groups as far as it can.
    expect(AppPasswordFormatter.format('abcdef'), 'abcd ef');
  });

  test(
    'AppPasswordFormatter formats live edits via the TextInputFormatter',
    () {
      const formatter = AppPasswordFormatter();
      final out = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'abcdefghijklmnop'),
      );
      expect(out.text, 'abcd efgh ijkl mnop');
      // Caret sits at the end so subsequent typing appends cleanly.
      expect(out.selection.baseOffset, out.text.length);
    },
  );

  // --- Widget: Intro renders the value prop + "How it works" list -----------
  testWidgets('Email Intro renders value prop and provider/how-it-works list', (
    WidgetTester tester,
  ) async {
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
      find.text('iCloud, Outlook, any IMAP coming'),
      200,
    );
    expect(find.text('iCloud, Outlook, any IMAP coming'), findsOneWidget);
  });

  // --- Widget: a connected account skips the cold pitch for the dashboard ----
  // Regression: the Intro is the `/email` entry and the back-stop beneath
  // Setup/Dashboard. When it ignored connection state, backing out of Setup —
  // or reopening Email — showed the first-run pitch, so a saved connection
  // looked lost. Connected → surface the dashboard here instead.
  testWidgets('Email Intro surfaces the dashboard when already connected', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _pump(
      tester,
      const EmailIntroScreen(),
      prefs: prefs,
      db: db,
      service: _StubSyncService(const []),
    );

    // Dashboard hero (connected account), not the cold-start pitch.
    expect(find.text('me@gmail.com'), findsOneWidget);
    expect(find.text('Stop logging card\ncharges by hand.'), findsNothing);
  });

  // --- Widget: Setup renders its credential form without crashing -----------
  // Regression: the screen's root was a bare ColoredBox, so its TextFields had
  // no Material ancestor and the form threw "No Material widget found".
  testWidgets('Email Setup renders the credential form under a Material', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _pump(tester, const EmailSetupScreen(), prefs: prefs, db: db);

    expect(tester.takeException(), isNull);
    expect(find.text('Gmail setup'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  // --- Widget: the sender allowlist lists defaults and supports add/remove ---
  testWidgets('Setup lists the sender allowlist and supports add + remove', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _pump(tester, const EmailSetupScreen(), prefs: prefs, db: db);

    // The three seeded senders render.
    expect(find.text('no-reply@grab.com'), findsOneWidget);
    expect(find.text('info@card.vib.com.vn'), findsOneWidget);
    expect(find.text('info@mail.shopee.vn'), findsOneWidget);

    // Add a sender via the trailing field + submit.
    await tester.enterText(find.byType(TextField).last, 'info@mail.lazada.vn');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('info@mail.lazada.vn'), findsOneWidget);

    // Remove the first sender via its xmark control.
    await tester.tap(find.byIcon(iconForSf('xmark')).first);
    await tester.pump();
    expect(find.text('no-reply@grab.com'), findsNothing);
  });

  // --- Widget: the allowlist flows into the connected account on Save --------
  testWidgets('Setup carries the sender allowlist into the connected account', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Tall viewport so the lazy ListView builds the whole form (the sender
    // section pushes Test/Save below an 800x600 fold otherwise).
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = MockEmailSyncService();
    await _pump(
      tester,
      const EmailSetupScreen(),
      prefs: prefs,
      db: db,
      service: service,
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'me@gmail.com'); // email
    await tester.enterText(fields.at(1), 'abcdefghijklmnop'); // app password

    // Test must succeed before Save unlocks.
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.account, isNotNull);
    expect(service.account!.senderFilters, const [
      'no-reply@grab.com',
      'info@card.vib.com.vn',
      'info@mail.shopee.vn',
    ]);
  });

  // --- Container: syncNow materialises imports as Entries, deduped by ref -----
  test(
    'Dashboard syncNow writes imports as Entries and dedupes on re-sync',
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
          category: 'Shopping',
        ),
        EmailImportItem(
          id: 'msg-2',
          merchant: 'Uber',
          amount: -18.40,
          receivedAt: DateTime(2026, 6, 9, 5),
          category: 'Transport',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          emailSyncServiceProvider.overrideWithValue(_StubSyncService(items)),
          hapticsServiceProvider.overrideWithValue(_NoHaptics()),
        ],
      );
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
    },
  );

  // --- Container: editing the allowlist persists without a reconnect --------
  test('Dashboard setSenderFilters updates the account live (no reconnect)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // A connected account (mock holds it in memory; same EmailSyncService seam).
    final service = MockEmailSyncService();
    await service.connect(
      const EmailAccount(
        address: 'me@gmail.com',
        provider: Provider.gmail,
        appPasswordRef: '',
      ),
      'abcd efgh ijkl mnop',
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        emailSyncServiceProvider.overrideWithValue(service),
        hapticsServiceProvider.overrideWithValue(_NoHaptics()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(emailDashboardControllerProvider, (_, _) {});

    final notifier = container.read(emailDashboardControllerProvider.notifier);
    await notifier.setSenderFilters(const ['no-reply@grab.com', 'info@card.vib.com.vn']);

    // The change lands on the connected account (so the next sync re-sends it)
    // and on the dashboard state (so the UI reflects it) — no reconnect.
    expect(service.account!.senderFilters,
        const ['no-reply@grab.com', 'info@card.vib.com.vn']);
    expect(container.read(emailDashboardControllerProvider).account!.senderFilters,
        const ['no-reply@grab.com', 'info@card.vib.com.vn']);
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
    await entries.insert(
      Entry(
        id: '',
        timestamp: thisMonth,
        type: EntryType.money,
        title: 'A',
        amount: -1,
        source: EntrySource.email,
        sourceRef: 'e1',
      ),
    );
    await entries.insert(
      Entry(
        id: '',
        timestamp: thisMonth,
        type: EntryType.money,
        title: 'B',
        amount: -2,
        source: EntrySource.email,
        sourceRef: 'e2',
      ),
    );
    await entries.insert(
      Entry(
        id: '',
        timestamp: lastMonth,
        type: EntryType.money,
        title: 'C',
        amount: -3,
        source: EntrySource.email,
        sourceRef: 'e3',
      ),
    );
    await entries.insert(
      Entry(
        id: '',
        timestamp: thisMonth,
        type: EntryType.money,
        title: 'manual',
        amount: -4,
        source: EntrySource.manual,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        emailSyncServiceProvider.overrideWithValue(_StubSyncService(const [])),
        hapticsServiceProvider.overrideWithValue(_NoHaptics()),
      ],
    );
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
  test(
    'Dashboard sync prefs reflect and persist via SettingsRepository',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          emailSyncServiceProvider.overrideWithValue(
            _StubSyncService(const []),
          ),
          hapticsServiceProvider.overrideWithValue(_NoHaptics()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(emailDashboardControllerProvider, (_, _) {});

      final notifier = container.read(
        emailDashboardControllerProvider.notifier,
      );

      // Defaults mirror the repository.
      expect(
        container.read(emailDashboardControllerProvider).syncCadence,
        SyncCadence.every15min,
      );
      expect(
        container.read(emailDashboardControllerProvider).autoCategorize,
        isTrue,
      );

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
    },
  );

  // --- Setup controller: the Test-connection lifecycle + Save gating --------
  group('EmailSetupController', () {
    ProviderContainer makeContainer(EmailSyncService service) {
      final container = ProviderContainer(
        overrides: [emailSyncServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'testConnection flips idle→testing→success and unlocks canSave',
      () async {
        // Gate the service so we can observe the in-flight "testing" state.
        final gate = Completer<void>();
        final container = makeContainer(_SetupSyncService(gate: gate.future));
        final setup = container.read(emailSetupControllerProvider.notifier);

        expect(
          container.read(emailSetupControllerProvider).test,
          TestState.idle,
        );
        expect(container.read(emailSetupControllerProvider).canSave, isFalse);

        final pending = setup.testConnection(
          _setupAccount,
          'abcd efgh ijkl mnop',
        );
        expect(
          container.read(emailSetupControllerProvider).test,
          TestState.testing,
        );
        expect(container.read(emailSetupControllerProvider).canSave, isFalse);

        gate.complete();
        await pending;

        expect(
          container.read(emailSetupControllerProvider).test,
          TestState.success,
        );
        expect(container.read(emailSetupControllerProvider).canSave, isTrue);
      },
    );

    test('a thrown testConnection lands on error, not stuck testing', () async {
      final container = makeContainer(
        _SetupSyncService(error: Exception('imap down')),
      );
      final setup = container.read(emailSetupControllerProvider.notifier);

      await setup.testConnection(_setupAccount, 'abcd efgh ijkl mnop');

      expect(
        container.read(emailSetupControllerProvider).test,
        TestState.error,
      );
      expect(container.read(emailSetupControllerProvider).canSave, isFalse);
    });

    test('a false testConnection result lands on error', () async {
      final container = makeContainer(_SetupSyncService(result: false));
      final setup = container.read(emailSetupControllerProvider.notifier);

      await setup.testConnection(_setupAccount, 'short');

      expect(
        container.read(emailSetupControllerProvider).test,
        TestState.error,
      );
      expect(container.read(emailSetupControllerProvider).canSave, isFalse);
    });

    test(
      'the re-entrancy guard ignores a second concurrent testConnection',
      () async {
        final gate = Completer<void>();
        final service = _SetupSyncService(gate: gate.future);
        final container = makeContainer(service);
        final setup = container.read(emailSetupControllerProvider.notifier);

        final first = setup.testConnection(
          _setupAccount,
          'abcd efgh ijkl mnop',
        );
        expect(
          container.read(emailSetupControllerProvider).test,
          TestState.testing,
        );

        // Second call while the first is in flight must short-circuit, not start
        // another service call.
        await setup.testConnection(_setupAccount, 'abcd efgh ijkl mnop');
        expect(service.testCalls, 1);

        gate.complete();
        await first;
        expect(service.testCalls, 1);
        expect(
          container.read(emailSetupControllerProvider).test,
          TestState.success,
        );
      },
    );

    test('markDirty re-locks Save after a successful test', () async {
      final container = makeContainer(_SetupSyncService());
      final setup = container.read(emailSetupControllerProvider.notifier);

      await setup.testConnection(_setupAccount, 'abcd efgh ijkl mnop');
      expect(container.read(emailSetupControllerProvider).canSave, isTrue);

      setup.markDirty();
      expect(container.read(emailSetupControllerProvider).test, TestState.idle);
      expect(container.read(emailSetupControllerProvider).canSave, isFalse);
    });
  });
}
