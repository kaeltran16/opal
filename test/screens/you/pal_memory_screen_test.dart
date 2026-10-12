import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/spend_patterns.dart';
import 'package:opal/controllers/correlations_controller.dart';
import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/pal_findings_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/spend_patterns_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/you/pal_memory_screen.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _caffeine = PalFact(id: 'f1', text: 'No caffeine after 2 PM');
const _vegetarian = PalFact(id: 'f2', text: 'Vegetarian on weekdays');
const _walks = InsightPattern(colorToken: 'move', title: 'Walks lift your mood.', detail: 'd');

// a Money finding the server does not hold, so only dismissAll can clear it.
const _spend = SpendPatterns(
  biggestDay: BiggestDay(
    peakWeekday: DateTime.friday,
    quietWeekday: DateTime.tuesday,
    peakAverage: 70,
    quietAverage: 35,
  ),
);
const _spendLine = 'You spend most on Fridays.';

/// Pal's memory held in the fake, so the real palMemory provider reloads what
/// a forget or clear left behind. [failWrites] makes forget and clear throw.
class _FakePal implements PalService {
  _FakePal({this.facts = const [], this.patterns = const []});

  List<PalFact> facts;
  List<InsightPattern> patterns;
  bool failWrites = false;

  PalMemoryDigest get _digest => PalMemoryDigest(facts: facts, patterns: patterns);

  @override
  Future<PalMemoryDigest> memory() async => _digest;

  @override
  Future<PalMemoryDigest> deleteFact(String id) async {
    if (failWrites) throw Exception('pal offline');
    facts = [for (final f in facts) if (f.id != id) f];
    return _digest;
  }

  @override
  Future<PalMemoryDigest> clearMemory() async {
    if (failWrites) throw Exception('pal offline');
    facts = const [];
    patterns = const [];
    return _digest;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoNutritionPatterns extends NutritionController {
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
      pending: null,
      patterns: [],
    );
  }
}

/// Opens What Pal remembers from a launcher page, as You pushes it. Returns
/// the container so a test can read the findings controller.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  _FakePal pal, {
  SpendPatterns spend = const SpendPatterns(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      palServiceProvider.overrideWithValue(pal),
      surfacedCorrelationsProvider.overrideWith((_) async => const []),
      spendPatternsProvider.overrideWith((_) => Stream.value(spend)),
      nutritionControllerProvider.overrideWith(_NoNutritionPatterns.new),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(builder: (_) => const PalMemoryScreen())),
            child: const Text('Open memory'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open memory'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PalMemoryScreen)));
}

const _emptyCopy =
    "As we talk, I'll note facts you mention and patterns I learn here. You can delete anything.";

