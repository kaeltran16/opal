import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/routine_editor_controller.dart';
import 'package:opal/data/db/database.dart' show LoopDatabase;
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/workout/routine_editor_screen.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/controls.dart';
import 'package:opal/widgets/exercise_row.dart';
import 'package:opal/widgets/inset_section.dart';
import 'package:opal/widgets/nav_bar.dart';

/// Builds a ProviderContainer with the standard in-memory overrides used
/// across the suite.
ProviderContainer _container(SharedPreferences prefs, LoopDatabase db) =>
    ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
      ],
    );

const _legDay = 'seed-routine-legs';
// tall enough that the whole editor lays out without lazy-list culling.
const _surface = Size(390, 2400);

/// Pumps the editor over a seeded in-memory database.
Future<void> _pumpEditor(WidgetTester tester, LoopDatabase db, {String? routineId}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _surface;
  addTearDown(tester.view.reset);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
      home: RoutineEditorScreen(routineId: routineId),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _navButton(String label) =>
    find.byWidgetPredicate((w) => w is NavIconButton && w.semanticLabel == label);

Finder get _search =>
    find.descendant(of: find.byType(SearchPill), matching: find.byType(TextField));

PillButton _save(WidgetTester tester) => tester.widget<PillButton>(
    find.byWidgetPredicate((w) => w is PillButton && w.label == 'Save'));

Future<void> _addExercise(WidgetTester tester, String query, String name) async {
  await tester.tap(find.text('Add exercise'));
  await tester.pumpAndSettle();
  await tester.enterText(_search, query);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ExerciseRow, name));
  await tester.pumpAndSettle();
}

/// colours painted by boxes between a row icon and its row.
Iterable<Color?> _paintedAroundRowIcons(WidgetTester tester) {
  final rows = find.byWidgetPredicate((w) => w is ExerciseRow || w is ListRow);
  final boxes = find.ancestor(
    of: find.descendant(of: rows, matching: find.byType(AppIcon)),
    matching: find.descendant(
      of: rows,
      matching:
          find.byWidgetPredicate((w) => w is Container || w is DecoratedBox || w is ColoredBox),
    ),
  );
  return tester.widgetList(boxes).map((w) => switch (w) {
        Container(:final color, :final decoration) =>
          color ?? (decoration is BoxDecoration ? decoration.color : null),
        DecoratedBox(:final decoration) => decoration is BoxDecoration ? decoration.color : null,
        ColoredBox(:final color) => color,
        _ => null,
      });
}

