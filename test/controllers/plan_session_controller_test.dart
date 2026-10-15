import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/plan_session_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/today/day_plan.dart';
import 'package:opal/services/pal/pal_service.dart';

const _step = 'Two-minute wind-down';
const _legs = 'seed-routine-legs';
const _treadmill = 'seed-routine-treadmill-int';
const _friday = 5;

PalProposal _proposal({
  String action = addRitualAction,
  ({String routineId, String step})? ritual,
  ({int weekday, String routineId})? slot,
}) =>
    PalProposal(
      id: 'p',
      tag: 'Rituals',
      colorToken: 'rituals',
      icon: 'sparkles',
      title: 'A proposal',
      body: 'Body.',
      approveLabel: 'Approve',
      approveIcon: 'plus',
      doneLabel: 'Done',
      action: action,
      ritual: ritual,
      slot: slot,
    );

PlanItem _addRitual([String routineId = 'evening']) =>
    proposalItem(_proposal(ritual: (routineId: routineId, step: _step)));

PlanItem _reschedule() => proposalItem(_proposal(
    action: rescheduleWorkoutAction, slot: (weekday: _friday, routineId: _legs)));

const _mood = PlanItem(id: 'mood', kind: PlanKind.mood, title: 'Mood check-in', icon: 'heart.fill');

late LoopDatabase _db;
late ProviderContainer _container;

PlanSessionController get _plan => _container.read(planSessionControllerProvider.notifier);
PlanSession get _session => _container.read(planSessionControllerProvider);

Future<List<String>> _eveningSteps() async => [
      for (final s in (await RitualRepository(_db).getAll()).firstWhere((r) => r.id == 'evening').steps)
        s.title,
    ];

Future<String?> _slot(int weekday) async => (await WeeklyPlanRepository(_db).getSchedule())
    .where((a) => a.weekday == weekday)
    .firstOrNull
    ?.routineId;

void main() {
  setUp(() async {
    _db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(_db).seedReferenceData();
    for (final r in SeedData.ritualRoutines()) {
      await RitualRepository(_db).upsertRoutine(r);
    }
    for (final r in SeedData.routines()) {
      await RoutineRepository(_db).insert(r);
    }
    await WeeklyPlanRepository(_db).upsert(_friday, _treadmill);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    _container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(_db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
  });

  tearDown(() async {
    _container.dispose();
    await _db.close();
  });

  test('approving add_ritual appends the step, and undo removes it', () async {
    final before = await _eveningSteps();

    await _plan.approve(_addRitual());

    expect(await _eveningSteps(), [...before, _step]);
    expect(_session.settled, {'proposal:p': true});
    expect(_session.undoLabel, '$_step added');

    await _plan.undo();

    expect(await _eveningSteps(), before);
    expect(_session.settled, isEmpty);
    expect(_session.canUndo, isFalse);
  });

  test('approving reschedule sets the slot, and undo restores the prior routine', () async {
    await _plan.approve(_reschedule());

    expect(await _slot(_friday), _legs);
    expect(_session.undoLabel, 'Leg Day on Friday');

    await _plan.undo();

    expect(await _slot(_friday), _treadmill);
    expect(_session.settled, isEmpty);
  });

  test('undo after a reschedule onto a rest day restores the rest day', () async {
    await WeeklyPlanRepository(_db).upsert(_friday, null);

    await _plan.approve(_reschedule());
    expect(await _slot(_friday), _legs);

    await _plan.undo();

    expect(await _slot(_friday), isNull);
  });

  test('approving add_ritual for a missing routine throws, settles and changes nothing',
      () async {
    final before = await RitualRepository(_db).getAll();

    await expectLater(_plan.approve(_addRitual('gone')), throwsA(isA<StateError>()));

    expect(_session.settled, isEmpty);
    expect(_session.canUndo, isFalse);
    final after = await RitualRepository(_db).getAll();
    expect(after.map((r) => r.id), before.map((r) => r.id));
    expect(after.map((r) => r.steps.length), before.map((r) => r.steps.length));
  });

  test('approving a proposal with an unknown action throws a StateError', () async {
    await expectLater(
        _plan.approve(proposalItem(_proposal(action: closeOutAction))), throwsStateError);
    expect(_session.settled, isEmpty);
  });

  test('a skip settles the item as not done and names it', () async {
    _plan.skip(_mood);

    expect(_session.settled, {'mood': false});
    expect(_session.undoLabel, 'Mood check-in skipped');

    await _plan.undo();
    expect(_session.settled, isEmpty);
    expect(_session.selected, 'mood');
  });

  test('a double undo pops only the step it reversed', () async {
    _plan.skip(_mood);
    await _plan.approve(_addRitual());

    await Future.wait([_plan.undo(), _plan.undo()]);

    expect(_session.settled, {'mood': false});
    expect(_session.undoLabel, 'Mood check-in skipped');
  });

  test('a failed undo throws and keeps the step', () async {
    await _plan.approve(_addRitual());
    await _db.close();

    await expectLater(_plan.undo(), throwsA(anything));

    expect(_session.undoLabel, '$_step added');
    expect(_session.settled, {'proposal:p': true});
  });
}
