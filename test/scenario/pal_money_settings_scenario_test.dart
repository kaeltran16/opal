@Tags(['scenario'])
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/analysis/spend_habits.dart';
import 'package:opal/app.dart';
import 'package:opal/controllers/area_detail_controller.dart';
import 'package:opal/controllers/budgets_controller.dart';
import 'package:opal/controllers/email_sync_controller.dart';
import 'package:opal/controllers/insights_controller.dart';
import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/recap_controller.dart';
import 'package:opal/controllers/spend_habits_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/email/email_dashboard_screen.dart';
import 'package:opal/screens/email/email_intro_screen.dart';
import 'package:opal/screens/email/email_setup_screen.dart';
import 'package:opal/screens/entry/new_entry_sheet.dart';
import 'package:opal/screens/money/budgets_screen.dart';
import 'package:opal/screens/nutrition/nutrition_meal_detail_screen.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/profile/profile_screen.dart';
import 'package:opal/screens/recap/recap_screen.dart';
import 'package:opal/screens/settings/about_screen.dart';
import 'package:opal/screens/settings/appearance_screen.dart';
import 'package:opal/screens/settings/budgets_goals_screen.dart';
import 'package:opal/screens/settings/export_data_screen.dart';
import 'package:opal/screens/settings/notifications_screen.dart';
import 'package:opal/screens/settings/privacy_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

import '../support/golden_harness.dart';
import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _askLabel = 'Tell Pal anything';
const _staticHowsMyWeek = 'How’s my week so far?';

// what the scenario pal answers, by message. anything else fails as offline.
const _question = 'how am I doing?';
const _answer = 'A steady week. Spending is under pace.';
const _offlineAsk = 'are you there?';
const _logAsk = 'coffee 5';
const _mealAsk = 'had a burrito bowl';
const _goalAsk = 'set my daily budget to 90';
const _loggableOffline = 'taxi 12';
const _goalBudget = 90;
const _writeTurn = Duration(milliseconds: 300);
const double _scrollStep = 200;

final _replies = <String, PalChatResult>{
  _question: const PalChatResult(reply: _answer),
  _logAsk: const PalChatResult(reply: 'Logged it.', actions: [
    LogEntryAction(type: EntryType.money, title: 'Coffee', amount: -5, category: 'Food & Drink'),
  ]),
  _mealAsk: PalChatResult(reply: 'Noted the bowl.', actions: [
    LogMealAction(
      name: 'Burrito bowl',
      cal: const IntRange(600, 800),
      confidence: NutritionConfidence.med,
      slot: 'Lunch',
    ),
  ]),
  _goalAsk: const PalChatResult(reply: 'Done.', actions: [
    SetGoalAction(target: GoalTarget.dailyBudget, value: _goalBudget),
  ]),
};

enum _Starters { pal, pending, none }

/// The mock with scripted chat replies, starters that can hang or be empty,
/// and a [gate] that holds every reply while it is set.
class _ScenarioPal extends MockPalService {
  _ScenarioPal({this.starters = _Starters.pal}) : super(latency: Duration.zero, seed: 0);

  final _Starters starters;
  Completer<void>? gate;

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async {
    await gate?.future;
    final reply = _replies[message];
    if (reply == null) throw const PalException('scenario: offline');
    return reply;
  }

  @override
  Future<List<PalSuggestion>> suggestions(SuggestionSurface surface) {
    if (surface != SuggestionSurface.composer) return super.suggestions(surface);
    return switch (starters) {
      _Starters.pal => super.suggestions(surface),
      _Starters.pending => Completer<List<PalSuggestion>>().future,
      _Starters.none => Future.value(const []),
    };
  }
}

/// Reports a fixed permission and schedules nothing.
class _FakeNotifications implements NotificationService {
  _FakeNotifications({this.granted = true});

  final bool granted;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermissions() async => granted;

  @override
  Future<void> schedule(NotificationRequest request) async {}

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

const _gmail = EmailAccount(address: 'me@gmail.com', provider: Provider.gmail, appPasswordRef: '');

/// An email service that is connected when [account] is set, and whose Test
/// connection answers [testResult].
class _FakeSync implements EmailSyncService {
  _FakeSync({this.account, this.testResult = true});

  @override
  EmailAccount? account;
  final bool testResult;
  int syncCalls = 0;
  final _status = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get status => _status.stream;
  @override
  bool get isConnected => account != null;
  @override
  Future<bool> testConnection(EmailAccount a, String p) async => testResult;
  @override
  Future<void> connect(EmailAccount a, String p) async => account = a;
  @override
  Future<void> updateSenderFilters(List<String> f) async {}
  @override
  Future<List<EmailImportItem>> syncNow() async {
    syncCalls++;
    return const [];
  }

  @override
  Future<void> disconnect() async => account = null;
  @override
  void dispose() => _status.close();
}

/// A meal controller that never emits, so the detail stays loading.
class _PendingNutrition extends NutritionController {
  @override
  Stream<NutritionState> build() => StreamController<NutritionState>().stream;
}

String _theme(bool dark) => dark ? 'dark' : 'light';

/// Boots the seeded app like `bootApp`, with [prefs] on top of its own, so a
/// scenario can pick the currency or a saved toggle.
Future<void> _boot(
  WidgetTester tester,
  bool dark, {
  Map<String, Object> prefs = const {},
  MockPalService? pal,
  NotificationService? notifications,
  List<Override> overrides = const [],
}) async {
  ignoreOverflowErrors();
  SharedPreferences.setMockInitialValues({
    'settings.onboardingComplete': true,
    'settings.brightness': dark ? 'dark' : 'light',
    ...prefs,
  });
  final sp = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  addTearDown(db.close);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(pal ?? _ScenarioPal()),
      notificationServiceProvider.overrideWithValue(notifications ?? _FakeNotifications()),
      ...overrides,
    ],
    child: const LoopApp(),
  ));
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LoopApp)));

