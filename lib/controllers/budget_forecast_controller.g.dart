// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_forecast_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Month-end outlook per capped envelope, most severe first. Reactive: re-emits
/// whenever this month's entries change. Reads envelopes one-shot per emission,
/// matching [budgetsDataProvider].
///
/// Empty when no envelope carries a cap — the honest empty state.

@ProviderFor(envelopeForecasts)
const envelopeForecastsProvider = EnvelopeForecastsProvider._();

/// Month-end outlook per capped envelope, most severe first. Reactive: re-emits
/// whenever this month's entries change. Reads envelopes one-shot per emission,
/// matching [budgetsDataProvider].
///
/// Empty when no envelope carries a cap — the honest empty state.

final class EnvelopeForecastsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<fc.EnvelopeForecast>>,
          List<fc.EnvelopeForecast>,
          Stream<List<fc.EnvelopeForecast>>
        >
    with
        $FutureModifier<List<fc.EnvelopeForecast>>,
        $StreamProvider<List<fc.EnvelopeForecast>> {
  /// Month-end outlook per capped envelope, most severe first. Reactive: re-emits
  /// whenever this month's entries change. Reads envelopes one-shot per emission,
  /// matching [budgetsDataProvider].
  ///
  /// Empty when no envelope carries a cap — the honest empty state.
  const EnvelopeForecastsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'envelopeForecastsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$envelopeForecastsHash();

  @$internal
  @override
  $StreamProviderElement<List<fc.EnvelopeForecast>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<fc.EnvelopeForecast>> create(Ref ref) {
    return envelopeForecasts(ref);
  }
}

String _$envelopeForecastsHash() => r'1db54deea4cd36fcf7c7e138d35190f2a29ae899';
