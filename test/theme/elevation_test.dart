import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/elevation.dart';

void main() {
  test('Elevation presets use the supplied color and rise by blur', () {
    const c = Color(0x1F000000);
    expect(Elevation.sm(c).single.blurRadius, 8);
    expect(Elevation.card(c).single.blurRadius, 16);
    expect(Elevation.fab(c).single.blurRadius, 24);
    expect(Elevation.card(c).single.color, c);
    expect(Elevation.card(c).single.offset, const Offset(0, 6));
  });
}
