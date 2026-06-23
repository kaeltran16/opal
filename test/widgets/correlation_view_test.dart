import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/widgets/correlation_view.dart';

void main() {
  // sleep(a) × money(b), binaryDim: sleep, continuousDim: money
  // meanWhenActive(short nights): 64, meanWhenInactive(other nights): 39
  const breakdown = GroupBreakdown(
    binaryDim: Dimension.sleep,
    continuousDim: Dimension.money,
    meanWhenActive: 64,
    meanWhenInactive: 39,
    countActive: 8,
    countInactive: 22,
  );
  final correlation = Correlation(
    a: Dimension.sleep,
    b: Dimension.money,
    r: 0.5,
    n: 30,
    breakdown: breakdown,
  );
  final view = CorrelationView(correlation);

  group('CorrelationView — with breakdown', () {
    test('pairLabel is title-cased noun pair', () {
      expect(view.pairLabel, 'Sleep × Spending');
    });

    test('compareLow label is active group', () {
      expect(view.compareLow, isNotNull);
      expect(view.compareLow!.label, 'After short nights');
    });

    test('compareHigh label is inactive group', () {
      expect(view.compareHigh, isNotNull);
      expect(view.compareHigh!.label, 'After other nights');
    });

    test('compareLow value matches formatValue for active mean', () {
      expect(view.compareLow!.value, formatValue(Dimension.money, 64));
    });

    test('compareHigh value matches formatValue for inactive mean', () {
      expect(view.compareHigh!.value, formatValue(Dimension.money, 39));
    });

    test('fractions are in [0,1] and the larger mean has frac == 1.0', () {
      // meanActive 64 > meanInactive 39, so compareLow.frac must be 1.0
      expect(view.compareLow!.frac, 1.0);
      expect(view.compareHigh!.frac, inInclusiveRange(0.0, 1.0));
      // exact: 39/64
      expect(view.compareHigh!.frac, closeTo(39 / 64, 1e-9));
    });

    test('numbers is non-empty', () {
      expect(view.numbers, isNotEmpty);
    });

    test('numbers has active count row', () {
      final labels = view.numbers.map((r) => r.$1).toList();
      expect(labels, contains('8 short nights'));
    });

    test('numbers has inactive count row', () {
      final labels = view.numbers.map((r) => r.$1).toList();
      expect(labels, contains('22 other nights'));
    });

    test('numbers includes Difference row with correct ratio', () {
      final diffRow = view.numbers.where((r) => r.$1 == 'Difference').toList();
      expect(diffRow, hasLength(1));
      expect(diffRow.first.$2, '${(64 / 39).toStringAsFixed(1)}×'); // '1.6×'
    });

    test('source contains last 30 days', () {
      expect(view.source.contains('last 30 days'), isTrue);
    });

    test('source mentions Apple Health when sleep is involved', () {
      expect(view.source.contains('Apple Health'), isTrue);
    });

    test('why is non-empty', () {
      expect(view.why, isNotEmpty);
    });

    test('line and claim equal correlation.summary', () {
      expect(view.line, correlation.summary);
      expect(view.claim, correlation.summary);
    });
  });

  group('CorrelationView — without breakdown', () {
    final noBreakdown = Correlation(
      a: Dimension.sleep,
      b: Dimension.mood,
      r: 0.45,
      n: 25,
    );
    final noView = CorrelationView(noBreakdown);

    test('compareLow is null', () {
      expect(noView.compareLow, isNull);
    });

    test('compareHigh is null', () {
      expect(noView.compareHigh, isNull);
    });

    test('numbers is empty', () {
      expect(noView.numbers, isEmpty);
    });

    test('line equals summary', () {
      expect(noView.line, noBreakdown.summary);
    });

    test('claim equals summary', () {
      expect(noView.claim, noBreakdown.summary);
    });

    test('source contains last 25 days', () {
      expect(noView.source.contains('last 25 days'), isTrue);
    });
  });

  group('CorrelationView — frac edge cases', () {
    test('both means zero gives frac 0 for both groups', () {
      final zeroCorr = Correlation(
        a: Dimension.sleep,
        b: Dimension.money,
        r: 0.0,
        n: 21,
        breakdown: const GroupBreakdown(
          binaryDim: Dimension.sleep,
          continuousDim: Dimension.money,
          meanWhenActive: 0,
          meanWhenInactive: 0,
          countActive: 5,
          countInactive: 16,
        ),
      );
      final zv = CorrelationView(zeroCorr);
      expect(zv.compareLow!.frac, 0.0);
      expect(zv.compareHigh!.frac, 0.0);
    });

    test('zero inactive mean suppresses Difference row', () {
      final zeroInactive = Correlation(
        a: Dimension.sleep,
        b: Dimension.money,
        r: 0.5,
        n: 21,
        breakdown: const GroupBreakdown(
          binaryDim: Dimension.sleep,
          continuousDim: Dimension.money,
          meanWhenActive: 50,
          meanWhenInactive: 0,
          countActive: 10,
          countInactive: 11,
        ),
      );
      final zv = CorrelationView(zeroInactive);
      final diffRows = zv.numbers.where((r) => r.$1 == 'Difference').toList();
      expect(diffRows, isEmpty);
    });
  });
}
