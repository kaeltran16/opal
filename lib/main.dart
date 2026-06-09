import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'controllers/providers.dart';
import 'data/seed/seeder.dart';

/// Composition root: loads `shared_preferences`, builds the `ProviderScope`
/// (real DB + mock services for now), seeds the DB once, and runs the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