void main() {
  testWidgets('lists facts and patterns under their headings', (tester) async {
    await _pump(
      tester,
      _FakePal(facts: [_caffeine, _vegetarian], patterns: [_walks]),
      spend: _spend,
    );

    expect(find.text('Facts and preferences Pal uses'), findsOneWidget);
    expect(find.text('What Pal remembers'), findsOneWidget);
    expect(find.text('Facts you told Pal'), findsOneWidget);
    expect(find.text(_caffeine.text), findsOneWidget);
    expect(find.text(_vegetarian.text), findsOneWidget);
    expect(find.text('Patterns Pal uses'), findsOneWidget);
    expect(
      find.text('The same patterns as Pal noticed on You. Dismiss one and it leaves both.'),
      findsOneWidget,
    );
    expect(find.text(_spendLine), findsOneWidget);
    expect(find.text('Money'), findsOneWidget);
    expect(find.text(_walks.title), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Clear what Pal remembers'), findsOneWidget);
    expect(find.text(_emptyCopy), findsNothing);
  });

  testWidgets('the x buttons carry Forget and Dismiss labels at 44 by 44', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakePal(facts: [_caffeine], patterns: [_walks]));

    final forget = find.bySemanticsLabel('Forget: ${_caffeine.text}');
    final dismiss = find.bySemanticsLabel('Dismiss: ${_walks.title}');
    expect(forget, findsOneWidget);
    expect(dismiss, findsOneWidget);
    expect(tester.getSemantics(forget), isSemantics(isButton: true, hasTapAction: true));
    expect(tester.getSize(forget), const Size(44, 44));
    expect(tester.getSize(dismiss), const Size(44, 44));
    handle.dispose();
  });

  testWidgets('forget removes the fact', (tester) async {
    final pal = _FakePal(facts: [_caffeine, _vegetarian]);
    await _pump(tester, pal);

    await tester.tap(find.bySemanticsLabel('Forget: ${_caffeine.text}'));
    await tester.pumpAndSettle();

    expect(find.text(_caffeine.text), findsNothing);
    expect(find.text(_vegetarian.text), findsOneWidget);
  });

  testWidgets('a failed forget keeps the fact and says so', (tester) async {
    final pal = _FakePal(facts: [_caffeine])..failWrites = true;
    await _pump(tester, pal);

    await tester.tap(find.bySemanticsLabel('Forget: ${_caffeine.text}'));
    await tester.pumpAndSettle();

    expect(find.text(_caffeine.text), findsOneWidget);
    expect(find.text("Couldn't forget that. Try again."), findsOneWidget);
  });

  testWidgets('dismissing a pattern removes it here and from the findings', (tester) async {
    final c = await _pump(tester, _FakePal(patterns: [_walks]), spend: _spend);

    await tester.tap(find.bySemanticsLabel('Dismiss: $_spendLine'));
    await tester.pumpAndSettle();

    expect(find.text(_spendLine), findsNothing);
    expect(find.text(_walks.title), findsOneWidget);
    final findings = c.read(palFindingsControllerProvider).requireValue;
    expect([for (final f in findings) f.line], [_walks.title]);
  });

  testWidgets('Clear asks inline first, and Cancel restores the idle button', (tester) async {
    await _pump(tester, _FakePal(facts: [_caffeine]));

    await tester.tap(find.text('Clear what Pal remembers'));
    await tester.pumpAndSettle();

    expect(find.text('Clear everything Pal remembers?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Clear what Pal remembers'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Clear what Pal remembers'), findsOneWidget);
    expect(find.text('Clear everything Pal remembers?'), findsNothing);
    expect(find.text(_caffeine.text), findsOneWidget);
  });

  testWidgets('Clear wipes facts and every pattern, then shows the empty copy',
      (tester) async {
    final c = await _pump(
      tester,
      _FakePal(facts: [_caffeine, _vegetarian], patterns: [_walks]),
      spend: _spend,
    );

    await tester.tap(find.text('Clear what Pal remembers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text(_caffeine.text), findsNothing);
    expect(find.text(_vegetarian.text), findsNothing);
    expect(find.text(_walks.title), findsNothing);
    // the on-device finding goes too, though the server never held it.
    expect(find.text(_spendLine), findsNothing);
    expect(c.read(palFindingsControllerProvider).requireValue, isEmpty);
    expect(find.text(_emptyCopy), findsOneWidget);
    expect(find.text('Clear what Pal remembers'), findsNothing);
  });

  testWidgets('a failed Clear keeps every fact and pattern and says so', (tester) async {
    final pal = _FakePal(facts: [_caffeine, _vegetarian], patterns: [_walks])
      ..failWrites = true;
    final c = await _pump(tester, pal, spend: _spend);

    await tester.tap(find.text('Clear what Pal remembers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't clear what Pal remembers. Try again."), findsOneWidget);
    expect(find.text(_caffeine.text), findsOneWidget);
    expect(find.text(_vegetarian.text), findsOneWidget);
    expect(find.text(_walks.title), findsOneWidget);
    expect(find.text(_spendLine), findsOneWidget);
    expect(c.read(palFindingsControllerProvider).requireValue, hasLength(2));
    // the confirm closes.
    expect(find.text('Clear everything Pal remembers?'), findsNothing);
    expect(find.text('Clear what Pal remembers'), findsOneWidget);
  });

  testWidgets('shows the empty copy and no Clear with nothing remembered', (tester) async {
    await _pump(tester, _FakePal());

    expect(find.text(_emptyCopy), findsOneWidget);
    expect(find.text('Facts you told Pal'), findsNothing);
    expect(find.text('Patterns Pal uses'), findsNothing);
    expect(find.text('Clear what Pal remembers'), findsNothing);
  });

  testWidgets('facts only: no patterns heading or caption', (tester) async {
    await _pump(tester, _FakePal(facts: [_caffeine]));

    expect(find.text('Facts you told Pal'), findsOneWidget);
    expect(find.text('Patterns Pal uses'), findsNothing);
    expect(
      find.text('The same patterns as Pal noticed on You. Dismiss one and it leaves both.'),
      findsNothing,
    );
    expect(find.text(_emptyCopy), findsNothing);
    expect(find.text('Clear what Pal remembers'), findsOneWidget);
  });

  testWidgets('findings only: no facts heading', (tester) async {
    await _pump(tester, _FakePal(), spend: _spend);

    expect(find.text('Facts you told Pal'), findsNothing);
    expect(find.text('Patterns Pal uses'), findsOneWidget);
    expect(find.text(_spendLine), findsOneWidget);
    expect(find.text(_emptyCopy), findsNothing);
    expect(find.text('Clear what Pal remembers'), findsOneWidget);
  });
}
