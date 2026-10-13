import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/inset_section.dart';

const _title = 'History and trends';
// the test font draws every glyph a full em wide, so only a short title stays on one line
const _shortTitle = 'History';
const _value = 'All sessions, all time';
const _header = 'Recent';
const _narrowWidth = 390.0;
const _phoneHeight = 844.0;
const _largeText = 1.3;
const _rowHeight = 52.0;

final _colors = AppColors.light();

Future<void> _pump(WidgetTester tester, Widget child, {double textScale = 1}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(_narrowWidth, _phoneHeight);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  return tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true, extensions: [_colors]),
    home: Scaffold(body: child),
  ));
}

Widget _section({String title = _title, String? value = _value}) => InsetSection(
      header: _header,
      children: [
        ListRow(
          icon: 'calendar',
          iconBg: const Color(0xFFFF0000),
          iconColor: const Color(0xFF00FF00),
          title: title,
          value: value,
          last: true,
          onTap: () {},
        ),
      ],
    );

/// colours painted by boxes between the icon and its row.
Iterable<Color?> _paintedAroundIcon(WidgetTester tester) {
  final inRow = find.descendant(of: find.byType(ListRow), matching: find.byWidgetPredicate(
    (w) => w is Container || w is DecoratedBox || w is ColoredBox,
  ));
  final boxes = find.ancestor(of: find.byType(AppIcon), matching: inRow);
  return tester.widgetList(boxes).map((w) => switch (w) {
        Container(:final color, :final decoration) =>
          color ?? (decoration is BoxDecoration ? decoration.color : null),
        DecoratedBox(:final decoration) => decoration is BoxDecoration ? decoration.color : null,
        ColoredBox(:final color) => color,
        _ => null,
      });
}

void main() {
  testWidgets('the icon sits on no coloured tile', (tester) async {
    await _pump(tester, _section());

    expect(_paintedAroundIcon(tester).whereType<Color>(), isEmpty);
  });

  testWidgets('the icon is a line icon in ink2', (tester) async {
    await _pump(tester, _section());

    expect(tester.widget<AppIcon>(find.byType(AppIcon).first).color, _colors.ink2);
  });

  testWidgets('a long title and value fit 390 wide at text scale 1.3', (tester) async {
    await _pump(tester, _section(), textScale: _largeText);

    expect(tester.takeException(), isNull);
    expect(find.text(_value), findsOneWidget);
  });

  testWidgets('a single-line row is exactly the tool-row height', (tester) async {
    await _pump(tester, _section(title: _shortTitle, value: null));

    expect(tester.getSize(find.byType(ListRow)).height, _rowHeight);
  });

  testWidgets('the header renders as written', (tester) async {
    await _pump(tester, _section());

    expect(find.text(_header), findsOneWidget);
    expect(find.text(_header.toUpperCase()), findsNothing);
  });

  testWidgets('a tappable row reads as its title and value', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _section());

    expect(find.bySemanticsLabel('$_title, $_value'), findsOneWidget);

    await _pump(tester, _section(value: null));
    expect(find.bySemanticsLabel(_title), findsOneWidget);
    semantics.dispose();
  });
}
