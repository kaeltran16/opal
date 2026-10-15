@Tags(['scenario'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/workout/active_session_screen.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _treadmillRoutine = 'seed-routine-treadmill-int';
const _treadmillSlot = 'seed-rex-cardio-treadmill';
const _startMinutes = 10;
const _wantMinutes = 20;
const _wantKm = 3.2;
const _kmTenths = 10;

String _theme(bool dark) => dark ? 'dark' : 'light';

Future<void> _tapTimes(WidgetTester tester, String label, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  scenarioTest('timed set entry', (tester, dark) async {
    await bootApp(tester, dark: dark);

    // a slot with no distance, so More distance starts from "No distance".
    final db = ProviderScope.containerOf(tester.element(find.byType(LoopApp)))
        .read(loopDatabaseProvider);
    await tester.runAsync(() => (db.update(db.routineExercises)
          ..where((r) => r.id.equals(_treadmillSlot)))
        .write(const RoutineExercisesCompanion(
          targetMinutes: Value(_startMinutes),
          targetKm: Value(null),
        )));

    appRouter(tester).pushNamed(AppRoute.activeSession.name,
        pathParameters: {'routineId': _treadmillRoutine});
    await tester.pumpAndSettle();

    expect(find.byType(ActiveSessionScreen), findsOneWidget);
    expect(find.text('Minutes'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('No distance'), findsOneWidget);
    expect(find.textContaining('kg'), findsNothing);
    await shot(tester, 'timed_set_entry_${_theme(dark)}');

    await _tapTimes(tester, 'More minutes', _wantMinutes - _startMinutes);
    await _tapTimes(tester, 'More distance', (_wantKm * _kmTenths).round());
    expect(find.text('20 min · 3.2 km'), findsOneWidget);

    await tester.tap(find.text('Complete set'));
    await tester.pumpAndSettle();

    expect(find.text('20 min · 3.2 km'), findsOneWidget);
    expect(find.text('Distance'), findsNothing);
    await shot(tester, 'timed_set_logged_${_theme(dark)}');
  });
}
