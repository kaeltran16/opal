import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/analysis/pal_findings.dart';
import 'package:opal/controllers/pal_findings_controller.dart';
import 'package:opal/controllers/pal_memory_controller.dart';
import 'package:opal/controllers/plan_session_controller.dart';
import 'package:opal/controllers/profile_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/settings_repository.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/profile/profile_screen.dart';
import 'package:opal/screens/you/autopilot_screen.dart';
import 'package:opal/screens/you/pal_memory_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/inset_section.dart';
import 'package:opal/widgets/nav_bar.dart';

import 'support/flush_provider_timers.dart';

// a Monday, as the goldens use: day 21 of a 9-day history is Sat Oct 10.
final _now = DateTime(2026, 9, 28, 9, 30);

const _sleepMoney = PalFinding(
  id: 'corr:sleep-money:+',
  areas: ['Sleep', 'Money'],
  line: 'Short nights cost you about \$18 the next day.',
  evidence: 'Seen after 9 of 11 short nights',
  a: FindingSide(label: 'After under 7 h', value: '\$71 a day', fraction: 71 / 80),
  b: FindingSide(label: 'After 7 h or more', value: '\$53 a day', fraction: 53 / 80),
  question: 'Tell me more: Short nights cost you about \$18 the next day.',
);
const _moodMove = PalFinding(
  id: 'corr:move-mood:+',
  areas: ['Move', 'Mood'],
  line: 'Your better days follow a workout.',
  evidence: '12 workout days, 18 without',
  a: FindingSide(label: 'After a workout', value: '4.1 of 5', fraction: 4.1 / 5),
  b: FindingSide(label: 'Other days', value: '3.2 of 5', fraction: 3.2 / 5),
  question: 'Tell me more: Your better days follow a workout.',
);
// no comparison, so it can never lead.
const _fridays = PalFinding(
  id: 'pal:Fridays cost the most',
  areas: ['Money'],
  line: 'Fridays cost the most',
  evidence: 'Dining out drives the spike.',
  question: 'Tell me more: Fridays cost the most',
);

class _FixedFindings extends PalFindingsController {
  _FixedFindings(this.list);
  final List<PalFinding> list;

  @override
  Future<List<PalFinding>> build() async => list;
}

class _ThrowingFindings extends PalFindingsController {
  @override
  Future<List<PalFinding>> build() async => throw StateError('test');
}

ProfileStats _stats(DateTime? memberSince) => ProfileStats(
      totalSpent: 0,
      moveKcal: 0,
      ritualsKept: 0,
      longestStreak: 0,
      memberSince: memberSince,
    );

Entry _workout(int daysAgo) => Entry(
    id: 'w$daysAgo',
    timestamp: clock.now().subtract(Duration(days: daysAgo)),
    type: EntryType.move,
    title: 'Run',
    duration: 30,
    calories: 200,
    source: EntrySource.manual);

