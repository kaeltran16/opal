@Tags(['scenario'])
library;

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/analysis/pal_findings.dart';
import 'package:opal/controllers/email_sync_controller.dart';
import 'package:opal/controllers/pal_findings_controller.dart';
import 'package:opal/controllers/profile_controller.dart';
import 'package:opal/screens/email/email_intro_screen.dart';
import 'package:opal/screens/money/budgets_screen.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/profile/profile_screen.dart';
import 'package:opal/screens/recap/recap_screen.dart';
import 'package:opal/screens/settings/about_screen.dart';
import 'package:opal/screens/settings/appearance_screen.dart';
import 'package:opal/screens/settings/budgets_goals_screen.dart';
import 'package:opal/screens/settings/export_data_screen.dart';
import 'package:opal/screens/settings/notifications_screen.dart';
import 'package:opal/screens/settings/privacy_screen.dart';
import 'package:opal/screens/you/autopilot_screen.dart';
import 'package:opal/screens/you/pal_memory_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _sleepMoneyLine = 'Short nights cost you about \$18 the next day.';
const _moodMoveLine = 'Your better days follow a workout.';
const _caffeine = 'No caffeine after 2 PM';
const _train = 'Prefers to train before 6 PM';
const _dinner = 'Dinner out with friends on Fridays';
const _coffee = 'Coffee nudge at \$15 / wk';
const _noPatterns = 'No patterns right now. Pal looks again as new days come in.';
const _memoryEmpty = "As we talk, I'll note facts you mention and patterns I learn here. "
    'You can delete anything.';
const _clear = 'Clear what Pal remembers';

// copied from the canvas's FINDINGS.
const _fixedFindings = [
  PalFinding(
    id: 'corr:sleep-money:+',
    areas: ['Sleep', 'Money'],
    line: _sleepMoneyLine,
    lead: 'Last night was short. Short nights cost you about \$18 the next day.',
    evidence: 'Seen after 9 of 11 short nights',
    a: FindingSide(label: 'After under 7 h', value: '\$71 a day', fraction: 71 / 80),
    b: FindingSide(label: 'After 7 h or more', value: '\$53 a day', fraction: 53 / 80),
    question: 'Tell me more: $_sleepMoneyLine',
  ),
  PalFinding(
    id: 'corr:move-mood:+',
    areas: ['Move', 'Mood'],
    line: _moodMoveLine,
    evidence: '12 workout days, 18 without',
    a: FindingSide(label: 'After a workout', value: '4.1 of 5', fraction: 4.1 / 5),
    b: FindingSide(label: 'Other days', value: '3.2 of 5', fraction: 3.2 / 5),
    question: 'Tell me more: $_moodMoveLine',
  ),
];

class _FixedFindings extends PalFindingsController {
  _FixedFindings(this.list);
  final List<PalFinding> list;

  @override
  Future<List<PalFinding>> build() async => list;
}

class _ThrowingFindings extends PalFindingsController {
  @override
  Future<List<PalFinding>> build() async => throw StateError('scenario');
}

enum _Autopilot { seeded, empty, error }

/// The mock with its own facts, writes that can fail, and an autopilot list
/// that can be empty or fail.
class _ScenarioPal extends MockPalService {
  _ScenarioPal({this.failWrites = false, this.autopilot = _Autopilot.seeded})
      : super(latency: Duration.zero, seed: 0);

  final bool failWrites;
  final _Autopilot autopilot;
  final List<PalFact> facts = [
    const PalFact(id: 'f1', text: _caffeine),
    const PalFact(id: 'f2', text: _train),
    const PalFact(id: 'f3', text: _dinner),
  ];

  PalMemoryDigest get _digest => PalMemoryDigest(facts: List.of(facts));

  @override
  Future<PalMemoryDigest> memory() async => _digest;

  @override
  Future<PalMemoryDigest> refreshMemory() async => _digest;

  @override
  Future<PalMemoryDigest> deleteFact(String id) async {
    if (failWrites) throw StateError('scenario');
    facts.removeWhere((f) => f.id == id);
    return _digest;
  }

  @override
  Future<PalMemoryDigest> clearMemory() async {
    if (failWrites) throw StateError('scenario');
    facts.clear();
    return _digest;
  }

  @override
  Future<PalAgenda> agenda() async {
    switch (autopilot) {
      case _Autopilot.seeded:
        return super.agenda();
      case _Autopilot.empty:
        final a = await super.agenda();
        return PalAgenda(proposals: a.proposals, streakDays: a.streakDays);
      case _Autopilot.error:
        throw StateError('scenario');
    }
  }
}

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onYou(Finder matching) =>
    find.descendant(of: find.byType(ProfileScreen), matching: matching);

