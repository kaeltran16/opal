import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/correlations.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seeder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seeded data surfaces Sleep x Spending and Mood x Routine', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await Seeder(db).seedDemoData();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: kCorrelationWindowDays));
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));

    final entries = await EntryRepository(db).getEntriesInRange(start, end);
    final meals = await NutritionRepository(db).getMealsInRange(start, end);
    final nights = await SleepRepository(db).getNightsInRange(start, end);
    final moods = await MoodRepository(db).getCheckinsInRange(start, end);

    final v = buildDailyVectors(entries, meals, nights, moods, now: now);
    final surfaced = surfacedCorrelations(v);

    bool has(Dimension a, Dimension b) => surfaced.any((c) =>
        (c.a == a && c.b == b) || (c.a == b && c.b == a));
    expect(has(Dimension.sleep, Dimension.money), isTrue,
        reason: 'engineered seed should surface Sleep x Spending');
    expect(has(Dimension.mood, Dimension.rituals), isTrue,
        reason: 'engineered seed should surface Mood x Routine');
  });
}
