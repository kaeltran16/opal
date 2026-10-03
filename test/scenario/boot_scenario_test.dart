@Tags(['scenario'])
library;

import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _tabLabel = 'Today';
const _shotWidth = 780;
const _shotHeight = 1688;

void main() {
  scenarioTest('boot', (tester, dark) async {
    await bootApp(tester, dark: dark);

    final label = find.text(_tabLabel).last;
    expect(label, findsOneWidget);

    // ahem glyphs are one em wide, so a real face lays the label out narrower
    // than font size times length.
    final paragraph = tester.renderObject<RenderParagraph>(label);
    final ahemWidth = paragraph.text.style!.fontSize! * _tabLabel.length;
    expect(paragraph.size.width, lessThan(ahemWidth));

    final name = 'boot_${dark ? 'dark' : 'light'}';
    await shot(tester, name);

    final bytes = File('${scenarioOut.path}/$name.png').readAsBytesSync();
    final image = (await tester.runAsync(() => decodeImageFromList(bytes)))!;
    addTearDown(image.dispose);
    expect(image.width, _shotWidth);
    expect(image.height, _shotHeight);
  });
}
