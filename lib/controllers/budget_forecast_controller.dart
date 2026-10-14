import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// prefixed so the provider function `envelopeForecasts` does not collide with
// the pure `forecastEnvelopes` it calls, and to keep the analysis origin visible.
import '../analysis/budget_forecast.dart' as fc;
import 'budget_envelopes_controller.dart';
import 'providers.dart';

part 'budget_forecast_controller.g.dart';

/// Month-end outlook per capped envelope, most severe first. Reactive: re-emits
/// whenever this month's entries change. Also re-emits when an envelope changes,
/// matching [budgetsDataProvider].
///
/// Empty when no envelope carries a cap — the honest empty state.
@riverpod
Stream<List<fc.EnvelopeForecast>> envelopeForecasts(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);

  final now = clock.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);

  // watched before the loop so an envelope write re-runs this provider.
  final envelopes = await ref.watch(budgetEnvelopesControllerProvider.future);

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    yield fc.forecastEnvelopes(envelopes, entries, now: now);
  }
}
