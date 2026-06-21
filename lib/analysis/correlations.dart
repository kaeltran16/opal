import 'dart:math' as math;

/// Statistical bar for surfacing a correlation (see the design spec). A pair
/// must clear all three: enough paired days, a strong |r|, and Holm-corrected
/// significance across the pairs tested.
const int kMinPairedDays = 21;
const double kMinAbsR = 0.4;
const double kAlpha = 0.05;

/// The four tracked dimensions whose daily series can be correlated.
enum Dimension { money, move, rituals, nutrition }

/// Pearson correlation of two equal-length series. Returns 0 when undefined
/// (n < 2 or either series is constant) so callers never see NaN.
double pearson(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2 || ys.length != n) return 0;
  var sx = 0.0, sy = 0.0;
  for (var i = 0; i < n; i++) {
    sx += xs[i];
    sy += ys[i];
  }
  final mx = sx / n, my = sy / n;
  var num = 0.0, dx2 = 0.0, dy2 = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - mx, dy = ys[i] - my;
    num += dx * dy;
    dx2 += dx * dx;
    dy2 += dy * dy;
  }
  final den = math.sqrt(dx2 * dy2);
  return den == 0 ? 0 : num / den;
}

/// Two-tailed p-value for a correlation via the Fisher z-transform
/// (z = atanh(r) * sqrt(n - 3) is ~standard-normal under H0). Returns 1.0 when
/// it can't be defined (n < 4 or |r| > 1) so such pairs never read as
/// significant. |r| == 1 is allowed through: Dart's infinity arithmetic yields
/// p → 0, which is correct for a perfect correlation with sufficient n.
double correlationPValue(double r, int n) {
  if (n < 4 || r.abs() > 1) return 1.0;
  final z = _atanh(r) * math.sqrt(n - 3);
  return 2 * (1 - _normalCdf(z.abs()));
}

double _atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));

/// Standard-normal CDF via an Abramowitz-Stegun erf approximation (max abs
/// error ~1.5e-7) — accurate enough for a significance gate, no package needed.
double _normalCdf(double x) => 0.5 * (1 + _erf(x / math.sqrt2));

double _erf(double x) {
  final t = 1 / (1 + 0.3275911 * x.abs());
  final y = 1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) *
                  t +
              0.254829592) *
          t *
          math.exp(-x * x);
  return x < 0 ? -y : y;
}

/// The two-group comparison shown in the trust sheet when one side of a pair is
/// a "did / didn't" dimension (Move or Rituals): the mean of the continuous
/// side on active days vs inactive days.
class GroupBreakdown {
  const GroupBreakdown({
    required this.binaryDim,
    required this.continuousDim,
    required this.meanWhenActive,
    required this.meanWhenInactive,
    required this.countActive,
    required this.countInactive,
  });
  final Dimension binaryDim;
  final Dimension continuousDim;
  final double meanWhenActive;
  final double meanWhenInactive;
  final int countActive;
  final int countInactive;
}

/// A verified relationship between two daily series: the pair, its Pearson [r]
/// and paired-day count [n], and (when one side is binary) the [breakdown] the
/// trust sheet renders. [summary] is the deterministic factual sentence the LLM
/// rephrases and the template fallback shows verbatim.
class Correlation {
  const Correlation({
    required this.a,
    required this.b,
    required this.r,
    required this.n,
    this.breakdown,
  });
  final Dimension a;
  final Dimension b;
  final double r;
  final int n;
  final GroupBreakdown? breakdown;

  bool involves(Dimension d) => a == d || b == d;

  String get strengthWord {
    final m = r.abs();
    if (m >= 0.6) return 'strong';
    if (m >= 0.4) return 'moderate';
    return 'slight';
  }

  String get summary {
    final b = breakdown;
    if (b != null) {
      final active = activeDayLabel(b.binaryDim);
      final inactive = inactiveDayLabel(b.binaryDim);
      return 'On your ${b.countActive} $active you averaged '
          '${formatValue(b.continuousDim, b.meanWhenActive)}; '
          'on your ${b.countInactive} $inactive, '
          '${formatValue(b.continuousDim, b.meanWhenInactive)}.';
    }
    final dir = r >= 0 ? 'higher' : 'lower';
    return 'Days with more ${dimensionNoun(a)} tend to run $dir on '
        '${dimensionNoun(this.b)} (based on $n days).';
  }
}

String dimensionNoun(Dimension d) => switch (d) {
      Dimension.money => 'spending',
      Dimension.move => 'activity',
      Dimension.rituals => 'rituals',
      Dimension.nutrition => 'calories',
    };

