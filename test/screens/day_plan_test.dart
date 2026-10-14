import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/controllers/spending_controller.dart' show DetailTracker;
import 'package:opal/controllers/weekly_plan_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/today/day_plan.dart';
import 'package:opal/services/pal/pal_service.dart' show PalAgenda, PalProposal;

// 2:00 PM: a 7:00 AM routine is overdue, a 9:00 PM one is still ahead.
final _now = DateTime(2026, 10, 4, 14);
final _yesterday = DateTime(2026, 10, 3, 14);

const _proposal = PalProposal(
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

const _legs = PalProposal(
  id: 'legs',
  tag: 'Workout',
  colorToken: 'move',
  icon: 'figure.run',
  title: 'Move Legs day to Friday',
  body: 'Friday is clear and open.',
  approveLabel: 'Move it',
  approveIcon: 'checkmark',
  doneLabel: 'Moved',
);

const _closeOutProposal = PalProposal(
  id: 'close-out-tonight',
  tag: 'Rituals',
  colorToken: 'rituals',
  icon: 'moon.stars.fill',
  title: 'Close out tonight',
  body: 'A 5-min wind-down closes your ring.',
  approveLabel: 'Start close-out',
  approveIcon: 'play.fill',
  doneLabel: 'Close-out queued',
  action: 'close_out',
);

const _addRitualProposal = PalProposal(
  id: 'add-wind-down-ritual',
  tag: 'Rituals',
  colorToken: 'rituals',
  icon: 'sparkles',
  title: 'Add a 2-min wind-down ritual',
  body: 'A short wind-down could anchor it.',
  approveLabel: 'Add ritual',
  approveIcon: 'plus',
  doneLabel: 'Added',
  action: 'add_ritual',
);

RitualRoutine _routine(String id, String time, {int steps = 1}) => RitualRoutine(
      id: id,
      name: 'Routine $id',
      time: time,
      tone: RitualTone.morning,
      icon: 'sparkles',
      blurb: 'Blurb $id',
      steps: [
        for (var i = 0; i < steps; i++)
          RitualStep(id: '$id-step-$i', title: 'Step $i', note: '', icon: 'sparkles'),
      ],
    );

RitualsState _rituals(List<RitualRoutine> routines,
        {Map<String, Set<int>> progress = const {}}) =>
    RitualsState(routines: routines, progress: progress);

WeekPlanDay _workout({bool rest = false, bool done = false}) => WeekPlanDay(
      day: 'Sun',
      date: 4,
      type: rest ? 'Rest' : 'Push',
      routine: rest ? null : 'Push Day A',
      est: rest ? null : 45,
      colorKey: rest ? 'rest' : 'move',
      icon: rest ? 'moon.stars.fill' : 'dumbbell.fill',
      done: done,
      today: true,
    );

MoodCheckin _checkin(DateTime at) =>
    MoodCheckin(id: 'c', timestamp: at, pleasantness: 0.7, source: EntrySource.manual);

NutritionMeal _meal(String id, DateTime at) => NutritionMeal(
      id: id,
      timestamp: at,
      slot: 'Lunch',
      name: 'Meal $id',
      source: NutritionSource.home,
      icon: 'fork.knife',
      confidence: NutritionConfidence.med,
      cal: const IntRange(400, 600),
      macros: macrosFromCal(const IntRange(400, 600)),
    );

DayPlan _plan({
  PalAgenda agenda = const PalAgenda(),
  RitualsState? rituals,
  WeekPlanDay? workout,
  MoodCheckin? lastCheckin,
  List<NutritionMeal> meals = const [],
}) =>
    buildDayPlan(
      agenda: agenda,
      rituals: rituals,
      workout: workout,
      lastCheckin: lastCheckin,
      meals: meals,
      now: _now,
    );

List<String> _ids(Iterable<PlanItem> items) => [for (final i in items) i.id];

void main() {
  const session = PlanSession();

  /// An overdue routine, a proposal, a future routine, and the standing items.
  DayPlan full() => _plan(
        agenda: const PalAgenda(proposals: [_proposal]),
        rituals: _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:00 PM')]),
      );

  group('open', () {
    test('orders overdue timed, then untimed, then future timed', () {
      expect(_ids(full().open(session, _now)), [
        'routine:morning',
        'proposal:rent',
        'mood',
        'meal',
        'closeOut',
      ]);
    });

    test('a routine whose time does not parse is untimed', () {
      final plan = _plan(rituals: _rituals([_routine('odd', 'whenever')]));
      expect(_ids(plan.open(session, _now)), ['routine:odd', 'mood', 'meal']);
    });

    test('a completed routine is not open', () {
      final plan = _plan(
        rituals: _rituals([_routine('morning', '7:00 AM')], progress: {
          'morning': {0},
        }),
      );
      expect(_ids(plan.open(session, _now)), isNot(contains('routine:morning')));
    });

    test('a skipped item leaves open', () {
      final plan = full();
      final skipped = session.settle('proposal:rent', done: false);
      expect(_ids(plan.open(skipped, _now)), isNot(contains('proposal:rent')));
    });
  });

  group('current and later', () {
    test('current is the first open item, later is the rest in order', () {
      final plan = full();
      expect(plan.current(session, _now)!.id, 'routine:morning');
      expect(_ids(plan.later(session, _now)),
          ['proposal:rent', 'mood', 'meal', 'closeOut']);
    });

    test('current follows select', () {
      final plan = full();
      final selected = session.select('closeOut');
      expect(plan.current(selected, _now)!.id, 'closeOut');
      expect(_ids(plan.later(selected, _now)),
          ['proposal:rent', 'mood', 'meal', 'routine:morning']);
    });

    test('current falls back to the first open item when the selected one is settled', () {
      final plan = full();
      final settled = session.settle('mood', done: true).select('mood');
      expect(plan.current(settled, _now)!.id, 'routine:morning');
    });
  });

  group('lead rules', () {
    const online = LeadRules(palOnline: true);
    const offline = LeadRules();

    /// Pal sent the move proposal before the money one; a workout is planned.
    DayPlan both() => _plan(
          agenda: const PalAgenda(proposals: [_legs, _proposal]),
          rituals: _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:00 PM')]),
          workout: _workout(),
        );

    test('proposals carry their area; the workout is move, routines are rituals', () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [
          _legs,
          _proposal,
          PalProposal(
            id: 'other',
            tag: 'Other',
            colorToken: 'mood',
            icon: 'sparkles',
            title: 'Other',
            body: '',
            approveLabel: 'Yes',
            approveIcon: 'checkmark',
            doneLabel: 'Done',
          ),
        ]),
        rituals: _rituals([_routine('morning', '7:00 AM')]),
        workout: _workout(),
      );
      DetailTracker? area(String id) => plan.items.firstWhere((i) => i.id == id).area;
      expect(area('proposal:legs'), DetailTracker.move);
      expect(area('proposal:rent'), DetailTracker.money);
      expect(area('proposal:other'), isNull);
      expect(area('workout'), DetailTracker.move);
      expect(area('routine:morning'), DetailTracker.rituals);
      expect(area('mood'), isNull);
    });

    test('online, proposals lead in agenda order ahead of an overdue routine', () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_legs, _proposal]),
        rituals: _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:00 PM')]),
      );
      expect(_ids(plan.open(session, _now, online)), [
        'proposal:legs',
        'proposal:rent',
        'routine:morning',
        'mood',
        'meal',
        'closeOut',
      ]);
    });

    test('offline, the overdue routine leads and proposals sit in clock position', () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_legs, _proposal]),
        rituals: _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:00 PM')]),
      );
      final clock = [
        'routine:morning',
        'proposal:legs',
        'proposal:rent',
        'mood',
        'meal',
        'closeOut',
      ];
      expect(_ids(plan.open(session, _now, offline)), clock);
      expect(_ids(plan.open(session, _now)), clock);
    });

    test('Money care forces the money proposal over a move proposal Pal sent first', () {
      final rules = LeadRules(palOnline: true, care: [DetailTracker.money]);
      expect(_ids(both().open(session, _now, rules)).take(3),
          ['proposal:rent', 'proposal:legs', 'routine:morning']);
    });

    test('Money care offline forces a held money proposal', () {
      final rules = LeadRules(care: [DetailTracker.money]);
      expect(_ids(both().open(session, _now, rules)).take(3),
          ['proposal:rent', 'routine:morning', 'proposal:legs']);
    });

    test('Move care forces the workout online and offline, not the move proposal', () {
      for (final palOnline in [true, false]) {
        final rules = LeadRules(palOnline: palOnline, care: [DetailTracker.move]);
        expect(both().open(session, _now, rules).first.id, 'workout');
      }
    });

    test('Routines care forces the earliest open routine or close-out, untimed last', () {
      final rules = LeadRules(palOnline: true, care: [DetailTracker.rituals]);
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_proposal]),
        rituals: _rituals([
          _routine('odd', 'whenever'),
          _routine('evening', '9:00 PM'),
          _routine('morning', '7:00 AM'),
        ]),
      );
      expect(plan.open(session, _now, rules).first.id, 'routine:morning');

      final morningDone = session.settle('routine:morning', done: true);
      expect(plan.open(morningDone, _now, rules).first.id, 'closeOut');

      final onlyOdd = morningDone.settle('closeOut', done: false);
      expect(plan.open(onlyOdd, _now, rules).first.id, 'routine:odd');
    });

    test('Routines care with the morning routine done leads with the close-out', () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_proposal]),
        rituals: _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:00 PM')],
            progress: {
              'morning': {0},
            }),
      );
      final rules = LeadRules(palOnline: true, care: [DetailTracker.rituals]);
      expect(plan.open(session, _now, rules).first.id, 'closeOut');
    });

    test('Money and Move both in care lead with the money proposal, then the workout', () {
      final rules =
          LeadRules(palOnline: true, care: [DetailTracker.money, DetailTracker.move]);
      expect(_ids(both().open(session, _now, rules)).take(3),
          ['proposal:rent', 'workout', 'proposal:legs']);
    });

    test('a care item already settled falls through to the next rule', () {
      final rules =
          LeadRules(palOnline: true, care: [DetailTracker.money, DetailTracker.move]);
      final rentDone = session.settle('proposal:rent', done: true);
      expect(both().open(rentDone, _now, rules).first.id, 'workout');

      final workoutSkipped = rentDone.settle('workout', done: false);
      expect(both().open(workoutSkipped, _now, rules).first.id, 'proposal:legs');
    });

    test('a care item already done falls through to the clock offline', () {
      final rules = LeadRules(care: [DetailTracker.move]);
      final plan = _plan(
        rituals: _rituals([_routine('morning', '7:00 AM')]),
        workout: _workout(done: true),
      );
      expect(plan.open(session, _now, rules).first.id, 'routine:morning');
    });

    test('Money care with no money proposal forces nothing', () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_legs]),
        rituals: _rituals([_routine('morning', '7:00 AM')]),
      );
      final rules = LeadRules(palOnline: true, care: [DetailTracker.money]);
      expect(_ids(plan.open(session, _now, rules)), _ids(plan.open(session, _now, online)));
    });

    test('later puts untimed first, then by minute, and excludes the lead', () {
      final plan = both();
      expect(plan.current(session, _now, online)!.id, 'proposal:legs');
      expect(_ids(plan.later(session, _now, online)), [
        'proposal:rent',
        'workout',
        'mood',
        'meal',
        'routine:morning',
        'closeOut',
      ]);
    });

    test('palPick ignores the selection; isPalPick follows it', () {
      final plan = both();
      expect(plan.isPalPick(session, _now, online), isTrue);

      final tapped = session.select('closeOut');
      expect(plan.current(tapped, _now, online)!.id, 'closeOut');
      expect(plan.palPick(tapped, _now, online)!.id, 'proposal:legs');
      expect(plan.isPalPick(tapped, _now, online), isFalse);

      final settled = tapped.settle('closeOut', done: false);
      expect(plan.current(settled, _now, online)!.id, 'proposal:legs');
      expect(plan.isPalPick(settled, _now, online), isTrue);
    });

    test('selecting the pick itself is still the pick; no lead is no pick', () {
      final plan = _plan();
      expect(plan.isPalPick(session.select('mood'), _now, online), isTrue);
      final over = session.settle('mood', done: true).settle('meal', done: true);
      expect(plan.palPick(over, _now, online), isNull);
      expect(plan.isPalPick(over, _now, online), isFalse);
    });
  });

  group('PlanSession', () {
    test('settle then undo restores the item and selects it', () {
      final plan = full();
      final settled = session.select('proposal:rent').settle('proposal:rent', done: true);
      expect(settled.selected, isNull);
      expect(settled.canUndo, isTrue);
      expect(_ids(plan.open(settled, _now)), isNot(contains('proposal:rent')));

      final undone = settled.undo();
      expect(undone.canUndo, isFalse);
      expect(undone.settled, isEmpty);
      expect(undone.selected, 'proposal:rent');
      expect(plan.current(undone, _now)!.id, 'proposal:rent');
    });

    test('undo reopens only the last settled item', () {
      final settled = session.settle('mood', done: true).settle('meal', done: false);
      final undone = settled.undo();
      expect(undone.settled, {'mood': true});
      expect(undone.history, ['mood']);
      expect(undone.selected, 'meal');
    });

    test('undo with an empty history returns itself', () {
      expect(identical(session.undo(), session), isTrue);
      expect(session.canUndo, isFalse);
    });
  });

  group('buildDayPlan', () {
    test('a proposal carries its body, labels and id', () {
      final item = full().items.firstWhere((i) => i.kind == PlanKind.proposal);
      expect(item.title, 'Hold \$40 for rent');
      expect(item.said, "Say yes and Monday's rent is covered.");
      expect(item.actionLabel, 'Hold \$40');
      expect(item.skipLabel, 'Not now');
      expect(item.ref, 'rent');
      expect(item.minuteOfDay, isNull);
    });

    test('a routine is timed, says its blurb and skips with Not today', () {
      final item = full().items.firstWhere((i) => i.id == 'routine:morning');
      expect(item.minuteOfDay, 7 * 60);
      expect(item.said, 'Blurb morning');
      expect(item.actionLabel, 'Start');
      expect(item.skipLabel, 'Not today');
      expect(item.ref, 'morning');
    });

    test('a planned workout is untimed with its estimate as detail', () {
      final item = _plan(workout: _workout()).items.firstWhere((i) => i.kind == PlanKind.workout);
      expect(item.title, 'Push Day A');
      expect(item.detail, '45 min');
      expect(item.minuteOfDay, isNull);
      expect(item.done, isFalse);
    });

    test('a finished workout is done', () {
      final plan = _plan(workout: _workout(done: true));
      expect(_ids(plan.open(session, _now)), isNot(contains('workout')));
    });

    test('a rest day has no workout item', () {
      final plan = _plan(workout: _workout(rest: true));
      expect(plan.items.where((i) => i.kind == PlanKind.workout), isEmpty);
    });

    test('a routine with no steps has no item', () {
      final plan = _plan(
        rituals: _rituals([_routine('morning', '7:00 AM'), _routine('empty', '8:00 AM', steps: 0)]),
      );
      expect(_ids(plan.items.where((i) => i.kind == PlanKind.routine)), ['routine:morning']);
    });

    test('no evening routine, or one with no steps, means no close-out item', () {
      for (final rituals in [
        null,
        _rituals(const []),
        _rituals([_routine('morning', '7:00 AM')]),
        _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:00 PM', steps: 0)]),
      ]) {
        final items = _plan(rituals: rituals).items;
        expect(items.where((i) => i.kind == PlanKind.closeOut), isEmpty);
        expect(_ids(items), isNot(contains('routine:evening')));
      }
    });

    test('the evening routine is the close-out row, at its time', () {
      final items = full().items;
      expect(_ids(items), isNot(contains('routine:evening')));
      final item = items.singleWhere((i) => i.kind == PlanKind.closeOut);
      expect(item.id, 'closeOut');
      expect(item.title, 'Close-out');
      expect(item.icon, 'moon.stars.fill');
      expect(item.minuteOfDay, 21 * 60);
      expect(item.said, 'Blurb evening');
      expect(item.actionLabel, 'Start');
      expect(item.done, isFalse);
      expect(item.ref, 'evening');
      expect(item.area, DetailTracker.rituals);
    });

    test('an evening routine with no time puts the close-out at 9:30 PM', () {
      for (final time in ['', 'whenever']) {
        final plan = _plan(rituals: _rituals([_routine('evening', time)]));
        expect(plan.items.singleWhere((i) => i.kind == PlanKind.closeOut).minuteOfDay,
            closeOutMinute);
      }
    });

    test('with every evening step done the close-out is done and not open', () {
      final plan = _plan(
        rituals: _rituals([_routine('evening', '9:00 PM', steps: 2)], progress: {
          'evening': {0, 1},
        }),
      );
      expect(plan.items.singleWhere((i) => i.kind == PlanKind.closeOut).done, isTrue);
      expect(_ids(plan.open(session, _now)), isNot(contains('closeOut')));
    });

    test("Pal's close-out proposal becomes the close-out row's sentence", () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_closeOutProposal, _proposal]),
        rituals: _rituals([_routine('evening', '9:00 PM')]),
      );
      expect(_ids(plan.items), ['proposal:rent', 'mood', 'meal', 'closeOut']);
      expect(plan.items.singleWhere((i) => i.id == 'closeOut').said, _closeOutProposal.body);
    });

    test("Pal's close-out proposal is dropped when there is no close-out row", () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_closeOutProposal]),
        rituals: _rituals([_routine('morning', '7:00 AM')]),
      );
      expect(_ids(plan.items), ['routine:morning', 'mood', 'meal']);
    });

    test("beside the close-out row Pal's add-ritual proposal is dropped, a plain one stays", () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_closeOutProposal, _addRitualProposal, _proposal]),
        rituals: _rituals([_routine('evening', '9:00 PM')]),
      );
      expect(_ids(plan.items), ['proposal:rent', 'mood', 'meal', 'closeOut']);
    });

    test("with no close-out row Pal's add-ritual proposal is a proposal row", () {
      for (final rituals in [
        null,
        _rituals([_routine('morning', '7:00 AM')]),
        _rituals([_routine('evening', '9:00 PM', steps: 0)]),
      ]) {
        final plan = _plan(
          agenda: const PalAgenda(proposals: [_closeOutProposal, _addRitualProposal, _proposal]),
          rituals: rituals,
        );
        final proposals = plan.items.where((i) => i.kind == PlanKind.proposal);
        expect(_ids(proposals), ['proposal:add-wind-down-ritual', 'proposal:rent']);
        expect(plan.items.where((i) => i.kind == PlanKind.closeOut), isEmpty);
      }
    });

    test('empty inputs leave only mood and Log a meal open; settling both ends the day', () {
      final plan = _plan();
      expect(_ids(plan.open(session, _now)), ['mood', 'meal']);

      final settled = session.settle('mood', done: true).settle('meal', done: false);
      expect(plan.open(settled, _now), isEmpty);
      expect(plan.current(settled, _now), isNull);
      expect(plan.later(settled, _now), isEmpty);
    });

    test('a check-in today is done; one from yesterday is still open', () {
      final today = _plan(lastCheckin: _checkin(DateTime(2026, 10, 4, 8, 15)));
      final mood = today.items.firstWhere((i) => i.kind == PlanKind.mood);
      expect(mood.done, isTrue);
      expect(_ids(today.open(session, _now)), ['meal']);

      final stale = _plan(lastCheckin: _checkin(_yesterday));
      expect(_ids(stale.open(session, _now)), ['mood', 'meal']);
    });

    test('a meal logged today removes Log a meal', () {
      final plan = _plan(meals: [_meal('a', DateTime(2026, 10, 4, 12, 30))]);
      expect(_ids(plan.items), ['mood']);
    });

    test('a meal from yesterday does not count as logged today', () {
      final plan = _plan(meals: [_meal('a', _yesterday)]);
      expect(_ids(plan.items), ['mood', 'meal']);
    });

  });

  group('whenLabel', () {
    test('a timed item reads its time, with its detail after it', () {
      const closeOut = PlanItem(
        id: 'closeOut',
        kind: PlanKind.closeOut,
        title: 'Close-out',
        icon: 'moon.stars.fill',
        minuteOfDay: closeOutMinute,
        detail: '5 min',
      );
      expect(closeOut.whenLabel, 'At 9:30 PM · 5 min');
      final evening = full().items.firstWhere((i) => i.id == 'closeOut');
      expect(evening.whenLabel, 'At 9:00 PM');
    });

    test('an untimed item reads Any time, with and without detail', () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_proposal]),
        workout: _workout(),
      );
      expect(plan.items.firstWhere((i) => i.id == 'workout').whenLabel, 'Any time · 45 min');
      expect(plan.items.firstWhere((i) => i.id == 'mood').whenLabel, 'Any time');
    });

    test('the lead has no Now: a proposal leading online reads Any time', () {
      final plan = full();
      final lead = plan.current(session, _now, const LeadRules(palOnline: true))!;
      expect(lead.id, 'proposal:rent');
      expect(lead.whenLabel, 'Any time');
    });
  });

  test('clockLabel formats midnight, noon and the afternoon', () {
    expect(clockLabel(0), '12:00 AM');
    expect(clockLabel(7 * 60 + 5), '7:05 AM');
    expect(clockLabel(12 * 60), '12:00 PM');
    expect(clockLabel(21 * 60 + 30), '9:30 PM');
  });
}
