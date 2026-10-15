import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expects each of [blocks] (a heading's or row's text on screen) to sit on a
/// semantics node of its own: the node a screen reader stops on for it, and
/// the nodes grouped under that one, carry that text and none of the others.
/// Needs `tester.ensureSemantics()`.
void expectOwnSemanticsNodes(WidgetTester tester, List<String> blocks) {
  for (final text in blocks) {
    final node = tester.getSemantics(find.text(text).first);
    expect(node.label, contains(text));
    final carried = _labels(node).join('\n');
    for (final other in blocks.where((b) => b != text)) {
      expect(carried, isNot(contains(other)), reason: '"$text" carries "$other"');
    }
  }
}

List<String> _labels(SemanticsNode node) {
  final labels = [node.label];
  node.visitChildren((child) {
    labels.addAll(_labels(child));
    return true;
  });
  return labels;
}
