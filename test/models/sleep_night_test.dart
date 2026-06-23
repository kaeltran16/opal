import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/sleep_night.dart';
import 'package:opal/models/enums.dart';

void main() {
  final n = SleepNight(
    id: 'n1',
    night: DateTime(2026, 6, 17),
    asleepMinutes: 432,
    inBedMinutes: 450,
    bedtime: '11:32',
    wake: '7:02',
    deepMinutes: 64,
    remMinutes: 98,
    coreMinutes: 270,
    awakeMinutes: 18,
    wakes: 2,
    source: EntrySource.health,
  );

  test('copyWith overrides one field, keeps the rest', () {
    final m = n.copyWith(asleepMinutes: 400);
    expect(m.asleepMinutes, 400);
    expect(m.inBedMinutes, 450);
    expect(m, isNot(n));
  });

  test('value equality', () {
    expect(n, n.copyWith());
    expect(n.hashCode, n.copyWith().hashCode);
  });
}
