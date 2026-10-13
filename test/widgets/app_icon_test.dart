import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/widgets/app_icon.dart';

void main() {
  test('maps the drag-handle glyph rather than falling back', () {
    expect(iconForSf('line.3.horizontal'), CupertinoIcons.line_horizontal_3);
    expect(iconForSf('line.3.horizontal'), isNot(CupertinoIcons.circle));
  });
}
