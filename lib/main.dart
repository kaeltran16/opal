import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'controllers/providers.dart';
import 'data/seed/seeder.dart';

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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LoopApp(),
    ),
  );
}
