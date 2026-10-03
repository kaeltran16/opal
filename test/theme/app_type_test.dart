import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_type.dart';

const _minTextSize = 12;

final _roles = <String, TextStyle>{
  'caption2': AppType.caption2,
  'caption': AppType.caption,
  'footnote': AppType.footnote,
  'subhead': AppType.subhead,
  'callout': AppType.callout,
  'body': AppType.body,
  'headline': AppType.headline,
  'title3': AppType.title3,
  'title2': AppType.title2,
  'title1': AppType.title1,
  'large': AppType.large,
  'brief': AppType.brief,
  'amount': AppType.amount,
  'amountLg': AppType.amountLg,
  'display': AppType.display,
  'score': AppType.score,
  'lead': AppType.lead,
  'title': AppType.title,
  'label': AppType.label,
};

void _expectRole(
  TextStyle style, {
  required double size,
  required double line,
  required FontWeight weight,
  required double tracking,
}) {
  expect(style.fontSize, size);
  expect(style.height! * style.fontSize!, closeTo(line, 0.001));
  expect(style.fontWeight, weight);
  expect(style.letterSpacing, tracking);
}

void main() {
  test('legacy roles keep their sizes', () {
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
  });

  test('brief is 21/38 semibold with tight tracking', () {
    expect(AppType.brief.fontSize, 21);
    expect(AppType.brief.height, 38 / 21);
    expect(AppType.brief.fontWeight, FontWeight.w600);
    expect(AppType.brief.letterSpacing, -0.3);
  });

  test('the DESIGN.md section 4 roles have the exact metrics', () {
    _expectRole(AppType.display, size: 64, line: 68, weight: FontWeight.w300, tracking: -1.6);
    _expectRole(AppType.score, size: 40, line: 44, weight: FontWeight.w300, tracking: -0.8);
    _expectRole(AppType.lead, size: 30, line: 36, weight: FontWeight.w300, tracking: -0.6);
    _expectRole(AppType.title, size: 22, line: 27, weight: FontWeight.w500, tracking: -0.4);
    _expectRole(AppType.label, size: 13, line: 18, weight: FontWeight.w500, tracking: 0.3);
  });

  test('lead is the only serif role', () {
    expect(AppType.lead.fontFamily, 'Newsreader');
    _roles.forEach((name, style) {
      if (name != 'lead') expect(style.fontFamily, isNull, reason: name);
    });
  });

  test('display and score carry tabular figures', () {
    const tabular = FontFeature.tabularFigures();
    expect(AppType.display.fontFeatures, contains(tabular));
    expect(AppType.score.fontFeatures, contains(tabular));
  });

  test('no role carries a colour', () {
    _roles.forEach((name, style) => expect(style.color, isNull, reason: name));
  });

  test('no role is below 12 except the legacy caption2', () {
    _roles.forEach((name, style) {
      if (name == 'caption2') return;
      expect(style.fontSize, greaterThanOrEqualTo(_minTextSize), reason: name);
    });
  });

  test('the bundled serif loads from the asset bundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = await rootBundle.load('assets/fonts/Newsreader-Light.ttf');
    expect(font.lengthInBytes, greaterThan(0));
  });
}
