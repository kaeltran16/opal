import 'package:flutter/foundation.dart';

import '../controllers/nutrition_controller.dart' show NutritionPattern;
import '../services/pal/pal_service.dart' show InsightPattern;
import '../util/dates.dart';
import '../util/format.dart';
import 'correlations.dart';
import 'spend_patterns.dart';

/// One side of a finding's a/b comparison. [fraction] is this side's value
/// over the larger side's value (0..1), so the bar widths compare directly.
@immutable
class FindingSide {
  const FindingSide({
    required this.label,
    required this.value,
    required this.fraction,
  });

  final String label;
  final String value;
  final double fraction;
}

/// A pattern Pal found, from any source: on-device correlations, spend
/// patterns, Nutrition's patterns or Pal's server memory. The one model You and
/// What Pal remembers both list.
///
/// [id] encodes the claim itself, so a finding whose claim changes (another
/// peak weekday, a flipped correlation sign) reads as new after a dismissal.
@immutable
class PalFinding {
  const PalFinding({
    required this.id,
    required this.areas,
    required this.line,
    this.lead,
    required this.evidence,
    this.a,
    this.b,
    required this.question,
  });

  final String id;
  final List<String> areas;
  final String line;
  final String? lead;
  final String evidence;
  final FindingSide? a;
  final FindingSide? b;

  /// What the composer is seeded with when the finding is tapped.
  final String question;

  bool get hasComparison => a != null && b != null;

  /// [areas] as prose: 'Sleep', 'Sleep and Money', 'A, B and C'.
  String get areasLabel {
    if (areas.length < 2) return areas.join();
    final head = areas.sublist(0, areas.length - 1).join(', ');
    return '$head and ${areas.last}';
  }
}

/// Source window the spend findings describe, shared by their evidence line.
const String _kSpendEvidence = 'Last $kSpendWindowDays days';

String _areaOf(Dimension d) => switch (d) {
  Dimension.money => 'Money',
  Dimension.move => 'Move',
  Dimension.rituals => 'Routines',
  Dimension.nutrition => 'Nutrition',
  Dimension.sleep => 'Sleep',
  Dimension.mood => 'Mood',
};

/// The area label for a server or tracker colour token; null when the token
/// names no known area.
String? _areaOfToken(String token) {
  for (final d in Dimension.values) {
    if (d.name == token) return _areaOf(d);
  }
  return null;
}

