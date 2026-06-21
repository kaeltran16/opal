# Correlation Engine + Trust Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compute real pairwise correlations across the four tracked dimensions on-device, surface only the single strongest that clears a strict statistical bar, narrate it via the existing insights LLM with a deterministic template fallback, and show its "why" through a trust sheet.

**Architecture:** A pure Dart module (`lib/analysis/correlations.dart`) builds daily aggregate vectors per dimension, computes Pearson correlations with a Fisher-z p-value, applies a Holm-Bonferroni correction across the 6 pairs, and returns the survivors sorted by strength. A Riverpod provider exposes that list to the Insights and Nutrition screens, which render a shared `CorrelationCard` (instant, from the computed data) whose wording the existing `/v1/insights` call upgrades by rephrasing the Dart-built factual summary. Tapping a card opens a trust sheet showing the numeric breakdown.

**Tech Stack:** Dart / Flutter, Riverpod (code-gen providers), Drift (data), TypeScript / Zod / Fastify (server proxy), `flutter_test` + Vitest.

## Global Constraints

- Confidence bar (every survivor must satisfy ALL): `n >= 21` paired days · `|r| >= 0.4` · Holm-corrected `p < 0.05` across the pairs tested. Constants: `kMinPairedDays = 21`, `kMinAbsR = 0.4`, `kAlpha = 0.05`.
- Window: rolling **90 days** ending today (`kCorrelationWindowDays = 90`), capped to available data.
- Missing-data rule: Money / Move / Rituals — a day with no entry is a genuine **0**, 0-filled across the span from the earliest in-window entry (of any type) to today. Nutrition — a day with **no logged meal is excluded** (not 0). Pairing uses the intersection of the two dimensions' day-sets.
- Daily scalars: Money = summed expense magnitude (`amount < 0`, use `.abs()`); Move = summed `calories ?? 0`; Rituals = count of `EntryType.rituals` entries; Nutrition = summed meal `cal.mid`.
- All correlation math is pure Dart with no external package. Server stays a thin proxy: it receives the Dart-built factual `summary` and only rephrases it; it never computes a correlation or invents one.
- Naming/SSOT: the `Correlation` list provider is the single source for surfaced correlations; both screens read it. The LLM narration applies only to `surfaced.first` (the globally strongest), matched by list position, not by re-deriving the pair on the server.
- No emojis in any copy. Comments lower-case, "why" not "what", only where needed (per repo convention).

---

### Task 1: Pure correlation engine — model, math, surfacing

**Files:**
- Create: `lib/analysis/correlations.dart`
- Test: `test/analysis/correlations_test.dart`

**Interfaces:**
- Consumes: nothing (pure; depends only on `dart:math`).
- Produces:
  - `enum Dimension { money, move, rituals, nutrition }`
  - `class DailySeries { final Dimension dim; final Map<int, double> byDay; }` where the key is a day ordinal `y*10000 + m*100 + d`.
  - `class GroupBreakdown { final Dimension binaryDim; final Dimension continuousDim; final double meanWhenActive; final double meanWhenInactive; final int countActive; final int countInactive; }`
  - `class Correlation { final Dimension a; final Dimension b; final double r; final int n; final GroupBreakdown? breakdown; bool involves(Dimension d); String get summary; String get strengthWord; }`
  - `double pearson(List<double> xs, List<double> ys)` — returns 0 when undefined (constant series / n<2).
  - `double correlationPValue(double r, int n)` — Fisher-z two-tailed p; returns 1.0 when n<4 or |r|>=1.
  - `List<Correlation> surfacedCorrelations(Map<Dimension, DailySeries> series, {int minN = kMinPairedDays, double minAbsR = kMinAbsR, double alpha = kAlpha})` — all pairs with shared days `>= minN`, Holm-corrected at `alpha`, kept when significant AND `|r| >= minAbsR`, sorted by `|r|` descending.
  - Constants `kMinPairedDays`, `kMinAbsR`, `kAlpha`.

- [ ] **Step 1: Write the failing test for `pearson`**

Create `test/analysis/correlations_test.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';

void main() {
  group('pearson', () {
    test('perfect positive is 1.0', () {
      expect(pearson([1, 2, 3, 4], [2, 4, 6, 8]), closeTo(1.0, 1e-9));
    });
    test('perfect negative is -1.0', () {
      expect(pearson([1, 2, 3, 4], [8, 6, 4, 2]), closeTo(-1.0, 1e-9));
    });
    test('a constant series yields 0 (undefined guarded)', () {
      expect(pearson([5, 5, 5, 5], [1, 2, 3, 4]), 0.0);
    });
    test('fewer than two points yields 0', () {
      expect(pearson([1], [2]), 0.0);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'opal' ... correlations.dart` / `pearson` undefined.

- [ ] **Step 3: Create the module with constants, `Dimension`, and `pearson`**

Create `lib/analysis/correlations.dart`:

```dart
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Write the failing test for `correlationPValue`**

Append to the test file's `main()`:

```dart
  group('correlationPValue', () {
    test('strong r over a large n is significant', () {
      expect(correlationPValue(0.7, 40), lessThan(0.001));
    });
    test('weak r over a small n is not significant', () {
      expect(correlationPValue(0.1, 22), greaterThan(0.05));
    });
    test('too few points is non-significant (p = 1)', () {
      expect(correlationPValue(0.9, 3), 1.0);
    });
  });
