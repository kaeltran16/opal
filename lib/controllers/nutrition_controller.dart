import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/repositories.dart';
import '../models/models.dart';
import '../services/pal/pal_service.dart';
import '../util/dates.dart';
import 'providers.dart';

part 'nutrition_controller.g.dart';

/// An expense today that looks like a meal but isn't logged yet — the "an
/// expense looks like a meal" prompt. [guess] is Pal's estimate from the
/// expense title.
class NutritionPending {
  const NutritionPending({required this.expense, required this.guess});
  final Entry expense;
  final MealEstimate guess;
}

/// Today's rollup: summed calorie + macro ranges plus counts and a qualitative
/// read of the day. No goals, no "remaining" — just how the day looks.
class NutritionDay {
  const NutritionDay({
    required this.cal,
    required this.macros,
    required this.meals,
    required this.takeout,
    required this.home,
    required this.feel,
    required this.note,
  });
  final IntRange cal;
  final Macros macros;
  final int meals, takeout, home;
  final String feel, note;
}

/// One bar of the week strip. [load] is the day's calorie-mid normalized to the
/// week's max (0..1); null for future days. [today] flags the current day.
class NutritionWeekDay {
  const NutritionWeekDay({
    required this.day,
    required this.date,
    required this.load,
    required this.takeout,
    required this.home,
    required this.today,
  });
  final String day;
  final int date;
  final double? load;
  final int takeout, home;
  final bool today;
}

/// A cross-tracker "connection" surfaced on the Nutrition tab.
class NutritionPattern {
  const NutritionPattern({
    required this.tracker,
    required this.icon,
    required this.title,
    required this.body,
    required this.spark,
    required this.emph,
  });
  final String tracker;
  final String icon;
  final String title;
  final String body;
  final List<int> spark;
  final List<int> emph;
}

/// The Nutrition view model: today's meals + rollup, the week strip, the
/// pending-expense prompt, and the connection patterns. The screen is dumb —
/// all math lives here.
class NutritionState {
  const NutritionState({
    required this.meals,
    required this.day,
    required this.week,
    required this.pending,
    required this.patterns,
  });
  final List<NutritionMeal> meals;
  final NutritionDay day;
  final List<NutritionWeekDay> week;
  final NutritionPending? pending;
  final List<NutritionPattern> patterns;
}

