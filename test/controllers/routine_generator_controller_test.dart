import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/routine_generator_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/services/services.dart';

/// A PalService whose only exercised seam is [generateRoutine]: it returns a
/// fixed draft, or throws, so we can drive the controller's success and failure
/// branches deterministically. Everything else is unused.
class _FakePal implements PalService {
  _FakePal({this.fails = false});

  final bool fails;
  int generateCalls = 0;
  String? lastGoal;

  @override
  Future<GeneratedRoutineDraft> generateRoutine(
    String goal,
    List<Exercise> available,
  ) async {
    generateCalls++;
    lastGoal = goal;
    if (fails) throw const PalException('routine generation failed');
    return const GeneratedRoutineDraft(
      name: 'Generated Push',
      tag: RoutineTag.upper,
      exercises: [
        GeneratedExerciseDraft(
          exerciseId: 'bench',
          sets: [GeneratedSetDraft(reps: 8, weightKg: 50)],
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // The controller's build() watches exercisesProvider, which streams from the
  // routine repo over loopDatabaseProvider — so an in-memory db is needed for
  // the catalog to resolve. palServiceProvider is the generate seam under test.
  ProviderContainer containerWith(LoopDatabase db, PalService pal) {
    final c = ProviderContainer(
      overrides: [
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(pal),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('RoutineGeneratorController.generate', () {
    test('starts idle', () {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final c = containerWith(db, _FakePal());

      expect(
        c.read(routineGeneratorControllerProvider),
        isA<RoutineGeneratorIdle>(),
      );
    });

    test('success surfaces a result carrying the generated draft', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final pal = _FakePal();
      final c = containerWith(db, pal);

      await c
          .read(routineGeneratorControllerProvider.notifier)
          .generate('build a push day');

      final state = c.read(routineGeneratorControllerProvider);
      expect(state, isA<RoutineGeneratorResult>());
      final result = state as RoutineGeneratorResult;
      expect(result.draft.name, 'Generated Push');
      expect(result.draft.exercises.single.exerciseId, 'bench');
      expect(pal.generateCalls, 1);
      expect(pal.lastGoal, 'build a push day'); // trimmed goal forwarded
    });

    test(
      'trims the goal before asking Pal and ignores surrounding whitespace',
      () async {
        final db = LoopDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final pal = _FakePal();
        final c = containerWith(db, pal);

        await c
            .read(routineGeneratorControllerProvider.notifier)
            .generate('   legs   ');

        expect(pal.lastGoal, 'legs');
      },
    );

    test('a blank goal is a no-op: stays idle and never calls Pal', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final pal = _FakePal();
      final c = containerWith(db, pal);

      await c.read(routineGeneratorControllerProvider.notifier).generate('   ');

      expect(
        c.read(routineGeneratorControllerProvider),
        isA<RoutineGeneratorIdle>(),
      );
      expect(pal.generateCalls, 0);
    });

    test(
      'a thrown service error is swallowed into an error state, not rethrown',
      () async {
        // The key untested branch the audit flagged: generate() must catch the
        // PalService failure and expose RoutineGeneratorError without letting the
        // exception escape.
        final db = LoopDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final c = containerWith(db, _FakePal(fails: true));
        final notifier = c.read(routineGeneratorControllerProvider.notifier);

        // does not throw out of generate()
        await expectLater(notifier.generate('boom'), completes);

        final state = c.read(routineGeneratorControllerProvider);
        expect(state, isA<RoutineGeneratorError>());
        expect(
          (state as RoutineGeneratorError).message,
          'Could not generate routine. Try again?',
        );
      },
    );
  });

  group('RoutineGeneratorController.reset', () {
    test('clears an error back to idle', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final c = containerWith(db, _FakePal(fails: true));
      final notifier = c.read(routineGeneratorControllerProvider.notifier);

      await notifier.generate('boom');
      expect(
        c.read(routineGeneratorControllerProvider),
        isA<RoutineGeneratorError>(),
      );

      notifier.reset();
      expect(
        c.read(routineGeneratorControllerProvider),
        isA<RoutineGeneratorIdle>(),
      );
    });
  });
}