```

- [ ] **Step 6: Run to verify it fails**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: FAIL — `correlationPValue` undefined.

- [ ] **Step 7: Implement `correlationPValue` (Fisher-z) and the normal CDF**

Append to `lib/analysis/correlations.dart`:

```dart
/// Two-tailed p-value for a correlation via the Fisher z-transform
/// (z = atanh(r) * sqrt(n - 3) is ~standard-normal under H0). Returns 1.0 when
/// it can't be defined (n < 4 or |r| >= 1) so such pairs never read as
/// significant.
double correlationPValue(double r, int n) {
  if (n < 4 || r.abs() >= 1) return 1.0;
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
```

- [ ] **Step 8: Run to verify it passes**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 9: Write the failing test for `Correlation` summary + strength**

Append to `main()`:

```dart
  group('Correlation presentation', () {
    final c = Correlation(
      a: Dimension.move,
      b: Dimension.money,
      r: -0.52,
      n: 28,
      breakdown: const GroupBreakdown(
        binaryDim: Dimension.move,
        continuousDim: Dimension.money,
        meanWhenActive: 34,
        meanWhenInactive: 52,
        countActive: 12,
        countInactive: 16,
      ),
    );
    test('involves reports membership', () {
      expect(c.involves(Dimension.money), isTrue);
      expect(c.involves(Dimension.rituals), isFalse);
    });
    test('strengthWord buckets |r|', () {
      expect(c.strengthWord, 'moderate');
      expect(
          Correlation(a: Dimension.move, b: Dimension.money, r: 0.75, n: 28)
              .strengthWord,
          'strong');
    });
    test('summary states the two-group comparison factually', () {
      expect(c.summary, contains('workout days'));
      expect(c.summary, contains('\$34'));
      expect(c.summary, contains('\$52'));
    });
  });
```

- [ ] **Step 10: Run to verify it fails**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: FAIL — `Correlation` / `GroupBreakdown` undefined.

- [ ] **Step 11: Implement `GroupBreakdown`, `Correlation`, and label/format helpers**

Append to `lib/analysis/correlations.dart`:

```dart
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
        '${dimensionNoun(b)} (based on $n days).';
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
```

- [ ] **Step 12: Run to verify it passes**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 13: Write the failing test for `surfacedCorrelations`**

Append to `main()`. The helper builds a `DailySeries` from a per-day-ordinal map:

```dart
  group('surfacedCorrelations', () {
    DailySeries series(Dimension d, List<double> values) {
      // map onto consecutive day ordinals starting 2026-01-01
      final byDay = <int, double>{};
      for (var i = 0; i < values.length; i++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: i));
        byDay[date.year * 10000 + date.month * 100 + date.day] = values[i];
      }
      return DailySeries(dim: d, byDay: byDay);
    }

    test('surfaces a strong, well-sampled pair', () {
      // 24 days, money mirrors move strongly (negative).
      final move = List<double>.generate(24, (i) => (i % 4 == 0) ? 0 : 300);
      final money = move.map((m) => m == 0 ? 60.0 : 30.0).toList();
      final out = surfacedCorrelations({
        Dimension.move: series(Dimension.move, move),
        Dimension.money: series(Dimension.money, money),
      });
      expect(out, isNotEmpty);
      expect(out.first.involves(Dimension.move), isTrue);
      expect(out.first.involves(Dimension.money), isTrue);
      expect(out.first.r.abs(), greaterThanOrEqualTo(kMinAbsR));
      expect(out.first.breakdown, isNotNull); // move is binary -> two-group
    });

    test('rejects an under-sampled pair (n < 21)', () {
      final move = List<double>.generate(10, (i) => (i % 2 == 0) ? 0 : 300);
      final money = move.map((m) => m == 0 ? 60.0 : 30.0).toList();
      final out = surfacedCorrelations({
        Dimension.move: series(Dimension.move, move),
        Dimension.money: series(Dimension.money, money),
      });
      expect(out, isEmpty);
    });

    test('rejects a weak pair (|r| < 0.4)', () {
      final move = List<double>.generate(30, (i) => (i % 2).toDouble() * 300);
      final money = List<double>.generate(30, (i) => 50 + (i % 7)); // unrelated
      final out = surfacedCorrelations({
        Dimension.move: series(Dimension.move, move),
        Dimension.money: series(Dimension.money, money),
      });
      expect(out, isEmpty);
    });

    test('a constant (fabricated-looking) series surfaces nothing', () {
      final flat = List<double>.filled(30, 100);
      final money = List<double>.generate(30, (i) => 40.0 + i);
      final out = surfacedCorrelations({
        Dimension.nutrition: series(Dimension.nutrition, flat),
        Dimension.money: series(Dimension.money, money),
      });
      expect(out, isEmpty); // guards against re-introducing fiction
    });
  });
```

- [ ] **Step 14: Run to verify it fails**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: FAIL — `DailySeries` / `surfacedCorrelations` undefined.

- [ ] **Step 15: Implement `DailySeries` and `surfacedCorrelations` (with Holm + breakdown)**

Append to `lib/analysis/correlations.dart`:

```dart
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
```

- [ ] **Step 16: Run to verify it passes**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: PASS (14 tests).

- [ ] **Step 17: Commit**

```bash
git add lib/analysis/correlations.dart test/analysis/correlations_test.dart
git commit -m "feat(insights): pure cross-dimension correlation engine"
```

---

### Task 2: Daily-vector builder from entries + meals

**Files:**
- Modify: `lib/analysis/correlations.dart` (add `buildDailyVectors`)
- Modify: `test/analysis/correlations_test.dart`

**Interfaces:**
- Consumes: `Entry` (`lib/models/entry.dart` — `type`, `timestamp`, `amount`, `calories`), `NutritionMeal` (`lib/models/nutrition_meal.dart` — `timestamp`, `cal.mid`), `EntryType` (`lib/models/enums.dart`).
- Produces: `Map<Dimension, DailySeries> buildDailyVectors(List<Entry> entries, List<NutritionMeal> meals, {required DateTime now, int windowDays = kCorrelationWindowDays})` and `const int kCorrelationWindowDays = 90`.

- [ ] **Step 1: Write the failing test**

Append to `main()` in `test/analysis/correlations_test.dart`:

```dart
  group('buildDailyVectors', () {
    final now = DateTime(2026, 3, 1, 12);
    Entry money(int daysAgo, double amount) => Entry(
        id: 'm$daysAgo',
        timestamp: now.subtract(Duration(days: daysAgo)),
        type: EntryType.money,
        title: 'x',
        amount: amount,
        source: EntrySource.manual);
    Entry move(int daysAgo, int cal) => Entry(
        id: 'w$daysAgo',
        timestamp: now.subtract(Duration(days: daysAgo)),
        type: EntryType.move,
        title: 'x',
        calories: cal,
        source: EntrySource.manual);

    test('money sums expense magnitude per day; income ignored', () {
      final v = buildDailyVectors(
          [money(1, -10), money(1, -5), money(1, 100)], const [],
          now: now);
      final key = _ord(now.subtract(const Duration(days: 1)));
      expect(v[Dimension.money]!.byDay[key], 15.0);
    });

    test('move days are 0-filled within the active span', () {
      // a move 3 days ago and one today -> day between is a real 0.
      final v = buildDailyVectors([move(3, 200), move(0, 200)], const [],
          now: now);
      expect(v[Dimension.move]!.byDay[_ord(now.subtract(const Duration(days: 1)))],
          0.0);
    });

    test('nutrition only has days with a logged meal (no 0-fill)', () {
      final meal = NutritionMeal(
        id: 'n1',
        timestamp: now.subtract(const Duration(days: 2)),
        slot: 'Lunch',
        name: 'x',
        source: NutritionSource.manual,
        icon: 'fork.knife',
        confidence: NutritionConfidence.med,
        cal: const IntRange(400, 600),
        macros: const MacroRange.zero(),
      );
      final v = buildDailyVectors([move(0, 200)], [meal], now: now);
      expect(v[Dimension.nutrition]!.byDay.length, 1);
      expect(v[Dimension.nutrition]!.byDay[_ord(now.subtract(const Duration(days: 2)))],
          500.0); // cal.mid
    });
  });
