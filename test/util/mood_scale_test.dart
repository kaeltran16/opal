import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/util/mood_scale.dart';

void main() {
  test('moodWord maps the 7 stops', () {
    expect(moodWord(0.0), 'Very unpleasant');
    expect(moodWord(0.5), 'Neutral');
    expect(moodWord(1.0), 'Very pleasant');
    expect(moodWord(0.62), 'Slightly pleasant'); // round(0.62*6)=4
  });

  test('hm / hmShort format minutes', () {
    expect(hm(432), '7h 12m');
    expect(hm(420), '7h');
    expect(hm(18), '18m');
    expect(hmShort(432), '7h12');
    expect(hmShort(420), '7h');
  });

  test('moodColor returns a Color and clamps', () {
    expect(moodColor(-1, false), isA<Color>());
    expect(moodColor(2, true), isA<Color>());
  });
}
