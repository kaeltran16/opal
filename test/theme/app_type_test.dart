import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_type.dart';

void main() {
  test('AppType ramp has the expected sizes and carries no color', () {
    expect(AppType.caption2.fontSize, 11);
    expect(AppType.caption.fontSize, 12);
    expect(AppType.footnote.fontSize, 13);
    expect(AppType.subhead.fontSize, 15);
    expect(AppType.callout.fontSize, 16);
    expect(AppType.body.fontSize, 17);
    expect(AppType.headline.fontSize, 17);
    expect(AppType.headline.fontWeight, FontWeight.w600);
    expect(AppType.title3.fontSize, 20);
    expect(AppType.title2.fontSize, 22);
    expect(AppType.title1.fontSize, 28);
    expect(AppType.large.fontSize, 34);
    expect(AppType.amount.fontSize, 34);
    expect(AppType.amountLg.fontSize, 48);
    expect(AppType.eyebrow.fontSize, 12);
    expect(AppType.body.color, isNull);
  });
}