```

Add the ordinal helper at the bottom of the file (outside `main`):

```dart
int _ord(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
```

Add imports at the top of the test file:

```dart
import 'package:opal/models/models.dart';
```

> If `IntRange`, `MacroRange`, `NutritionMeal`, `NutritionSource`, `NutritionConfidence`, `EntrySource` are not all exported by `lib/models/models.dart`, import their specific files instead — verify with `grep -rn "class IntRange\|class MacroRange\|MacroRange.zero" lib/models`. If `MacroRange.zero()` does not exist, construct `MacroRange` with its real required fields (read `lib/models/nutrition_meal.dart`).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: FAIL — `buildDailyVectors` undefined.

- [ ] **Step 3: Implement `buildDailyVectors`**

Append to `lib/analysis/correlations.dart` (add `import` at top of file):

```dart
import '../models/models.dart';
```

```dart
/// Rolling window for correlations: the last [kCorrelationWindowDays] days.
const int kCorrelationWindowDays = 90;

int _dayOrd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Builds one daily scalar series per dimension over the window ending [now].
///
/// Money/Move/Rituals are 0-filled across the span from the earliest in-window
/// entry (of any type) to today — a day with no entry is a genuine zero.
/// Nutrition is only defined on days with a logged meal (no log != ate
/// nothing), so its pairs naturally pair on the intersection of days.
Map<Dimension, DailySeries> buildDailyVectors(
  List<Entry> entries,
  List<NutritionMeal> meals, {
  required DateTime now,
  int windowDays = kCorrelationWindowDays,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final windowStart = today.subtract(Duration(days: windowDays - 1));
  bool inWindow(DateTime t) =>
      !t.isBefore(windowStart) && t.isBefore(today.add(const Duration(days: 1)));

  final money = <int, double>{};
  final move = <int, double>{};
  final rituals = <int, double>{};
  DateTime? earliest;
  for (final e in entries) {
    if (!inWindow(e.timestamp)) continue;
    final day = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
    if (earliest == null || day.isBefore(earliest!)) earliest = day;
    final k = _dayOrd(day);
    switch (e.type) {
      case EntryType.money:
        if ((e.amount ?? 0) < 0) money[k] = (money[k] ?? 0) + e.amount!.abs();
      case EntryType.move:
        move[k] = (move[k] ?? 0) + (e.calories ?? 0).toDouble();
      case EntryType.rituals:
        rituals[k] = (rituals[k] ?? 0) + 1;
    }
  }

  // 0-fill money/move/rituals across [earliest, today]. With no entries at all,
  // there is nothing to fill (every map stays empty -> no pairs clear the bar).
  if (earliest != null) {
    for (var d = earliest!;
        !d.isAfter(today);
        d = d.add(const Duration(days: 1))) {
      final k = _dayOrd(d);
      money.putIfAbsent(k, () => 0);
      move.putIfAbsent(k, () => 0);
      rituals.putIfAbsent(k, () => 0);
    }
  }

  final nutrition = <int, double>{};
  for (final meal in meals) {
    if (!inWindow(meal.timestamp)) continue;
    final k = _dayOrd(meal.timestamp);
    nutrition[k] = (nutrition[k] ?? 0) + meal.cal.mid.toDouble();
  }

  return {
    Dimension.money: DailySeries(dim: Dimension.money, byDay: money),
    Dimension.move: DailySeries(dim: Dimension.move, byDay: move),
    Dimension.rituals: DailySeries(dim: Dimension.rituals, byDay: rituals),
    Dimension.nutrition: DailySeries(dim: Dimension.nutrition, byDay: nutrition),
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/analysis/correlations_test.dart`
Expected: PASS (17 tests). If the nutrition test fails on `MacroRange.zero()`/`IntRange`, fix the test fixture per the Step-1 note, not the implementation.

- [ ] **Step 5: Commit**

```bash
git add lib/analysis/correlations.dart test/analysis/correlations_test.dart
git commit -m "feat(insights): build daily dimension vectors from entries and meals"
```

---

### Task 3: `surfacedCorrelationsProvider`

**Files:**
- Create: `lib/controllers/correlations_controller.dart`
- Test: `test/controllers/correlations_controller_test.dart`

**Interfaces:**
- Consumes: `entryRepositoryProvider` (`EntryRepository.getEntriesInRange(from,to) -> Future<List<Entry>>`), `nutritionRepositoryProvider` (`NutritionRepository.getMealsInRange(from,to) -> Future<List<NutritionMeal>>`), and `buildDailyVectors` / `surfacedCorrelations` from Task 1-2. Both repo providers are declared in `lib/controllers/providers.dart`.
- Produces: `Future<List<Correlation>> surfacedCorrelations(Ref ref)` exposed as `surfacedCorrelationsProvider` (code-gen).

- [ ] **Step 1: Write the failing test**

Create `test/controllers/correlations_controller_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/controllers/correlations_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

void main() {
  test('surfaces a strong move-money relationship from real entries', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = EntryRepository(db);
    final now = DateTime.now();
    // 28 days: every 3rd day a workout (300 kcal) + light spend; else heavy spend.
    for (var i = 0; i < 28; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final workout = i % 3 == 0;
      if (workout) {
        await repo.insert(Entry(
            id: 'w$i', timestamp: day.add(const Duration(hours: 7)),
            type: EntryType.move, title: 'run', calories: 300,
            source: EntrySource.manual));
      }
      await repo.insert(Entry(
          id: 'm$i', timestamp: day.add(const Duration(hours: 18)),
          type: EntryType.money, title: 'spend',
          amount: workout ? -20.0 : -60.0, category: 'Food', source: EntrySource.manual));
    }

    final c = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(c.dispose);

    final out = await c.read(surfacedCorrelationsProvider.future);
    expect(out, isNotEmpty);
    expect(out.first.involves(Dimension.move), isTrue);
    expect(out.first.involves(Dimension.money), isTrue);
  });
}
```

> Verify `loopDatabaseProvider` is the right override seam (it is used the same way in `test/controllers/insights_controller_test.dart`). `nutritionRepositoryProvider` resolves from the same `loopDatabaseProvider`, so the empty-meals path needs no override.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/controllers/correlations_controller_test.dart`
Expected: FAIL — `correlations_controller.dart` / `surfacedCorrelationsProvider` does not exist.

- [ ] **Step 3: Implement the provider**

Create `lib/controllers/correlations_controller.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

// prefixed so the provider function `surfacedCorrelations` does not collide
// with the pure `surfacedCorrelations` it calls (same name, same scope).
import '../analysis/correlations.dart' as corr;
import 'providers.dart';

part 'correlations_controller.g.dart';

/// Surfaced cross-dimension correlations over the rolling window, strongest
/// first. Computed on-device from entries + meals; empty when nothing clears
/// the confidence bar (the honest empty state). Single source of truth shared
/// by the Insights and Nutrition surfaces.
@riverpod
Future<List<corr.Correlation>> surfacedCorrelations(Ref ref) async {
  final entryRepo = ref.watch(entryRepositoryProvider);
  final nutritionRepo = ref.watch(nutritionRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start =
      today.subtract(const Duration(days: corr.kCorrelationWindowDays - 1));
  final end = today.add(const Duration(days: 1));

  final entries = await entryRepo.getEntriesInRange(start, end);
  final meals = await nutritionRepo.getMealsInRange(start, end);

  final vectors = corr.buildDailyVectors(entries, meals, now: now);
  return corr.surfacedCorrelations(vectors);
}
```

- [ ] **Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/controllers/correlations_controller.g.dart`, exit 0.

> If `Ref` is unresolved, match the import style of `lib/controllers/insights_controller.dart` (it imports `package:riverpod_annotation/riverpod_annotation.dart` and uses bare `Ref`). Keep it identical.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/controllers/correlations_controller_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/controllers/correlations_controller.dart lib/controllers/correlations_controller.g.dart test/controllers/correlations_controller_test.dart
git commit -m "feat(insights): surfacedCorrelations provider over a 90-day window"
```

---

### Task 4: Server — narrate the provided correlation

**Files:**
- Modify: `server/src/prompts.ts` (`InsightsContext`, `insightsPrompt`)
- Modify: `server/src/schemas.ts` (`insightsContextSchema`, `insightsSchema`)
- Test: `server/src/prompts.test.ts`

**Interfaces:**
- Consumes: the client sends `context.correlation = { summary: string }` (optional).
- Produces: insights response gains `correlationNarration: string | null`. `insightsPrompt` instructs the model to rephrase `correlation.summary` warmly into that field and to invent no other relationship.

- [ ] **Step 1: Write the failing prompt test**

Add to `server/src/prompts.test.ts` (inside the existing insights `describe`/`it` group, mirroring the file's style):

```ts
it('includes the verified correlation summary and forbids inventing others', () => {
  const p = insightsPrompt({
    range: 'week', spent: 100, budget: 200, moveKcal: 0, moveTargetKcal: 0,
    ritualsKept: 0, ritualsTarget: 0, activeDays: 0, streakDays: 0,
    topCategory: 'Food', topCategoryPct: 34, spendByWeekday: [10, 20, 30, 40, 50, 25, 25],
    entries: [], correlation: { summary: 'On your 12 workout days you averaged $34; on your 16 rest days, $52.' },
  })
  expect(p).toContain('workout days you averaged $34')
  expect(p).toContain('correlationNarration')
  expect(p.toLowerCase()).toContain('do not invent')
})
```

- [ ] **Step 2: Run to verify it fails**

Run (from `server/`): `npm test -- prompts`
Expected: FAIL — output lacks `correlationNarration` / the summary text; type error on `correlation` not in `InsightsContext`.

- [ ] **Step 3: Extend `InsightsContext` and the prompt**

In `server/src/prompts.ts`, add the field to the interface (after `entries: string[]` at line ~50):

```ts
  entries: string[]
  // a single verified cross-dimension relationship, computed on-device; the
  // model only rephrases it. absent when nothing cleared the client's bar.
  correlation?: { summary: string }
```

In `insightsPrompt` (line ~115), extend the response shape and add the clause. Change the `shape` const to include the new field:

```ts
  const shape = `{"headline": string|null, "lede": string|null, "suggestion": string|null, "correlationNarration": string|null, "wins": [{"colorToken": "money"|"move"|"rituals", "title": string, "sub": string}], "patterns": [{"colorToken": "money"|"move"|"rituals", "title": string, "detail": string}]}`
```

Then, just before the prompt's return/assembly, build a correlation clause and include it (place the `corr` line with the other context lines, and append the instruction to the prompt body):

```ts
  const corr = c.correlation
    ? `\n\nVerified relationship (computed from their data — rephrase this as ONE warm, specific sentence in "correlationNarration"; do NOT invent any other cross-domain relationship, and set "correlationNarration" to null if this is absent):\n${c.correlation.summary}`
    : '\n\nNo verified cross-domain relationship this period — set "correlationNarration" to null.'
```

Append `${corr}` into the returned template string (next to where `byDay`/`entries` are interpolated). Keep the existing content intact.

- [ ] **Step 4: Run to verify it passes**

Run (from `server/`): `npm test -- prompts`
Expected: PASS.

- [ ] **Step 5: Add the schema fields with a failing test**

Add to `server/src/app.test.ts` (or the schema's own test if present) an assertion that the insights body accepts a `correlation` and that the response type allows `correlationNarration`. Minimal — extend the existing valid-insights test context with `correlation: { summary: 's' }` and assert a 200. Locate the existing `/v1/insights` test (around `app.test.ts:207`) and add to its `context`:

```ts
      correlation: { summary: 'On your 12 workout days you averaged $34; on your 16 rest days, $52.' },
```

- [ ] **Step 6: Run to verify it fails**

Run (from `server/`): `npm test -- app`
Expected: FAIL — Zod rejects the unknown `correlation` key (400) if the schema is strict, or the type is missing.

- [ ] **Step 7: Extend the Zod schemas**

In `server/src/schemas.ts`, on the insights context schema (the object containing `spendByWeekday` at line ~50), add:

```ts
  spendByWeekday: z.array(z.number()), entries: z.array(z.string()),
  correlation: z.object({ summary: z.string() }).optional(),
```

On the insights *response* schema (`insightsSchema` in `server/src/schemas.ts` / wherever `headline`/`patterns` are defined — confirm with `grep -n "insightsSchema" server/src/schemas.ts server/src/pal.ts`), add:

```ts
  correlationNarration: z.string().nullable().optional(),
```

> `insightsSchema` lives near `server/src/pal.ts:174`/`schemas.ts`. Add the field in whichever module defines the parsed shape so `pal.insights()` returns it.

- [ ] **Step 8: Run to verify both pass**

Run (from `server/`): `npm test`
Expected: PASS (all server suites).

- [ ] **Step 9: Commit**

```bash
git add server/src/prompts.ts server/src/schemas.ts server/src/prompts.test.ts server/src/app.test.ts
git commit -m "feat(insights): server narrates a client-provided verified correlation"
```

---

### Task 5: Client wiring — send the summary, receive the narration

**Files:**
- Modify: `lib/services/pal/pal_service.dart` (`PalInsights.correlationNarration`)
- Modify: `lib/services/pal/http_pal_service.dart` (map the field)
- Modify: `lib/services/pal/mock_pal_service.dart` (echo a narration from the summary)
- Modify: `lib/services/pal/pal_context_builder.dart` (`buildInsightsContext` accepts `correlationSummary`)
- Modify: `lib/controllers/providers.dart` (inject the strongest summary)
- Test: `test/services/pal/mock_pal_service_test.dart` (or the existing insights mock test)

**Interfaces:**
- Consumes: `surfacedCorrelationsProvider` (Task 3); `Correlation.summary` (Task 1).
- Produces: `PalInsights.correlationNarration` (`String?`); `buildInsightsContext(..., String? correlationSummary)` adds `'correlation': {'summary': ...}` to the wire map when non-null.

- [ ] **Step 1: Add `correlationNarration` to `PalInsights` (no behavior change yet)**

In `lib/services/pal/pal_service.dart`, `PalInsights` (line ~380): add the field to the constructor and class, leaving `isEmpty` unchanged (the correlation card is driven by the provider, not by `isEmpty`).

```dart
  const PalInsights({
    this.headline,
    this.lede,
    this.suggestion,
    this.correlationNarration,
    this.wins = const [],
    this.patterns = const [],
  });
  ...
  /// One warm sentence rephrasing the verified correlation, or null. The card
  /// falls back to the deterministic Correlation.summary when this is null.
  final String? correlationNarration;
```

- [ ] **Step 2: Write the failing mock test**

In `test/services/pal/mock_pal_service_test.dart`, add (matching the file's existing style for constructing the service and calling `insights`):

```dart
test('insights echoes a correlation narration when present is not required',
    () async {
  // the mock has no incoming context, so it returns a null narration by default
  final svc = MockPalService();
  final res = await svc.insights(InsightRange.week);
  expect(res.correlationNarration, isNull);
});
```

> This pins the mock's default. The real narration is exercised by the HTTP mapping test in Step 5. If `MockPalService()` needs constructor args, copy them from the existing tests in the same file.

- [ ] **Step 3: Run to verify it fails or passes trivially**

Run: `flutter test test/services/pal/mock_pal_service_test.dart`
Expected: FAIL to compile until `correlationNarration` exists (Step 1 already added it) — then PASS. If it passes immediately, that's fine; the field defaults to null.

- [ ] **Step 4: Map `correlationNarration` in `HttpPalService.insights`**

In `lib/services/pal/http_pal_service.dart`, `insights()` (line ~241), add the field to the returned `PalInsights`:

```dart
    return PalInsights(
      headline: json['headline'] as String?,
      lede: json['lede'] as String?,
      suggestion: json['suggestion'] as String?,
      correlationNarration: json['correlationNarration'] as String?,
      wins: mapList(
```

- [ ] **Step 5: Write a failing HTTP-mapping test**

In `test/services/http_pal_service_test.dart` (the file already tests the insights mapping — match its mock-client setup), add a case where the fake response includes `"correlationNarration": "You spend less on workout days."` and assert:

```dart
expect(result.correlationNarration, 'You spend less on workout days.');
```

- [ ] **Step 6: Run to verify it passes**

Run: `flutter test test/services/http_pal_service_test.dart`
Expected: PASS.

- [ ] **Step 7: Extend `buildInsightsContext` to carry the summary**

In `lib/services/pal/pal_context_builder.dart`, `buildInsightsContext` (line ~152): add the parameter and emit the field only when present.

```dart
Map<String, Object?> buildInsightsContext({
  required InsightRange range,
  required List<Entry> entries,
  required Goals goals,
  required int periodDays,
  required int streakDays,
  List<RitualRoutine> routines = const [],
  DateTime? periodStart,
  String? correlationSummary,
}) {
```

At the end, in the returned map, add:

```dart
    'spendByWeekday': spendByWeekday,
    'entries': entries.take(_maxInsightEntries).map(formatEntryLine).toList(),
    if (correlationSummary != null)
      'correlation': {'summary': correlationSummary},
  };
```

- [ ] **Step 8: Inject the strongest summary in `providers.dart`**

In `lib/controllers/providers.dart`, the `insights:` closure (line ~284), read the provider and pass the strongest summary. Add near the top of the closure body, and pass it to `buildInsightsContext`:

```dart
    insights: (range) async {
      final surfaced = await ref.read(surfacedCorrelationsProvider.future);
      final now = DateTime.now();
      ...
      return buildInsightsContext(
        range: range,
        entries: windowEntries,
        goals: await goals.get(),
        periodDays: periodDays,
        streakDays: moveStreakDays(lookback, now: now),
        routines: await ritualRoutines.getAll(),
        periodStart: start,
        correlationSummary: surfaced.isEmpty ? null : surfaced.first.summary,
      );
    },
```

Add the import at the top of `providers.dart`:

```dart
import 'correlations_controller.dart';
```

> `ref` is in scope inside this provider's build. `ref.read` (not `watch`) is correct here — the closure runs per-call, and a `watch` would not re-key the cache differently than recomputing the summary does.

- [ ] **Step 9: Make `MockPalService` rephrase the summary (so offline/dev shows narration)**

In `lib/services/pal/mock_pal_service.dart`, `insights()`: the mock has no incoming context map, so it cannot see the summary. Leave `correlationNarration` null there — the card's template fallback (Task 6) renders `Correlation.summary` directly, which is the same factual sentence. Confirm the mock's `PalInsights(...)` still compiles (the new named arg defaults to null). No code change required unless the mock constructs `PalInsights` positionally (it does not).

- [ ] **Step 10: Run the affected suites**

Run: `flutter test test/services/ test/controllers/`
Expected: PASS. Fix any constructor-arg drift surfaced by the new named field.

- [ ] **Step 11: Commit**

```bash
git add lib/services/pal/pal_service.dart lib/services/pal/http_pal_service.dart lib/services/pal/pal_context_builder.dart lib/controllers/providers.dart test/services
git commit -m "feat(insights): plumb the verified correlation summary and narration"
```

---

### Task 6: `CorrelationCard` + trust sheet widgets

**Files:**
- Create: `lib/widgets/correlation_card.dart`
- Test: `test/screens/correlation_card_test.dart`

**Interfaces:**
- Consumes: `Correlation` (Task 1), theme (`context.colors`, `AppType`, `Spacing`, `Radii`), `AppIcon`, `PressScale` (see `lib/screens/nutrition/nutrition_patterns_screen.dart` for the established card idiom).
- Produces:
  - `class CorrelationCard extends StatelessWidget { const CorrelationCard({required this.correlation, this.narration}); }` — renders eyebrow ("MOVE x MONEY"), `narration ?? correlation.summary` as the body, a `based on N days` chip + strength word, and is tappable to open the sheet.
  - `Future<void> showCorrelationTrustSheet(BuildContext context, Correlation c)` — modal sheet with the numeric breakdown.

- [ ] **Step 1: Write the failing widget test**

Create `test/screens/correlation_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/correlation_card.dart';

void main() {
  const correlation = Correlation(
    a: Dimension.move,
    b: Dimension.money,
    r: -0.52,
    n: 28,
    breakdown: GroupBreakdown(
      binaryDim: Dimension.move,
      continuousDim: Dimension.money,
      meanWhenActive: 34,
      meanWhenInactive: 52,
      countActive: 12,
      countInactive: 16,
    ),
  );

  Widget host(Widget child) =>
      AppTheme(child: MaterialApp(home: Scaffold(body: child)));

  testWidgets('shows the sample size and falls back to the summary', (t) async {
    await t.pumpWidget(host(const CorrelationCard(correlation: correlation)));
    expect(find.textContaining('28 days'), findsOneWidget);
    expect(find.textContaining('workout days'), findsOneWidget); // summary body
  });

  testWidgets('prefers the narration when provided', (t) async {
    await t.pumpWidget(host(const CorrelationCard(
        correlation: correlation, narration: 'You spend less on workout days.')));
    expect(find.text('You spend less on workout days.'), findsOneWidget);
  });

  testWidgets('tapping opens the trust sheet with the two-group breakdown',
      (t) async {
    await t.pumpWidget(host(Builder(
      builder: (ctx) => CorrelationCard(
        correlation: correlation,
        // tap handled internally; just ensure the sheet content shows
      ),
    )));
    await t.tap(find.byType(CorrelationCard));
    await t.pumpAndSettle();
    expect(find.textContaining('\$34'), findsWidgets);
    expect(find.textContaining('\$52'), findsWidgets);
  });
}
```

> Confirm the theme wrapper: check how `test/screens/nutrition_widgets_test.dart` wraps widgets (the exact `AppTheme`/`context.colors` provider). Match that wrapper here rather than inventing `AppTheme(...)` if the real name differs.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/correlation_card_test.dart`
Expected: FAIL — `correlation_card.dart` does not exist.

- [ ] **Step 3: Implement the card + sheet**

Create `lib/widgets/correlation_card.dart`. Model the card on `_PatternCard` in `nutrition_patterns_screen.dart` (eyebrow row with two square dots + tracker glyph, title/body column). Use `context.colors`, `AppType`, `Spacing`, `Radii`, `AppIcon`, `PressScale`.

```dart
import 'package:flutter/material.dart';

import '../analysis/correlations.dart';
import '../theme/theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

/// A surfaced cross-dimension correlation: eyebrow, narrated (or templated)
/// body, and a sample-size + strength chip. Tappable to reveal the breakdown.
class CorrelationCard extends StatelessWidget {
  const CorrelationCard({super.key, required this.correlation, this.narration});

  final Correlation correlation;
  final String? narration;

  static String _label(Dimension d) => switch (d) {
        Dimension.money => 'Money',
        Dimension.move => 'Move',
        Dimension.rituals => 'Rituals',
        Dimension.nutrition => 'Nutrition',
      };

  static String _token(Dimension d) => switch (d) {
        Dimension.money => 'money',
        Dimension.move => 'move',
        Dimension.rituals => 'rituals',
        Dimension.nutrition => 'nutrition',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final aColor = c.forType(_token(correlation.a));
    final bColor = c.forType(_token(correlation.b));
    final body = narration ?? correlation.summary;
    final eyebrow =
        '${_label(correlation.a)} x ${_label(correlation.b)}'.toUpperCase();

    return PressScale(
      onTap: () => showCorrelationTrustSheet(context, correlation),
      semanticLabel: body,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: aColor.withValues(alpha: 0.18), width: 0.5),
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Dot(color: aColor),
                const SizedBox(width: Spacing.xs),
                _Dot(color: bColor),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption2.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.ink3,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(width: Spacing.sm),
                AppIcon('chart.line.uptrend.xyaxis', size: 15, color: aColor),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(body,
                style: AppType.subhead.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -0.24,
                    height: 1.35)),
            const SizedBox(height: Spacing.sm),
            Text('Based on ${correlation.n} days · ${correlation.strengthWord} link',
                style: AppType.caption2.copyWith(color: c.ink3)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: 8,
      height: 8,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)));
}

/// Modal "why" sheet: the two-group means (when one side is binary) or a trend
/// line, plus the sample size — the underlying-data view the trust layer
/// requires.
Future<void> showCorrelationTrustSheet(
    BuildContext context, Correlation correlation) {
  final c = context.colors;
  final b = correlation.breakdown;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why you\'re seeing this',
              style: AppType.title3.copyWith(
                  fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: Spacing.md),
          if (b != null) ...[
            _Row(
                label: '${b.countActive} ${activeDayLabel(b.binaryDim)}',
                value: formatValue(b.continuousDim, b.meanWhenActive),
                colors: c),
            const SizedBox(height: Spacing.sm),
            _Row(
                label: '${b.countInactive} ${inactiveDayLabel(b.binaryDim)}',
                value: formatValue(b.continuousDim, b.meanWhenInactive),
                colors: c),
          ] else
            Text(correlation.summary,
                style: AppType.body.copyWith(color: c.ink)),
          const SizedBox(height: Spacing.lg),
          Text(
              'Computed from your own data over ${correlation.n} days. '
              'A ${correlation.strengthWord} link, not a certainty.',
              style: AppType.footnote.copyWith(color: c.ink3, height: 1.4)),
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.colors});
  final String label;
  final String value;
  final dynamic colors;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: AppType.subhead.copyWith(color: colors.ink2))),
          Text(value,
              style: AppType.subhead
                  .copyWith(fontWeight: FontWeight.w700, color: colors.ink)),
        ],
      );
}
```

> Verify these theme symbols exist with the names used: `context.colors`, `c.forType`, `c.surface`, `c.ink`/`ink2`/`ink3`, `AppType.caption2`/`subhead`/`title3`/`body`/`footnote`, `Spacing.xs/sm/md/lg/xl`, `Radii.card`, `AppIcon`, `PressScale`. All appear in `nutrition_patterns_screen.dart` except `c.ink2`/`AppType.title3`/`AppType.body` — confirm those via `grep -rn "ink2\|title3\b\|AppType.body\b" lib/theme lib/screens` and substitute the nearest real token if absent. Pick a real SF Symbol for the glyph (`chart.line.uptrend.xyaxis`) — confirm it renders via the existing `AppIcon` map; fall back to `'sparkles'` if unmapped. Replace `dynamic colors` with the real colors type once confirmed (avoid `dynamic` in committed code).

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/correlation_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/correlation_card.dart test/screens/correlation_card_test.dart
git commit -m "feat(insights): CorrelationCard and trust sheet widgets"
```

