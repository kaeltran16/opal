import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/radii.dart';

void main() {
  test('Radii exposes the semantic radius ramp', () {
    expect(Radii.xs, 4.0);
    expect(Radii.sm, 8.0);
    expect(Radii.md, 12.0);
    expect(Radii.card, 14.0);
    expect(Radii.lg, 16.0);
    expect(Radii.xl, 20.0);
    expect(Radii.xxl, 28.0);
    expect(Radii.pill, 999.0);
  });
}