/// Pumps the app on You with [findings] (null keeps the real controller),
/// [memberSince] (unset keeps the real stats) and [workoutDays] consecutive
/// workouts ending today. [inShell] false pumps You alone, without the tab
/// bar. Returns the router.
Future<GoRouter> _pumpYou(
  WidgetTester tester, {
  List<PalFinding>? findings,
  PalFindingsController Function()? findingsCtl,
  Object? memberSince = _unset,
  int workoutDays = 0,
  String? name,
  PalMemoryDigest? memory,
  // wide enough that Ahem copy fits the screens pushed from You.
  Size size = const Size(800, 2400),
  bool inShell = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (name != null) await SettingsRepository(prefs).setDisplayName(name);
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final router = createRouter(initialLocation: '/you');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(MockPalService(latency: Duration.zero, seed: 0)),
        if (findingsCtl != null)
          palFindingsControllerProvider.overrideWith(findingsCtl)
        else if (findings != null)
          palFindingsControllerProvider.overrideWith(() => _FixedFindings(findings)),
        if (memberSince != _unset)
          profileStatsProvider
              .overrideWith((ref) => Stream.value(_stats(memberSince as DateTime?))),
        if (workoutDays > 0)
          allEntriesStreamProvider.overrideWith((ref) =>
              Stream.value([for (var i = 0; i < workoutDays; i++) _workout(i)])),
        if (memory != null) palMemoryProvider.overrideWith((ref) async => memory),
      ],
      child: inShell
          ? MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
              routerConfig: router,
            )
          : MaterialApp(
              theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
              home: const Scaffold(body: ProfileScreen()),
            ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

const Object _unset = Object();

/// Runs [body] under the fixed Monday clock.
Future<void> _atNow(Future<void> Function() body) => withClock(Clock.fixed(_now), body);

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  // --- Pure aggregation (buildProfileStats) ---------------------------------
  test('buildProfileStats folds this-year entries + rituals into the grid', () {
    final now = DateTime(2026, 6, 1);
    final entries = <Entry>[
      // This-year money: two expenses (-$30, -$20) + one income (+$100, ignored).
      Entry(
          id: 'm1',
          timestamp: DateTime(2026, 1, 5),
          type: EntryType.money,
          title: 'Groceries',
          amount: -30,
          source: EntrySource.manual),
      Entry(
          id: 'm2',
          timestamp: DateTime(2026, 2, 5),
          type: EntryType.money,
          title: 'Coffee',
          amount: -20,
          source: EntrySource.manual),
      Entry(
          id: 'm3',
          timestamp: DateTime(2026, 2, 6),
          type: EntryType.money,
          title: 'Paycheck',
          amount: 100,
          source: EntrySource.manual),
      // This-year move: 90 + 60 = 150 kcal.
      Entry(
          id: 'mv1',
          timestamp: DateTime(2026, 3, 1),
          type: EntryType.move,
          title: 'Run',
          duration: 30,
          calories: 90,
          source: EntrySource.manual),
      Entry(
          id: 'mv2',
          timestamp: DateTime(2026, 3, 2),
          type: EntryType.move,
          title: 'Walk',
          duration: 30,
          calories: 60,
          source: EntrySource.manual),
      // This-year rituals: 3 kept (these also form a 3-day ritual streak
      // ending on `now`, May 30 / 31 / Jun 1).
      Entry(
          id: 'r0',
          timestamp: DateTime(2026, 5, 30, 7),
          type: EntryType.rituals,
          title: 'Read',
          source: EntrySource.manual),
      Entry(
          id: 'r1',
          timestamp: DateTime(2026, 5, 31, 7),
          type: EntryType.rituals,
          title: 'Read',
          source: EntrySource.manual),
      Entry(
          id: 'r2',
          timestamp: DateTime(2026, 6, 1, 7),
          type: EntryType.rituals,
          title: 'Read',
          source: EntrySource.manual),
      // Last-year entry: must be excluded from totals but set memberSince.
      Entry(
          id: 'old',
          timestamp: DateTime(2024, 12, 1),
          type: EntryType.money,
          title: 'Old',
          amount: -999,
          source: EntrySource.manual),
    ];
    final routines = const [
      RitualRoutine(
          id: 'a',
          name: 'Morning',
          time: '7:00 AM',
          tone: RitualTone.morning,
          icon: 'sunrise.fill',
          blurb: '',
          streak: 12),
      RitualRoutine(
          id: 'b',
          name: 'Evening',
          time: '9:30 PM',
          tone: RitualTone.evening,
          icon: 'moon.stars.fill',
          blurb: '',
          streak: 5),
    ];

    final stats = buildProfileStats(entries, routines, now: now);

    expect(stats.totalSpent, 50); // -30 + -20, income excluded
    expect(stats.moveKcal, 150);
    expect(stats.ritualsKept, 3);
    // computed from the persisted ritual entries (3 consecutive days ending on
    // `now`), not the seeded RitualRoutine.streak values (12/5).
    expect(stats.longestStreak, 3);
    expect(stats.memberSinceYear, 2024); // earliest entry year
    expect(stats.memberSince, DateTime(2024, 12, 1)); // earliest full date
    // best move day: mv1 (90 kcal) beats mv2 (60 kcal)
    expect(stats.bestMoveDay, DateTime(2026, 3, 1));
    expect(stats.bestMoveDayKcal, 90);
  });

  // --- Pure milestone + streak-start helpers --------------------------------
  test('nextStreakMilestone returns the next ladder rung, null past the top',
      () {
    expect(nextStreakMilestone(0), 7);
    expect(nextStreakMilestone(7), 14); // strictly greater
    expect(nextStreakMilestone(11), 14);
    expect(nextStreakMilestone(30), 60);
    expect(nextStreakMilestone(365), isNull); // no fabricated target
    expect(nextStreakMilestone(400), isNull);
  });

  test('streakStartDate counts back inclusively; null for a zero streak', () {
    final today = DateTime(2026, 4, 22, 9, 30); // time-of-day ignored
    expect(streakStartDate(1, today), DateTime(2026, 4, 22)); // today
    expect(streakStartDate(11, today), DateTime(2026, 4, 12));
    expect(streakStartDate(0, today), isNull);
  });

  // --- Widget: the You tab -------------------------------------------------
  group('You header line', () {
    testWidgets('carries the live workout streak', (tester) async {
      await _pumpYou(tester, name: 'Mira', findings: const [], workoutDays: 3);
      expect(find.text('Mira · 3-day workout streak'), findsOneWidget);
      await flushProviderTimers(tester);
    });

    testWidgets('without a streak, says how long the user has tracked',
        (tester) async {
      await _pumpYou(tester,
          name: 'Mira', findings: const [], memberSince: DateTime(2026, 3, 4));
      expect(find.text('Mira · Tracking since March 2026'), findsOneWidget);
      await flushProviderTimers(tester);
    });

    testWidgets('with no history, says the user is getting started',
        (tester) async {
      await _pumpYou(tester, name: 'Mira', findings: const [], memberSince: null);
      expect(find.text('Mira · Just getting started'), findsOneWidget);
      await flushProviderTimers(tester);
    });

    testWidgets('ellipsises with no overflow at text scale 1.3 on a 390-wide '
        'surface', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const name = 'Maximiliana Okafor-Featherstonehaughs Jr';
      expect(name.length, 40);
      await _pumpYou(tester,
          name: name,
          findings: const [_sleepMoney, _moodMove],
          workoutDays: 1000,
          size: const Size(390, 844),
          // the shell's tab bar is another run's; this checks You itself.
          inShell: false);

      final line = find.text('$name · 1000-day workout streak');
      expect(line, findsOneWidget);
      final text = tester.widget<Text>(line);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.getRect(line).right, lessThanOrEqualTo(390 - Spacing.lg));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('About and help'), 300);
      expect(tester.takeException(), isNull);
      await flushProviderTimers(tester);
    });
  });

  group('You title', () {
    testWidgets('is the shared large title with the header line beneath it',
        (tester) async {
      await _pumpYou(tester, name: 'Mira', findings: const [], workoutDays: 3);
      final view = tester.widget<LargeTitleScrollView>(find.descendant(
          of: find.byType(ProfileScreen), matching: find.byType(LargeTitleScrollView)));
      expect(view.title, 'You');
      expect(view.subtitle, 'Mira · 3-day workout streak');
      await flushProviderTimers(tester);
    });

    testWidgets('collapsed, sits centred and clear of the gutter on a 390-wide '
        'surface', (tester) async {
      await _pumpYou(tester,
          findings: const [_sleepMoney, _moodMove],
          size: const Size(390, 844),
          inShell: false);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final compact = tester.getRect(find.text('You'));
      expect(compact.center.dx, closeTo(195, 1));
      expect(compact.left, greaterThanOrEqualTo(Spacing.lg));
      await flushProviderTimers(tester);
    });

    testWidgets('is announced as a header', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpYou(tester, findings: const [], inShell: false);
      expect(tester.getSemantics(find.text('You')),
          isSemantics(label: 'You', isHeader: true));
      handle.dispose();
      await flushProviderTimers(tester);
    });
  });

  group('You findings', () {
    testWidgets('the lead is the first finding with a comparison; the rest are '
        'Also seen', (tester) async {
      await _pumpYou(tester, findings: const [_fridays, _sleepMoney, _moodMove]);

      expect(find.text('Pal noticed · Sleep and Money'), findsOneWidget);
      expect(find.text(_sleepMoney.line), findsOneWidget);
      expect(find.text('After under 7 h'), findsOneWidget);
      expect(find.text('\$53 a day'), findsOneWidget);
      expect(find.text(_sleepMoney.evidence), findsOneWidget);
      expect(find.text('Also seen'), findsOneWidget);
      expect(find.text('Money · ${_fridays.evidence}'), findsOneWidget);
      expect(find.text('Move and Mood · ${_moodMove.evidence}'), findsOneWidget);
      // Also seen shows no bars.
      expect(find.text('After a workout'), findsNothing);
      final also = tester.getTopLeft(find.text('Also seen')).dy;
      expect(tester.getTopLeft(find.text(_sleepMoney.line)).dy, lessThan(also));
      expect(tester.getTopLeft(find.text(_fridays.line)).dy, greaterThan(also));
      expect(tester.getTopLeft(find.text(_moodMove.line)).dy,
          greaterThan(tester.getTopLeft(find.text(_fridays.line)).dy));
      await flushProviderTimers(tester);
    });

    testWidgets('with no comparison anywhere, every finding is Also seen',
        (tester) async {
      await _pumpYou(tester, findings: const [_fridays]);
      expect(find.textContaining('Pal noticed'), findsNothing);
      expect(find.text('Also seen'), findsOneWidget);
      expect(find.text(_fridays.line), findsOneWidget);
      await flushProviderTimers(tester);
    });

    testWidgets('a finding reads its comparison, or its areas, then Ask Pal',
        (tester) async {
      await _pumpYou(tester, findings: const [_sleepMoney, _fridays]);
      expect(
          find.bySemanticsLabel('Short nights cost you about \$18 the next day. '
              'After under 7 h \$71 a day, After 7 h or more \$53 a day. Ask Pal'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Fridays cost the most. Money. Ask Pal'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Dismiss: ${_sleepMoney.line}'), findsOneWidget);
      expect(find.bySemanticsLabel('Dismiss: ${_fridays.line}'), findsOneWidget);
      expect(tester.getSize(find.bySemanticsLabel('Dismiss: ${_fridays.line}')),
          const Size(44, 44));
      await flushProviderTimers(tester);
    });

    testWidgets('tapping a finding opens the composer seeded with its question',
        (tester) async {
      await _pumpYou(tester, findings: const [_sleepMoney]);
      await tester.tap(find.text(_sleepMoney.line));
      await tester.pumpAndSettle();
      final sheet = tester.widget<PalComposerSheet>(find.byType(PalComposerSheet));
      expect(sheet.seed, _sleepMoney.question);
      await flushProviderTimers(tester);
    });

    testWidgets('dismissing the lead promotes the next one and leaves Patterns '
        'Pal uses', (tester) async {
      await _pumpYou(tester, findings: const [_sleepMoney, _fridays, _moodMove]);

      await tester.tap(find.bySemanticsLabel('Dismiss: ${_sleepMoney.line}'));
      await tester.pumpAndSettle();

      expect(find.text(_sleepMoney.line), findsNothing);
      expect(find.text('Pal noticed · Move and Mood'), findsOneWidget);
      expect(find.text('After a workout'), findsOneWidget);
      expect(find.text('Also seen'), findsOneWidget);
      expect(find.text(_fridays.line), findsOneWidget);

      await _tapText(tester, 'What Pal remembers');
      expect(find.byType(PalMemoryScreen), findsOneWidget);
      expect(find.text('Patterns Pal uses'), findsOneWidget);
      expect(find.text(_moodMove.line), findsOneWidget);
      expect(find.text(_sleepMoney.line), findsNothing);
      await flushProviderTimers(tester);
    });

    testWidgets('Still learning names the weekday when day 21 is this week',
        (tester) async {
      await _atNow(() async {
        await _pumpYou(tester,
            findings: const [], memberSince: _now.subtract(const Duration(days: 15)));
        expect(find.text('Still learning your patterns.'), findsOneWidget);
        expect(
            find.text('Patterns need 21 days of logging. You have 16, so the first '
                'ones should show up Saturday.'),
            findsOneWidget);
        expect(find.text('16 of 21 days'), findsOneWidget);
        expect(find.bySemanticsLabel('16 of 21 days logged'), findsOneWidget);
        await flushProviderTimers(tester);
      });
    });

    testWidgets('Still learning names the date when day 21 is further',
        (tester) async {
      await _atNow(() async {
        await _pumpYou(tester,
            findings: const [], memberSince: _now.subtract(const Duration(days: 8)));
        expect(
            find.text('Patterns need 21 days of logging. You have 9, so the first '
                'ones should show up on Oct 10.'),
            findsOneWidget);
        expect(find.text('9 of 21 days'), findsOneWidget);
        expect(find.bySemanticsLabel('9 of 21 days logged'), findsOneWidget);
        await flushProviderTimers(tester);
      });
    });

    testWidgets('Still learning with no history asks for a first log',
        (tester) async {
      await _atNow(() async {
        await _pumpYou(tester, findings: const [], memberSince: null);
        expect(
            find.text('Patterns need 21 days of logging. Log a few things and Pal '
                'starts looking.'),
            findsOneWidget);
        expect(find.text('0 of 21 days'), findsOneWidget);
        expect(find.bySemanticsLabel('0 of 21 days logged'), findsOneWidget);
        await flushProviderTimers(tester);
      });
    });

    testWidgets('no findings after 21 days says there are none right now',
        (tester) async {
      await _atNow(() async {
        await _pumpYou(tester,
            findings: const [], memberSince: _now.subtract(const Duration(days: 20)));
        expect(find.text('No patterns right now. Pal looks again as new days come in.'),
            findsOneWidget);
        expect(find.text('Still learning your patterns.'), findsNothing);
        await flushProviderTimers(tester);
      });
    });

    testWidgets('a findings error says they could not load', (tester) async {
      await _pumpYou(tester, findingsCtl: _ThrowingFindings.new);
      expect(find.text("Couldn't load Pal's findings."), findsOneWidget);
      // the rest of You still shows.
      expect(find.text('What Pal remembers'), findsOneWidget);
      await flushProviderTimers(tester);
    });
  });

  group('You rows', () {
    testWidgets('the Pal rows show their counts and push their screens',
        (tester) async {
      await _pumpYou(tester,
          findings: const [],
          memory: const PalMemoryDigest(facts: [
            PalFact(id: 'f1', text: 'No caffeine after 2 PM'),
            PalFact(id: 'f2', text: 'Prefers to train before 6 PM'),
            PalFact(id: 'f3', text: 'Dinner out with friends on Fridays'),
          ]));

      expect(find.bySemanticsLabel('What Pal remembers, 3 facts'), findsOneWidget);
      // both automations default on.
      expect(find.bySemanticsLabel('Autopilot, 2 on'), findsOneWidget);

      await _tapText(tester, 'What Pal remembers');
      expect(find.byType(PalMemoryScreen), findsOneWidget);
      await tester.tap(
          find.descendant(of: find.byType(PalMemoryScreen), matching: find.text('You')));
      await tester.pumpAndSettle();

      await _tapText(tester, 'Autopilot');
      expect(find.byType(AutopilotScreen), findsOneWidget);
      await flushProviderTimers(tester);
    });

    testWidgets('the Autopilot value counts the switches that are on',
        (tester) async {
      await _pumpYou(tester, findings: const []);
      expect(find.bySemanticsLabel('Autopilot, 2 on'), findsOneWidget);

      await _tapText(tester, 'Autopilot');
      await tester.tap(find.bySemanticsLabel('Spend nudge'));
      await tester.pumpAndSettle();
      await tester.tap(
          find.descendant(of: find.byType(AutopilotScreen), matching: find.text('You')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Autopilot, 1 on'), findsOneWidget);
      await flushProviderTimers(tester);
    });

    testWidgets('each settings row lands on its route', (tester) async {
      final router = await _pumpYou(tester, findings: const []);
      expect(find.text('Settings'), findsOneWidget);

      const rows = {
        'Goals': '/you/budgets-goals',
        'Budgets': '/you/budgets',
        'Reviews': '/recap',
        'Email sync': '/email',
        'Data and privacy': '/you/privacy',
        'Appearance': '/you/appearance',
        'About and help': '/you/about',
      };
      for (final MapEntry(key: title, value: path) in rows.entries) {
        await _tapText(tester, title);
        // the pushed route's state: a push leaves the base location as is.
        final uri = router.state.uri;
        expect(uri.path, path, reason: title);
        if (title == 'Reviews') expect(uri.queryParameters['range'], 'day');
        router.go('/you');
        await tester.pumpAndSettle();
      }
      expect(find.text('Day · Week · Month'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      await flushProviderTimers(tester);
    });

    testWidgets('You no longer lists Insights or the old groups', (tester) async {
      await _pumpYou(tester, findings: const []);
      for (final gone in [
        'Insights',
        'All stats',
        'Help & feedback',
        'Daily budget',
        'Workout goal',
        'Daily routines',
        'What Pal noticed',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      await flushProviderTimers(tester);
    });
  });

  testWidgets('Not now on a Pal suggests row records a step that Undo names',
      (tester) async {
    const title = 'Move Legs day to Friday';
    await _pumpYou(tester, findings: const []);
    final notNow = find.bySemanticsLabel('Not now: $title');
    await tester.ensureVisible(notNow);
    await tester.pumpAndSettle();

    await tester.tap(notNow);
    await tester.pumpAndSettle();

    expect(find.text(title), findsNothing);
    final session = ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)))
        .read(planSessionControllerProvider);
    expect(session.settled, {'proposal:move-legs-friday': false});
    expect(session.undoLabel, '$title skipped');
    await flushProviderTimers(tester);
  });

  testWidgets(
      'the You tab has no Areas group; the areas live on their own tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final router = createRouter(initialLocation: '/you');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // the tall view lays out the whole list, so a missing group is really gone.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('AREAS'), findsNothing);
    expect(find.byType(ListRow), findsNothing);

    await flushProviderTimers(tester);
  });
}