---

### Task 7: Surface on the Insights screen

**Files:**
- Modify: `lib/screens/money/insights_screen.dart`
- Test: `test/spending_detail_test.dart` (or the screen's existing test — confirm which test mounts `InsightsScreen`)

**Interfaces:**
- Consumes: `surfacedCorrelationsProvider` (Task 3), `insightsProvider` (existing, for `correlationNarration`), `CorrelationCard` (Task 6).
- Produces: the globally strongest correlation renders as a `CorrelationCard` in the patterns area; narration from `insightsProvider` applies to it.

- [ ] **Step 1: Read the screen to find the patterns render site**

Run: `grep -n "patterns\|ref.watch\|InsightPattern\|ConsumerWidget\|build(" lib/screens/money/insights_screen.dart`
Identify where the existing LLM `patterns` list renders (the section to place the correlation card above).

- [ ] **Step 2: Write the failing test**

In the screen's test, seed a DB with the 28-day move/money pattern (reuse the generator from Task 3's test), mount the Insights screen for the week range with a fake Pal returning a known `correlationNarration`, and assert the narration text appears. If no screen test exists, create `test/screens/insights_screen_test.dart` mirroring `test/screens/nutrition_screen_test.dart`'s harness.

```dart
expect(find.textContaining('workout days'), findsWidgets);
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/screens/insights_screen_test.dart`
Expected: FAIL — no correlation card rendered yet.