String activeDayLabel(Dimension binaryDim) => switch (binaryDim) {
      Dimension.move => 'workout days',
      Dimension.rituals => 'ritual days',
      _ => 'active days',
    };

String inactiveDayLabel(Dimension binaryDim) => switch (binaryDim) {
      Dimension.move => 'rest days',
      Dimension.rituals => 'days you skipped',
      _ => 'other days',
    };

String formatValue(Dimension d, double v) => switch (d) {
      Dimension.money => '\$${v.round()}',
      Dimension.move => '${v.round()} kcal',
      Dimension.nutrition => '${v.round()} cal',
      Dimension.rituals => v.round().toString(),
    };

/// One dimension's daily scalar series, keyed by day ordinal (y*10000+m*100+d).
class DailySeries {
  const DailySeries({required this.dim, required this.byDay});
  final Dimension dim;
  final Map<int, double> byDay;
}

/// Dimensions whose daily scalar is a "did / didn't" signal — eligible to drive
/// the trust sheet's two-group breakdown.
const _binaryDims = {Dimension.move, Dimension.rituals};

class _PairStat {
  _PairStat(this.a, this.b, this.r, this.n, this.p, this.xs, this.ys, this.days);
  final Dimension a, b;
  final double r;
  final int n;
  final double p;
  final List<double> xs, ys;
  final List<int> days;
}

/// Computes every pair with at least [minN] shared days, applies a
/// Holm-Bonferroni correction at [alpha] across the tested pairs, keeps those
/// significant AND with |r| >= [minAbsR], and returns them sorted by |r| desc.
List<Correlation> surfacedCorrelations(
  Map<Dimension, DailySeries> series, {
  int minN = kMinPairedDays,
  double minAbsR = kMinAbsR,
  double alpha = kAlpha,
}) {
  final dims = series.keys.toList();
  final stats = <_PairStat>[];
  for (var i = 0; i < dims.length; i++) {
    for (var j = i + 1; j < dims.length; j++) {
      final sa = series[dims[i]]!, sb = series[dims[j]]!;
      final days = sa.byDay.keys.where(sb.byDay.containsKey).toList()..sort();
      if (days.length < minN) continue;
      final xs = [for (final d in days) sa.byDay[d]!];
      final ys = [for (final d in days) sb.byDay[d]!];
      final r = pearson(xs, ys);
      stats.add(_PairStat(
          dims[i], dims[j], r, days.length, correlationPValue(r, days.length),
          xs, ys, days));
    }
  }
  if (stats.isEmpty) return const [];

  // Holm-Bonferroni: sort by p asc; reject while p <= alpha/(m-i) ; stop at the
  // first failure (Holm's step-down also stops all subsequent).
  final m = stats.length;
  stats.sort((x, y) => x.p.compareTo(y.p));
  final kept = <_PairStat>[];
  for (var i = 0; i < m; i++) {
    if (stats[i].p <= alpha / (m - i)) {
      kept.add(stats[i]);
    } else {
      break;
    }
  }

  final out = kept
      .where((s) => s.r.abs() >= minAbsR)
      .map(_toCorrelation)
      .toList()
    ..sort((x, y) => y.r.abs().compareTo(x.r.abs()));
  return out;
}

Correlation _toCorrelation(_PairStat s) {
  // pick the binary side (if any) to drive the two-group breakdown.
  Dimension? binary;
  Dimension? cont;
  if (_binaryDims.contains(s.a) && !_binaryDims.contains(s.b)) {
    binary = s.a;
    cont = s.b;
  } else if (_binaryDims.contains(s.b) && !_binaryDims.contains(s.a)) {
    binary = s.b;
    cont = s.a;
  }
  GroupBreakdown? breakdown;
  if (binary != null && cont != null) {
    final binaryXs = binary == s.a ? s.xs : s.ys;
    final contXs = cont == s.a ? s.xs : s.ys;
    var sumActive = 0.0, sumInactive = 0.0;
    var nActive = 0, nInactive = 0;
    for (var i = 0; i < binaryXs.length; i++) {
      if (binaryXs[i] > 0) {
        sumActive += contXs[i];
        nActive++;
      } else {
        sumInactive += contXs[i];
        nInactive++;
      }
    }
    breakdown = GroupBreakdown(
      binaryDim: binary,
      continuousDim: cont,
      meanWhenActive: nActive == 0 ? 0 : sumActive / nActive,
      meanWhenInactive: nInactive == 0 ? 0 : sumInactive / nInactive,
      countActive: nActive,
      countInactive: nInactive,
    );
  }
  return Correlation(a: s.a, b: s.b, r: s.r, n: s.n, breakdown: breakdown);
}