Future<void> _go(WidgetTester tester, String location) async {
  appRouter(tester).go(location);
  await tester.pumpAndSettle();
}

/// Pushes a route above the shell: the composer, the recap, email and new entry.
Future<void> _push(WidgetTester tester, String location) async {
  unawaited(appRouter(tester).push(location));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps [finder] for a meal save that then closes the sheet. The save awaits
/// a haptic, a platform-channel call the test engine answers only on a real
/// async turn, which the test's fake-async zone never takes.
Future<void> _tapToWrite(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.runAsync(() => Future<void>.delayed(_writeTurn));
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String tab) async {
  await tester.tap(find.descendant(of: find.byType(GlassTabBar), matching: find.text(tab)));
  await tester.pumpAndSettle();
}

/// Scrolls the first scrollable inside [screen] until [finder] shows, down
/// the page or, with [up], back up it.
Future<void> _reveal(WidgetTester tester, Type screen, Finder finder, {bool up = false}) async {
  await tester.scrollUntilVisible(finder.hitTestable(), up ? -_scrollStep : _scrollStep,
      scrollable: find.descendant(of: find.byType(screen), matching: find.byType(Scrollable)).first);
  await tester.pumpAndSettle();
}

// --- composer ---------------------------------------------------------------

Finder get _sheet => find.byType(PalComposerSheet);

Finder _inSheet(Finder matching) => find.descendant(of: _sheet, matching: matching);

Future<void> _ask(WidgetTester tester) => _tap(tester, find.bySemanticsLabel(_askLabel));

Future<void> _close(WidgetTester tester) async {
  await _tap(tester, _inSheet(find.bySemanticsLabel('Close')));
  expect(_sheet, findsNothing);
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(_inSheet(find.byType(TextField)), text);
  await tester.pump();
  await tester.tap(_inSheet(find.bySemanticsLabel('Send')));
  await tester.pumpAndSettle();
}

void _expectChip(String label) =>
    expect(_inSheet(find.text(label)), findsOneWidget, reason: 'chip $label');

// --- nutrition --------------------------------------------------------------

const _linkedMeal = 'seed-meal-m3';
const _handMeal = 'seed-meal-m1';

Finder _onDetail(Finder matching) =>
    find.descendant(of: find.byType(NutritionMealDetailScreen), matching: matching);

Finder _inBottomSheet(Finder matching) =>
    find.descendant(of: find.byType(BottomSheet), matching: matching);

// --- money ------------------------------------------------------------------

EnvelopeSpend _envelope(String category, {required double cap, required double spent}) =>
    EnvelopeSpend(
      envelope: BudgetEnvelope(
        id: 'env-$category',
        category: category,
        cap: cap,
        icon: 'cart.fill',
        colorToken: 'money',
        position: 0,
      ),
      spent: spent,
    );

Override _budgets(Stream<BudgetsData> Function() data) =>
    budgetsDataProvider.overrideWith((ref) => data());

BudgetsData _month(List<EnvelopeSpend> envelopes) => BudgetsData(
      envelopes: envelopes,
      month: DateTime(goldenClock.now().year, goldenClock.now().month),
      monthlyBudget: 3000,
    );

Finder _onBudgets(Finder matching) =>
    find.descendant(of: find.byType(BudgetsScreen), matching: matching);

const _habit = HabitPick(title: 'Blue Bottle', averageAmount: 4.5, occurrences: 4, category: 'Food & Drink');

Finder _onEntry(Finder matching) =>
    find.descendant(of: find.byType(NewEntrySheet), matching: matching);

Future<void> _key(WidgetTester tester, String key) async {
  await tester.tap(_onEntry(find.text(key)).last);
  await tester.pump();
}

// --- recap ------------------------------------------------------------------

const _tryThis = 'Try a short walk after lunch.';

String _win(InsightRange range) => 'Kept the ${range.name} steady';

List<Override> _insights({Future<PalInsights?> Function(InsightRange range)? answer}) => [
      recapMemoryRefreshProvider.overrideWith((_) async {}),
      for (final range in InsightRange.values)
        insightsProvider(range).overrideWith((_) =>
            answer?.call(range) ??
            Future.value(PalInsights(
              wins: [InsightWin(colorToken: 'move', title: _win(range), sub: 'Three days running')],
              suggestion: _tryThis,
            ))),
    ];

Finder _onRecap(Finder matching) =>
    find.descendant(of: find.byType(RecapScreen), matching: matching);

// --- settings ---------------------------------------------------------------

bool _switchOn(WidgetTester tester, String title) => tester
    .widget<CupertinoSwitch>(find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(GestureDetector)).first,
      matching: find.byType(CupertinoSwitch),
    ))
    .value;

