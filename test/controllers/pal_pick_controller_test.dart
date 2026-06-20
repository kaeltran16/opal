import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/start_workout_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart';

/// A PalService that records every suggestWorkout call and returns a scripted
/// sequence of suggestions. Other methods return harmless defaults.
class _RecordingPal implements PalService {
  _RecordingPal(this._suggestions);

  @override
  Future<PalAgenda> agenda() async => const PalAgenda();

  @override
  Future<MealEstimate> estimateMeal(String description) async =>
      const MealEstimate(
        name: 'Meal',
        cal: IntRange(300, 500),
        confidence: NutritionConfidence.low,
      );

  final List<WorkoutSuggestion> _suggestions;
  final List<({bool another, String? excludeRoutineId})> calls = [];
  int _i = 0;

  @override
  Future<WorkoutSuggestion> suggestWorkout({
    bool another = false,
    String? excludeRoutineId,
  }) async {
    calls.add((another: another, excludeRoutineId: excludeRoutineId));
    final s = _suggestions[_i.clamp(0, _suggestions.length - 1)];
    _i++;
    return s;
  }

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async =>
      const PalChatResult(reply: 'ok');
  @override
  Future<ParsedEntryDraft> parse(String text) async =>
      const ParsedEntryDraft(type: EntryType.money);
  @override
  Future<String> review(DateTime anchor, ReviewRange range) async => '';
  @override
  Future<PalInsights> insights(InsightRange range) async => const PalInsights();
  @override
  Future<String> postWorkoutNote(Workout workout) async => '';
  @override
  Future<GeneratedRoutineDraft> generateRoutine(
          String goal, List<Exercise> available) async =>
      const GeneratedRoutineDraft(name: '', tag: RoutineTag.custom, exercises: []);
  @override
  Future<PalMemoryDigest> memory() async => const PalMemoryDigest();
  @override
  Future<PalMemoryDigest> refreshMemory() async => const PalMemoryDigest();
  @override
  Future<PalMemoryDigest> deleteFact(String id) async => const PalMemoryDigest();
  @override
  Future<PalMemoryDigest> clearMemory() async => const PalMemoryDigest();
  @override
  Future<List<PalSuggestion>> suggestions(SuggestionSurface surface) async => const [];
}

void main() {
  test('another() passes the currently-shown routineId as excludeRoutineId', () async {
    final pal = _RecordingPal(const [
      WorkoutSuggestion(title: 'Push Day A', rationale: '', routineId: 'r-push'),
      WorkoutSuggestion(title: 'Leg Day', rationale: '', routineId: 'r-legs'),
    ]);
    final container = ProviderContainer(overrides: [
      palServiceProvider.overrideWithValue(pal),
    ]);
    addTearDown(container.dispose);

    // initial build resolves the first suggestion.
    final first = await container.read(palPickControllerProvider.future);
    expect(first.routineId, 'r-push');

    await container.read(palPickControllerProvider.notifier).another();

    // the second call asks for another, excluding the routine that was shown.
    expect(pal.calls, hasLength(2));
    expect(pal.calls[0], (another: false, excludeRoutineId: null));
    expect(pal.calls[1], (another: true, excludeRoutineId: 'r-push'));
  });
}