- [ ] **Step 4: Render the card**

In `lib/screens/money/insights_screen.dart` build method, watch both providers and insert the card above the existing patterns section:

```dart
final surfaced = ref.watch(surfacedCorrelationsProvider).asData?.value ?? const [];
final narration = ref.watch(insightsProvider(InsightRange.week)).asData?.value?.correlationNarration;
...
// in the children list, before the existing patterns:
if (surfaced.isNotEmpty)
  Padding(
    padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.md),
    child: CorrelationCard(correlation: surfaced.first, narration: narration),
  ),
```

Add imports:

```dart
import '../../analysis/correlations.dart';
import '../../controllers/correlations_controller.dart';
import '../../widgets/correlation_card.dart';
```

> Use the same `InsightRange` the screen already requests from `insightsProvider` (match the existing `ref.watch(insightsProvider(...))` argument in this file; do not introduce a second range). If the screen reads `insightsProvider(range)` from a local `range` variable, use that.

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/screens/insights_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/money/insights_screen.dart test/screens/insights_screen_test.dart
git commit -m "feat(insights): surface the strongest correlation on the Insights screen"
```

---

### Task 8: Surface nutrition correlations on the Connections screen

**Files:**
- Modify: `lib/screens/nutrition/nutrition_patterns_screen.dart`
- Test: `test/screens/nutrition_patterns_test.dart`

**Interfaces:**
- Consumes: `surfacedCorrelationsProvider` (Task 3), `insightsProvider` (for narration of the global-strongest), `CorrelationCard` (Task 6).
- Produces: nutrition-involving correlations render as `CorrelationCard`s above the existing money pattern card; the one equal to `surfaced.first` shows the narration, others show their template summary.

- [ ] **Step 1: Write the failing test**

In `test/screens/nutrition_patterns_test.dart`, seed a DB with a strong nutrition-involving relationship (e.g. 24 days where workout days have higher calories — Move/Nutrition), mount `NutritionPatternsScreen`, and assert a calories-based correlation body appears:

```dart
expect(find.textContaining('cal'), findsWidgets);
```

> Mirror the harness already used in this test file (it watches `nutritionControllerProvider`); add the `loopDatabaseProvider` override so `surfacedCorrelationsProvider` reads the seeded entries/meals.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/nutrition_patterns_test.dart`
Expected: FAIL — only the existing pattern cards render.