/// Streams the Nutrition view model and owns meal logging actions.
@riverpod
class NutritionController extends _$NutritionController {
  @override
  Stream<NutritionState> build() async* {
    final repo = ref.watch(nutritionRepositoryProvider);
    final entryRepo = ref.watch(entryRepositoryProvider);
    final pal = ref.watch(palServiceProvider);

    final now = DateTime.now();
    final todayStart = startOfDay(now);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekStart = startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));

    // Re-emit whenever today's meals change.
    await for (final meals in repo.watchMealsForDay(now)) {
      final day = _rollup(meals);

      final weekMeals = await repo.getMealsInRange(weekStart, weekEnd);
      final week = _buildWeek(weekStart, now, weekMeals);

      final pending = await _derivePending(
        entryRepo: entryRepo,
        repo: repo,
        pal: pal,
        todayStart: todayStart,
        todayEnd: todayEnd,
      );

      final weekEntries = await entryRepo.getEntriesInRange(weekStart, weekEnd);
      final patterns = _buildPatterns(weekMeals, weekEntries);

      yield NutritionState(
        meals: meals,
        day: day,
        week: week,
        pending: pending,
        patterns: patterns,
      );
    }
  }

  NutritionDay _rollup(List<NutritionMeal> meals) {
    var calLo = 0, calHi = 0;
    var pLo = 0, pHi = 0, cLo = 0, cHi = 0, fLo = 0, fHi = 0;
    var takeout = 0, home = 0;
    for (final m in meals) {
      calLo += m.cal.lo;
      calHi += m.cal.hi;
      pLo += m.macros.protein.lo;
      pHi += m.macros.protein.hi;
      cLo += m.macros.carbs.lo;
      cHi += m.macros.carbs.hi;
      fLo += m.macros.fat.lo;
      fHi += m.macros.fat.hi;
      if (m.source == NutritionSource.takeout) {
        takeout++;
      } else {
        home++;
      }
    }
    final cal = IntRange(calLo, calHi);
    final macros = Macros(
      protein: IntRange(pLo, pHi),
      carbs: IntRange(cLo, cHi),
      fat: IntRange(fLo, fHi),
    );

    final mid = cal.mid;
    final feel = mid < 1500
        ? 'lighter day'
        : mid > 2200
            ? 'fuller day'
            : 'balanced day';
    // carb kcal share of the day, at the macro mids (carbs @ 4 kcal/g).
    final carbKcal = macros.carbs.mid * 4;
    final note = (mid > 0 && carbKcal / mid > 0.5)
        ? 'leaning carb-heavy'
        : 'a fair mix';

    return NutritionDay(
      cal: cal,
      macros: macros,
      meals: meals.length,
      takeout: takeout,
      home: home,
      feel: feel,
      note: note,
    );
  }

  List<NutritionWeekDay> _buildWeek(
      DateTime weekStart, DateTime now, List<NutritionMeal> weekMeals) {
    final today = startOfDay(now);
    // bucket meals by day-of-week offset from the week start.
    final mids = List<int>.filled(7, 0);
    final takeouts = List<int>.filled(7, 0);
    final homes = List<int>.filled(7, 0);
    for (final m in weekMeals) {
      final i = startOfDay(m.timestamp).difference(weekStart).inDays;
      if (i < 0 || i > 6) continue;
      mids[i] += m.cal.mid;
      if (m.source == NutritionSource.takeout) {
        takeouts[i]++;
      } else {
        homes[i]++;
      }
    }
    final maxMid = mids.fold(0, (a, b) => b > a ? b : a);

    return List<NutritionWeekDay>.generate(7, (i) {
      final date = weekStart.add(Duration(days: i));
      final isFuture = startOfDay(date).isAfter(today);
      return NutritionWeekDay(
        day: kWeekdaysShort[i],
        date: date.day,
        load: isFuture || maxMid == 0 ? null : mids[i] / maxMid,
        takeout: takeouts[i],
        home: homes[i],
        today: startOfDay(date) == today,
      );
    });
  }

  Future<NutritionPending?> _derivePending({
    required EntryRepository entryRepo,
    required NutritionRepository repo,
    required PalService pal,
    required DateTime todayStart,
    required DateTime todayEnd,
  }) async {
    // most recent today (the stream is newest-first) food expense not yet
    // turned into a meal.
    final entries = await entryRepo.getEntriesInRange(todayStart, todayEnd);
    final linked = await repo.linkedEntryIds(todayStart, todayEnd);
    Entry? candidate;
    for (final e in entries) {
      if (e.type == EntryType.money &&
          (e.amount ?? 0) < 0 &&
          e.category == 'Food & Drink' &&
          !linked.contains(e.id)) {
        candidate = e;
        break;
      }
    }
    if (candidate == null) return null;
    final guess = await pal.estimateMeal('${candidate.title} takeout');
    return NutritionPending(expense: candidate, guess: guess);
  }

  // first-pass: qualitative bodies; headline numbers are real
  List<NutritionPattern> _buildPatterns(
      List<NutritionMeal> weekMeals, List<Entry> weekEntries) {
    // real headline: takeout food spend vs home-cooked this week.
    var takeoutSpend = 0.0;
    final linkedFoodIds = {
      for (final m in weekMeals)
        if (m.source == NutritionSource.takeout && m.linkedEntryId != null)
          m.linkedEntryId!
    };
    for (final e in weekEntries) {
      if (e.type == EntryType.money &&
          (e.amount ?? 0) < 0 &&
          e.category == 'Food & Drink' &&
          linkedFoodIds.contains(e.id)) {
        takeoutSpend += e.amount!.abs();
      }
    }
    final homeMeals =
        weekMeals.where((m) => m.source != NutritionSource.takeout).length;
    final takeoutMeals =
        weekMeals.where((m) => m.source == NutritionSource.takeout).length;
    final spendStr = '\$${takeoutSpend.round()}';
    final moneyBody = takeoutMeals == 0
        ? 'No takeout logged this week — every meal so far was home-cooked.'
        : 'You spent about $spendStr on $takeoutMeals takeout '
            '${takeoutMeals == 1 ? 'meal' : 'meals'} this week, against '
            '$homeMeals cooked at home.';

    return [
      NutritionPattern(
        tracker: 'money',
        icon: 'creditcard.fill',
        title: 'Takeout vs. home',
        body: moneyBody,
        spark: [takeoutMeals, homeMeals],
        emph: const [0],
      ),
      const NutritionPattern(
        tracker: 'move',
        icon: 'figure.run',
        title: 'Fuel around workouts',
        body: "On the days you trained, you tended to eat a little more — "
            "your body asking for it after the work.",
        spark: [40, 55, 48, 70, 62, 80, 58],
        emph: [3, 5],
      ),
      const NutritionPattern(
        tracker: 'rituals',
        icon: 'sparkles',
        title: 'Mornings set the tone',
        body: "Days that started with your morning ritual leaned lighter and "
            "more balanced through lunch.",
        spark: [60, 45, 50, 40, 55, 42, 48],
        emph: [1, 3],
      ),
      const NutritionPattern(
        tracker: 'nutrition',
        icon: 'leaf.fill',
        title: 'Your steady rhythm',
        body: "Most days land in a similar range — a calm, repeatable baseline "
            "rather than big swings.",
        spark: [52, 58, 50, 55, 53, 60, 54],
        emph: [],
      ),
    ];
  }

  /// Logs a hand-entered meal from a Pal estimate. Source = manual.
  Future<void> addManualMeal({
    required String slot,
    required String name,
    required MealEstimate est,
  }) async {
    await ref.read(nutritionRepositoryProvider).insert(
          NutritionMeal(
            id: '',
            timestamp: DateTime.now(),
            slot: slot,
            name: name,
            source: NutritionSource.manual,
            icon: NutritionSource.manual.icon,
            confidence: est.confidence,
            cal: est.cal,
            macros: est.macros,
          ),
        );
    await ref.read(hapticsServiceProvider).light();
  }

  /// Confirms a takeout expense as a meal, scaling the estimate by [portion]
  /// (`Lighter` 0.78 / `As shown` 1 / `Larger` 1.25). Source = takeout, linked
  /// back to the originating expense.
  Future<void> confirmFromExpense(
    Entry e,
    MealEstimate guess, {
    required String name,
    required String portion,
  }) async {
    final factor = switch (portion) {
      'Lighter' => 0.78,
      'Larger' => 1.25,
      _ => 1.0,
    };
    IntRange scale(IntRange r) =>
        IntRange((r.lo * factor).round(), (r.hi * factor).round());
    final cal = scale(guess.cal);
    final macros = Macros(
      protein: scale(guess.macros.protein),
      carbs: scale(guess.macros.carbs),
      fat: scale(guess.macros.fat),
    );
    await ref.read(nutritionRepositoryProvider).insert(
          NutritionMeal(
            id: '',
            timestamp: e.timestamp,
            slot: 'Dinner',
            name: name,
            source: NutritionSource.takeout,
            icon: NutritionSource.takeout.icon,
            confidence: guess.confidence,
            cal: cal,
            macros: macros,
            linkedEntryId: e.id,
          ),
        );
    await ref.read(hapticsServiceProvider).light();
  }

  /// Removes a meal.
  Future<void> deleteMeal(String id) =>
      ref.read(nutritionRepositoryProvider).deleteById(id);

  /// Pal's calorie/macro estimate for a free-text meal [description].
  Future<MealEstimate> estimateFor(String description) =>
      ref.read(palServiceProvider).estimateMeal(description);
}
