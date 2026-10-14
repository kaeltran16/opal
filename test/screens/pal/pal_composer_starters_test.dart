import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/entry_repository.dart';
import 'package:opal/data/repositories/settings_repository.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/app_icon.dart';

/// One of the static fallback labels, used to assert the fallback is (or isn't)
/// on screen. Kept in sync with `_IdleBody._starters`.
const _staticLabel = 'Verve coffee, \$5';

/// Pal with no pick to offer; the starters come from the suggestions seam.
class _NoPickPal implements PalService {
  @override
  Future<WorkoutSuggestion> suggestWorkout({bool another = false, String? excludeRoutineId}) =>
      Future.error(const PalException('unreachable'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The composer sheet with its suggestions seam driven by [suggestions], in
/// [currency], logging offline into [db].
Future<Widget> _app(
  FutureOr<List<PalSuggestion>> Function() suggestions, {
  Currency currency = Currency.usd,
  LoopDatabase? db,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await SettingsRepository(prefs).setCurrency(currency);
  final colors = AppColors.light();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (db != null) loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(_NoPickPal()),
      palSuggestionsProvider(SuggestionSurface.composer)
          .overrideWith((ref) async => suggestions()),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: const Scaffold(body: PalComposerSheet()),
    ),
  );
}

const _vndLabel = 'Verve coffee, 5.000\u00a0₫';

void main() {
  testWidgets('composer renders Pal-provided starters as plain pills', (tester) async {
    await tester.pumpWidget(await _app(() => const [
          PalSuggestion(
              label: 'Pal-made coffee, \$4',
              icon: 'cup.and.saucer.fill',
              colorToken: 'money'),
        ]));
    await tester.pumpAndSettle();
    expect(find.text('Pal-made coffee, \$4'), findsOneWidget);
    // a pill carries no icon of its own.
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.name == 'cup.and.saucer.fill'),
        findsNothing);
  });

  testWidgets('shows a skeleton — not the fallback — while suggestions load', (tester) async {
    final pending = Completer<List<PalSuggestion>>();
    addTearDown(() => pending.complete(const []));

    await tester.pumpWidget(await _app(() => pending.future));
    await tester.pump();

    expect(find.byKey(const Key('starter-skeleton')), findsOneWidget,
        reason: 'loading needs its own signal');
    expect(find.text(_staticLabel), findsNothing,
        reason: 'the fallback must not masquerade as a loaded suggestion');
  });

  testWidgets('falls back to the static starters when Pal returns nothing', (tester) async {
    await tester.pumpWidget(await _app(() => const <PalSuggestion>[]));
    await tester.pumpAndSettle();

    expect(find.text(_staticLabel), findsOneWidget);
    expect(find.byKey(const Key('starter-skeleton')), findsNothing);
  });

  testWidgets('the static coffee starter reads in vnd and logs -5000 offline',
      (tester) async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
        await _app(() => const <PalSuggestion>[], currency: Currency.vnd, db: db));
    await tester.pumpAndSettle();

    expect(find.text(_staticLabel), findsNothing);
    await tester.tap(find.text(_vndLabel));
    await tester.pumpAndSettle();

    final entries = await tester.runAsync(() => EntryRepository(db).getAll());
    final money = entries!.where((e) => e.type == EntryType.money).toList();
    expect(money, hasLength(1));
    expect(money.single.title, 'Verve coffee');
    expect(money.single.amount, -5000);
  });

  testWidgets('the static coffee starter follows a currency switch while open',
      (tester) async {
    await tester.pumpWidget(await _app(() => const <PalSuggestion>[]));
    await tester.pumpAndSettle();
    expect(find.text(_staticLabel), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(PalComposerSheet)));
    await container.read(appSettingsControllerProvider.notifier).setCurrency(Currency.vnd);
    await tester.pumpAndSettle();

    expect(find.text(_vndLabel), findsOneWidget);
    expect(find.text(_staticLabel), findsNothing);
  });
}
