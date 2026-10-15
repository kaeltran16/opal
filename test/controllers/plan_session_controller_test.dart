import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
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
const _evening = 'Evening wind-down';
const _legs = 'seed-routine-legs';
const _treadmill = 'seed-routine-treadmill-int';
const _friday = 5;

// a sunday, so friday is neither today nor tomorrow.
final _lateEvening = Clock.fixed(DateTime(2026, 10, 4, 23, 58));
final _nextMorning = Clock.fixed(DateTime(2026, 10, 5, 7, 30));
// a thursday, so friday is tomorrow.
final _thursday = Clock.fixed(DateTime(2026, 10, 15, 9));

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

const _morning = PlanItem(
  id: 'routine:morning',
  kind: PlanKind.routine,
  title: 'Morning',
  icon: 'sun.max.fill',
);

/// A settings store whose plan save fails, for the undo error path.
class _FailingSave extends SettingsRepository {
  _FailingSave(super.prefs);

  @override
  Future<void> setPlanSettled(DateTime day, Map<String, bool> settled) =>
      Future.error(StateError('disk full'));
}

late LoopDatabase _db;
late SharedPreferences _prefs;
late ProviderContainer _container;

/// Another app launch on the same database and preferences. The session is
/// built on its first read, so read it inside the clock the test runs at.
ProviderContainer _launch({List<Override> overrides = const []}) {
  final c = ProviderContainer(overrides: [
    loopDatabaseProvider.overrideWithValue(_db),
    sharedPreferencesProvider.overrideWithValue(_prefs),
    ...overrides,
  ]);
  addTearDown(c.dispose);
  return c;
}

PlanSessionController get _plan => _container.read(planSessionControllerProvider.notifier);
PlanSession get _session => _container.read(planSessionControllerProvider);

PlanSessionController _planOf(ProviderContainer c) => c.read(planSessionControllerProvider.notifier);
PlanSession _sessionOf(ProviderContainer c) => c.read(planSessionControllerProvider);

