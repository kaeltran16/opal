import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unmounts the app so Riverpod disposes its providers and Drift's deferred
/// stream-close `Timer` is scheduled, then advances the fake clock to flush it.
///
/// Without this, full-app + real-database boot tests trip flutter_test's
/// end-of-test `!timersPending` invariant: on dispose Drift cancels its stream
/// queries via `StreamQueryStore.markAsClosed`, which posts a `Timer(Duration
/// .zero)` that is still pending when the framework verifies invariants. Call
/// as the last line of such tests.
///
/// The pump also outlasts the stock MockPalService latency (600 ms): Today
/// asks Pal for its brief and agenda on boot, so a test that settles before
/// those replies still has their delay timers pending.
Future<void> flushProviderTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}
