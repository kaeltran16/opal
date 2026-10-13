import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/controllers/spending_controller.dart';
import 'package:opal/widgets/app_icon.dart';

void main() {
  test('areas run in display order with their titles', () {
    expect(Area.values.map((a) => a.title),
        ['Money', 'Move', 'Routines', 'Nutrition', 'Sleep', 'Mood']);
  });

  test('glyphs are the canvas symbols', () {
    expect(Area.values.map((a) => a.glyph), [
      'dollarsign.circle.fill',
      'figure.run',
      'sparkles',
      'fork.knife',
      'moon.stars.fill',
      'heart.fill',
    ]);
  });

  test('every glyph maps to a real icon, not the fallback circle', () {
    for (final area in Area.values) {
      expect(iconForSf(area.glyph), isNot(CupertinoIcons.circle),
          reason: area.name);
    }
  });

  test('exactly money, move and routines have a state rule', () {
    expect(Area.values.where((a) => a.hasStateRule),
        [Area.money, Area.move, Area.routines]);
  });

  test('trackers map to the shipped detail trackers', () {
    expect({for (final a in Area.values) a: a.tracker}, {
      Area.money: DetailTracker.money,
      Area.move: DetailTracker.move,
      Area.routines: DetailTracker.rituals,
      Area.nutrition: null,
      Area.sleep: null,
      Area.mood: null,
    });
  });
}
