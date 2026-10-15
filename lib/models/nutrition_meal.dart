import '../util/dates.dart';
import 'enums.dart';

/// An inclusive integer estimate range (e.g. a calorie or gram spread).
class IntRange {
  const IntRange(this.lo, this.hi);
  final int lo;
  final int hi;

  /// Rounded midpoint — the "≈" figure shown in the UI.
  int get mid => ((lo + hi) / 2).round();

  @override
  bool operator ==(Object other) =>
      other is IntRange && other.lo == lo && other.hi == hi;
  @override
  int get hashCode => Object.hash(lo, hi);
}

/// Protein / carbs / fat gram ranges for a meal.
class Macros {
  const Macros({required this.protein, required this.carbs, required this.fat});
  final IntRange protein, carbs, fat;

  @override
  bool operator ==(Object other) =>
      other is Macros &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat;
  @override
  int get hashCode => Object.hash(protein, carbs, fat);
}

/// Derives a rough macro split from a calorie range. Honest, wide-ish ranges —
/// never fake precision: protein 22% @4 kcal/g, carbs 50% @4, fat 28% @9.
Macros macrosFromCal(IntRange cal) {
  IntRange mk(double frac, int kcalPerG) => IntRange(
        (cal.lo * frac / kcalPerG).round(),
        (cal.hi * frac / kcalPerG).round(),
      );
  return Macros(protein: mk(0.22, 4), carbs: mk(0.50, 4), fat: mk(0.28, 9));
}

/// AI calorie + macro estimate for a free-text meal description.
///
/// [macros] is derived from [cal] via [macrosFromCal] — no separate wire field
/// needed; the getter recomputes on every access.
///
/// Re-exported by `pal_service.dart`, which is how callers normally reach it.
class MealEstimate {
  const MealEstimate({
    required this.name,
    required this.cal,
    required this.confidence,
  });

  final String name;
  final IntRange cal;
  final NutritionConfidence confidence;

  Macros get macros => macrosFromCal(cal);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealEstimate &&
          other.name == name &&
          other.cal == cal &&
          other.confidence == confidence;

  @override
  int get hashCode => Object.hash(name, cal, confidence);
}

// Unicode-aware on purpose: `\w` is ASCII-only in Dart, so an `[^\w\s]` strip
// would delete every accented letter — turning "phở bò" into "ph b" and letting
// unrelated dishes collide on one key. Matching punctuation and symbols directly
// leaves letters, marks and digits of any script intact.
final _foodPunctuation = RegExp(r'[\p{P}\p{S}]', unicode: true);
final _whitespaceRun = RegExp(r'\s+');

/// Lookup key for a meal description: lower-cased, punctuation folded to spaces,
/// with runs of whitespace collapsed. The key the saved-food estimate cache is
/// stored under, so "Pho bo!", "pho-bo" and "  pho   bo " reuse one estimate.
///
/// Deliberately exact after normalizing — no fuzzy or substring matching. The
/// cache exists so the same meal reads the same every time; a near-match that
/// silently answered with a different dish's calories would trade that away.
///
/// Unicode composition is not normalized, so a precomposed "ở" and a decomposed
/// "ơ" + tone mark key separately. Both round-trip correctly; they just don't
/// share a cache entry.
String normalizeFoodKey(String description) => description
    .toLowerCase()
    .replaceAll(_foodPunctuation, ' ')
    .replaceAll(_whitespaceRun, ' ')
    .trim();

/// A logged meal/drink. Everything is an AI estimate (ranges + confidence).
/// A meal name as the app shows it: first letter capitalised, the rest as
/// given ("matcha latte" -> "Matcha latte"). The model and the user both write
/// names in whatever case, and the rest of the app writes sentence case.
String mealName(String name) {
  final t = name.trim();
  return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
}

class NutritionMeal {
  const NutritionMeal({
    required this.id,
    required this.timestamp,
    required this.slot,
    required this.name,
    required this.source,
    required this.icon,
    required this.confidence,
    required this.cal,
    required this.macros,
    this.note,
    this.tags = const [],
    this.linkedEntryId,
  });

  final String id;
  final DateTime timestamp;

  /// 'Breakfast' | 'Lunch' | 'Dinner' | 'Snack' | 'Drink'.
  final String slot;
  final String name;
  final NutritionSource source;

  /// SF-symbol glyph for the row tile.
  final String icon;
  final NutritionConfidence confidence;
  final IntRange cal;
  final Macros macros;
  final String? note;
  final List<String> tags;

  /// FK to the originating expense [Entry.id] when [source] is takeout.
  final String? linkedEntryId;

  /// Display clock time, e.g. "7:50 AM".
  String get time => clockTime(timestamp);

  NutritionMeal copyWith({
    String? id,
    DateTime? timestamp,
    String? slot,
    String? name,
    NutritionSource? source,
    String? icon,
    NutritionConfidence? confidence,
    IntRange? cal,
    Macros? macros,
    String? note,
    List<String>? tags,
    String? linkedEntryId,
  }) =>
      NutritionMeal(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        slot: slot ?? this.slot,
        name: name ?? this.name,
        source: source ?? this.source,
        icon: icon ?? this.icon,
        confidence: confidence ?? this.confidence,
        cal: cal ?? this.cal,
        macros: macros ?? this.macros,
        note: note ?? this.note,
        tags: tags ?? this.tags,
        linkedEntryId: linkedEntryId ?? this.linkedEntryId,
      );

  @override
  bool operator ==(Object other) =>
      other is NutritionMeal &&
      other.id == id &&
      other.timestamp == timestamp &&
      other.slot == slot &&
      other.name == name &&
      other.source == source &&
      other.icon == icon &&
      other.confidence == confidence &&
      other.cal == cal &&
      other.macros == macros &&
      other.note == note &&
      _listEq(other.tags, tags) &&
      other.linkedEntryId == linkedEntryId;

  @override
  int get hashCode => Object.hash(id, timestamp, slot, name, source, icon,
      confidence, cal, macros, note, Object.hashAll(tags), linkedEntryId);

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
