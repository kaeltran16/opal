import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/analysis/pal_findings.dart';
import 'package:opal/analysis/spend_patterns.dart';
import 'package:opal/controllers/correlations_controller.dart';
import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/pal_findings_controller.dart';
import 'package:opal/controllers/pal_memory_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/spend_patterns_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/failing_stream.dart';

// with a breakdown (a comparison) and without one (no bars).
const _corrWithBars = Correlation(
  a: Dimension.money,
  b: Dimension.move,
  r: -0.55,
  n: 30,
  breakdown: GroupBreakdown(
    binaryDim: Dimension.move,
    continuousDim: Dimension.money,
    meanWhenActive: 20,
    meanWhenInactive: 60,
    countActive: 10,
    countInactive: 20,
  ),
);
const _corrNoBars = Correlation(
  a: Dimension.nutrition,
  b: Dimension.mood,
  r: 0.5,
  n: 40,
);

const _spend = SpendPatterns(
  noSpendStreakDays: 8,
  biggestDay: BiggestDay(
    peakWeekday: DateTime.friday,
    quietWeekday: DateTime.tuesday,
    peakAverage: 70,
    quietAverage: 35,
  ),
);

const _nutritionPattern = NutritionPattern(
  tracker: 'money',
  icon: 'creditcard.fill',
  title: 'Takeout vs. home',
  body: 'You spent about \$42 on 3 takeout meals this week.',
  spark: [3, 5],
  emph: [0],
);

const _memory = PalMemoryDigest(
  patterns: [
    InsightPattern(colorToken: 'rituals', title: 'Walks help', detail: 'd'),
  ],
);

class _FakeNutritionController extends NutritionController {
  @override
  Stream<NutritionState> build() async* {
    yield const NutritionState(
      meals: [],
      day: NutritionDay(
        cal: IntRange(0, 0),
        macros: Macros(
          protein: IntRange(0, 0),
          carbs: IntRange(0, 0),
          fat: IntRange(0, 0),
        ),
        meals: 0,
        takeout: 0,
        home: 0,
        feel: '',
        note: '',
      ),
      week: [],
      patterns: [_nutritionPattern],
    );
  }
}

class _FailingNutritionController extends NutritionController {
  @override
  Stream<NutritionState> build() => failingStream(Exception('db locked'));
}

ProviderContainer _container(
  SharedPreferences prefs, {
  Future<PalMemoryDigest> Function()? memory,
  bool failingDbSources = false,
}) {
  final dbError = Exception('db locked');
  // no auto-retry by default: a retrying source re-enters loading and
  // rebuilds the findings forever, where the real palMemory catches and
  // settles at once. failing DB sources keep riverpod's default, so their own
  // retry setting is what the test exercises.
  final c = ProviderContainer(
    retry: failingDbSources ? null : (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      surfacedCorrelationsProvider.overrideWith(
        (_) async => failingDbSources
            ? throw dbError
            : const [_corrWithBars, _corrNoBars],
      ),
      spendPatternsProvider.overrideWith(
        (_) => failingDbSources ? failingStream(dbError) : Stream.value(_spend),
      ),
      nutritionControllerProvider.overrideWith(
        failingDbSources
            ? _FailingNutritionController.new
            : _FakeNutritionController.new,
      ),
      palMemoryProvider.overrideWith((_) => (memory ?? () async => _memory)()),
    ],
  );
  addTearDown(c.dispose);
  // keep the auto-dispose notifier alive between reads and actions.
  c.listen(palFindingsControllerProvider, (_, _) {});
  return c;
}

List<String> _ids(List<PalFinding> findings) => [
  for (final f in findings) f.id,
];

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('sources concatenate in source order', () async {
    final c = _container(prefs);
    final findings = await c.read(palFindingsControllerProvider.future);

    expect(_ids(findings), [
      'corr:money-move:-',
      'corr:nutrition-mood:+',
      'money:biggest-day:5',
      'money:no-spend-streak',
      'nutrition:Takeout vs. home',
      'pal:Walks help',
    ]);
  });

  test('dismiss removes the id from state at once', () async {
    final c = _container(prefs);
    await c.read(palFindingsControllerProvider.future);

    await c
        .read(palFindingsControllerProvider.notifier)
        .dismiss('money:no-spend-streak');

    final ids = _ids(c.read(palFindingsControllerProvider).value!);
    expect(ids, isNot(contains('money:no-spend-streak')));
    expect(ids, hasLength(5));
  });

  test('a dismissed finding stays gone after a restart', () async {
    final first = _container(prefs);
    await first.read(palFindingsControllerProvider.future);
    await first
        .read(palFindingsControllerProvider.notifier)
        .dismiss('pal:Walks help');
    first.dispose();

    // a fresh container over the same backing store is a relaunch.
    final restarted = _container(await SharedPreferences.getInstance());
    final ids = _ids(
      await restarted.read(palFindingsControllerProvider.future),
    );
    expect(ids, isNot(contains('pal:Walks help')));
    expect(ids, contains('corr:money-move:-'));
  });

  test('dismissAll empties the list, also after a restart', () async {
    final c = _container(prefs);
    await c.read(palFindingsControllerProvider.future);

    await c.read(palFindingsControllerProvider.notifier).dismissAll();
    expect(c.read(palFindingsControllerProvider).value, isEmpty);

    c.dispose();
    final restarted = _container(prefs);
    expect(await restarted.read(palFindingsControllerProvider.future), isEmpty);
  });

  test('with Pal memory failing, on-device findings still return', () async {
    final c = _container(
      prefs,
      memory: () async => throw Exception('pal backend unreachable'),
    );
    final ids = _ids(await c.read(palFindingsControllerProvider.future));

    expect(ids, [
      'corr:money-move:-',
      'corr:nutrition-mood:+',
      'money:biggest-day:5',
      'money:no-spend-streak',
      'nutrition:Takeout vs. home',
    ]);
  });

  test(
    'with the DB sources failing, Pal memory findings return promptly',
    () async {
      final c = _container(prefs, failingDbSources: true);
      // well under riverpod's default retry schedule, which takes tens of
      // seconds to give up.
      final findings = await c
          .read(palFindingsControllerProvider.future)
          .timeout(const Duration(seconds: 5));

      expect(_ids(findings), ['pal:Walks help']);
    },
  );

  test('money comparisons use the chosen currency', () async {
    SharedPreferences.setMockInitialValues({'settings.currency': 'VND'});
    final c = _container(await SharedPreferences.getInstance());
    final findings = await c.read(palFindingsControllerProvider.future);

    final corr = findings.firstWhere((f) => f.id == 'corr:money-move:-');
    expect(corr.a!.value, '20\u00a0₫');
    expect(corr.b!.value, '60\u00a0₫');
  });

  test(
    'dismissing the lead promotes the next finding with a comparison',
    () async {
      final c = _container(prefs);
      final before = await c.read(palFindingsControllerProvider.future);
      final lead = before.firstWhere((f) => f.hasComparison);
      expect(lead.id, 'corr:money-move:-');

      await c.read(palFindingsControllerProvider.notifier).dismiss(lead.id);

      final after = c.read(palFindingsControllerProvider).value!;
      expect(
        after.firstWhere((f) => f.hasComparison).id,
        'money:biggest-day:5',
      );
    },
  );
}