/// Lets the fire-and-forget saves land.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

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
    _prefs = await SharedPreferences.getInstance();
    _container = _launch();
  });

  tearDown(() async {
    await _db.close();
  });

  group('approve performs and undo reverses', () {
    test('approving add_ritual appends the step, and undo removes it', () async {
      final before = await _eveningSteps();

      await _plan.approve(_addRitual());

      expect(await _eveningSteps(), [...before, _step]);
      expect(_session.settled, {'proposal:p': true});
      expect(_session.notice?.label, 'Added $_step to $_evening');
      expect(_session.notice?.undoable, isTrue);

      await _plan.undo();

      expect(await _eveningSteps(), before);
      expect(_session.settled, isEmpty);
      expect(_session.canUndo, isFalse);
    });

    test('approving reschedule sets the slot, and undo restores the prior routine', () async {
      await withClock(_lateEvening, () async {
        await _plan.approve(_reschedule());

        expect(await _slot(_friday), _legs);
        expect(_session.notice?.label, 'Planned Leg Day for Friday');

        await _plan.undo();

        expect(await _slot(_friday), _treadmill);
        expect(_session.settled, isEmpty);
      });
    });

    test('a reschedule onto tomorrow names it tomorrow', () async {
      await withClock(_thursday, () async {
        await _plan.approve(_reschedule());
        expect(_session.notice?.label, 'Planned Leg Day for tomorrow');
      });
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

    test('a put-off settles the item as not done and names it', () async {
      _plan.putOff(_mood);

      expect(_session.settled, {'mood': false});
      expect(_session.notice?.label, 'Put off until tomorrow: Mood check-in');

      await _plan.undo();
      expect(_session.settled, isEmpty);
    });

    test('bring back names the item, offers no Undo, and dismiss clears the notice', () async {
      _plan.putOff(_morning);
      expect(_session.notice!.undoable, isTrue);

      _plan.bringBack(_morning);
      expect(_session.notice!.label, 'Morning is back on today');
      expect(_session.notice!.undoable, isFalse);
      expect(_session.settled, isNot(contains('routine:morning')));

      _plan.dismissNotice();
      expect(_session.notice, isNull);
      await _flush();
    });

    test('a double undo pops only the step it reversed', () async {
      _plan.putOff(_mood);
      await _plan.approve(_addRitual());

      await Future.wait([_plan.undo(), _plan.undo()]);

      expect(_session.settled, {'mood': false});
      expect(_session.lastStep?.label, 'Put off until tomorrow: Mood check-in');
    });

    test('a failed undo write throws and keeps the step', () async {
      await _plan.approve(_addRitual());
      await _db.close();

      await expectLater(_plan.undo(), throwsA(anything));

      expect(_session.lastStep?.label, 'Added $_step to $_evening');
      expect(_session.settled, {'proposal:p': true});
    });
  });

  group('the day is saved', () {
    test('a put-off and an approval survive a relaunch on the same day', () async {
      await withClock(_lateEvening, () async {
        final first = _launch();
        _planOf(first).putOff(_morning);
        await _planOf(first).approve(_addRitual());
        await _flush();

        final relaunched = _launch();
        expect(_sessionOf(relaunched).settled, {'routine:morning': false, 'proposal:p': true});
        expect(_sessionOf(relaunched).day, DateTime(2026, 10, 4));
        // the toast is gone after a relaunch, so is what it could undo.
        expect(_sessionOf(relaunched).canUndo, isFalse);
        expect(_sessionOf(relaunched).notice, isNull);
      });
    });

    test('a container built the next day starts empty', () async {
      await withClock(_lateEvening, () async {
        _planOf(_launch()).putOff(_morning);
        await _flush();
      });

      await withClock(_nextMorning, () async {
        final next = _launch();
        expect(_sessionOf(next).settled, isEmpty);
        expect(_sessionOf(next).day, DateTime(2026, 10, 5));
      });
    });

    test('syncDay past midnight empties the state, and a later save writes the new day',
        () async {
      final c = await withClock(_lateEvening, () async {
        final c = _launch();
        _planOf(c).putOff(_morning);
        await _flush();
        // the same day keeps the session.
        _planOf(c).syncDay(DateTime(2026, 10, 4, 23, 59));
        expect(_sessionOf(c).settled, {'routine:morning': false});
        return c;
      });

      _planOf(c).syncDay(_nextMorning.now());
      expect(_sessionOf(c).settled, isEmpty);
      expect(_sessionOf(c).canUndo, isFalse);
      expect(_sessionOf(c).day, DateTime(2026, 10, 5));

      _planOf(c).putOff(_mood);
      await _flush();
      final repo = SettingsRepository(_prefs);
      expect(repo.planSettled(DateTime(2026, 10, 5)), {'mood': false});
      expect(repo.planSettled(DateTime(2026, 10, 4)), isEmpty);
    });

    test('undo reverses the last change and saves it', () async {
      await withClock(_lateEvening, () async {
        final c = _launch();
        await _planOf(c).approve(_addRitual());
        _planOf(c).putOff(_morning);
        await _flush();

        await _planOf(c).undo();

        expect(_sessionOf(c).settled, {'proposal:p': true});
        expect(_sessionOf(c).notice, isNull);
        expect(SettingsRepository(_prefs).planSettled(DateTime(2026, 10, 4)), {'proposal:p': true});
      });
    });

    test('a failed undo save throws and leaves the change in place', () async {
      await withClock(_lateEvening, () async {
        final c = _launch(
            overrides: [settingsRepositoryProvider.overrideWithValue(_FailingSave(_prefs))]);
        _planOf(c).putOff(_morning);
        await _flush();

        await expectLater(_planOf(c).undo(), throwsStateError);
        expect(_sessionOf(c).settled, {'routine:morning': false});
        expect(_sessionOf(c).canUndo, isTrue);
      });
    });
  });
}
