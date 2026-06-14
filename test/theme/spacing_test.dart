import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/spacing.dart';

void main() {
  test('Spacing exposes the 4pt ramp', () {
    expect(Spacing.xxs, 2.0);
    expect(Spacing.xs, 4.0);
    expect(Spacing.sm, 8.0);
    expect(Spacing.md, 12.0);
    expect(Spacing.lg, 16.0);
    expect(Spacing.xl, 20.0);
    expect(Spacing.xxl, 24.0);
    expect(Spacing.xxxl, 32.0);
  });
}
