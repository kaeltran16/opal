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
    this.linkedExpenses = const {},
  });
  final List<NutritionMeal> meals;
  final NutritionDay day;
  final List<NutritionWeekDay> week;
  final NutritionPending? pending;
  final List<NutritionPattern> patterns;

  /// Linked expenses for this week's meals, keyed by `Entry.id`. Lets the meal
  /// detail show the originating merchant + amount for a `linkedEntryId`.
  final Map<String, Entry> linkedExpenses;
}

/// Streams the Nutrition view model and owns meal logging actions.
@riverpod
class NutritionController extends _$NutritionController {
  /// Portion-size scale factors shared with the confirm sheet preview.
  static const Map<String, double> portionFactors = {
    'Lighter': 0.78,
    'As shown': 1.0,
    'Larger': 1.25,
  };
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

      // Index the expenses behind this week's linked meals so the detail can
      // name the merchant + amount a meal came from.
      final linkedIds = {
        for (final m in weekMeals)
          if (m.linkedEntryId != null) m.linkedEntryId!
      };
      final linkedExpenses = {
        for (final e in weekEntries)
          if (linkedIds.contains(e.id)) e.id: e
      };

      yield NutritionState(
        meals: meals,
        day: day,
        week: week,
        pending: pending,
        patterns: patterns,
        linkedExpenses: linkedExpenses,
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
    // honest read of the takeout/home split (real counts). the old
    // "carb-heavy" note was noise: macros are defined as a fixed 50% carbs, so
    // that ratio could never reflect a genuinely carb-heavy day.
    final note = takeout == 0
        ? 'all home-cooked'
        : home == 0
            ? 'all takeout'
            : takeout > home
                ? 'mostly takeout'
                : 'mostly home-cooked';

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

  // only the money pattern is computed from real data; the former move /
  // rituals / steady-rhythm patterns were constant prose stated as observed
  // fact, so they are not emitted until a real computation exists.
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

  /// Edits an existing meal in place from a (possibly re-run) estimate. Keeps
  /// the meal's identity — id, timestamp, source, icon, link — and rewrites only
  /// the slot, name, and estimate. Routes through `upsert` so no duplicate is
  /// created.
  Future<void> updateMeal(
    NutritionMeal meal, {
    required String slot,
    required String name,
    required MealEstimate est,
  }) async {
    await ref.read(nutritionRepositoryProvider).upsert(
          meal.copyWith(
            slot: slot,
            name: name,
            confidence: est.confidence,
            cal: est.cal,
            macros: est.macros,
          ),
        );
    await ref.read(hapticsServiceProvider).light();
  }

  /// Meal slot inferred from the time of day an expense landed. Also used by
  /// the add-by-hand sheet to default the slot to the current hour.
  static String slotForHour(int hour) {
    if (hour < 11) return 'Breakfast';
    if (hour < 15) return 'Lunch';
    if (hour < 21) return 'Dinner';
    return 'Snack';
  }

  /// Confirms a takeout expense as a meal, scaling the estimate by [portion]
  /// (`Lighter` 0.78 / `As shown` 1 / `Larger` 1.25). Source = takeout, linked
  /// back to the originating expense. Slot is inferred from the expense time.
  Future<void> confirmFromExpense(
    Entry e,
    MealEstimate guess, {
    required String name,
    required String portion,
  }) async {
    final factor = portionFactors[portion] ?? 1.0;
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
            slot: slotForHour(e.timestamp.hour),
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
