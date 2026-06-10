import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [HapticsService] that records how many times each method was called, so the
/// toggle path can assert the light haptic fired (no-op on web in production).
class _SpyHaptics implements HapticsService {
  int lightCount = 0;
  @override
  Future<void> light() async => lightCount++;
  @override
  Future<void> medium() async {}
  @override
  Future<void> success() async {}
}

void main() {
  testWidgets(
      'Rituals tab: tapping a check writes a ritual Entry and increments the count',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed three rituals in display order.
    final rituals = RitualRepository(db);
    await rituals.insert(
        const Ritual(id: 'r-pages', title: 'Morning pages', icon: 'book.closed.fill', order: 0, streak: 4));
    await rituals.insert(
        const Ritual(id: 'r-read', title: 'Read', icon: 'books.vertical.fill', order: 1));
    await rituals.insert(
        const Ritual(id: 'r-water', title: 'Drink water', icon: 'sparkles', order: 2));

    final entries = EntryRepository(db);
    final haptics = _SpyHaptics();

    // Start the router directly on the Rituals tab so the screen is mounted.
    final router = createRouter(initialLocation: '/rituals');
    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          hapticsServiceProvider.overrideWithValue(haptics),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The progress card starts at "0 / 3" (rendered as one rich Text).
    expect(find.text('0 / 3'), findsOneWidget);

    // Helper: read all entries via a real-async drift Future (drift queries
    // need uncontrolled async, so wrap in runAsync).
    Future<List<Entry>> allEntries() async =>
        (await tester.runAsync(() => entries.getAll()))!;

    // No ritual entries logged yet.
    var all = await allEntries();
    expect(all.where((e) => e.type == EntryType.rituals), isEmpty);

    // Tap the first ritual's CheckButton.
    final checks = find.byType(CheckButton);
    expect(checks, findsNWidgets(3));
    await tester.tap(checks.first);
    await tester.pumpAndSettle();

    // A ritual-type Entry was written (so the Today rituals ring updates).
    all = await allEntries();
    final ritualEntries = all.where((e) => e.type == EntryType.rituals).toList();
    expect(ritualEntries, hasLength(1));
    expect(ritualEntries.single.ritualId, 'r-pages');
    expect(ritualEntries.single.source, EntrySource.manual);

    // Light haptic fired (no-op in production on web).
    expect(haptics.lightCount, 1);

    // The count card now reads "1 / 3".
    expect(find.text('1 / 3'), findsOneWidget);

    // Tapping again removes today's entry (toggle off) — count back to 0.
    await tester.tap(find.byType(CheckButton).first);
    await tester.pumpAndSettle();
    all = await allEntries();
    expect(all.where((e) => e.type == EntryType.rituals), isEmpty);
  });
}
