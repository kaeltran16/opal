import 'package:riverpod_annotation/riverpod_annotation.dart';

// prefixed so the provider function `envelopeForecasts` does not collide with
// the pure `forecastEnvelopes` it calls, and to keep the analysis origin visible.
import '../analysis/budget_forecast.dart' as fc;
import 'providers.dart';

part 'budget_forecast_controller.g.dart';

/// Month-end outlook per capped envelope, most severe first. Reactive: re-emits
/// whenever this month's entries change. Reads envelopes one-shot per emission,
/// matching [budgetsDataProvider].
///
/// Empty when no envelope carries a cap — the honest empty state.
@riverpod
Stream<List<fc.EnvelopeForecast>> envelopeForecasts(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final envelopeRepo = ref.watch(budgetEnvelopeRepositoryProvider);

  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    final envelopes = await envelopeRepo.getEnvelopes();
    yield fc.forecastEnvelopes(envelopes, entries, now: now);
  }
}
