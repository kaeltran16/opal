import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/plan_session_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/repositories/settings_repository.dart';
import 'package:opal/screens/today/day_plan.dart';

final _lateEvening = Clock.fixed(DateTime(2026, 10, 4, 23, 58));
final _nextMorning = Clock.fixed(DateTime(2026, 10, 5, 7, 30));

const _rent = PlanItem(
  id: 'proposal:rent',
  kind: PlanKind.proposal,
  title: r'Hold $40 for rent',
  icon: 'dollarsign.circle.fill',
  doneDetail: r'Held $40 in your Rent envelope',
);

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

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

ProviderContainer _container(SharedPreferences prefs, {List<Override> overrides = const []}) {
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides],
  );
  addTearDown(container.dispose);
  return container;
}

PlanSessionController _plan(ProviderContainer c) => c.read(planSessionControllerProvider.notifier);

PlanSession _session(ProviderContainer c) => c.read(planSessionControllerProvider);

/// Lets the fire-and-forget saves land.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('a put-off and an approval survive a relaunch on the same day', () async {
    final prefs = await _prefs();
    await withClock(_lateEvening, () async {
      final first = _container(prefs);
      _plan(first).putOff(_morning);
      _plan(first).approve(_rent);
      await _flush();

      final relaunched = _container(prefs);
      expect(_session(relaunched).settled, {'routine:morning': false, 'proposal:rent': true});
      expect(_session(relaunched).day, DateTime(2026, 10, 4));
      // the toast is gone after a relaunch, so is what it could undo.
      expect(_session(relaunched).canUndo, isFalse);
      expect(_session(relaunched).notice, isNull);
    });
  });

  test('a container built the next day starts empty', () async {
    final prefs = await _prefs();
    await withClock(_lateEvening, () async {
      _plan(_container(prefs)).putOff(_morning);
      await _flush();
    });

    await withClock(_nextMorning, () async {
      final next = _container(prefs);
      expect(_session(next).settled, isEmpty);
      expect(_session(next).day, DateTime(2026, 10, 5));
    });
  });

  test('syncDay past midnight empties the state, and a later save writes the new day', () async {
    final prefs = await _prefs();
    final c = await withClock(_lateEvening, () async {
      final c = _container(prefs);
      _plan(c).putOff(_morning);
      await _flush();
      // the same day keeps the session.
      _plan(c).syncDay(DateTime(2026, 10, 4, 23, 59));
      expect(_session(c).settled, {'routine:morning': false});
      return c;
    });

    _plan(c).syncDay(_nextMorning.now());
    expect(_session(c).settled, isEmpty);
    expect(_session(c).canUndo, isFalse);
    expect(_session(c).day, DateTime(2026, 10, 5));

    _plan(c).approve(_rent);
    await _flush();
    final repo = SettingsRepository(prefs);
    expect(repo.planSettled(DateTime(2026, 10, 5)), {'proposal:rent': true});
    expect(repo.planSettled(DateTime(2026, 10, 4)), isEmpty);
  });

  test('undo reverses the last change and saves it', () async {
    final prefs = await _prefs();
    await withClock(_lateEvening, () async {
      final c = _container(prefs);
      _plan(c).approve(_rent);
      _plan(c).putOff(_morning);
      await _flush();

      await _plan(c).undo();

      expect(_session(c).settled, {'proposal:rent': true});
      expect(_session(c).notice, isNull);
      expect(SettingsRepository(prefs).planSettled(DateTime(2026, 10, 4)),
          {'proposal:rent': true});
    });
  });

  test('a failed undo save throws and leaves the change in place', () async {
    final prefs = await _prefs();
    await withClock(_lateEvening, () async {
      final c = _container(prefs,
          overrides: [settingsRepositoryProvider.overrideWithValue(_FailingSave(prefs))]);
      _plan(c).putOff(_morning);
      await _flush();

      await expectLater(_plan(c).undo(), throwsStateError);
      expect(_session(c).settled, {'routine:morning': false});
      expect(_session(c).canUndo, isTrue);
    });
  });

  test('each change sets a named notice', () async {
    final prefs = await _prefs();
    await withClock(_lateEvening, () async {
      final c = _container(prefs);

      _plan(c).putOff(_morning);
      expect(_session(c).notice!.label, 'Put off until tomorrow: Morning');
      expect(_session(c).notice!.undoable, isTrue);

      _plan(c).approve(_rent);
      expect(_session(c).notice!.label, r'Held $40 in your Rent envelope');
      expect(_session(c).notice!.undoable, isTrue);

      // with no done detail, an approval names the item.
      _plan(c).approve(const PlanItem(
          id: 'proposal:walk', kind: PlanKind.proposal, title: 'Walk at noon', icon: 'figure.walk'));
      expect(_session(c).notice!.label, 'Walk at noon');

      _plan(c).bringBack(_morning);
      expect(_session(c).notice!.label, 'Morning is back on today');
      expect(_session(c).notice!.undoable, isFalse);
      expect(_session(c).settled, isNot(contains('routine:morning')));

      _plan(c).dismissNotice();
      expect(_session(c).notice, isNull);
      await _flush();
    });
  });
}
