import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

import '../support/legacy_schema.dart';

const _pho = MealEstimate(
  name: 'Pho bo',
  cal: IntRange(450, 620),
  confidence: NutritionConfidence.med,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeFoodKey', () {
    test('collapses case, punctuation and whitespace', () {
      expect(normalizeFoodKey('Pho bo!'), 'pho bo');
      expect(normalizeFoodKey('  pho   BO '), 'pho bo');
      expect(normalizeFoodKey('pho-bo'), 'pho bo');
    });

    test('keeps accented letters instead of stripping them', () {
      expect(normalizeFoodKey('Phở bò'), 'phở bò');
      expect(normalizeFoodKey('Phở-bò'), normalizeFoodKey('Phở bò'));
    });

    test('does not conflate different dishes', () {
      expect(normalizeFoodKey('pho bo'), isNot(normalizeFoodKey('pho ga')));
      // Both reduce to "ph b" if accents are stripped as punctuation.
      expect(normalizeFoodKey('phở bò'), isNot(normalizeFoodKey('phú bá')));
    });
  });

  group('cachedEstimate', () {
    late LoopDatabase db;
    late NutritionRepository repo;

    setUp(() {
      db = LoopDatabase.forTesting(NativeDatabase.memory());
      repo = NutritionRepository(db);
      addTearDown(db.close);
    });

    test('misses before anything is remembered', () async {
      expect(await repo.cachedEstimate('pho bo'), isNull);
    });

    test('returns the remembered estimate unchanged', () async {
      await repo.rememberEstimate('pho bo', _pho);

      final hit = await repo.cachedEstimate('pho bo');

      expect(hit, _pho);
      expect(hit!.cal, const IntRange(450, 620));
      expect(hit.macros, _pho.macros);
    });

    test('keeps the original confidence — caching is not extra accuracy',
        () async {
      await repo.rememberEstimate('pho bo', _pho);

      expect((await repo.cachedEstimate('pho bo'))!.confidence,
          NutritionConfidence.med);
    });

    test('hits across punctuation and spacing differences', () async {
      await repo.rememberEstimate('Pho bo!', _pho);

      expect(await repo.cachedEstimate('  pho   BO '), _pho);
    });

    test('a different dish still misses', () async {
      await repo.rememberEstimate('pho bo', _pho);

      expect(await repo.cachedEstimate('pho ga'), isNull);
    });

    test('an empty description is never cached or looked up', () async {
      await repo.rememberEstimate('   ', _pho);

      expect(await repo.cachedEstimate('   '), isNull);
    });

    test('remembering the same description twice replaces, never duplicates',
        () async {
      await repo.rememberEstimate('pho bo', _pho);
      await repo.rememberEstimate(
        'PHO BO',
        const MealEstimate(
          name: 'Pho bo (large)',
          cal: IntRange(700, 900),
          confidence: NutritionConfidence.low,
        ),
      );

      final rows = await db.select(db.savedFoods).get();
      expect(rows, hasLength(1));
      expect((await repo.cachedEstimate('pho bo'))!.cal,
          const IntRange(700, 900));
    });
  });

  test('v9->v10 migration creates the saved-food cache', () async {
    // Stamp a v9 user_version so Drift runs onUpgrade(9->10) on open. The v9
    // schema had no saved_foods table, so a successful read proves the
    // migration created it rather than onCreate having built a fresh DB.
    final upgraded = LoopDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute(v10RoutineExercises);
      raw.execute('PRAGMA user_version = 9');
    }));
    addTearDown(upgraded.close);
    final upgradedRepo = NutritionRepository(upgraded);

    await upgradedRepo.rememberEstimate('pho bo', _pho);

    expect(await upgradedRepo.cachedEstimate('pho bo'), _pho);
  });
}