void _mockClipboard(WidgetTester tester, {required bool fails}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData' && fails) throw PlatformException(code: 'clipboard');
    return null;
  });
  addTearDown(() =>
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

void main() {
  // --- composer -------------------------------------------------------------

  scenarioTest('composer chips', (tester, dark) async {
    final theme = _theme(dark);
    await _boot(tester, dark);

    // composer_idle_workout
    await _tab(tester, 'Workout');
    await _ask(tester);
    _expectChip('Workout');
    expect(_inSheet(find.text('You could ask')), findsOneWidget);
    expect(_inSheet(find.textContaining(RegExp(r'^Start '))), findsOneWidget);
    expect(_inSheet(find.text('Verve coffee, \$5')), findsOneWidget);
    expect(_inSheet(find.text(_askLabel)), findsOneWidget);
    await shot(tester, 'composer_idle_workout_$theme');

    // composer_close
    await _close(tester);
    expect(find.bySemanticsLabel(_askLabel), findsOneWidget);
    await shot(tester, 'composer_close_$theme');

    for (final (step, tab, label) in [
      ('composer_chip_today', 'Today', 'Today'),
      ('composer_chip_areas', 'Areas', 'Areas'),
      ('composer_chip_you', 'You', 'You'),
    ]) {
      await _tab(tester, tab);
      await _ask(tester);
      _expectChip(label);
      expect(_inSheet(find.text('Pal')), findsOneWidget);
      await shot(tester, '${step}_$theme');
      await _close(tester);
    }

    // composer_chip_area_money
    await _go(tester, '/areas/money');
    await _ask(tester);
    _expectChip(Area.money.title);
    await shot(tester, 'composer_chip_area_money_$theme');
    await _close(tester);

    // composer_chip_fallback: opened from nowhere known.
    await _push(tester, '/pal-composer');
    // the header and the chip.
    expect(_inSheet(find.text('Pal')), findsNWidgets(2));
    await shot(tester, 'composer_chip_fallback_$theme');
    await _close(tester);

    // composer_start_pick
    await _tab(tester, 'Workout');
    await _ask(tester);
    final pick = _inSheet(find.textContaining(RegExp(r'^Start (?!a workout$)')));
    expect(pick, findsOneWidget);
    await _tap(tester, pick);
    expect(_sheet, findsNothing);
    expect(find.byType(StartWorkoutScreen), findsOneWidget);
    await shot(tester, 'composer_start_pick_$theme');
  });

  scenarioTest('composer starters loading', (tester, dark) async {
    await _boot(tester, dark, pal: _ScenarioPal(starters: _Starters.pending));
    await _ask(tester);

    expect(find.byKey(const Key('starter-skeleton')), findsOneWidget);
    expect(_inSheet(find.text('Start a workout')), findsNothing);
    expect(_inSheet(find.textContaining(RegExp(r'^Start '))), findsOneWidget);
    expect(_inSheet(find.text('Verve coffee, \$5')), findsNothing);
    await shot(tester, 'composer_starters_loading_${_theme(dark)}');
  });

  scenarioTest('composer starters fallback', (tester, dark) async {
    await _boot(tester, dark, pal: _ScenarioPal(starters: _Starters.none));
    await _ask(tester);

    expect(find.byKey(const Key('starter-skeleton')), findsNothing);
    for (final label in ['Verve coffee, \$5', 'Finished morning pages', _staticHowsMyWeek]) {
      expect(_inSheet(find.text(label)), findsOneWidget, reason: label);
    }
    await shot(tester, 'composer_starters_fallback_${_theme(dark)}');
  });

  scenarioTest('composer conversation', (tester, dark) async {
    final theme = _theme(dark);
    final pal = _ScenarioPal();
    await _boot(tester, dark, pal: pal);
    await _ask(tester);
    final c = tester.element(_sheet).colors;

    // composer_thinking
    pal.gate = Completer<void>();
    await _send(tester, _question);
    expect(_inSheet(find.text(_question)), findsOneWidget);
    expect(_inSheet(find.text('…')), findsOneWidget);
    expect(_inSheet(find.text('Ask a follow-up')), findsOneWidget);
    await shot(tester, 'composer_thinking_$theme');

    // composer_answer
    pal.gate!.complete();
    pal.gate = null;
    await tester.pumpAndSettle();
    expect(_inSheet(find.text('…')), findsNothing);
    expect(tester.widget<Text>(_inSheet(find.text(_answer))).style?.color, c.ink);
    await shot(tester, 'composer_answer_$theme');

    // composer_offline_answer
    await _send(tester, _offlineAsk);
    final offline = _inSheet(find.textContaining("Pal couldn't reach the server"));
    expect(offline, findsOneWidget);
    expect(tester.widget<Text>(offline).style?.color, c.ink3);
    expect(find.byType(NewEntrySheet), findsNothing);
    await shot(tester, 'composer_offline_answer_$theme');

    // composer_log
    await _send(tester, _logAsk);
    expect(_inSheet(find.text('Based on')), findsOneWidget);
    expect(_inSheet(find.text('Spending today')), findsOneWidget);
    final logged = 'Logged Coffee · ${formatCurrency(-5, Currency.usd, withSign: true)}.';
    expect(_inSheet(find.text(logged)), findsOneWidget);
    expect(_inSheet(find.bySemanticsLabel('Undo')), findsOneWidget);
    expect(_inSheet(find.bySemanticsLabel('Edit')), findsOneWidget);
    await shot(tester, 'composer_log_$theme');

    // composer_log_undone
    await _tap(tester, _inSheet(find.bySemanticsLabel('Undo')));
    expect(_inSheet(find.text('Undone')), findsOneWidget);
    expect(_inSheet(find.text(logged)), findsNothing);
    expect(_inSheet(find.bySemanticsLabel('Undo')), findsNothing);
    await shot(tester, 'composer_log_undone_$theme');

    // composer_log_edit: Edit takes the turn back and refills the input.
    await _send(tester, _logAsk);
    expect(_inSheet(find.text(logged)), findsOneWidget);
    await _tap(tester, _inSheet(find.bySemanticsLabel('Edit')));
    expect(_inSheet(find.text(logged)), findsNothing);
    final field = tester.widget<TextField>(_inSheet(find.byType(TextField)));
    expect(field.controller!.text, _logAsk);
    await shot(tester, 'composer_log_edit_$theme');

    // composer_meal
    await _send(tester, _mealAsk);
    expect(
        _inSheet(find.text('Burrito bowl · 600–800 kcal, ${NutritionConfidence.med.label}')),
        findsOneWidget);
    expect(_inSheet(find.bySemanticsLabel('Undo')), findsOneWidget);
    expect(_inSheet(find.bySemanticsLabel('Edit')), findsOneWidget);
    await shot(tester, 'composer_meal_$theme');

    // composer_goal_action
    await _send(tester, _goalAsk);
    expect(
        _inSheet(find.text(
            'Daily budget set to ${formatCurrency(_goalBudget, Currency.usd)}.')),
        findsOneWidget);
    await shot(tester, 'composer_goal_action_$theme');

    // composer_offline_handoff: unreachable with something loggable hands off
    // to New entry.
    await _send(tester, _loggableOffline);
    expect(_sheet, findsNothing);
    expect(find.byType(NewEntrySheet), findsOneWidget);
    expect(find.text("Pal's unreachable. Log it here."), findsOneWidget);
    await shot(tester, 'composer_offline_handoff_$theme');
  });

  scenarioTest('why thread', (tester, dark) async {
    const rent = 'Set aside \$40 for rent';
    await bootToday(tester,
        dark: dark,
        pal: TodayPal(
          headline: 'A steady start.',
          proposals: [proposal('hold-rent-40', rent)],
        ));
    final why = find.descendant(of: find.byType(TodayScreen), matching: find.text('Why this first'));
    await _tap(tester, why);

    expect(_sheet, findsOneWidget);
    _expectChip('Today');
    expect(_inSheet(find.text('Why $rent first?')), findsOneWidget);
    expect(_inSheet(find.text('Ask a follow-up')), findsOneWidget);
    await shot(tester, 'why_thread_${_theme(dark)}');
  });

  // --- nutrition ------------------------------------------------------------

  scenarioTest('meal detail linked', (tester, dark) async {
    await _boot(tester, dark, prefs: {'settings.currency': Currency.vnd.code});
    await _go(tester, '/areas/nutrition/meal/$_linkedMeal');

    expect(_onDetail(find.text('Tartine sandwich')), findsOneWidget);
    expect(_onDetail(find.text('kcal, likely 560–820')), findsOneWidget);
    expect(_onDetail(find.text('Macros')), findsOneWidget);
    expect(_onDetail(find.text('estimated from Tartine order')), findsOneWidget);
    expect(_onDetail(find.text('from expense · high-carb')), findsOneWidget);
    await _reveal(tester, NutritionMealDetailScreen, _onDetail(find.text('Linked expense')));
    expect(_onDetail(find.text('Tartine')), findsOneWidget);
    // the user's currency: the dong sign, never a dollar.
    expect(_onDetail(find.text(formatCurrency(16.20, Currency.vnd))), findsOneWidget);
    expect(_onDetail(find.textContaining(r'$')), findsNothing);
    await shot(tester, 'meal_detail_linked_${_theme(dark)}');
  });

  scenarioTest('meal detail by hand', (tester, dark) async {
    final theme = _theme(dark);
    await _boot(tester, dark);
    await _go(tester, '/areas/nutrition/meal/$_handMeal');

    // meal_detail_by_hand
    expect(_onDetail(find.text('Oats & banana')), findsOneWidget);
    await _reveal(tester, NutritionMealDetailScreen, _onDetail(find.text('Added by hand')));
    expect(_onDetail(find.text('Not from an expense')), findsOneWidget);
    expect(_onDetail(find.bySemanticsLabel('Adjust estimate')), findsOneWidget);
    expect(_onDetail(find.bySemanticsLabel('Delete')), findsOneWidget);
    await shot(tester, 'meal_detail_by_hand_$theme');

    // meal_adjust
    await _tap(tester, _onDetail(find.bySemanticsLabel('Adjust estimate')));
    expect(_inBottomSheet(find.text('Adjust estimate')), findsOneWidget);
    expect(_inBottomSheet(find.text('Or pick a common one')), findsNothing);
    await shot(tester, 'meal_adjust_$theme');

    // add_meal_edit: edit mode saves over the meal in place.
    await tester.enterText(_inBottomSheet(find.byType(TextField)).last, 'Oats & berries');
    await _tapToWrite(tester, _inBottomSheet(find.text('Save')));
    expect(find.byType(BottomSheet), findsNothing);
    expect(_onDetail(find.text('Oats & berries')), findsOneWidget);
    await shot(tester, 'add_meal_edit_$theme');

    // meal_delete: back on the Nutrition page, without the meal.
    await _tap(tester, _onDetail(find.bySemanticsLabel('Delete')));
    expect(find.byType(NutritionMealDetailScreen), findsNothing);
    expect(find.byWidgetPredicate((w) => w is DetailScreen && w.area == Area.nutrition),
        findsOneWidget);
    final meals = _container(tester).read(areaDetailProvider(Area.nutrition)).requireValue.meals;
    expect(meals.where((m) => m.id == _handMeal), isEmpty);
    await shot(tester, 'meal_delete_$theme');
  });

  scenarioTest('meal detail loading', (tester, dark) async {
    await _boot(tester, dark,
        overrides: [nutritionControllerProvider.overrideWith(_PendingNutrition.new)]);
    await _go(tester, '/areas/nutrition/meal/$_handMeal');

    expect(_onDetail(find.text('Loading…')), findsOneWidget);
    expect(_onDetail(find.text('Nutrition')), findsOneWidget);
    await shot(tester, 'meal_detail_loading_${_theme(dark)}');
  });

  scenarioTest('meal detail missing', (tester, dark) async {
    await _boot(tester, dark);
    await _go(tester, '/areas/nutrition/meal/gone');

    expect(_onDetail(find.text('Meal not found.')), findsOneWidget);
    expect(_onDetail(find.text('Not found')), findsOneWidget);
    await shot(tester, 'meal_detail_missing_${_theme(dark)}');
  });

  scenarioTest('add meal', (tester, dark) async {
    final theme = _theme(dark);
    await _boot(tester, dark);
    await _go(tester, '/areas/nutrition');
    final add = find.bySemanticsLabel('Add a meal');
    await _reveal(tester, DetailScreen, add);
    await tester.tap(add.hitTestable());
    await tester.pumpAndSettle();

    // add_meal_empty
    expect(_inBottomSheet(find.text('Add a meal')), findsOneWidget);
    expect(_inBottomSheet(find.text('When')), findsOneWidget);
    expect(_inBottomSheet(find.text('What did you eat?')), findsOneWidget);
    expect(_inBottomSheet(find.text('Or pick a common one')), findsOneWidget);
    await shot(tester, 'add_meal_empty_$theme');

    // add_meal_slot_selected
    await _tap(tester, _inBottomSheet(find.bySemanticsLabel('Dinner')));
    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(_inBottomSheet(find.bySemanticsLabel('Dinner'))),
        isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(_inBottomSheet(find.bySemanticsLabel('Lunch'))),
        isSemantics(isSelected: false));
    handle.dispose();
    await shot(tester, 'add_meal_slot_selected_$theme');

    // add_meal_estimated
    await tester.enterText(_inBottomSheet(find.byType(TextField)).last, 'pho');
    await _tap(tester, _inBottomSheet(find.bySemanticsLabel('Estimate')));
    expect(_inBottomSheet(find.textContaining('kcal, likely ')), findsOneWidget);
    expect(_inBottomSheet(find.text('Protein')), findsOneWidget);
    expect(_inBottomSheet(find.text('Or pick a common one')), findsNothing);
    await shot(tester, 'add_meal_estimated_$theme');

    // add_meal_saved
    await _tapToWrite(tester, _inBottomSheet(find.text('Save')));
    expect(find.byType(BottomSheet), findsNothing);
    final meals = _container(tester).read(areaDetailProvider(Area.nutrition)).requireValue.meals;
    expect(meals.where((m) => m.name == 'pho' && m.slot == 'Dinner'), hasLength(1));
    await shot(tester, 'add_meal_saved_$theme');
  });

  // --- money ----------------------------------------------------------------

  for (final (step, data) in [
    ('budgets_on_track', () => Stream.value(_month([_envelope('Groceries', cap: 500, spent: 200)]))),
    ('budgets_over', () => Stream.value(_month([_envelope('Dining', cap: 100, spent: 120)]))),
    ('budgets_zero_cap', () => Stream.value(_month([_envelope('Gifts', cap: 0, spent: 0)]))),
    ('budgets_loading', () => StreamController<BudgetsData>().stream),
    ('budgets_error', () => Stream<BudgetsData>.error(StateError('scenario'))),
  ]) {
    scenarioTest(step, (tester, dark) async {
      await _boot(tester, dark, overrides: [_budgets(data)]);
      await _go(tester, '/you/budgets');

      expect(find.byType(BudgetsScreen), findsOneWidget);
      switch (step) {
        case 'budgets_on_track':
          expect(_onBudgets(find.text(formatCurrency(2800, Currency.usd))), findsOneWidget);
          expect(_onBudgets(find.text('left this month')), findsOneWidget);
          expect(_onBudgets(find.text('${formatCurrency(300, Currency.usd)} left')), findsOneWidget);
          for (final word in ['On track', 'Worth watching', 'Needs care']) {
            expect(_onBudgets(find.text(word)), findsNothing, reason: word);
          }
        case 'budgets_over':
          expect(_onBudgets(find.text('${formatCurrency(20, Currency.usd)} over')), findsOneWidget);
          expect(_onBudgets(find.text('Needs care')), findsOneWidget);
        case 'budgets_zero_cap':
          expect(_onBudgets(find.text('${formatCurrency(0, Currency.usd)} left')), findsOneWidget);
          expect(_onBudgets(find.text('Needs care')), findsNothing);
          expect(tester.takeException(), isNull);
        case 'budgets_loading':
          expect(_onBudgets(find.text('…')), findsOneWidget);
        case 'budgets_error':
          expect(_onBudgets(find.text("Couldn't load your budgets.")), findsOneWidget);
      }
      await shot(tester, '${step}_${_theme(dark)}');
    });
  }

  scenarioTest('budgets goals', (tester, dark) async {
    final theme = _theme(dark);
    await _boot(tester, dark);
    await _go(tester, '/you/budgets-goals');
    final seeded = SeedData.goals.dailyBudget;

    // budgets_goals
    expect(find.byType(BudgetsGoalsScreen), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Daily targets'), findsOneWidget);
    expect(find.text(formatCurrency(seeded, Currency.usd)), findsOneWidget);
    await shot(tester, 'budgets_goals_$theme');

    // budgets_goals_stepper
    await _tap(tester, find.bySemanticsLabel('Increase Budget'));
    expect(find.text(formatCurrency(seeded + 5, Currency.usd)), findsOneWidget);
    await shot(tester, 'budgets_goals_stepper_$theme');

    // budgets_goals_saved: Save writes the goals and returns to You.
    await _tap(tester, find.bySemanticsLabel('Save'));
    expect(find.byType(BudgetsGoalsScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    final goals = await _container(tester).read(goalsRepositoryProvider).get();
    expect(goals.dailyBudget, seeded + 5);
    await shot(tester, 'budgets_goals_saved_$theme');
  });

  scenarioTest('new entry expense', (tester, dark) async {
    final theme = _theme(dark);
    await _boot(tester, dark, overrides: [
      spendHabitsProvider.overrideWith((ref) => Stream.value(const [_habit])),
    ]);
    await _push(tester, '/entry/new');

    // new_entry_expense
    expect(_onEntry(find.text('New entry')), findsOneWidget);
    for (final key in ['1', '2']) {
      await _key(tester, key);
    }
    expect(_onEntry(find.text('12.00')), findsOneWidget);
    expect(_onEntry(find.text(Currency.usd.symbol)), findsOneWidget);
    await shot(tester, 'new_entry_expense_$theme');

    // new_entry_quick_pick
    final detail = formatCurrency(_habit.averageAmount, Currency.usd);
    expect(_onEntry(find.bySemanticsLabel('${_habit.title}, $detail')), findsOneWidget);
    await _tap(tester, _onEntry(find.text(_habit.title)));
    expect(_onEntry(find.text('4.50')), findsOneWidget);
    await shot(tester, 'new_entry_quick_pick_$theme');

    // new_entry_added: Add writes the expense and closes the sheet.
    await _tap(tester, _onEntry(find.bySemanticsLabel('Add')));
    expect(find.byType(NewEntrySheet), findsNothing);
    final all = await _container(tester).read(entryRepositoryProvider).getAll();
    expect(all.where((e) => e.title == _habit.title && e.amount == -4.5), hasLength(1));
    await shot(tester, 'new_entry_added_$theme');
  });

  scenarioTest('new entry kinds', (tester, dark) async {
    final theme = _theme(dark);
    await _boot(tester, dark);

    // new_entry_workout
    await _push(tester, '/entry/new?kind=workout');
    expect(_onEntry(find.text('min')), findsOneWidget);
    expect(_onEntry(find.bySemanticsLabel('Run, 30 min')), findsOneWidget);
    await shot(tester, 'new_entry_workout_$theme');
    await _tap(tester, _onEntry(find.text('Cancel')));
    expect(find.byType(NewEntrySheet), findsNothing);

    // new_entry_ritual
    await _push(tester, '/entry/new?kind=ritual');
    expect(_onEntry(find.text('New routine')), findsWidgets);
    expect(_onEntry(find.bySemanticsLabel('Morning pages, Routine')), findsOneWidget);
    await shot(tester, 'new_entry_ritual_$theme');
    await _tap(tester, _onEntry(find.text('Cancel')));

    // new_entry_log_with_pal: Pal's parse fills the form.
    await _push(tester, '/entry/new');
    expect(_onEntry(find.text('Log with Pal')), findsOneWidget);
    await tester.enterText(_onEntry(find.byType(TextField)).first, 'coffee 5');
    await _tap(tester, _onEntry(find.text('Parse')));
    expect(_onEntry(find.text('5.00')), findsOneWidget);
    await shot(tester, 'new_entry_log_with_pal_$theme');
    await _tap(tester, _onEntry(find.text('Cancel')));

    // new_entry_offline_notice
    await _push(tester, '/entry/new?kind=expense&notice=pal-offline');
    expect(find.text("Pal's unreachable. Log it here."), findsOneWidget);
    await shot(tester, 'new_entry_offline_notice_$theme');
  });

  // --- recap ----------------------------------------------------------------

  scenarioTest('recap ranges', (tester, dark) async {
    final theme = _theme(dark);
    await _boot(tester, dark, overrides: _insights());
    await _push(tester, '/recap?range=day');

    // recap_day
    for (final caption in ['Spent', 'Moved', 'Rituals']) {
      expect(_onRecap(find.text(caption)), findsOneWidget, reason: caption);
    }
    expect(_onRecap(find.text('Wins')), findsOneWidget);
    expect(_onRecap(find.text(_win(InsightRange.day))), findsOneWidget);
    await shot(tester, 'recap_day_$theme');

    // recap_week, recap_month
    for (final (range, label) in [(InsightRange.week, 'Week'), (InsightRange.month, 'Month')]) {
      await _tap(tester, _onRecap(find.text(label)));
      expect(_onRecap(find.text(_win(range))), findsOneWidget, reason: label);
      expect(_onRecap(find.text(_win(InsightRange.day))), findsNothing);
      await shot(tester, 'recap_${range.name}_$theme');
    }

    // recap_ask_pal_more
    await _reveal(tester, RecapScreen, _onRecap(find.text('Ask Pal more')));
    expect(_onRecap(find.text(_tryThis)), findsOneWidget);
    await _tap(tester, _onRecap(find.text('Ask Pal more')));
    expect(_sheet, findsOneWidget);
    expect(_inSheet(find.text('Tell me more about this recap')), findsOneWidget);
    await shot(tester, 'recap_ask_pal_more_$theme');
  });

  scenarioTest('recap patterns row', (tester, dark) async {
    await _boot(tester, dark, overrides: _insights());
    await _push(tester, '/recap?range=day');
    await _reveal(tester, RecapScreen, _onRecap(find.text('Patterns are on You')));
    await _tap(tester, _onRecap(find.text('Patterns are on You')));

    expect(find.byType(RecapScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    await shot(tester, 'recap_patterns_row_${_theme(dark)}');
  });

  scenarioTest('recap loading', (tester, dark) async {
    await _boot(tester, dark,
        overrides: _insights(answer: (_) => Completer<PalInsights?>().future));
    await _push(tester, '/recap?range=day');

    expect(_onRecap(find.text('Pal is reviewing your recap…')), findsOneWidget);
    await shot(tester, 'recap_loading_${_theme(dark)}');
  });

  scenarioTest('recap error', (tester, dark) async {
    await _boot(tester, dark, overrides: [
      ..._insights(),
      recapDataProvider(InsightRange.day)
          .overrideWith((_) => Stream<RecapData>.error(StateError('scenario'))),
    ]);
    await _push(tester, '/recap?range=day');

    expect(_onRecap(find.text("Couldn't load this recap.")), findsOneWidget);
    await shot(tester, 'recap_error_${_theme(dark)}');
  });

  scenarioTest('recap empty', (tester, dark) async {
    await _boot(tester, dark, overrides: _insights(answer: (_) async => null));
    await _push(tester, '/recap?range=day');

    expect(_onRecap(find.text('Keep logging and Pal will gather your wins and patterns here.')),
        findsOneWidget);
    expect(_onRecap(find.text('Wins')), findsNothing);
    await shot(tester, 'recap_empty_${_theme(dark)}');
  });

  // --- email ----------------------------------------------------------------

  scenarioTest('email setup', (tester, dark) async {
    final theme = _theme(dark);
    final sync = _FakeSync();
    await _boot(tester, dark, overrides: [emailSyncServiceProvider.overrideWithValue(sync)]);
    await _push(tester, '/email');

    // email_intro
    expect(find.byType(EmailIntroScreen), findsOneWidget);
    expect(find.text('Stop logging card charges by hand.'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
    expect(find.bySemanticsLabel('Connect'), findsOneWidget);
    await shot(tester, 'email_intro_$theme');

    // email_connect
    await _tap(tester, find.bySemanticsLabel('Connect'));
    expect(find.byType(EmailSetupScreen), findsOneWidget);
    expect(find.text('Gmail setup'), findsOneWidget);
    await shot(tester, 'email_connect_$theme');

    // email_setup_empty: Save stays inert until a test passes.
    final fields = find.descendant(of: find.byType(EmailSetupScreen), matching: find.byType(TextField));
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, isEmpty);
    await _reveal(tester, EmailSetupScreen, find.text('Save'));
    await _tap(tester, find.text('Save'));
    expect(sync.account, isNull);
    expect(find.byType(EmailSetupScreen), findsOneWidget);
    await shot(tester, 'email_setup_empty_$theme');

    // email_setup_ready
    await _reveal(tester, EmailSetupScreen, find.text('App password'), up: true);
    await tester.enterText(fields.at(0), _gmail.address);
    await tester.enterText(fields.at(1), 'abcdefghijklmnop');
    await _reveal(tester, EmailSetupScreen, find.text('Test connection'));
    await _tap(tester, find.text('Test connection'));
    expect(find.text('Connected to imap.gmail.com'), findsOneWidget);
    await shot(tester, 'email_setup_ready_$theme');
  });

  scenarioTest('email setup test failed', (tester, dark) async {
    await _boot(tester, dark,
        overrides: [emailSyncServiceProvider.overrideWithValue(_FakeSync(testResult: false))]);
    await _push(tester, '/email');
    await _tap(tester, find.bySemanticsLabel('Connect'));

    final fields = find.descendant(of: find.byType(EmailSetupScreen), matching: find.byType(TextField));
    await tester.enterText(fields.at(1), 'abcdefghijklmnop');
    await _reveal(tester, EmailSetupScreen, find.text('Test connection'));
    await _tap(tester, find.text('Test connection'));
    expect(find.text('Connection failed. Check the password.'), findsOneWidget);
    await shot(tester, 'email_setup_test_failed_${_theme(dark)}');
  });

  scenarioTest('email dashboard', (tester, dark) async {
    final theme = _theme(dark);
    final sync = _FakeSync(account: _gmail);
    await _boot(tester, dark, overrides: [emailSyncServiceProvider.overrideWithValue(sync)]);
    await _push(tester, '/email');

    // email_dashboard_connected
    expect(find.byType(EmailDashboardScreen), findsOneWidget);
    expect(find.text(_gmail.address), findsOneWidget);
    expect(find.text('Connected · Never synced'), findsOneWidget);
    await shot(tester, 'email_dashboard_connected_$theme');

    // email_sync_now
    await _tap(tester, find.text('Sync now'));
    expect(sync.syncCalls, 1);
    await shot(tester, 'email_sync_now_$theme');

    // email_dashboard_toggle
    expect(_switchOn(tester, 'Notify on new detection'), isFalse);
    await _tap(tester, find.text('Notify on new detection'));
    expect(_switchOn(tester, 'Notify on new detection'), isTrue);
    await shot(tester, 'email_dashboard_toggle_$theme');

    // email_disconnect: the entry turns back into the intro.
    await _reveal(tester, EmailDashboardScreen, find.text('Disconnect'));
    await _tap(tester, find.text('Disconnect'));
    expect(sync.account, isNull);
    expect(find.byType(EmailDashboardScreen), findsNothing);
    expect(find.text('Stop logging card charges by hand.'), findsOneWidget);
    await shot(tester, 'email_disconnect_$theme');
  });

  scenarioTest('email dashboard failed', (tester, dark) async {
    await _boot(tester, dark, overrides: [
      emailSyncServiceProvider.overrideWithValue(_FakeSync(account: _gmail)),
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.error)),
    ]);
    await _push(tester, '/email');

    expect(find.text('Sync failed. Try again.'), findsOneWidget);
    await shot(tester, 'email_dashboard_failed_${_theme(dark)}');
  });

  // --- settings -------------------------------------------------------------

  scenarioTest('notifications', (tester, dark) async {
    final theme = _theme(dark);
    await _boot(tester, dark,
        prefs: {'settings.ritualReminders': false, 'settings.budgetAlerts': false});
    await _go(tester, '/you/notifications');

    // notifications_allowed
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('Not allowed yet'), findsNothing);
    await shot(tester, 'notifications_allowed_$theme');

    // notifications_toggle
    expect(_switchOn(tester, 'Routine reminders'), isFalse);
    await _tap(tester, find.text('Routine reminders'));
    expect(_switchOn(tester, 'Routine reminders'), isTrue);
    expect(find.text('Reminder time'), findsOneWidget);
    await shot(tester, 'notifications_toggle_$theme');
  });

  scenarioTest('notifications not allowed', (tester, dark) async {
    await _boot(tester, dark,
        prefs: {'settings.budgetAlerts': true},
        notifications: _FakeNotifications(granted: false));
    await _go(tester, '/you/notifications');

    expect(find.text('Not allowed yet'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    await shot(tester, 'notifications_not_allowed_${_theme(dark)}');
  });

  scenarioTest('settings screens', (tester, dark) async {
    final theme = _theme(dark);
    await _boot(tester, dark);

    // privacy
    await _go(tester, '/you/privacy');
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(find.text('Stored on this device'), findsOneWidget);
    expect(find.text('No tracking'), findsOneWidget);
    await shot(tester, 'privacy_$theme');

    // about
    await _go(tester, '/you/about');
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('Opal'), findsOneWidget);
    expect(find.text('Built with'), findsOneWidget);
    await shot(tester, 'about_$theme');

    // appearance
    await _go(tester, '/you/appearance');
    final screen = find.byType(AppearanceScreen);
    expect(screen, findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(Theme.of(tester.element(screen)).brightness, dark ? Brightness.dark : Brightness.light);
    await shot(tester, 'appearance_$theme');

    // appearance_light
    await _tap(tester, find.text('Light'));
    expect(Theme.of(tester.element(screen)).brightness, Brightness.light);
    expect(_container(tester).read(appSettingsControllerProvider).brightness, Brightness.light);
    await shot(tester, 'appearance_light_$theme');
  });

  for (final step in ['export_idle', 'export_done', 'export_error']) {
    scenarioTest(step, (tester, dark) async {
      if (step != 'export_idle') _mockClipboard(tester, fails: step == 'export_error');
      await _boot(tester, dark);
      await _go(tester, '/you/export');

      final copy = find.textContaining(RegExp(r'^Copy \d+ entries as JSON$'));
      expect(find.byType(ExportDataScreen), findsOneWidget);
      expect(copy, findsOneWidget);
      if (step != 'export_idle') await _tap(tester, copy);
      switch (step) {
        case 'export_done':
          expect(find.textContaining(RegExp(r'^Copied \d+ entries to the clipboard\.$')),
              findsOneWidget);
        case 'export_error':
          expect(find.text("Couldn't copy. Try again."), findsOneWidget);
          expect(find.textContaining('Copied'), findsNothing);
      }
      await shot(tester, '${step}_${_theme(dark)}');
    });
  }
}
