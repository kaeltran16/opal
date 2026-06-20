import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  test('mock returns non-empty suggestions for each surface', () async {
    final pal = MockPalService(latency: Duration.zero);
    for (final surface in SuggestionSurface.values) {
      final out = await pal.suggestions(surface);
      expect(out, isNotEmpty, reason: 'surface $surface');
      expect(out.first.label, isNotEmpty);
      expect(out.first.icon, isNotEmpty);
    }
  });

  test('composer suggestions include at least one concrete log (entry payload)', () async {
    final pal = MockPalService(latency: Duration.zero);
    final out = await pal.suggestions(SuggestionSurface.composer);
    expect(out.any((s) => s.entry != null), isTrue);
  });

  test('routineGoal suggestions are label-only (no entry payload)', () async {
    final pal = MockPalService(latency: Duration.zero);
    final out = await pal.suggestions(SuggestionSurface.routineGoal);
    expect(out.every((s) => s.entry == null), isTrue);
  });
}
