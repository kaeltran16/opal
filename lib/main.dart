import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'controllers/providers.dart';
import 'data/seed/seeder.dart';

/// Composition root: loads `shared_preferences`, initializes the timezone DB
/// (so U27 local notifications can `zonedSchedule`), builds the `ProviderScope`,
/// seeds the DB once, and runs the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local-notification scheduling resolves times against the device zone.
  // The IANA DB has no web backing, so skip it there (notifications no-op).
  if (!kIsWeb) {
    tzdata.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localZone));
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Seed first-run content before the first frame.
  await Seeder(container.read(loopDatabaseProvider)).seedIfNeeded();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LoopApp(),
    ),
  );
}
