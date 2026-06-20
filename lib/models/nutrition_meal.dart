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

/// A logged meal/drink. Everything is an AI estimate (ranges + confidence).
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

  /// Display clock time, e.g. "07:50".
  String get time =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}';

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
