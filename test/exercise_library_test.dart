import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loop/controllers/providers.dart';
import 'package:loop/data/db/database.dart';
import 'package:loop/data/repositories/routine_repository.dart';
import 'package:loop/data/seed/seeder.dart';
import 'package:loop/models/models.dart';
import 'package:loop/screens/library/exercise_library_screen.dart';
import 'package:loop/theme/app_colors.dart';
import 'package:loop/widgets/inset_section.dart';

/// Pumps the Exercise Library wrapped in a MaterialApp carrying the AppColors
/// ThemeExtension (so `context.colors` resolves) + a ProviderScope whose DB is
/// the seeded in-memory one passed in.
///
/// Uses a tall surface so the full grouped catalog (~13 muscle sections) lays
/// out without lazy-list culling, keeping `find.text` assertions simple.
Future<void> _pumpLibrary(
    WidgetTester tester, LoopDatabase db, List<Exercise> catalog) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loopDatabaseProvider.overrideWithValue(db),
        // Feed the screen the seeded catalog as a single-shot, closed stream.
        // This is a screen test (rendering/filtering), not a drift-streaming
        // test: a live `q.watch()` subscription leaves an uncancelled timer
        // that FakeAsync flags as `!timersPending` at end-of-body. A closed
        // `Stream.value` emits once and completes — no pending timer.
        exercisesProvider.overrideWith((ref) => Stream.value(catalog)),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: [AppColors.light(AppAccent.blue)],
        ),
        home: const ExerciseLibraryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoopDatabase db;
  late List<Exercise> catalog;

  setUp(() async {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    // Seed the full catalog (~21 exercises across the 5 groups + routines).
    await Seeder(db).seedIfNeeded();
    // Snapshot the seeded catalog so the screen can be driven by a closed
    // stream (see `_pumpLibrary`) rather than a live drift subscription.
    catalog = await RoutineRepository(db).getAllExercises();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('renders muscle-grouped sections with rows from the seed',
      (tester) async {
    await _pumpLibrary(tester, db, catalog);

    // Grouped sections render (one per muscle present in the catalog).
    expect(find.byType(InsetSection), findsWidgets);
    expect(find.byType(ListRow), findsWidgets);

    // A representative row from several groups is present.
    expect(find.text('Barbell Bench Press'), findsOneWidget); // Push / Chest
    expect(find.text('Back Squat'), findsOneWidget); // Legs / Quads
    expect(find.text('Plank'), findsOneWidget); // Core

    // Muscle section header (InsetSection uppercases it).
    expect(find.text('CHEST'), findsOneWidget);

    // PR value renders for a lift with a fractional PR (bench = 92.5 kg).
    expect(find.text('92.5 kg'), findsOneWidget);
    // A whole-kg PR renders without a decimal (squat = 115 kg).
    expect(find.text('115 kg'), findsOneWidget);
  });

  testWidgets('typing in search filters by name', (tester) async {
    await _pumpLibrary(tester, db, catalog);

    // Baseline: bench + squat both visible.
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Back Squat'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();

    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Back Squat'), findsNothing);
  });

  testWidgets('chip filters by group', (tester) async {
    await _pumpLibrary(tester, db, catalog);

    // Both a Cardio and a Push exercise are present before filtering.
    expect(find.text('Treadmill Run'), findsOneWidget); // Cardio
    expect(find.text('Barbell Bench Press'), findsOneWidget); // Push

    // Tap the "Cardio" filter chip.
    await tester.tap(find.text('Cardio'));
    await tester.pumpAndSettle();

    // Only Cardio exercises remain.
    expect(find.text('Treadmill Run'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsNothing);
    expect(find.text('Back Squat'), findsNothing); // Legs gone too
  });
}
