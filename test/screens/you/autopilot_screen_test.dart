import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/pal_agenda_controller.dart';
import 'package:opal/screens/you/autopilot_screen.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';

const _rent = PalAutopilotItem(
  id: 'rent-watch',
  colorToken: 'money',
  icon: 'house.fill',
  title: 'Rent auto-pay watch',
  subtitle: 'Alerts if balance dips before Mon',
  enabled: true,
);

const _coffee = PalAutopilotItem(
  id: 'coffee-nudge',
  colorToken: 'money',
  icon: 'cup.and.saucer.fill',
  title: 'Coffee nudge at \$15 / wk',
  subtitle: "You're at \$23, currently paused",
  enabled: false,
);

/// Opens Autopilot from a launcher page, as You pushes it.
Future<void> _pump(WidgetTester tester, Future<PalAgenda> Function() agenda) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [palAgendaProvider.overrideWith((ref) => agenda())],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(builder: (_) => const AutopilotScreen())),
            child: const Text('Open autopilot'),
          ),
        ),
      ),
    ),
  ));
  await _open(tester);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open autopilot'));
  await tester.pumpAndSettle();
}

Finder _switchOf(String title) =>
    find.descendant(of: find.bySemanticsLabel(title), matching: find.byType(CupertinoSwitch));

bool _isOn(WidgetTester tester, String title) =>
    tester.widget<CupertinoSwitch>(_switchOf(title)).value;

void main() {
  testWidgets('renders a row per autopilot item with its switch', (tester) async {
    await _pump(tester, () async => const PalAgenda(autopilot: [_rent, _coffee]));

    expect(find.text('Pal'), findsOneWidget);
    expect(find.text('Autopilot'), findsOneWidget);
    expect(find.text('What Pal handles quietly. Switch any of it off.'), findsOneWidget);
    expect(find.text('Rent auto-pay watch'), findsOneWidget);
    expect(find.text('Alerts if balance dips before Mon'), findsOneWidget);
    expect(find.text('Coffee nudge at \$15 / wk'), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsNWidgets(2));
    expect(_isOn(tester, _rent.title), isTrue);
    expect(_isOn(tester, _coffee.title), isFalse);
  });

  testWidgets('tapping a switch flips it and its semantics report checked', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, () async => const PalAgenda(autopilot: [_rent, _coffee]));

    expect(
      tester.getSemantics(_switchOf(_coffee.title)),
      isSemantics(label: _coffee.title, hasToggledState: true, isToggled: false),
    );

    await tester.tap(_switchOf(_coffee.title));
    await tester.pumpAndSettle();

    expect(_isOn(tester, _coffee.title), isTrue);
    expect(
      tester.getSemantics(_switchOf(_coffee.title)),
      isSemantics(label: _coffee.title, hasToggledState: true, isToggled: true),
    );
    // the other switch keeps its own state.
    expect(_isOn(tester, _rent.title), isTrue);
    handle.dispose();
  });

  testWidgets('tapping the row text flips its switch too', (tester) async {
    await _pump(tester, () async => const PalAgenda(autopilot: [_rent, _coffee]));

    await tester.tap(find.text(_rent.subtitle));
    await tester.pumpAndSettle();

    expect(_isOn(tester, _rent.title), isFalse);
  });

  testWidgets('a flipped switch survives popping and reopening Autopilot', (tester) async {
    await _pump(tester, () async => const PalAgenda(autopilot: [_rent, _coffee]));

    await tester.tap(_switchOf(_coffee.title));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back to You'), findsOneWidget);
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    expect(find.byType(AutopilotScreen), findsNothing);

    await _open(tester);
    expect(_isOn(tester, _coffee.title), isTrue);
    expect(_isOn(tester, _rent.title), isTrue);
  });

  testWidgets('shows the empty copy when nothing is on autopilot', (tester) async {
    await _pump(tester, () async => const PalAgenda());

    expect(find.text('Nothing on autopilot yet.'), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsNothing);
  });

  testWidgets('shows the error copy when the agenda fails', (tester) async {
    await _pump(tester, () => Future.error(Exception('pal offline')));

    expect(find.text("Couldn't load autopilot."), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsNothing);
  });
}