Finder _youList() =>
    find.descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable)).first;

/// The back control on a screen pushed from You.
Finder _back(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.text('You'));

Finder _switch(String title) => find.descendant(
    of: find.bySemanticsLabel(title), matching: find.byType(CupertinoSwitch));

Future<void> _boot(
  WidgetTester tester,
  bool dark, {
  PalFindingsController Function()? findings,
  _ScenarioPal? pal,
  List<Override> overrides = const [],
}) async {
  await bootApp(tester,
      dark: dark,
      palService: pal ?? _ScenarioPal(),
      overrides: [
        palFindingsControllerProvider
            .overrideWith(findings ?? () => _FixedFindings(_fixedFindings)),
        ...overrides,
      ]);
  await tester.tap(find.descendant(
      of: find.byType(GlassTabBar), matching: find.text('You')));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls You down from its top until [finder] is on screen, then taps it.
Future<void> _tapOnYou(WidgetTester tester, Finder finder) async {
  await _toTop(tester);
  await tester.scrollUntilVisible(finder.hitTestable(), 200, scrollable: _youList());
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _toTop(WidgetTester tester) async {
  await tester.scrollUntilVisible(_onYou(find.text('You')).hitTestable(), -300,
      scrollable: _youList());
  await tester.pumpAndSettle();
}

/// The router, found from You: a pushed screen may have no [Scaffold] for
/// [appRouter] to start from.
GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(ProfileScreen, skipOffstage: false)));

Future<void> _pop(WidgetTester tester) async {
  _router(tester).pop();
  await tester.pumpAndSettle();
}

/// Opens a screen pushed from You by its row.
Future<void> _open(WidgetTester tester, String row) =>
    _tapOnYou(tester, _onYou(find.text(row)));

