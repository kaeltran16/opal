import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart' hide ExerciseRow;
import 'package:opal/data/repositories/routine_repository.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/library/exercise_library_screen.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/controls.dart';
import 'package:opal/widgets/exercise_row.dart';
import 'package:opal/widgets/inset_section.dart';
import 'package:opal/widgets/nav_bar.dart';

/// Pumps the Exercise Library wrapped in a MaterialApp carrying the AppColors
/// ThemeExtension (so `context.colors` resolves) + a ProviderScope whose DB is
/// the seeded in-memory one passed in.
///
/// Uses a tall surface so the full grouped catalog (5 group sections) lays
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
          extensions: [AppColors.light()],
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
    // Seed the full catalog (~36 exercises across the 5 groups + routines).
    await Seeder(db).seedIfNeeded();
    // Snapshot the seeded catalog so the screen can be driven by a closed
    // stream (see `_pumpLibrary`) rather than a live drift subscription.
    catalog = await RoutineRepository(db).getAllExercises();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('uses the shared large-title nav bar (matches sibling screens)',
      (tester) async {
    await _pumpLibrary(tester, db, catalog);

    expect(find.byType(LargeTitleNavBar), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
  });

  testWidgets('renders group-grouped sections with rows from the seed',
      (tester) async {
    await _pumpLibrary(tester, db, catalog);

    // Grouped sections render (one per group present in the catalog).
    expect(find.byType(InsetSection), findsWidgets);

    // A representative row from several groups is present.
    expect(find.text('Barbell Bench Press'), findsOneWidget); // Push
    expect(find.text('Back Squat'), findsOneWidget); // Legs
    expect(find.text('Plank'), findsOneWidget); // Core

    // Group section headers, as written (the filter chips share the names).
    Finder header(String group) =>
        find.descendant(of: find.byType(InsetSection), matching: find.text(group));
    expect(header('Push'), findsOneWidget);
    expect(header('Legs'), findsOneWidget);
    expect(header('Core'), findsOneWidget);

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

  testWidgets('chip filters by group and reports selected', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpLibrary(tester, db, catalog);

    // Both a Cardio and a Push exercise are present before filtering.
    expect(find.text('Treadmill Run'), findsOneWidget); // Cardio
    expect(find.text('Barbell Bench Press'), findsOneWidget); // Push

    Finder chip(String label) =>
        find.widgetWithText(AppChip, label);
    expect(tester.getSemantics(chip('All')), matchesSemantics(
      isButton: true,
      hasSelectedState: true,
      isSelected: true,
      hasTapAction: true,
      label: 'All',
    ));

    await tester.tap(chip('Cardio'));
    await tester.pumpAndSettle();

    // Only Cardio exercises remain.
    expect(find.text('Treadmill Run'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsNothing);
    expect(find.text('Back Squat'), findsNothing); // Legs gone too
    expect(tester.getSemantics(chip('Cardio')), matchesSemantics(
      isButton: true,
      hasSelectedState: true,
      isSelected: true,
      hasTapAction: true,
      label: 'Cardio',
    ));
    expect(tester.getSemantics(chip('All')), matchesSemantics(
      isButton: true,
      hasSelectedState: true,
      hasTapAction: true,
      label: 'All',
    ));
    handle.dispose();
  });

  testWidgets('a search with no match shows the empty line', (tester) async {
    await _pumpLibrary(tester, db, catalog);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseRow), findsNothing);
    expect(find.text('No exercises match "zzz".'), findsOneWidget);
  });

  testWidgets('rows are ExerciseRows with no coloured icon tile',
      (tester) async {
    await _pumpLibrary(tester, db, catalog);

    final row = find.widgetWithText(ExerciseRow, 'Back Squat');
    expect(row, findsOneWidget);
    // detail is muscle · equipment; the PR is the value.
    final squat = catalog.firstWhere((e) => e.name == 'Back Squat');
    expect(tester.widget<ExerciseRow>(row).detail,
        '${squat.muscle} · ${squat.equipment}');
    expect(tester.widget<ExerciseRow>(row).value, '115 kg');

    final icons = find.descendant(
        of: find.byType(ExerciseRow), matching: find.byType(AppIcon));
    expect(icons, findsWidgets);
    for (final icon in icons.evaluate()) {
      final tiles = tester
          .widgetList(find.ancestor(
              of: find.byWidget(icon.widget),
              matching: find.byWidgetPredicate(
                  (w) => w is Container || w is DecoratedBox)))
          .map(_decoration)
          .where((d) => d?.color != null);
      expect(tiles, isEmpty);
    }
  });
}

BoxDecoration? _decoration(Widget w) => switch (w) {
      Container(decoration: final BoxDecoration d) => d,
      DecoratedBox(decoration: final BoxDecoration d) => d,
      _ => null,
    };