- [ ] **Step 3: Render nutrition correlation cards**

In `lib/screens/nutrition/nutrition_patterns_screen.dart` `build`, watch the provider and filter to nutrition-involving correlations, rendering them above the existing `for (final p in patterns)` loop:

```dart
final surfaced = ref.watch(surfacedCorrelationsProvider).asData?.value ?? const [];
final narration = ref.watch(insightsProvider(InsightRange.week)).asData?.value?.correlationNarration;
final nutritionCorrs =
    surfaced.where((c) => c.involves(Dimension.nutrition)).toList();
...
// in children, before the existing patterns loop:
for (final corr in nutritionCorrs)
  Padding(
    padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.md),
    child: CorrelationCard(
      correlation: corr,
      narration: (surfaced.isNotEmpty && identical(corr, surfaced.first))
          ? narration
          : null,
    ),
  ),
```

Add imports:

```dart
import '../../analysis/correlations.dart';
import '../../controllers/correlations_controller.dart';
import '../../services/pal/pal_service.dart' show InsightRange;
import '../../widgets/correlation_card.dart';
```

> `identical` works because both reads resolve the same provider instance within a frame; if the lint flags it, compare by pair instead: `corr.a == surfaced.first.a && corr.b == surfaced.first.b`.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/nutrition_patterns_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/nutrition/nutrition_patterns_screen.dart test/screens/nutrition_patterns_test.dart
git commit -m "feat(insights): surface nutrition correlations on the Connections screen"
```

---

### Task 9: Full verification + analyzer

**Files:** none (verification only).

- [ ] **Step 1: Analyze**

Run: `flutter analyze`
Expected: No new issues. Resolve any introduced by the new files (notably the `dynamic colors` substitution in Task 6 and unused imports).

- [ ] **Step 2: Run the full Dart suite**

Run: `flutter test`
Expected: PASS, no skips.

- [ ] **Step 3: Run the full server suite**

Run (from `server/`): `npm test`
Expected: PASS.

- [ ] **Step 4: Commit any analyzer fixups**

```bash
git add -A
git commit -m "chore(insights): analyzer and test cleanup for the correlation engine"
```

---

## Self-Review

**1. Spec coverage:**
- Scope (6 pairs) — Task 1 `surfacedCorrelations` iterates all pairs; Task 2 builds all four vectors. ✓
- Confidence bar (n>=21, |r|>=0.4, Holm) — Task 1 Steps 13-16. ✓
- Missing-data rules (money/move/rituals 0-fill; nutrition exclude) — Task 2 Step 3. ✓
- All-Pearson + binary split only for trust sheet — Task 1 `_toCorrelation`. ✓
- Compute site A (client computes, LLM narrates, template fallback) — Tasks 3-5; fallback in Task 6 (`narration ?? summary`). ✓
- Latency / instant render — card reads `surfacedCorrelationsProvider` (no network); narration upgrades async. ✓
- Trust drill-down (numeric breakdown) — Task 6 sheet. ✓
- Surfacing (Insights + Nutrition) — Tasks 7-8. ✓
- Server minimal + backward-compatible (optional fields) — Task 4. ✓
- Audit-lesson regression (constant series → nothing) — Task 1 Step 13. ✓

**2. Placeholder scan:** No "TBD/TODO/handle errors" left. The `>` notes are verification instructions (confirm a symbol, substitute a token), each with a concrete command and fallback — not deferred work.

**3. Type consistency:** `Correlation`, `GroupBreakdown`, `DailySeries`, `Dimension` defined in Task 1 and used unchanged in 2-8. `surfacedCorrelations` (function) and `surfacedCorrelationsProvider` (Task 3) named consistently. `buildInsightsContext(..., correlationSummary)` (Task 5 Step 7) matches the call site (Step 8). `PalInsights.correlationNarration` defined (Task 5 Step 1), mapped (Step 4), consumed (Tasks 7-8). Server `correlation.summary` (input) and `correlationNarration` (output) consistent across Task 4 and Task 5.

## Known follow-ups (out of scope, noted not silently dropped)

- Per-card narration: only `surfaced.first` is narrated; other nutrition cards show their (factual) template. A follow-up can send each surfaced correlation's summary for its own narration.
- The Move daily scalar uses `calories ?? 0`, so a logged workout with unknown calories reads as a rest day in the two-group split. Acceptable for v1; revisit if zero-calorie move entries are common.
- Rituals daily scalar is a raw ritual-entry count, not `completedRoutines`. A deliberate choice to keep the engine independent of goals/routines; revisit if it misleads.
