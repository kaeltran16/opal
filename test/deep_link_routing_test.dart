import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/services/services.dart';

/// U25/U26 — the native deep-link → GoRouter wiring in `app.dart`.
///
/// `LoopApp` subscribes to [SiriShortcutsService.deepLinks] (fed natively by
/// Live-Activity taps and Siri/AppIntents) and `go`es each path. This test
/// drives a fake service so the wiring is exercised without the iOS channel,
/// covering both a streamed (warm) link and the duplicate-suppression guard.
class _FakeSiriShortcutsService implements SiriShortcutsService {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// Emit a deep-link path as if the native bridge produced one.
  void emit(String path) => _controller.add(path);

  @override
  Stream<String> get deepLinks => _controller.stream;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> donateShortcuts() async {}

  @override
  Future<String?> consumeInitialDeepLink() async => null;

  @override
  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }
}

void main() {
  testWidgets('a deep link routes the app to the matching screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final siri = _FakeSiriShortcutsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          siriShortcutsServiceProvider.overrideWithValue(siri),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Boots to Today, not yet on Start Workout.
    expect(find.text("PAL'S PICK FOR TODAY"), findsNothing);

    // A Siri "Start workout" intent / Live-Activity-style deep link arrives.
    siri.emit('/move/start');
    await tester.pumpAndSettle();
    expect(find.text("PAL'S PICK FOR TODAY"), findsOneWidget);

    // Flush the Pal-pick mock-latency timer + drift stream-close timers before
    // teardown (autoDispose drift streams leak a zero-duration close timer).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a /pal deep link pushes the Pal hub above the shell',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final siri = _FakeSiriShortcutsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          siriShortcutsServiceProvider.overrideWithValue(siri),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The canonical Pal path is /pal (the old /pal-home, /pal-inbox redirect to
    // it). It must be treated as an above-shell overlay route and pushed, not
    // go'd — otherwise the hub replaces the whole stack and looks stuck.
    siri.emit('/pal');
    await tester.pumpAndSettle();
    expect(find.text('Needs you'), findsOneWidget);

    // Flush the agenda/brief mock-latency + drift stream-close timers.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an immediate duplicate deep link is ignored',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final siri = _FakeSiriShortcutsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          siriShortcutsServiceProvider.overrideWithValue(siri),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Open the New Entry sheet via deep link.
    siri.emit('/entry/new');
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsOneWidget);

    // A warm Siri intent both pushes over the channel AND re-opens the URL, so
    // the same path can fire twice in a beat — the dedup guard must drop the
    // second so we don't stack a second identical sheet.
    siri.emit('/entry/new');
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsOneWidget);

    // Flush the New Entry sheet's pending timers before teardown.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
