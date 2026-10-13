import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flush_provider_timers.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  _FlushOnFailureBinding();
  await testMain();
}

/// Does [flushProviderTimers]' work for a test body that throws before
/// reaching it. flutter_test leaves a failed test's tree mounted, so its
/// providers' Drift streams stay open and the test's `addTearDown(db.close)`
/// waits on them forever, hanging every test after it. Teardowns run outside
/// the fake clock, so this has to happen here, inside the test zone, before
/// the failure propagates.
class _FlushOnFailureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  Future<void> runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester, {
    String description = '',
  }) => super.runTest(
    () async {
      try {
        await testBody();
      } catch (_) {
        await _flush();
        rethrow;
      }
    },
    invariantTester,
    description: description,
  );

  Future<void> _flush() async {
    try {
      runApp(const SizedBox());
      await pump();
      await pump(kProviderTimerFlush);
    } catch (e, st) {
      // the original failure is what the test reports; keep this one visible.
      debugPrint('flush after a failed test failed: $e\n$st');
    }
  }
}