void main() {
  // ---------------------------------------------------------------------------
  // Pure — reindex rewrites order to match list position.
  // ---------------------------------------------------------------------------
  test('reindex assigns order to match list position', () {
    RoutineExercise ex(String id, int order) =>
        RoutineExercise(id: id, exerciseId: 'e-$id', order: order);

    // A list whose stored orders are stale after a move (b moved before a).
    final reordered = reindex([ex('b', 1), ex('a', 0), ex('c', 2)]);

    expect(reordered.map((e) => e.id).toList(), ['b', 'a', 'c']);
    expect(reordered.map((e) => e.order).toList(), [0, 1, 2]);
  });

  // ---------------------------------------------------------------------------
  // Create path — build a new routine via the controller and persist it.
  // ---------------------------------------------------------------------------
  test('controller creates a new routine with ordered exercises', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final container = _container(prefs, db);
    addTearDown(container.dispose);

    final provider = routineEditorControllerProvider(null);
    container.listen(provider, (_, _) {}); // hold across awaits (autoDispose)
    await container.read(provider.future);
    final c = container.read(provider.notifier);

    c.setName('Test Routine');
    c.setTag(RoutineTag.full);
    c.setRest(90);
    c.toggleWarmup(true);
    c.addExercise('bench');
    c.addExercise('squat');
    await c.save();

    final repo = container.read(routineRepositoryProvider);
    final all = await repo.getAll();
    final created = all.firstWhere((r) => r.name == 'Test Routine');

    expect(created.tag, RoutineTag.full);
    expect(created.restSeconds, 90);
    expect(created.warmupReminder, true);
    expect(created.orderedExercises.map((e) => e.exerciseId).toList(),
        ['bench', 'squat']);
    expect(created.orderedExercises.map((e) => e.order).toList(), [0, 1]);
  });

  // ---------------------------------------------------------------------------
  // Edit path — load a seeded routine, rename + reorder, persist via update.
  // ---------------------------------------------------------------------------
  test('controller edits a seeded routine: rename + reorder persist', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final container = _container(prefs, db);
    addTearDown(container.dispose);

    final provider = routineEditorControllerProvider('seed-routine-legs');
    container.listen(provider, (_, _) {}); // hold across awaits (autoDispose)
    final loaded = await container.read(provider.future);
    final c = container.read(provider.notifier);

    // Sanity: the seeded leg day loaded with its slots in order.
    final originalFirst = loaded.draft.orderedExercises.first.exerciseId;
    expect(originalFirst, 'squat');

    c.setName('Leg Day v2');
    // Move the first slot to the end (onReorderItem gives a post-removal index).
    c.reorder(0, loaded.draft.exercises.length - 1);
    await c.save();

    final repo = container.read(routineRepositoryProvider);
    final updated = await repo.getById('seed-routine-legs');

    expect(updated, isNotNull);
    expect(updated!.name, 'Leg Day v2');
    // The previously-first exercise now sits last, and order is contiguous.
    expect(updated.orderedExercises.last.exerciseId, originalFirst);
    expect(updated.orderedExercises.map((e) => e.order).toList(),
        List.generate(updated.exercises.length, (i) => i));
  });

  // ---------------------------------------------------------------------------
  // Screen — the editor over a seeded database.
  // ---------------------------------------------------------------------------
  group('editor screen', () {
    late LoopDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = LoopDatabase.forTesting(NativeDatabase.memory());
      await Seeder(db).seedIfNeeded();
    });
    tearDown(() => db.close());

    testWidgets('the add exercise sheet filters by search and adds the tapped exercise',
        (tester) async {
      await _pumpEditor(tester, db);
      expect(find.text('Exercises · 0'), findsOneWidget);

      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ExerciseRow, 'Back Squat'), findsOneWidget);

      await tester.enterText(_search, 'bench');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ExerciseRow, 'Back Squat'), findsNothing);
      expect(find.text('Chest · Barbell'), findsOneWidget);

      await tester.tap(find.widgetWithText(ExerciseRow, 'Barbell Bench Press'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchPill), findsNothing);
      expect(find.text('Exercises · 1'), findsOneWidget);
      expect(find.widgetWithText(ExerciseRow, 'Barbell Bench Press'), findsOneWidget);
    });

    testWidgets("the targets sheet's steppers change sets and reps", (tester) async {
      await _pumpEditor(tester, db, routineId: _legDay);
      expect(find.text('4 × 5 · 110 kg'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Edit targets for Back Squat'));
      await tester.pumpAndSettle();
      expect(find.text('Targets'), findsOneWidget);

      await tester.tap(_navButton('Increase Sets'));
      await tester.tap(_navButton('Decrease Reps'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Sets, 5'), findsOneWidget);
      expect(find.bySemanticsLabel('Reps, 4'), findsOneWidget);

      await tester.tap(find.widgetWithText(PillButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.text('5 × 4 · 110 kg'), findsOneWidget);
    });

    testWidgets('the toggles are app switches that flip the draft', (tester) async {
      await _pumpEditor(tester, db);
      AppSwitch toggle(String label) => tester.widget<AppSwitch>(
          find.byWidgetPredicate((w) => w is AppSwitch && w.semanticLabel == label));

      expect(find.byType(AppSwitch), findsNWidgets(2));
      expect(toggle('Warmup reminder').value, isFalse);
      expect(toggle('Auto-progress weights').value, isFalse);

      await tester.tap(find.byWidgetPredicate(
          (w) => w is AppSwitch && w.semanticLabel == 'Warmup reminder'));
      await tester.tap(find.byWidgetPredicate(
          (w) => w is AppSwitch && w.semanticLabel == 'Auto-progress weights'));
      await tester.pumpAndSettle();

      expect(toggle('Warmup reminder').value, isTrue);
      expect(toggle('Auto-progress weights').value, isTrue);
    });

    testWidgets('save is disabled until a name and an exercise exist', (tester) async {
      await _pumpEditor(tester, db);
      expect(_save(tester).onTap, isNull);

      await tester.enterText(find.byType(TextField), 'Push day');
      await tester.pumpAndSettle();
      expect(_save(tester).onTap, isNull);

      await _addExercise(tester, 'bench', 'Barbell Bench Press');
      expect(_save(tester).onTap, isNotNull);

      await tester.enterText(find.byType(TextField), '  ');
      await tester.pumpAndSettle();
      expect(_save(tester).onTap, isNull);
    });

    testWidgets('no row icon sits on a coloured tile', (tester) async {
      await _pumpEditor(tester, db, routineId: _legDay);

      expect(find.byType(ExerciseRow), findsWidgets);
      expect(_paintedAroundRowIcons(tester).whereType<Color>(), isEmpty);
    });
  });
}
