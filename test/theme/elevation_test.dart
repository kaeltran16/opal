import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/elevation.dart';

void main() {
  test('Elevation.fab uses the supplied color', () {
    const c = Color(0x1F000000);
    expect(Elevation.fab(c).single.blurRadius, 24);
    expect(Elevation.fab(c).single.color, c);
    expect(Elevation.fab(c).single.offset, const Offset(0, 8));
  });
}
