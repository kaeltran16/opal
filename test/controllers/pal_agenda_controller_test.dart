import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/mood_controller.dart';
import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/pal_agenda_controller.dart';
import 'package:opal/controllers/plan_session_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/controllers/weekly_plan_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/today/day_plan.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

/// Plays back one scripted response per `agenda` call: a [PalAgenda] is
/// returned, anything else is thrown. The last response repeats, so a retry
/// sees the same outcome. Each call's plan is kept in [plans].
class _ScriptedPal extends MockPalService {
  _ScriptedPal(this.script) : super(latency: Duration.zero);

  final List<Object> script;
  final plans = <List<PlanFact>>[];

  @override
  Future<PalAgenda> agenda({List<PlanFact> plan = const []}) async {
    plans.add(plan);
    final next = script.length > 1 ? script.removeAt(0) : script.single;
    if (next is PalAgenda) return next;
    throw next;
  }
}

const _rent = PalProposal(
  id: 'rent',
  tag: 'Money',
  colorToken: 'money',
  icon: 'dollarsign.circle.fill',
  title: 'Hold \$40 for rent',
  body: "Say yes and Monday's rent is covered.",
  approveLabel: 'Hold \$40',
  approveIcon: 'checkmark',
  doneLabel: 'Held',
);

// 9:15 PM: past the late hour with nothing moved, so Move is in Needs care;
// the 9:00 PM close-out is due and the 7:00 AM routine is missed.
final _lateEvening = Clock.fixed(DateTime(2026, 10, 4, 21, 15));

RitualRoutine _routine(String id, String time, int steps) => RitualRoutine(
      id: id,
      name: id == eveningRoutineId ? 'Evening' : 'Morning',
      time: time,
      tone: RitualTone.morning,
      icon: 'sparkles',
      blurb: '',
      steps: [
        for (var i = 0; i < steps; i++)
          RitualStep(id: '$id-$i', title: 'Step $i', note: '', icon: 'sparkles'),
      ],
    );

class _Rituals extends RitualsController {
  @override
  Stream<RitualsState> build() => Stream.value(RitualsState(
        routines: [_routine('morning', '7:00 AM', 3), _routine(eveningRoutineId, '9:00 PM', 2)],
        progress: const {
          eveningRoutineId: {0},
        },
      ));
}

class _Mood extends MoodController {
  @override
  Stream<MoodState> build() => Stream.value(const MoodState(
        todayCheckins: [],
        todayLean: 0.5,
        mostTag: null,
        lastCheckin: null,
        week: [],
      ));
}

class _Nutrition extends NutritionController {
  @override
  Stream<NutritionState> build() => Stream.value(const NutritionState(
        meals: [],
        day: NutritionDay(
          cal: IntRange(0, 0),
          macros: Macros(protein: IntRange(0, 0), carbs: IntRange(0, 0), fat: IntRange(0, 0)),
          meals: 0,
          takeout: 0,
          home: 0,
          feel: '',
          note: '',
        ),
        week: [],
        patterns: [],
      ));
}

/// The local day behind the plan: two routines, a planned workout, no
/// check-in, no meal, nothing moved.
List<Override> _day({Stream<TodayState>? today}) => [
      ritualsControllerProvider.overrideWith(_Rituals.new),
      moodControllerProvider.overrideWith(_Mood.new),
      nutritionControllerProvider.overrideWith(_Nutrition.new),
      weeklyPlanControllerProvider.overrideWith((ref) => Stream.value(const WeeklyPlan(days: [
            WeekPlanDay(
              day: 'Sun',
              date: 4,
              type: 'Push',
              routine: 'Push Day A',
              est: 45,
              colorKey: 'move',
              icon: 'dumbbell.fill',
              today: true,
            ),
          ]))),
      todayStateProvider.overrideWith(
          (ref) => today ?? Stream.value(const TodayState(entries: [], goals: Goals()))),
    ];

ProviderContainer _container(_ScriptedPal pal, {List<Override> overrides = const []}) {
  final c = ProviderContainer(overrides: [
    palServiceProvider.overrideWithValue(pal),
    ...overrides,
  ]);
  addTearDown(c.dispose);
  return c;
}

/// Holds a listener so the auto-dispose provider survives between reads.
void _listen(ProviderContainer c) => c.listen(palAgendaProvider, (_, _) {});

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  test('a failed fetch is an error, not an empty agenda', () async {
    final c = _container(_ScriptedPal([Exception('unreachable')]));
    _listen(c);

    await expectLater(c.read(palAgendaProvider.future), throwsException);

    final state = c.read(palAgendaProvider);
    expect(state, isA<AsyncError<PalAgenda>>());
    expect(state.value, isNull);
  });

  test('a failed refresh is an error that still holds the earlier proposals', () async {
    final c = _container(_ScriptedPal([
      const PalAgenda(proposals: [_rent]),
      Exception('unreachable'),
    ]));
    _listen(c);
    expect((await c.read(palAgendaProvider.future)).proposals, [_rent]);

    c.invalidate(palAgendaProvider);
    await expectLater(c.read(palAgendaProvider.future), throwsException);

    final state = c.read(palAgendaProvider);
    expect(state.hasError, isTrue);
    expect(state.value?.proposals, [_rent]);
  });

  test('the agenda receives the open local items as facts, in lead order', () async {
    final prefs = await _prefs();
    await withClock(_lateEvening, () async {
      final pal = _ScriptedPal([const PalAgenda()]);
      final c = _container(pal, overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ..._day(),
      ]);
      c.read(planSessionControllerProvider.notifier).putOff(const PlanItem(
            id: 'meal',
            kind: PlanKind.meal,
            title: 'Log a meal',
            icon: 'fork.knife',
          ));
      _listen(c);

      await c.read(palAgendaProvider.future);

      final plan = pal.plans.single;
      // Move care leads with the workout; the meal is put off.
      expect([for (final f in plan) f.key], [
        'workout|anytime|45 min',
        'closeOut|due|1 of 2 steps',
        'mood|anytime|',
        'routine:morning|missed|3 steps',
      ]);
      expect(plan.first.why, 'Move needs care, and an area in Needs care always leads.');
      expect(plan.first.title, 'Push Day A');
    });
  });

  test("a failed input still fetches the agenda, with an empty plan", () async {
    final prefs = await _prefs();
    await withClock(_lateEvening, () async {
      final pal = _ScriptedPal([const PalAgenda(proposals: [_rent])]);
      final c = _container(pal, overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ..._day(today: Stream.error(StateError('no database'))),
      ]);
      _listen(c);

      expect((await c.read(palAgendaProvider.future)).proposals, [_rent]);
      expect(pal.plans.single, isEmpty);
    });
  });
}
