import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The labels a screen reader stops on inside [scope], in tree order: every
/// semantics node that carries a label or a tap. A blank entry is a stop with
/// nothing to read. Needs `tester.ensureSemantics()`.
List<String> semanticsStops(WidgetTester tester, Finder scope) {
  final stops = <String>[];
  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (!node.isMergedIntoParent &&
        (data.label.isNotEmpty || data.hasAction(SemanticsAction.tap))) {
      stops.add(data.label);
    }
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(tester.getSemantics(scope));
  return stops;
}