String _capitalise(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _question(String line) => 'Tell me more: $line';

/// Builds the two sides from their raw values, each fraction taken over the
/// larger one (0 when both are 0).
(FindingSide, FindingSide) _sides(
  String labelA,
  String valueA,
  double rawA,
  String labelB,
  String valueB,
  double rawB,
) {
  final hi = rawA > rawB ? rawA : rawB;
  double frac(double v) => hi <= 0 ? 0 : (v / hi).clamp(0.0, 1.0);
  return (
    FindingSide(label: labelA, value: valueA, fraction: frac(rawA)),
    FindingSide(label: labelB, value: valueB, fraction: frac(rawB)),
  );
}

PalFinding _finding({
  required String id,
  required List<String> areas,
  required String line,
  required String evidence,
  (FindingSide, FindingSide)? sides,
}) => PalFinding(
  id: id,
  areas: areas,
  line: line,
  evidence: evidence,
  a: sides?.$1,
  b: sides?.$2,
  question: _question(line),
);

/// One finding per surfaced correlation, keeping their strongest-first order.
List<PalFinding> findingsFromCorrelations(
  List<Correlation> correlations,
  Currency currency,
) => [for (final c in correlations) _fromCorrelation(c, currency)];

PalFinding _fromCorrelation(Correlation c, Currency currency) {
  final id = 'corr:${c.a.name}-${c.b.name}:${c.r < 0 ? '-' : '+'}';
  final areas = [_areaOf(c.a), _areaOf(c.b)];
  final bd = c.breakdown;
  if (bd == null) {
    final line =
        'More ${dimensionNoun(c.a)} goes with '
        '${c.r < 0 ? 'less' : 'more'} ${dimensionNoun(c.b)}.';
    return _finding(
      id: id,
      areas: areas,
      line: line,
      evidence: 'Over ${c.n} days',
    );
  }
  final active = activeDayLabel(bd.binaryDim);
  final inactive = inactiveDayLabel(bd.binaryDim);
  final dir = bd.meanWhenActive >= bd.meanWhenInactive ? 'higher' : 'lower';
  return _finding(
    id: id,
    areas: areas,
    line: '${_areaOf(bd.continuousDim)} runs $dir on $active.',
    evidence: '${bd.countActive} $active, ${bd.countInactive} $inactive',
    sides: _sides(
      _capitalise(active),
      formatValue(bd.continuousDim, bd.meanWhenActive, currency: currency),
      bd.meanWhenActive,
      _capitalise(inactive),
      formatValue(bd.continuousDim, bd.meanWhenInactive, currency: currency),
      bd.meanWhenInactive,
    ),
  );
}

/// Spend patterns as Money findings, in the detector's order.
List<PalFinding> findingsFromSpendPatterns(
  SpendPatterns patterns,
  Currency currency,
) {
  // averages and window totals are rounded: cents on a derived figure are noise.
  String perDay(double v) =>
      '${formatCurrency(v.roundToDouble(), currency)} a day';
  String amount(double v) => formatCurrency(v.roundToDouble(), currency);
  const money = ['Money'];

  final out = <PalFinding>[];
  final day = patterns.biggestDay;
  if (day != null) {
    final peak = kWeekdays[day.peakWeekday - 1];
    final quiet = kWeekdays[day.quietWeekday - 1];
    out.add(
      _finding(
        id: 'money:biggest-day:${day.peakWeekday}',
        areas: money,
        line: 'You spend most on ${peak}s.',
        evidence: _kSpendEvidence,
        sides: _sides(
          peak,
          perDay(day.peakAverage),
          day.peakAverage,
          quiet,
          perDay(day.quietAverage),
          day.quietAverage,
        ),
      ),
    );
  }

  final split = patterns.weekendSplit;
  if (split != null) {
    final weekend = split.heavierOnWeekend;
    out.add(
      _finding(
        id: 'money:weekend-split:${weekend ? 'weekend' : 'weekday'}',
        areas: money,
        line: weekend
            ? 'Weekends cost more than weekdays.'
            : 'Weekdays cost more than weekends.',
        evidence: _kSpendEvidence,
        sides: _sides(
          'Weekend days',
          perDay(split.weekendAverage),
          split.weekendAverage,
          'Weekdays',
          perDay(split.weekdayAverage),
          split.weekdayAverage,
        ),
      ),
    );
  }

  final peak = patterns.daypartPeak;
  if (peak != null) {
    final rest = peak.share == 0 ? 0.0 : peak.total / peak.share - peak.total;
    final name = _capitalise(peak.daypart.name);
    out.add(
      _finding(
        id: 'money:daypart-peak:${peak.daypart.name}',
        areas: money,
        line: '$name takes ${(peak.share * 100).round()}% of your spending.',
        evidence: _kSpendEvidence,
        sides: _sides(
          name,
          amount(peak.total),
          peak.total,
          'Rest of the day',
          amount(rest),
          rest,
        ),
      ),
    );
  }

  if (patterns.noSpendStreakDays > 0) {
    out.add(
      _finding(
        id: 'money:no-spend-streak',
        areas: money,
        line: '${patterns.noSpendStreakDays} days without spending.',
        evidence: 'Ending yesterday',
      ),
    );
  }

  for (final u in patterns.unusual) {
    final e = u.entry;
    final spent = e.amount!.abs();
    final usual = u.multipleOfMean == 0 ? 0.0 : spent / u.multipleOfMean;
    out.add(
      _finding(
        id: 'money:unusual:${e.id}',
        areas: money,
        line: '${e.title} was ${u.multipleOfMean.round()}x your usual expense.',
        evidence: '${kMonthsShort[e.timestamp.month - 1]} ${e.timestamp.day}',
        sides: _sides(
          e.title,
          formatCurrency(spent, currency),
          spent,
          'Your usual expense',
          amount(usual),
          usual,
        ),
      ),
    );
  }
  return out;
}

/// Nutrition's takeout patterns, only when there was takeout this week.
List<PalFinding> findingsFromNutritionPatterns(
  List<NutritionPattern> patterns,
) => [
  for (final p in patterns)
    if (p.spark.isNotEmpty && p.spark[0] > 0) _fromNutrition(p),
];

PalFinding _fromNutrition(NutritionPattern p) {
  final tracker = _areaOfToken(p.tracker);
  final takeout = p.spark[0];
  final home = p.spark.length > 1 ? p.spark[1] : 0;
  return _finding(
    id: 'nutrition:${p.title}',
    areas: [
      'Nutrition',
      if (tracker != null && tracker != 'Nutrition') tracker,
    ],
    line: p.body,
    evidence: 'This week',
    sides: _sides(
      'Takeout meals',
      '$takeout',
      takeout.toDouble(),
      'Cooked at home',
      '$home',
      home.toDouble(),
    ),
  );
}

/// Pal's server memory patterns: a line and its evidence, no comparison.
List<PalFinding> findingsFromPalPatterns(List<InsightPattern> patterns) => [
  for (final p in patterns)
    _finding(
      id: 'pal:${p.title}',
      areas: [?_areaOfToken(p.colorToken)],
      line: p.title,
      evidence: p.detail,
    ),
];
