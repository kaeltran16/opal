import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/mood_checkin.dart';
import 'package:opal/models/enums.dart';

void main() {
  final c = MoodCheckin(
    id: 'c1',
    timestamp: DateTime(2026, 6, 17, 13, 40),
    pleasantness: 0.62,
    tag: 'Calm',
    source: EntrySource.manual,
  );

  test('copyWith + equality', () {
    expect(c, c.copyWith());
    expect(c.copyWith(tag: null).tag, isNull);
    expect(c.copyWith(pleasantness: 0.7).pleasantness, 0.7);
  });
}