void main() {
  scenarioTest('you', (tester, dark) async {
    final theme = _theme(dark);
    final pal = _ScenarioPal();
    await _boot(tester, dark, pal: pal);

    // you_top
    expect(
        _onYou(find.byWidgetPredicate(
            (w) => w is Text && (w.data ?? '').startsWith('You · '))),
        findsOneWidget);
    expect(find.text('Pal noticed · Sleep and Money'), findsOneWidget);
    expect(find.text(_fixedFindings.first.lead!), findsOneWidget);
    expect(find.text('After under 7 h'), findsOneWidget);
    expect(find.text('\$71 a day'), findsOneWidget);
    expect(find.text('After 7 h or more'), findsOneWidget);
    expect(find.text('\$53 a day'), findsOneWidget);
    expect(find.text('Also seen'), findsOneWidget);
    expect(find.text(_moodMoveLine), findsOneWidget);
    await shot(tester, 'you_top_$theme');
    await tester.scrollUntilVisible(
        find.bySemanticsLabel('Autopilot, 2 on').hitTestable(), 200,
        scrollable: _youList());
    expect(find.bySemanticsLabel('What Pal remembers, 3 facts'), findsOneWidget);
    expect(find.text('3 facts'), findsOneWidget);
    expect(find.text('2 on'), findsOneWidget);
    await _toTop(tester);

    // you_finding_composer
    await _tap(tester, find.text(_fixedFindings.first.lead!));
    final sheet = find.byType(PalComposerSheet);
    expect(sheet, findsOneWidget);
    expect(tester.widget<PalComposerSheet>(sheet).seed, 'Tell me more: $_sleepMoneyLine');
    expect(find.descendant(of: sheet, matching: find.text('Tell me more: $_sleepMoneyLine')),
        findsOneWidget);
    await shot(tester, 'you_finding_composer_$theme');
    await _pop(tester);
    expect(sheet, findsNothing);

    // you_dismissed
    await _tap(tester, find.bySemanticsLabel('Dismiss: $_sleepMoneyLine'));
    expect(find.text(_sleepMoneyLine), findsNothing);
    expect(find.text('Pal noticed · Move and Mood'), findsOneWidget);
    expect(find.text(_moodMoveLine), findsOneWidget);
    expect(find.text('After a workout'), findsOneWidget);
    expect(find.text('Also seen'), findsNothing);
    await shot(tester, 'you_dismissed_$theme');

    // you_settings
    await tester.scrollUntilVisible(_onYou(find.text('About and help')).hitTestable(), 200,
        scrollable: _youList());
    await tester.pumpAndSettle();
    final emailOn = ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)))
        .read(emailDashboardControllerProvider)
        .isConnected;
    expect(find.text('Settings'), findsOneWidget);
    for (final row in [
      'Goals',
      'Budgets',
      'Reviews',
      'Email sync',
      'Data and privacy',
      'Appearance',
      'About and help',
    ]) {
      expect(_onYou(find.text(row)), findsOneWidget, reason: row);
    }
    expect(find.text('Day · Week · Month'), findsOneWidget);
    expect(find.text(emailOn ? 'Gmail · On' : 'Not connected'), findsOneWidget);
    await shot(tester, 'you_settings_$theme');

    // you_row_*: each row lands on its screen
    final rows = {
      'goals': ('Goals', BudgetsGoalsScreen),
      'budgets': ('Budgets', BudgetsScreen),
      'reviews': ('Reviews', RecapScreen),
      'email': ('Email sync', EmailIntroScreen),
      'appearance': ('Appearance', AppearanceScreen),
      'about': ('About and help', AboutScreen),
    };
    for (final MapEntry(key: step, value: (row, screen)) in rows.entries) {
      await _open(tester, row);
      expect(find.byType(screen), findsOneWidget, reason: row);
      if (step == 'reviews') {
        expect(_router(tester).state.uri.queryParameters['range'], 'day');
      }
      await shot(tester, 'you_row_${step}_$theme');
      await _pop(tester);
    }

    // you_data_privacy
    await _open(tester, 'Data and privacy');
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(find.text('Data and privacy'), findsWidgets);
    final privacyList = find
        .descendant(of: find.byType(PrivacyScreen), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Notifications').hitTestable(), 200,
        scrollable: privacyList);
    expect(find.text('Export data'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    await shot(tester, 'you_data_privacy_$theme');

    // you_privacy_export
    await _tap(tester, find.text('Export data'));
    expect(find.byType(ExportDataScreen), findsOneWidget);
    await shot(tester, 'you_privacy_export_$theme');
    await _pop(tester);

    // you_privacy_notifications
    await tester.scrollUntilVisible(find.text('Notifications').hitTestable(), 200,
        scrollable: privacyList);
    await _tap(tester, find.text('Notifications'));
    expect(find.byType(NotificationsScreen), findsOneWidget);
    await shot(tester, 'you_privacy_notifications_$theme');
    await _pop(tester);
    await _pop(tester);
    expect(find.byType(PrivacyScreen), findsNothing);

    // you_memory
    await _open(tester, 'What Pal remembers');
    expect(find.byType(PalMemoryScreen), findsOneWidget);
    for (final fact in [_caffeine, _train, _dinner]) {
      expect(find.text(fact), findsOneWidget, reason: fact);
    }
    expect(find.text('Patterns Pal uses'), findsOneWidget);
    final inMemory = find.descendant(of: find.byType(PalMemoryScreen), matching: find.text(_moodMoveLine));
    expect(inMemory, findsOneWidget);
    expect(find.descendant(of: find.byType(PalMemoryScreen), matching: find.text(_sleepMoneyLine)),
        findsNothing);
    await shot(tester, 'you_memory_$theme');

    // you_memory_dismiss
    await _tap(tester, find.bySemanticsLabel('Dismiss: $_moodMoveLine'));
    expect(inMemory, findsNothing);
    expect(find.text('Patterns Pal uses'), findsNothing);
    await shot(tester, 'you_memory_dismiss_$theme');

    // you_memory_forget
    await _tap(tester, find.bySemanticsLabel('Forget: $_caffeine'));
    expect(find.text(_caffeine), findsNothing);
    expect(pal.facts.map((f) => f.text), [_train, _dinner]);
    await shot(tester, 'you_memory_forget_$theme');

    // you_memory_clear_cancel
    await _tap(tester, find.text(_clear));
    await _tap(tester, find.text('Cancel'));
    expect(find.text(_clear), findsOneWidget);
    expect(find.text('Clear everything Pal remembers?'), findsNothing);
    await shot(tester, 'you_memory_clear_cancel_$theme');

    // you_memory_clear_ask
    await _tap(tester, find.text(_clear));
    expect(find.text('Clear everything Pal remembers?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    await shot(tester, 'you_memory_clear_ask_$theme');

    // you_memory_cleared
    await _tap(tester, find.text('Clear'));
    expect(find.text(_memoryEmpty), findsOneWidget);
    expect(find.text(_train), findsNothing);
    await shot(tester, 'you_memory_cleared_$theme');
    await _tap(tester, _back(PalMemoryScreen));
    expect(find.byType(PalMemoryScreen), findsNothing);
    await _toTop(tester);
    expect(find.text(_noPatterns), findsOneWidget);

    // you_autopilot
    await _open(tester, 'Autopilot');
    expect(find.byType(AutopilotScreen), findsOneWidget);
    for (final title in ['Rent auto-pay watch', 'Weekly review draft', _coffee]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(tester.widget<CupertinoSwitch>(_switch(_coffee)).value, isFalse);
    await _tap(tester, _switch(_coffee));
    expect(tester.widget<CupertinoSwitch>(_switch(_coffee)).value, isTrue);
    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(_switch(_coffee)),
        isSemantics(label: _coffee, hasToggledState: true, isToggled: true));
    handle.dispose();
    await shot(tester, 'you_autopilot_$theme');

    // you_autopilot_count
    await _tap(tester, _back(AutopilotScreen));
    await tester.scrollUntilVisible(find.text('3 on').hitTestable(), 200,
        scrollable: _youList());
    expect(find.bySemanticsLabel('Autopilot, 3 on'), findsOneWidget);
    await shot(tester, 'you_autopilot_count_$theme');
  });

  scenarioTest('you_learning', (tester, dark) async {
    final now = clock.now();
    await _boot(tester, dark, findings: () => _FixedFindings(const []), overrides: [
      profileStatsProvider.overrideWith((ref) => Stream.value(ProfileStats(
            totalSpent: 0,
            moveKcal: 0,
            ritualsKept: 0,
            longestStreak: 0,
            memberSince: now.subtract(const Duration(days: 8)),
          ))),
    ]);

    expect(find.text('Still learning your patterns.'), findsOneWidget);
    expect(
        find.text('Patterns need 21 days of logging. You have 9, so the first ones '
            'should show up on Oct 10.'),
        findsOneWidget);
    expect(find.text('9 of 21 days'), findsOneWidget);
    expect(find.bySemanticsLabel('9 of 21 days logged'), findsOneWidget);
    await shot(tester, 'you_learning_${_theme(dark)}');
  });

  scenarioTest('you_no_patterns', (tester, dark) async {
    await _boot(tester, dark, findings: () => _FixedFindings(const []));
    expect(find.text(_noPatterns), findsOneWidget);
    await shot(tester, 'you_no_patterns_${_theme(dark)}');
  });

  scenarioTest('you_findings_error', (tester, dark) async {
    await _boot(tester, dark, findings: _ThrowingFindings.new);
    expect(find.text("Couldn't load Pal's findings."), findsOneWidget);
    await shot(tester, 'you_findings_error_${_theme(dark)}');
  });

  scenarioTest('you_memory_forget_failed', (tester, dark) async {
    await _boot(tester, dark, pal: _ScenarioPal(failWrites: true));
    await _open(tester, 'What Pal remembers');
    await _tap(tester, find.bySemanticsLabel('Forget: $_caffeine'));
    expect(find.text("Couldn't forget that. Try again."), findsOneWidget);
    expect(find.text(_caffeine), findsOneWidget);
    await shot(tester, 'you_memory_forget_failed_${_theme(dark)}');
  });

  scenarioTest('you_memory_clear_failed', (tester, dark) async {
    await _boot(tester, dark, pal: _ScenarioPal(failWrites: true));
    await _open(tester, 'What Pal remembers');
    await _tap(tester, find.text(_clear));
    await _tap(tester, find.text('Clear'));
    expect(find.text("Couldn't clear what Pal remembers. Try again."), findsOneWidget);
    for (final fact in [_caffeine, _train, _dinner]) {
      expect(find.text(fact), findsOneWidget, reason: fact);
    }
    await shot(tester, 'you_memory_clear_failed_${_theme(dark)}');
  });

  scenarioTest('you_autopilot_empty', (tester, dark) async {
    await _boot(tester, dark, pal: _ScenarioPal(autopilot: _Autopilot.empty));
    await _open(tester, 'Autopilot');
    expect(find.text('Nothing on autopilot yet.'), findsOneWidget);
    await shot(tester, 'you_autopilot_empty_${_theme(dark)}');
  });

  scenarioTest('you_autopilot_error', (tester, dark) async {
    await _boot(tester, dark, pal: _ScenarioPal(autopilot: _Autopilot.error));
    await _open(tester, 'Autopilot');
    expect(find.text("Couldn't load autopilot."), findsOneWidget);
    await shot(tester, 'you_autopilot_error_${_theme(dark)}');
  });
}
