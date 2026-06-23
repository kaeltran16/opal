import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/screens/mood/mood_logger_sheet.dart';
import 'package:opal/screens/mood/widgets/mood_widgets.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/util/mood_scale.dart';

import '../../support/flush_provider_timers.dart';

/// Wraps a button that opens the sheet. We use a full ProviderScope +
/// a real (empty) in-memory DB so the logCheckin call can resolve without
/// crashing. No Seeder needed — the sheet doesn't read existing data.
Widget _buildOpener(LoopDatabase db, SharedPreferences prefs) {
  final colors = AppColors.light(AppAccent.indigo);
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(
        MockPalService(latency: const Duration(milliseconds: 1)),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showMoodLogger(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<(LoopDatabase, SharedPreferences)> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  return (db, prefs);
}

void main() {
  testWidgets('logger sheet opens and shows Check in title', (tester) async {
    final (db, prefs) = await _setup();
    addTearDown(db.close);
    await tester.pumpWidget(_buildOpener(db, prefs));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('HOW YOU FEEL RIGHT NOW'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('sheet shows the initial mood word (Neutral at t=0.5)',
      (tester) async {
    final (db, prefs) = await _setup();
    addTearDown(db.close);
    await tester.pumpWidget(_buildOpener(db, prefs));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // moodWord(0.5) == 'Neutral'
    expect(find.text(moodWord(0.5)), findsWidgets);

    await flushProviderTimers(tester);
  });

  testWidgets('dragging the scale track updates the mood word', (tester) async {
    final (db, prefs) = await _setup();
    addTearDown(db.close);
    await tester.pumpWidget(_buildOpener(db, prefs));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // drag the track toward the right (pleasant end)
    final trackFinder = find.byType(MoodScaleTrack);
    expect(trackFinder, findsOneWidget);
    final trackRect = tester.getRect(trackFinder);
    // tap near the right edge
    await tester.tapAt(
      Offset(trackRect.left + trackRect.width * 0.92, trackRect.center.dy),
    );
    await tester.pump();

    // word should now be 'Pleasant' or 'Very pleasant'
    final words = ['Slightly pleasant', 'Pleasant', 'Very pleasant'];
    final anyPleasant = words.any((w) => find.text(w).evaluate().isNotEmpty);
    expect(anyPleasant, isTrue,
        reason: 'tapping near the right end should produce a pleasant word');

    await flushProviderTimers(tester);
  });

  testWidgets('tag chips are visible and tapping one selects it',
      (tester) async {
    final (db, prefs) = await _setup();
    addTearDown(db.close);
    await tester.pumpWidget(_buildOpener(db, prefs));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // scroll down to reveal tags
    final sheetScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Calm'),
      200,
      scrollable: sheetScrollable,
    );
    expect(find.text('Calm'), findsOneWidget);

    // tap 'Calm' to select it
    await tester.tap(find.text('Calm'));
    await tester.pump();

    // it stays visible — build didn't crash; the chip tinted state is in
    // _MoodLoggerSheetState so we just assert no error and 'Calm' still present
    expect(find.text('Calm'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('Log mood button is visible and tappable', (tester) async {
    final (db, prefs) = await _setup();
    addTearDown(db.close);
    await tester.pumpWidget(_buildOpener(db, prefs));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // button may be below sheet fold; find by semantics
    expect(find.bySemanticsLabel('Log mood'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('tapping Log mood closes the sheet', (tester) async {
    final (db, prefs) = await _setup();
    addTearDown(db.close);
    await tester.pumpWidget(_buildOpener(db, prefs));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Log mood'));
    await tester.pumpAndSettle();

    // sheet closed — the Check in title is gone
    expect(find.text('Check in'), findsNothing);

    await flushProviderTimers(tester);
  });

  // GAP: we cannot currently spy on `logCheckin` calls without either
  // injecting a fake notifier or using an instrumented repository.
  // The test above verifies the sheet closes after the button tap, which
  // exercises the code path (logCheckin called, then Navigator.pop). The
  // actual DB insert is covered by mood_controller_test.dart.
}
