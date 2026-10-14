import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/widgets/app_icon.dart';

// the manage icon picker's filled keys; the picker map itself stays private.
const _pickerFillKeys = [
  'sunrise.fill', 'sun.max.fill', 'moon.stars.fill', 'drop.fill', //
  'bolt.fill', 'leaf.fill', 'book.closed.fill', 'books.vertical.fill',
  'character.book.closed.fill', 'tray.fill', 'cup.and.saucer.fill',
  'heart.fill',
];

const _envelopePickerNames = [
  'cup.and.saucer', 'basket', 'bolt', 'bag', 'car', 'tv', //
  'heart', 'house', 'fork.knife', 'creditcard', 'gift', 'airplane',
];

const _envelopeFillKeys = [
  'bag.fill', 'car.fill', 'tv.fill', 'basket.fill', 'house.fill',
];

void main() {
  test('maps the drag-handle glyph rather than falling back', () {
    expect(iconForSf('line.3.horizontal'), CupertinoIcons.line_horizontal_3);
    expect(iconForSf('line.3.horizontal'), isNot(CupertinoIcons.circle));
  });

  test('every filled picker glyph has a distinct line form', () {
    for (final key in _pickerFillKeys) {
      expect(lineIconForSf(key), isNot(iconForSf(key)), reason: key);
      expect(lineIconForSf(key), isNot(CupertinoIcons.circle), reason: key);
    }
  });

  test('every envelope picker glyph is mapped', () {
    for (final name in _envelopePickerNames) {
      expect(lineIconForSf(name), isNot(CupertinoIcons.circle), reason: name);
    }
  });

  test('seeded envelope .fill names draw as a distinct outline', () {
    for (final key in _envelopeFillKeys) {
      expect(lineIconForSf(key), isNot(iconForSf(key)), reason: key);
      expect(lineIconForSf(key), isNot(CupertinoIcons.circle), reason: key);
    }
  });

  test('a name with no .fill suffix keeps its glyph', () {
    expect(lineIconForSf('sparkles'), iconForSf('sparkles'));
  });

  test('a .fill name with no line stem keeps the filled glyph', () {
    expect(lineIconForSf('flame.fill'), iconForSf('flame.fill'));
  });
}
