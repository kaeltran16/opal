import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'controllers/providers.dart';
import 'controllers/today_controller.dart';
import 'controllers/watch_log.dart';
import 'controllers/watch_workout.dart';
import 'controllers/widget_sync_controller.dart';
import 'data/seed/seeder.dart';
import 'services/services.dart' show bindWatchChannel;

/// When true (set via `--dart-define=SEED_DATA=true`, e.g. the "dev (seeded)"
/// launch config), the demo user's history is seeded. Defaults to false so real
/// usage builds start with only the reference exercise catalog and no demo data.
const _seedData = bool.fromEnvironment('SEED_DATA');

/// Composition root: loads `shared_preferences`, initializes the timezone DB
/// (so U27 local notifications can `zonedSchedule`), builds the `ProviderScope`,
/// seeds the DB once, and runs the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local-notification scheduling resolves times against the device zone.
  // The IANA DB has no web backing, so skip it there (notifications no-op).
  if (!kIsWeb) {
    tzdata.initializeTimeZones();
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone));
    } catch (e) {
      // a missing/unknown device zone must not crash startup; UTC keeps
      // notification scheduling functional (offset will just be wrong).
      debugPrint('Timezone init failed, falling back to UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // The exercise catalog is reference data the app needs in every build, so it
  // seeds unconditionally. The fake-user demo history stays dev-only.
  final seeder = Seeder(container.read(loopDatabaseProvider));
  await seeder.seedReferenceData();
  if (_seedData) {
    await seeder.seedDemoData();
  }

  // the Watch logs through this engine while it runs (OpalWatchRelay); a
  // write the headless engine made meanwhile reaches these streams by `changed`.
  // Workout commands come only here: the session lives in this engine.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final db = container.read(loopDatabaseProvider);
    final watch = container.read(watchLogProvider);
    unawaited(bindWatchChannel(
      log: watch.log,
      undo: watch.undo,
      workout: container.read(watchWorkoutProvider).handle,
      onChanged: () => db.markTablesUpdated([
        db.entries,
        db.nutritionMeals,
        db.goalsTable,
        db.routines,
        db.routineExercises,
      ]),
    ));
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LoopApp(),
    ),
  );
}

/// Entrypoint of the headless engine OpalWatchRelay starts when a Watch message
/// wakes the app and no app engine is running. It only logs: no UI, seeding,
/// timezone or notification setup. After each change it pushes the rings
/// widget itself, since `WidgetSyncController` lives in the app.
@pragma('vm:entry-point')
Future<void> watchMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  final watch = container.read(watchLogProvider);
  await bindWatchChannel(
    log: watch.log,
    undo: watch.undo,
    afterChange: () => _pushWidget(container),
  );
}

Future<void> _pushWidget(ProviderContainer container) async {
  // listening keeps the auto-dispose today stream alive until it has a value
  final today = container.listen(todayStateProvider.future, (_, _) {});
  try {
    final state = await today.read();
    final currency = container.read(settingsRepositoryProvider).currency;
    await container
        .read(widgetSyncServiceProvider)
        .sync(buildWidgetSnapshot(state.glance, currency, clock.now()));
  } finally {
    today.close();
  }
}
