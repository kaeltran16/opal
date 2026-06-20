import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';

void main() {
  test('seeding populates nutrition meals', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    final meals = await db.select(db.nutritionMeals).get();
    expect(meals.length, greaterThanOrEqualTo(4));
    await db.close();
  });
}
