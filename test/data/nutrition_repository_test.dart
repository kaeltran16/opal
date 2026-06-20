import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/nutrition_repository.dart';
import 'package:opal/models/models.dart';

NutritionMeal _meal(String id, DateTime ts, {String? linked}) => NutritionMeal(
      id: id, timestamp: ts, slot: 'Lunch', name: 'X',
      source: linked == null ? NutritionSource.home : NutritionSource.takeout,
      icon: 'leaf.fill', confidence: NutritionConfidence.med,
      cal: const IntRange(400, 600), macros: macrosFromCal(const IntRange(400, 600)),
      linkedEntryId: linked,
    );

void main() {
  late LoopDatabase db;
  late NutritionRepository repo;
  setUp(() {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    repo = NutritionRepository(db);
  });
  tearDown(() => db.close());

  test('insert assigns a UUID when id is empty', () async {
    final id = await repo.insert(_meal('', DateTime(2026, 6, 21, 9)));
    expect(id, isNotEmpty);
  });

  test('watchMealsForDay returns only that day, ascending', () async {
    await repo.insert(_meal('a', DateTime(2026, 6, 21, 19)));
    await repo.insert(_meal('b', DateTime(2026, 6, 21, 8)));
    await repo.insert(_meal('c', DateTime(2026, 6, 20, 8)));
    final meals = await repo.watchMealsForDay(DateTime(2026, 6, 21)).first;
    expect(meals.map((m) => m.id), ['b', 'a']);
  });

  test('linkedEntryIds reports expenses already turned into meals', () async {
    await repo.insert(_meal('a', DateTime(2026, 6, 21, 12), linked: 'e1'));
    final ids = await repo.linkedEntryIds(
        DateTime(2026, 6, 21), DateTime(2026, 6, 22));
    expect(ids, {'e1'});
  });
}
