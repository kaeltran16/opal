import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [NutritionMeal]s. Reactive via `watch*` streams. Assigns a UUID
/// on insert when the caller passes an empty id (the common case from UI).
class NutritionRepository {
  NutritionRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  Stream<List<NutritionMeal>> watchMealsForDay([DateTime? day]) {
    final d = day ?? DateTime.now();
    final start = DateTime(d.year, d.month, d.day);
    return watchMealsInRange(start, start.add(const Duration(days: 1)));
  }

  Stream<List<NutritionMeal>> watchMealsInRange(DateTime from, DateTime to) {
    final q = _db.select(_db.nutritionMeals)
      ..where((t) =>
          t.timestamp.isBiggerOrEqualValue(from) &
          t.timestamp.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  Future<List<NutritionMeal>> getMealsInRange(DateTime from, DateTime to) async {
    final q = _db.select(_db.nutritionMeals)
      ..where((t) =>
          t.timestamp.isBiggerOrEqualValue(from) &
          t.timestamp.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    return (await q.get()).map((r) => r.toModel()).toList();
  }

  Future<String> insert(NutritionMeal meal) async {
    final id = meal.id.isEmpty ? _uuid.v4() : meal.id;
    await _db
        .into(_db.nutritionMeals)
        .insert(meal.copyWith(id: id).toCompanion());
    return id;
  }

  Future<void> upsert(NutritionMeal meal) =>
      _db.into(_db.nutritionMeals).insertOnConflictUpdate(meal.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.nutritionMeals)..where((t) => t.id.equals(id))).go();

  /// Entry ids that already have a linked meal in [from, to) — used to derive
  /// the "an expense looks like a meal" pending card without double-counting.
  Future<Set<String>> linkedEntryIds(DateTime from, DateTime to) async {
    final q = _db.select(_db.nutritionMeals)
      ..where((t) =>
          t.linkedEntryId.isNotNull() &
          t.timestamp.isBiggerOrEqualValue(from) &
          t.timestamp.isSmallerThanValue(to));
    return (await q.get()).map((r) => r.linkedEntryId!).toSet();
  }
}
