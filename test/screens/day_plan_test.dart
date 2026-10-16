import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/controllers/spending_controller.dart' show DetailTracker;
import 'package:opal/controllers/weekly_plan_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/today/day_plan.dart';
import 'package:opal/services/pal/pal_service.dart' show PalAgenda, PalProposal, PlanFact;
import 'package:opal/util/dates.dart' show clockLabel;

// 8:30 AM: a 7:00 AM routine is overdue but not yet missed, a 9:00 PM one is
// still ahead.
final _now = DateTime(2026, 10, 4, 8, 30);
final _yesterday = DateTime(2026, 10, 3, 14);
final _day = DateTime(2026, 10, 4);

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

RitualRoutine _routine(String id, String time, {int steps = 1, String? name}) => RitualRoutine(
      id: id,
      name: name ?? 'Routine $id',
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

WeekPlanDay _workout({bool rest = false, bool done = false, bool trained = false}) =>
    WeekPlanDay(
      day: 'Sun',
      date: 4,
      type: rest ? 'Rest' : 'Push',
      routine: rest ? null : 'Push Day A',
      est: rest ? null : 45,
      colorKey: rest ? 'rest' : 'move',
      icon: rest ? 'moon.stars.fill' : 'dumbbell.fill',
      done: done,
      trained: trained,
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
  final session = PlanSession(day: _day);

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
      final skipped = session.settle('proposal:rent', done: false, label: '');
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

    test('current is the first open item under the lead rules too', () {
      final plan = full();
      const care = LeadRules(palOnline: true, care: [DetailTracker.rituals]);
      expect(plan.current(session, _now, care), plan.open(session, _now, care).first);
      final morningDone = session.settle('routine:morning', done: true, label: '');
      expect(plan.current(morningDone, _now, care)!.id, 'closeOut');
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

      final morningDone = session.settle('routine:morning', done: true, label: '');
      expect(plan.open(morningDone, _now, rules).first.id, 'closeOut');

      final onlyOdd = morningDone.settle('closeOut', done: false, label: '');
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
      final rentDone = session.settle('proposal:rent', done: true, label: '');
      expect(both().open(rentDone, _now, rules).first.id, 'workout');

      final workoutSkipped = rentDone.settle('workout', done: false, label: '');
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
  });

  group('missed items', () {
    // 8:06 PM, the walkthrough's evening: Morning is 13 hours past its slot.
    final evening = DateTime(2026, 10, 4, 20, 6);
    final plan = _plan(
      rituals: _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:30 PM')]),
    );

    test('a timed item past its slot by more than four hours goes to the end', () {
      expect(_ids(plan.open(session, evening)),
          ['mood', 'meal', 'closeOut', 'routine:morning']);
    });

    test('a timed item stays in the lead up to four hours past its slot', () {
      final atEleven = DateTime(2026, 10, 4, 11);
      expect(plan.open(session, atEleven).first.id, 'routine:morning');
      final justAfter = DateTime(2026, 10, 4, 11, 1);
      expect(plan.open(session, justAfter).last.id, 'routine:morning');
    });

    test('Routines care leads with the close-out over a missed morning routine', () {
      final rules = LeadRules(care: [DetailTracker.rituals]);
      expect(plan.open(session, evening, rules).first.id, 'closeOut');
      final closedOut = session.settle('closeOut', done: true, label: '');
      expect(plan.open(closedOut, evening, rules).first.id, 'routine:morning');
    });
  });

  group('whyNote', () {
    const online = LeadRules(palOnline: true);

    test('names the clock reason, what else is open and the order rule', () {
      final evening = DateTime(2026, 10, 4, 20, 6);
      final plan = _plan(
        rituals: _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:30 PM')]),
      );
      final settled = session.settle('mood', done: true, label: '').settle('meal', done: true, label: '');
      final lead = plan.current(settled, evening, online)!;

      final note = plan.whyNote(lead, settled, evening, online);

      expect(lead.id, 'closeOut');
      expect(note, startsWith('Today shows Close-out first. '
          'It is the next thing on the clock, at 9:30 PM.'));
      expect(note, contains('Still open after it: Routine morning (missed, was at 7:00 AM).'));
      expect(note, contains("Today's order: an area in Needs care"));
    });

    test("names Needs care and Pal's proposals when they decide the lead", () {
      final plan = _plan(agenda: const PalAgenda(proposals: [_legs, _proposal]));
      final care = LeadRules(palOnline: true, care: [DetailTracker.money]);
      final rent = plan.current(session, _now, care)!;
      expect(plan.whyNote(rent, session, _now, care),
          contains('Money needs care, and an area in Needs care always leads.'));

      final legs = plan.current(session, _now, online)!;
      expect(plan.whyNote(legs, session, _now, online),
          contains("Pal proposed it, and Pal's proposals lead while Pal is online."));
    });

    test('reads the same as before reasonFor was pulled out', () {
      final evening = DateTime(2026, 10, 4, 20, 6);
      final plan = _plan(
        rituals: _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:30 PM')]),
      );
      final settled = session.settle('mood', done: true, label: '').settle('meal', done: true, label: '');
      final lead = plan.current(settled, evening, online)!;

      expect(
        plan.whyNote(lead, settled, evening, online),
        'Today shows Close-out first. It is the next thing on the clock, at 9:30 PM. '
        'Still open after it: Routine morning (missed, was at 7:00 AM). '
        "Today's order: an area in Needs care, then Pal's proposals while Pal is "
        'online, then the clock: items due in the last four hours, untimed items, '
        'upcoming items, then missed ones.',
      );
    });
  });

  group('rows', () {
    // 8:06 PM: Morning is missed, the close-out is still ahead.
    final evening = DateTime(2026, 10, 4, 20, 6);

    PlanRow row(DayPlan plan, String id, PlanSession s, [DateTime? at]) =>
        plan.rows(s, at ?? _now).singleWhere((r) => r.item.id == id);

    test('lists timed items by minute, then untimed ones in build order', () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_proposal]),
        rituals: _rituals([_routine('evening', '9:00 PM'), _routine('morning', '7:00 AM')]),
        workout: _workout(),
      );
      expect(_ids(plan.rows(session, _now).map((r) => r.item)),
          ['routine:morning', 'closeOut', 'proposal:rent', 'workout', 'mood', 'meal']);
    });

    test('done and put-off items stay listed; done ones count in progress', () {
      final plan = _plan(
        agenda: const PalAgenda(proposals: [_proposal]),
        rituals: _rituals([_routine('morning', '7:00 AM'), _routine('evening', '9:00 PM')],
            progress: {
              'morning': {0},
            }),
      );
      final s = session
          .settle('proposal:rent', done: true, label: '')
          .settle('meal', done: false, label: '');

      final rows = plan.rows(s, _now);
      expect(_ids(rows.map((r) => r.item)),
          ['routine:morning', 'closeOut', 'proposal:rent', 'mood', 'meal']);
      expect(rows.map((r) => r.state), [
        PlanRowState.done,
        PlanRowState.open,
        PlanRowState.done,
        PlanRowState.open,
        PlanRowState.putOff,
      ]);
      expect(plan.progress(s), (done: 2, total: 5));
    });

    test('an open row reads its detail and acts with its action label', () {
      final plan = _plan(
        rituals: _rituals([_routine('morning', '7:00 AM', steps: 4)], progress: {
          'morning': {0, 1},
        }),
        workout: _workout(),
      );
      final morning = row(plan, 'routine:morning', session);
      expect(morning.state, PlanRowState.open);
      expect(morning.detail, '2 of 4 steps');
      expect(morning.verb, 'Start');
      expect(morning.tappable, isTrue);
      expect(morning.semanticLabel, 'Start: Routine morning, 2 of 4 steps');

      expect(row(plan, 'workout', session).detail, '45 min');
      final meal = row(plan, 'meal', session);
      expect(meal.detail, isNull);
      expect(meal.semanticLabel, 'Log a meal: Log a meal');
    });

    test('a put-off row reads Put off until tomorrow and brings it back', () {
      final r = row(_plan(), 'meal', session.settle('meal', done: false, label: ''));
      expect(r.state, PlanRowState.putOff);
      expect(r.detail, 'Put off until tomorrow');
      expect(r.verb, 'Bring back');
      expect(r.tappable, isTrue);
      expect(r.semanticLabel, 'Bring back: Log a meal, Put off until tomorrow');
    });

    test('a missed row reads Missed before its detail', () {
      final plan = _plan(
        rituals: _rituals([_routine('morning', '7:00 AM', steps: 3, name: 'Morning')]),
      );
      final r = row(plan, 'routine:morning', session, evening);
      expect(r.state, PlanRowState.missed);
      expect(r.detail, 'Missed · 3 steps');
      expect(r.semanticLabel, 'Start: Morning, Missed · 3 steps');

      const bare = PlanItem(id: 'x', kind: PlanKind.routine, title: 'X', icon: 'sparkles');
      expect(const PlanRow(item: bare, state: PlanRowState.missed).detail, 'Missed');
    });

    test('an open proposal reads Pal suggests', () {
      final plan = _plan(agenda: const PalAgenda(proposals: [_proposal]));
      final r = row(plan, 'proposal:rent', session);
      expect(r.detail, 'Pal suggests');
      expect(r.semanticLabel, 'Hold \$40: Hold \$40 for rent, Pal suggests');
    });

    test('an approved proposal reads its done label and is inert', () {
      final plan = _plan(agenda: const PalAgenda(proposals: [_proposal]));
      final r = row(plan, 'proposal:rent', session.settle('proposal:rent', done: true, label: ''));
      expect(r.state, PlanRowState.done);
      expect(r.detail, 'Held');
      expect(r.verb, isNull);
      expect(r.tappable, isFalse);
      expect(r.semanticLabel, 'Hold \$40 for rent, Held');
    });

    test('a done routine or workout reads Done and is inert', () {
      final plan = _plan(
        rituals: _rituals([_routine('morning', '7:00 AM')], progress: {
          'morning': {0},
        }),
        workout: _workout(done: true),
      );
      for (final id in ['routine:morning', 'workout']) {
        final r = row(plan, id, session);
        expect(r.detail, 'Done');
        expect(r.tappable, isFalse);
      }
    });

    test('a done mood row reads the mood word and checks in again', () {
      final plan = _plan(lastCheckin: _checkin(DateTime(2026, 10, 4, 8, 15)));
      final r = row(plan, 'mood', session);
      expect(r.state, PlanRowState.done);
      expect(r.detail, 'Slightly pleasant');
      expect(r.verb, 'Check in again');
      expect(r.semanticLabel, 'Check in again: Mood check-in, Slightly pleasant');
    });
  });

  group('plan facts', () {
    final evening = DateTime(2026, 10, 4, 20, 6);

    DayPlan day({Map<String, Set<int>> progress = const {}}) => _plan(
          agenda: const PalAgenda(proposals: [_proposal]),
          rituals: _rituals(
            [_routine('morning', '7:00 AM', steps: 3), _routine('evening', '9:00 PM')],
            progress: progress,
          ),
          workout: _workout(),
          lastCheckin: _checkin(DateTime(2026, 10, 4, 8, 15)),
        );

    test('are the open local items in lead order, without proposals or settled items', () {
      final plan = day(progress: {
        'morning': {0},
      });
      final s = session.settle('meal', done: false, label: '');

      final facts = plan.planFacts(s, _now);

      expect(facts.map((f) => f.title), ['Routine morning', 'Push Day A', 'Close-out']);
      final morning = facts.first;
      expect(morning.key, 'routine:morning|due|1 of 3 steps');
      expect(morning.when, '7:00 AM');
      expect(morning.status, PlanFact.due);
      expect(morning.steps, '1 of 3 steps');
      expect(morning.why, 'It was due at 7:00 AM, under four hours ago, and is still open.');
      final workout = facts[1];
      expect(workout.key, 'workout|anytime|45 min');
      expect(workout.when, 'any time');
      expect(workout.status, PlanFact.anytime);
      expect(workout.steps, '45 min');
      final closeOut = facts[2];
      expect(closeOut.status, PlanFact.upcoming);
      expect(closeOut.when, '9:00 PM');
      expect(closeOut.steps, '1 step');
    });

    test('a missed item says so, and an untimed item without detail has an empty key part', () {
      final facts = day().planFacts(session, evening);
      final morning = facts.singleWhere((f) => f.title == 'Routine morning');
      expect(morning.status, PlanFact.missed);
      expect(morning.key, 'routine:morning|missed|3 steps');
      expect(facts.singleWhere((f) => f.title == 'Log a meal').key, 'meal|anytime|');
    });

    test('why follows the lead rules it is given', () {
      final plan = day();
      final closeOut = plan.items.singleWhere((i) => i.id == 'closeOut');
      final fact = plan.factFor(closeOut, session, evening, LeadRules(care: [DetailTracker.rituals]));
      expect(fact.why, 'Routines needs care, and an area in Needs care always leads.');
      expect(fact.why,
          plan.reasonFor(closeOut, session, evening, LeadRules(care: [DetailTracker.rituals])));
    });

    test('the key changes when the steps or the status change', () {
      String key(DayPlan plan, DateTime at) => plan
          .factFor(plan.items.singleWhere((i) => i.id == 'routine:morning'), session, at)
          .key;
      final fresh = key(day(), _now);
      final stepped = key(day(progress: {
        'morning': {0},
      }), _now);
      final missed = key(day(), evening);
      expect({fresh, stepped, missed}, hasLength(3));
    });
  });

  group('leadLine', () {
    final plan = _plan(
      agenda: const PalAgenda(proposals: [_proposal]),
      rituals: _rituals([_routine('morning', '7:00 AM')]),
      workout: _workout(),
    );
    PlanItem item(String id) => plan.items.singleWhere((i) => i.id == id);
    final morningKey = plan.factFor(item('routine:morning'), session, _now).key;
    final agenda = PalAgenda(lines: {morningKey: 'Pal says start the morning.'});

    test('with no lead, the day is done', () {
      expect(leadLine(lead: null, agenda: agenda, online: true, leadKey: null),
          'Nothing is left. Rest up.');
    });

    test('a proposal says its body', () {
      expect(
          leadLine(lead: item('proposal:rent'), agenda: agenda, online: true, leadKey: morningKey),
          _proposal.body);
    });

    test("online with a line for the lead's key, Pal's line", () {
      expect(
          leadLine(lead: item('routine:morning'), agenda: agenda, online: true, leadKey: morningKey),
          'Pal says start the morning.');
    });

    test("offline, the item's sentence even with a matching line", () {
      expect(
          leadLine(
              lead: item('routine:morning'), agenda: agenda, online: false, leadKey: morningKey),
          'Blurb morning');
    });

    test("a stale key falls back to the item's sentence", () {
      const stepped = 'routine:morning|due|1 of 1 steps';
      expect(
          leadLine(lead: item('routine:morning'), agenda: agenda, online: true, leadKey: stepped),
          'Blurb morning');
    });

    test('with no sentence, the title', () {
      expect(leadLine(lead: item('workout'), agenda: agenda, online: true, leadKey: 'workout|anytime|45 min'),
          'Push Day A');
    });
  });

  group('PlanSession', () {
    test('settle names the change, offers Undo and keeps the day', () {
      final plan = full();
      final settled = session.settle('proposal:rent', done: true, label: 'Held');
      expect(settled.day, _day);
      expect(settled.settled, {'proposal:rent': true});
      expect(settled.canUndo, isTrue);
      expect(settled.history.single.id, 'proposal:rent');
      expect(settled.history.single.label, 'Held');
      expect(settled.notice!.label, 'Held');
      expect(settled.notice!.undoable, isTrue);
      expect(_ids(plan.open(settled, _now)), isNot(contains('proposal:rent')));
    });

    test('each change is a new notice, so the toast restarts', () {
      final first = session.settle('mood', done: false, label: 'Put off');
      final again = first.undo().settle('mood', done: false, label: 'Put off');
      expect(identical(first.notice, again.notice), isFalse);
    });

    test('undo reopens only the last change and clears the notice', () {
      final plan = full();
      final settled = session
          .settle('mood', done: true, label: 'Mood')
          .settle('meal', done: false, label: 'Meal');
      final undone = settled.undo();
      expect(undone.settled, {'mood': true});
      expect(undone.history.map((c) => c.id), ['mood']);
      expect(undone.notice, isNull);
      expect(undone.day, _day);
      // no tap-to-swap: the lead stays the clock's.
      expect(plan.current(undone, _now)!.id, 'routine:morning');
    });

    test('bringBack reopens the item, drops its change and offers no Undo', () {
      final settled = session
          .settle('mood', done: true, label: 'Mood')
          .settle('meal', done: false, label: 'Meal');
      final back = settled.bringBack('meal', label: 'Log a meal is back on today');
      expect(back.settled, {'mood': true});
      expect(back.history.map((c) => c.id), ['mood']);
      expect(back.notice!.label, 'Log a meal is back on today');
      expect(back.notice!.undoable, isFalse);
      // undo then reaches the change before it.
      expect(back.undo().settled, isEmpty);
    });

    test('dismissNotice clears the notice and keeps the rest', () {
      final settled = session.settle('mood', done: true, label: 'Mood');
      final quiet = settled.dismissNotice();
      expect(quiet.notice, isNull);
      expect(quiet.settled, settled.settled);
      expect(quiet.canUndo, isTrue);
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

    test('another routine finished today settles the planned slot too', () {
      final plan = _plan(workout: _workout(trained: true));
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

      final settled = session.settle('mood', done: true, label: '').settle('meal', done: false, label: '');
      expect(plan.open(settled, _now), isEmpty);
      expect(plan.current(settled, _now), isNull);
      expect(plan.later(settled, _now), isEmpty);
    });

    test('a check-in today makes the mood item done; one from yesterday leaves it open', () {
      final mood = _plan(lastCheckin: _checkin(DateTime(2026, 10, 4, 8, 15)))
          .items
          .firstWhere((i) => i.kind == PlanKind.mood);
      expect(mood.title, 'Mood check-in');
      expect(mood.done, isTrue);
      final stale = _plan(lastCheckin: _checkin(_yesterday));
      expect(stale.items.firstWhere((i) => i.kind == PlanKind.mood).done, isFalse);
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
      expect(evening.whenLabel, 'At 9:00 PM · 1 step');
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

  group('proposalItem', () {
    test('carries the proposal it stands for', () {
      final item = proposalItem(_addRitualProposal);
      expect(item.kind, PlanKind.proposal);
      expect(item.proposal, _addRitualProposal);
    });

    test('a close-out proposal still opens the close-out', () {
      final item = proposalItem(_closeOutProposal);
      expect(item.kind, PlanKind.closeOut);
      expect(item.proposal, _closeOutProposal);
    });
  });

  group('pendingProposals', () {
    const agenda = PalAgenda(proposals: [_proposal, _closeOutProposal, _addRitualProposal]);

    test('lists every proposal, the ones Today folds or hides included', () {
      final items = pendingProposals(agenda, PlanSession(day: _day));

      expect(items.map((i) => i.title),
          [_proposal.title, _closeOutProposal.title, _addRitualProposal.title]);
      expect(items.map((i) => i.kind),
          [PlanKind.proposal, PlanKind.closeOut, PlanKind.proposal]);
    });

    test("a proposal's done detail is its done label", () {
      expect(proposalItem(_proposal).doneDetail, _proposal.doneLabel);
    });

    test('leaves out what the session approved or put off', () {
      final session = PlanSession(day: _day)
          .settle('proposal:${_proposal.id}', done: true, label: '')
          .settle('proposal:${_addRitualProposal.id}', done: false, label: '');

      expect(pendingProposals(agenda, session).map((i) => i.title),
          [_closeOutProposal.title]);
    });
  });
}
