# Nutrition Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fifth top-level "Nutrition" tab — an AI-estimate food tracker (calorie ranges + confidence, no goals/counting) that turns takeout expenses into meals and surfaces cross-tracker connections.

**Architecture:** Mirrors the existing tracker stack end-to-end: a pure `NutritionMeal` domain model → a Drift `NutritionMeals` table (+ schema migration) → `NutritionRepository` (plain Dart, UUID-on-insert) → a Riverpod codegen controller exposing a computed `NutritionState` → dumb screens. AI calorie estimation is a new `PalService.estimateMeal` seam (mock + http, with graceful offline fallback). The takeout→meal "pending" card is **derived** from an unlinked food-category expense `Entry` (single source of truth — the spend lives in `Entries`, the meal links back via `linkedEntryId`). The `/you` (profile) tab is lifted out of the bottom-bar shell into a pushed route opened by a new Today-header avatar, freeing the fifth bar slot for Nutrition.

**Tech Stack:** Flutter, Drift (`drift`/`drift_flutter`, codegen via `build_runner`), Riverpod (`riverpod_annotation`, codegen), go_router (`StatefulShellRoute.indexedStack`), `uuid`.

## Global Constraints

- **Feature name is "Nutrition"** in both UI copy and code symbols (no "Nourish" anywhere). Classes `Nutrition*`, files `nutrition_*`, theme tokens `nutrition`/`nutritionTint`, route `/nutrition`.
- **Accent color (terracotta):** light `#E2553D`, dark `#F06A4D`. Tints: light 14% alpha, dark 18% alpha (matches the existing `money`/`move`/`rituals` tint convention).
- **No goals, no "remaining", no over-budget red.** Every number is an AI estimate shown as a **range** with a confidence level. Copy stays in the design's calm register ("how you've been eating", "rough guess / fair estimate / pretty sure").
- **Enums persist as their stable `.wire` string** (never `.name`/`.index`), parsed via `fromWire`.
- **Repositories take/return domain models only** — Drift row types never leak above the repository layer.
- **Caller-supplied ids**; repositories assign a UUID when `id` is empty.
- **Design tokens, not literals:** `Spacing.*`, `Radii.*`, `Elevation.*`, `AppType.*`/`AppFonts.sf|sfr`, `context.colors.*`. Inline literals only where the design uses an off-scale value (noted per task).
- **Git:** conventional commits (`type(scope): subject`), one commit per task, no co-author line, no push. The repo owner approves commits separately — steps stage + commit locally only.
- **Verify after each task:** `flutter analyze` clean for touched files; `flutter test` green.

### Design → Flutter token map (applies to every UI task)

| Design (JSX) | Flutter |
|---|---|
| `theme.nourish` / `theme.nourishTint` | `c.nutrition` / `c.nutritionTint` |
| `theme.ink/ink2/ink3/ink4/hair/fill/surface/bg/money/move/rituals` | `c.ink/...` (same names) |
| `SF` font family | `AppFonts.sf(size:, weight:, letterSpacing:, height:)` |
| `SFR` font family | `AppFonts.sfr(size:, weight:, ...)` (always tabular) |
| px `4/8/12/16/20/24/32` | `Spacing.xs/sm/md/lg/xl/xxl/xxxl` |
| radius `8/12/14/16/20/28` | `Radii.sm/md/card/lg/xl/xxl` (radius `18` → inline `18`, off-scale) |
| `onClick`/`cursor:pointer` button | `PressScale(onTap:)` or `GestureDetector` |
| SF symbol string | `AppIcon('name', size:, color:)` |

Source of truth for the screens is the Claude Design project `b14afff0-1260-4a1b-8de4-6a50fd32f9f5`, files `src/nutrition-data.jsx` (was `nourish-data`), `src/nourish-screens.jsx`, `src/nourish-add.jsx`, `src/components.jsx`. Port the named components 1:1 using the table above.

---

## File Structure

**New files**
- `lib/models/nutrition_meal.dart` — `NutritionMeal` immutable model + `IntRange` helper + `macrosFromCal`.
- `lib/data/repositories/nutrition_repository.dart` — CRUD + `addFromExpense` + unlinked-expense query.
- `lib/controllers/nutrition_controller.dart` (+ `.g.dart`) — `NutritionState`, `NutritionController`, `nutritionPatterns` helpers, `nutritionRepositoryProvider` (in `providers.dart`).
- `lib/screens/nutrition/nutrition_screen.dart` — landing (hero, pending, meals, week strip, connections).
- `lib/screens/nutrition/nutrition_meal_detail_screen.dart` — meal detail.
- `lib/screens/nutrition/nutrition_patterns_screen.dart` — connections list.
- `lib/screens/nutrition/nutrition_confirm_sheet.dart` — takeout→meal sheet.
- `lib/screens/nutrition/nutrition_add_sheet.dart` — add-by-hand sheet.
- `lib/screens/nutrition/widgets/nutrition_widgets.dart` — `ConfidenceChip`, `CalRange`, `MacroSplit`, `SourceTag`, `MealRow`, `SheetShell`, `ChipRow`.
- Test files mirroring the above under `test/`.

**Modified files**
- `lib/theme/app_colors.dart` — add `nutrition`/`nutritionTint` (field, factories, `copyWith`, `lerp`, `forType`).
- `lib/models/enums.dart` — add `NutritionSource`, `NutritionConfidence`.
- `lib/models/models.dart` — export `nutrition_meal.dart`.
- `lib/data/db/tables.dart` — add `NutritionMeals` table.
- `lib/data/db/database.dart` — register table, bump `schemaVersion` 7→8, migration.
- `lib/data/db/mappers.dart` — `NutritionMeal` ↔ row mappers.
- `lib/data/seed/seed_data.dart` + `lib/data/seed/seeder.dart` — seed 4 meals + 1 pending expense; marker bump.
- `lib/controllers/providers.dart` — `nutritionRepositoryProvider`.
- `lib/services/pal/pal_service.dart` — `MealEstimate` type + `estimateMeal` on the interface.
- `lib/services/pal/mock_pal_service.dart` — deterministic `estimateMeal`.
- `lib/services/pal/http_pal_service.dart` — `estimateMeal` over `/v1/nutrition/estimate` + offline fallback.
- `lib/widgets/app_icon.dart` — add `'pencil'` glyph.
- `lib/router.dart` — add `/nutrition` branch (+ `meal/:id`, `patterns`); lift `/you` to a top-level pushed route.
- `lib/screens/shell/loop_shell.dart` — `_tabIds` = today/move/nutrition/rituals.
- `lib/widgets/loop_tab_bar.dart` — tabs today/move/+FAB/nutrition/rituals (drop You).
- `lib/screens/today/today_screen.dart` — leading slot becomes a profile avatar → push You.
- `lib/screens/profile/profile_screen.dart` — add a back/Done leading action (now pushed, not a tab root).

---

## Task 1: Theme tokens (`nutrition` / `nutritionTint`)

**Files:**
- Modify: `lib/theme/app_colors.dart`
- Test: `test/theme/app_colors_test.dart` (create)

**Interfaces:**
- Produces: `AppColors.nutrition`, `AppColors.nutritionTint` (both `Color`); `AppColors.forType('nutrition') == nutrition`.

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/app_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  test('light/dark expose terracotta nutrition token', () {
    expect(AppColors.light(AppAccent.indigo).nutrition, const Color(0xFFE2553D));
    expect(AppColors.dark(AppAccent.indigo).nutrition, const Color(0xFFF06A4D));
  });

  test('forType routes nutrition + copyWith/lerp keep the token', () {
    final c = AppColors.light(AppAccent.indigo);
    expect(c.forType('nutrition'), c.nutrition);
    expect(c.copyWith(accent: const Color(0xFF000000)).nutrition, c.nutrition);
    final mixed = c.lerp(AppColors.dark(AppAccent.indigo), 1.0) as AppColors;
    expect(mixed.nutrition, const Color(0xFFF06A4D));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/app_colors_test.dart`
Expected: FAIL — `nutrition` getter not defined.

- [ ] **Step 3: Implement the token**

In `lib/theme/app_colors.dart`:
1. Add to the constructor (after `ritualsTint`): `required this.nutrition,` and `required this.nutritionTint,`.
2. Add fields near `rituals`: `final Color nutrition, nutritionTint;`
3. In `forType`, add a case before the default: `'nutrition' => nutrition,`
4. In `AppColors.light(...)` (after `ritualsTint`):

```dart
      nutrition: const Color(0xFFE2553D),
      nutritionTint: const Color.fromRGBO(226, 85, 61, 0.14),
```
5. In `AppColors.dark(...)`:

```dart
      nutrition: const Color(0xFFF06A4D),
      nutritionTint: const Color.fromRGBO(240, 106, 77, 0.18),
```
6. In `copyWith`, source both from `base` like the other tracker tokens:

```dart
      nutrition: base.nutrition, nutritionTint: base.nutritionTint,
```
7. In `lerp`, add: `nutrition: c(nutrition, other.nutrition), nutritionTint: c(nutritionTint, other.nutritionTint),`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/app_colors_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_colors.dart test/theme/app_colors_test.dart
git commit -m "feat(theme): add terracotta nutrition tracker token"
```

---

## Task 2: Enums + `NutritionMeal` model + `macrosFromCal`

**Files:**
- Modify: `lib/models/enums.dart`, `lib/models/models.dart`
- Create: `lib/models/nutrition_meal.dart`
- Test: `test/models/nutrition_meal_test.dart`

**Interfaces:**
- Produces:
  - `enum NutritionSource { home, takeout, manual }` with `.wire` + `fromWire` + `label` (`'home'|'takeout'|'by hand'`) + `icon` (`'leaf.fill'|'bag.fill'|'pencil'`).
  - `enum NutritionConfidence { low, med, high }` with `.wire` + `fromWire` + `label` (`'rough guess'|'fair estimate'|'pretty sure'`) + `bars` (`1|2|3`).
  - `class IntRange { final int lo, hi; const IntRange(this.lo, this.hi); int get mid => ((lo + hi) / 2).round(); }`
  - `class Macros { final IntRange protein, carbs, fat; }`
  - `class NutritionMeal { String id; DateTime timestamp; String slot; String name; NutritionSource source; String icon; NutritionConfidence confidence; IntRange cal; Macros macros; String? note; List<String> tags; String? linkedEntryId; ... copyWith, ==, hashCode }`
  - `Macros macrosFromCal(IntRange cal)` — protein 22%@4kcal/g, carbs 50%@4, fat 28%@9 (rounded).

- [ ] **Step 1: Write the failing test**

```dart
// test/models/nutrition_meal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';

void main() {
  test('IntRange mid rounds the midpoint', () {
    expect(const IntRange(290, 400).mid, 345);
  });

  test('enum wire round-trips', () {
    expect(NutritionSource.fromWire('takeout'), NutritionSource.takeout);
    expect(NutritionConfidence.fromWire('high').bars, 3);
    expect(NutritionConfidence.med.label, 'fair estimate');
  });

  test('macrosFromCal derives honest ranges', () {
    final m = macrosFromCal(const IntRange(400, 800));
    expect(m.protein.lo, 22); // 400*.22/4
    expect(m.carbs.hi, 100);  // 800*.50/4
    expect(m.fat.hi, 25);     // round(800*.28/9)
  });

  test('copyWith preserves untouched fields', () {
    final meal = NutritionMeal(
      id: 'm1', timestamp: DateTime(2026, 6, 21, 8), slot: 'Breakfast',
      name: 'Oats', source: NutritionSource.home, icon: 'leaf.fill',
      confidence: NutritionConfidence.high, cal: const IntRange(290, 400),
      macros: macrosFromCal(const IntRange(290, 400)), tags: const ['fiber-rich'],
    );
    expect(meal.copyWith(name: 'Oats & berries').tags, ['fiber-rich']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/nutrition_meal_test.dart`
Expected: FAIL — types undefined.

- [ ] **Step 3a: Add enums** to `lib/models/enums.dart`

```dart
/// Where a [NutritionMeal] came from. `takeout` meals are born from an expense.
enum NutritionSource {
  home('home', 'home', 'leaf.fill'),
  takeout('takeout', 'takeout', 'bag.fill'),
  manual('manual', 'by hand', 'pencil');

  const NutritionSource(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final String icon;

  static NutritionSource fromWire(String wire) =>
      values.firstWhere((e) => e.wire == wire);
}

/// How sure Pal is about a nutrition estimate. Drives the confidence chip.
enum NutritionConfidence {
  low('low', 'rough guess', 1),
  med('med', 'fair estimate', 2),
  high('high', 'pretty sure', 3);

  const NutritionConfidence(this.wire, this.label, this.bars);
  final String wire;
  final String label;
  final int bars;

  static NutritionConfidence fromWire(String wire) =>
      values.firstWhere((e) => e.wire == wire);
}
```

- [ ] **Step 3b: Create the model** `lib/models/nutrition_meal.dart`

```dart
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
```

- [ ] **Step 3c:** Add `export 'nutrition_meal.dart';` to `lib/models/models.dart` (alphabetical: after `goals.dart`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/nutrition_meal_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/ test/models/nutrition_meal_test.dart
git commit -m "feat(models): add NutritionMeal model + nutrition enums"
```

---

## Task 3: Drift table + migration + mappers

**Files:**
- Modify: `lib/data/db/tables.dart`, `lib/data/db/database.dart`, `lib/data/db/mappers.dart`
- Test: `test/data/nutrition_mapper_test.dart`

**Interfaces:**
- Consumes: `NutritionMeal`, `IntRange`, `Macros`, enums (Task 2).
- Produces: drift `NutritionMeals` table + generated `NutritionMealRow`/`NutritionMealsCompanion`; `NutritionMealRow.toModel()`, `NutritionMeal.toCompanion()`. `schemaVersion == 8`.

**Tags storage:** newline-joined string in a `tags` TEXT column (tags never contain newlines). Macros + cal stored as 8 INT columns (`calLo,calHi,proteinLo,proteinHi,carbsLo,carbsHi,fatLo,fatHi`).

- [ ] **Step 1: Add the table** to `lib/data/db/tables.dart`

```dart
/// AI-estimated meals/drinks for the Nutrition tracker. All amounts are ranges.
@DataClassName('NutritionMealRow')
class NutritionMeals extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get slot => text()();
  TextColumn get name => text()();

  /// [NutritionSource.wire].
  TextColumn get source => text()();
  TextColumn get icon => text()();

  /// [NutritionConfidence.wire].
  TextColumn get confidence => text()();

  IntColumn get calLo => integer()();
  IntColumn get calHi => integer()();
  IntColumn get proteinLo => integer()();
  IntColumn get proteinHi => integer()();
  IntColumn get carbsLo => integer()();
  IntColumn get carbsHi => integer()();
  IntColumn get fatLo => integer()();
  IntColumn get fatHi => integer()();

  TextColumn get note => text().nullable()();

  /// Newline-joined tag list ('' when none).
  TextColumn get tags => text().withDefault(const Constant(''))();

  /// FK to [Entries.id] for takeout meals (null otherwise).
  TextColumn get linkedEntryId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Register + migrate** in `lib/data/db/database.dart`
1. Add `NutritionMeals,` to the `@DriftDatabase(tables: [...])` list.
2. Change `int get schemaVersion => 7;` to `8`.
3. Add a comment line to the migration doc-block: `// v7 -> v8: new nutrition_meals table backs the Nutrition tracker. Brand-new table; creating it leaves existing data untouched; the seeder (marker bump) populates demo meals.`
4. Add to `onUpgrade`, after the `if (from < 7)` block:

```dart
          if (from < 8) {
            await m.createTable(nutritionMeals);
          }
```

- [ ] **Step 3: Add mappers** to `lib/data/db/mappers.dart`

```dart
// ---------------------------------------------------------------------------
// NutritionMeal
// ---------------------------------------------------------------------------

extension NutritionMealRowMapper on NutritionMealRow {
  NutritionMeal toModel() => NutritionMeal(
        id: id,
        timestamp: timestamp,
        slot: slot,
        name: name,
        source: NutritionSource.fromWire(source),
        icon: icon,
        confidence: NutritionConfidence.fromWire(confidence),
        cal: IntRange(calLo, calHi),
        macros: Macros(
          protein: IntRange(proteinLo, proteinHi),
          carbs: IntRange(carbsLo, carbsHi),
          fat: IntRange(fatLo, fatHi),
        ),
        note: note,
        tags: tags.isEmpty ? const [] : tags.split('\n'),
        linkedEntryId: linkedEntryId,
      );
}

extension NutritionMealModelMapper on NutritionMeal {
  NutritionMealsCompanion toCompanion() => NutritionMealsCompanion(
        id: Value(id),
        timestamp: Value(timestamp),
        slot: Value(slot),
        name: Value(name),
        source: Value(source.wire),
        icon: Value(icon),
        confidence: Value(confidence.wire),
        calLo: Value(cal.lo),
        calHi: Value(cal.hi),
        proteinLo: Value(macros.protein.lo),
        proteinHi: Value(macros.protein.hi),
        carbsLo: Value(macros.carbs.lo),
        carbsHi: Value(macros.carbs.hi),
        fatLo: Value(macros.fat.lo),
        fatHi: Value(macros.fat.hi),
        note: Value(note),
        tags: Value(tags.join('\n')),
        linkedEntryId: Value(linkedEntryId),
      );
}
```

- [ ] **Step 4: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `database.g.dart` with `NutritionMealRow`, `NutritionMealsCompanion`, `db.nutritionMeals`. No errors.

- [ ] **Step 5: Write + run the round-trip test**

```dart
// test/data/nutrition_mapper_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/db/mappers.dart';
import 'package:opal/models/models.dart';

void main() {
  test('NutritionMeal survives a DB round-trip', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final meal = NutritionMeal(
      id: 'm1', timestamp: DateTime(2026, 6, 21, 12, 40), slot: 'Lunch',
      name: 'Turkey sandwich', source: NutritionSource.takeout, icon: 'fork.knife',
      confidence: NutritionConfidence.med, cal: const IntRange(560, 820),
      macros: macrosFromCal(const IntRange(560, 820)),
      note: 'estimated from Tartine order', tags: const ['from expense', 'high-carb'],
      linkedEntryId: 'e1',
    );
    await db.into(db.nutritionMeals).insert(meal.toCompanion());
    final row = await db.select(db.nutritionMeals).getSingle();
    expect(row.toModel(), meal);
    await db.close();
  });
}
```

Run: `flutter test test/data/nutrition_mapper_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/db/ test/data/nutrition_mapper_test.dart
git commit -m "feat(db): add nutrition_meals table, migration v8, mappers"
```

---

## Task 4: `NutritionRepository` + provider

**Files:**
- Create: `lib/data/repositories/nutrition_repository.dart`
- Modify: `lib/data/repositories/repositories.dart` (export), `lib/controllers/providers.dart` (provider)
- Test: `test/data/nutrition_repository_test.dart`

**Interfaces:**
- Consumes: `LoopDatabase`, `NutritionMeal`, `EntryRepository`'s `Entry`.
- Produces:
  - `class NutritionRepository(LoopDatabase, {Uuid?})` with:
    - `Stream<List<NutritionMeal>> watchMealsForDay([DateTime? day])` — ascending by timestamp.
    - `Stream<List<NutritionMeal>> watchMealsInRange(DateTime from, DateTime to)`
    - `Future<List<NutritionMeal>> getMealsInRange(DateTime from, DateTime to)`
    - `Future<String> insert(NutritionMeal)` — UUID if empty.
    - `Future<void> upsert(NutritionMeal)`
    - `Future<void> deleteById(String id)`
    - `Future<Set<String>> linkedEntryIds(DateTime from, DateTime to)` — entry ids already turned into meals (for pending derivation).
  - `nutritionRepositoryProvider` (keepAlive) in `providers.dart`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/nutrition_repository_test.dart
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/nutrition_repository_test.dart`
Expected: FAIL — repository undefined.

- [ ] **Step 3: Implement** `lib/data/repositories/nutrition_repository.dart`

```dart
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
```

- [ ] **Step 4:** Add `export 'nutrition_repository.dart';` to `lib/data/repositories/repositories.dart`. Add to `lib/controllers/providers.dart` (after `budgetEnvelopeRepository`):

```dart
@Riverpod(keepAlive: true)
NutritionRepository nutritionRepository(Ref ref) =>
    NutritionRepository(ref.watch(loopDatabaseProvider));
```

- [ ] **Step 5: Run codegen + test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/data/nutrition_repository_test.dart`
Expected: provider generated; tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/ lib/controllers/providers.dart lib/controllers/providers.g.dart test/data/nutrition_repository_test.dart
git commit -m "feat(data): add NutritionRepository + provider"
```

---

## Task 5: Seed demo meals + pending expense

**Files:**
- Modify: `lib/data/seed/seed_data.dart`, `lib/data/seed/seeder.dart`
- Test: `test/data/nutrition_seed_test.dart`

**Interfaces:**
- Consumes: `NutritionRepository`, `EntryRepository`.
- Produces: `SeedData.nutritionMeals()` → 4 `NutritionMeal`s (the design's m1–m4, **today** at 07:50/08:30/12:40/19:10); one extra food expense `Entry` (`id:'seed-nutrition-pending'`, Thai Basil, `-24.80`, category `'Dining'`, detail `'DoorDash'`, today 20:15) appended in `SeedData.entries()`. m2/m3 carry `linkedEntryId` to existing seed coffee/lunch expenses if present, else null. Seeder writes meals; marker bumped to `initial_seed_v7`.

> **Dates:** seed meals must land **today** so the landing isn't empty. Use the existing helper the other seeds use for "today" (check `seed_data.dart` for a `now`/`today` anchor; reuse it — do **not** introduce a second clock).

- [ ] **Step 1: Inspect** `lib/data/seed/seed_data.dart` to find the existing "today" anchor and the entry-id naming pattern; reuse them.

- [ ] **Step 2: Write the failing test**

```dart
// test/data/nutrition_seed_test.dart
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
```

- [ ] **Step 3:** Add `SeedData.nutritionMeals()` (4 meals per the design's m1–m4; cal/macros/tags/source/icon/confidence verbatim), append the Thai Basil expense to `SeedData.entries()`, and in `seeder.dart` add a meals loop (`insertOrReplace`) and bump `_markerKey` to `'initial_seed_v7'`.

```dart
// in seeder.dart, before the marker write:
for (final meal in SeedData.nutritionMeals()) {
  await _db.into(_db.nutritionMeals).insert(meal.toCompanion(), mode: replace);
}
```

- [ ] **Step 4: Run test**

Run: `flutter test test/data/nutrition_seed_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/seed/ test/data/nutrition_seed_test.dart
git commit -m "feat(seed): seed nutrition meals + a pending takeout expense"
```

**CHECKPOINT — data layer:** run `dart run build_runner build --delete-conflicting-outputs`, then `flutter analyze` and `flutter test`. Both must be clean before UI work begins.

---

## Task 6: `PalService.estimateMeal` (interface + mock + http)

**Files:**
- Modify: `lib/services/pal/pal_service.dart`, `lib/services/pal/mock_pal_service.dart`, `lib/services/pal/http_pal_service.dart`
- Test: `test/services/mock_estimate_meal_test.dart`

**Interfaces:**
- Produces:
  - `class MealEstimate { final String name; final IntRange cal; final NutritionConfidence confidence; const MealEstimate({...}); Macros get macros => macrosFromCal(cal); }`
  - `Future<MealEstimate> estimateMeal(String description)` on `PalService`.
- Mock: deterministic by keyword — salad/yogurt/banana → low band, sandwich/pasta/rice/burrito → high band, else mid band; `name` = title-cased description; confidence med (low for empty/very short).
- Http: `POST /v1/nutrition/estimate {text}` → `{name, calLo, calHi, confidence}`; on any `PalException`/parse failure, **fall back** to the same deterministic local estimate so offline still works (matches the design's offline path).

- [ ] **Step 1: Add to the interface** (`pal_service.dart`)

Add the `MealEstimate` class near the other DTOs (it can use `IntRange`/`Macros`/`NutritionConfidence` — `models.dart` is already imported), and add to `abstract interface class PalService`:

```dart
  /// `/nutrition/estimate`: estimate a calorie RANGE + confidence for a
  /// free-text meal [description]. Powers the "Add a meal" sheet.
  Future<MealEstimate> estimateMeal(String description);
```

- [ ] **Step 2: Write the failing mock test**

```dart
// test/services/mock_estimate_meal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/mock_pal_service.dart';

void main() {
  test('estimateMeal returns a sane range + confidence', () async {
    final pal = MockPalService(latency: Duration.zero);
    final e = await pal.estimateMeal('chicken & rice bowl');
    expect(e.cal.lo, lessThan(e.cal.hi));
    expect(e.name, isNotEmpty);
    expect(NutritionConfidence.values, contains(e.confidence));
    expect(e.macros.protein.lo, greaterThan(0));
  });
}
```

- [ ] **Step 3: Implement in mock** (`mock_pal_service.dart`) — reuse `_titleCase`:

```dart
  @override
  Future<MealEstimate> estimateMeal(String description) async {
    await Future<void>.delayed(latency);
    return _localEstimate(description);
  }

  static MealEstimate localEstimate(String description) {
    final lower = description.toLowerCase();
    final (IntRange cal, NutritionConfidence conf) = switch (lower) {
      _ when lower.trim().length < 3 => (const IntRange(150, 350), NutritionConfidence.low),
      _ when RegExp(r'salad|yogurt|banana|fruit|snack').hasMatch(lower) =>
        (const IntRange(120, 320), NutritionConfidence.med),
      _ when RegExp(r'sandwich|pasta|rice|burrito|burger|pizza|noodle').hasMatch(lower) =>
        (const IntRange(520, 820), NutritionConfidence.med),
      _ => (const IntRange(300, 560), NutritionConfidence.low),
    };
    return MealEstimate(
      name: _titleCaseStatic(description.trim().isEmpty ? 'Meal' : description.trim()),
      cal: cal,
      confidence: conf,
    );
  }

  MealEstimate _localEstimate(String d) => localEstimate(d);
```

(Promote `_titleCase` to a static `_titleCaseStatic` or duplicate the 3-line helper; keep DRY by having the instance method delegate.)

- [ ] **Step 4: Implement in http** (`http_pal_service.dart`):

```dart
  @override
  Future<MealEstimate> estimateMeal(String description) async {
    try {
      final json = await _post('/v1/nutrition/estimate', {'text': description});
      final lo = (json['calLo'] as num?)?.round();
      final hi = (json['calHi'] as num?)?.round();
      if (lo == null || hi == null) return MockPalService.localEstimate(description);
      return MealEstimate(
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name'] as String
            : description.trim(),
        cal: IntRange(lo, hi < lo ? lo : hi),
        confidence: _confidenceFromWire(json['confidence'] as String?),
      );
    } on PalException {
      return MockPalService.localEstimate(description); // graceful offline fallback
    }
  }

  NutritionConfidence _confidenceFromWire(String? w) => switch (w) {
        'high' => NutritionConfidence.high,
        'med' => NutritionConfidence.med,
        _ => NutritionConfidence.low,
      };
```

Add `import 'mock_pal_service.dart';` to `http_pal_service.dart`.

- [ ] **Step 5: Run test**

Run: `flutter test test/services/mock_estimate_meal_test.dart`
Expected: PASS. Also `flutter analyze lib/services/pal` clean (every `PalService` impl now satisfies the interface).

- [ ] **Step 6: Commit**

```bash
git add lib/services/pal/ test/services/mock_estimate_meal_test.dart
git commit -m "feat(pal): add estimateMeal seam (mock + http with offline fallback)"
```

---

## Task 7: `NutritionController` + `NutritionState`

**Files:**
- Create: `lib/controllers/nutrition_controller.dart` (+ generated `.g.dart`)
- Test: `test/controllers/nutrition_controller_test.dart`

**Interfaces:**
- Consumes: `nutritionRepositoryProvider`, `entryRepositoryProvider`, `palServiceProvider`, `hapticsServiceProvider`.
- Produces:
  - `class NutritionPending { final Entry expense; final MealEstimate guess; }`
  - `class NutritionDay { final IntRange cal; final Macros macros; final int meals, takeout, home; final String feel, note; }`
  - `class NutritionWeekDay { final String day; final int date; final double? load; final int takeout, home; final bool today; }`
  - `class NutritionPattern { final String tracker; final String icon; final String title; final String body; final List<int> spark; final List<int> emph; }`
  - `class NutritionState { final List<NutritionMeal> meals; final NutritionDay day; final List<NutritionWeekDay> week; final NutritionPending? pending; final List<NutritionPattern> patterns; }`
  - `NutritionController extends _$NutritionController` → `Stream<NutritionState> build()`; methods `addManualMeal(...)`, `confirmFromExpense(Entry, MealEstimate, {String name, String portion})`, `deleteMeal(String id)`, `Future<MealEstimate> estimateFor(String description)`.
- Rollups: `day.cal = IntRange(sum lo, sum hi)`; macros summed component-wise; `feel`/`note` qualitative from the mid (`< 1500` → 'lighter day', `> 2200` → 'fuller day', else 'balanced day'; note 'leaning carb-heavy' when carbs-mid kcal share > 0.5). Week `load` = day cal-mid normalized to the week max (future days `null`). Pending = the most recent food-category (`Dining|Coffee|Groceries|Takeout`) expense **today** whose id ∉ `linkedEntryIds`, paired with `palService.estimateMeal('<title> takeout')`.

- [ ] **Step 1: Write the failing test** (uses in-memory DB + `MockPalService`, overriding the repo/pal providers)

```dart
// test/controllers/nutrition_controller_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  test('day rollup sums calorie + macro ranges across today\'s meals', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(MockPalService(latency: Duration.zero)),
    ]);
    addTearDown(() { container.dispose(); db.close(); });

    final now = DateTime.now();
    final repo = container.read(nutritionRepositoryProvider);
    await repo.insert(NutritionMeal(
      id: '', timestamp: DateTime(now.year, now.month, now.day, 8), slot: 'Breakfast',
      name: 'Oats', source: NutritionSource.home, icon: 'leaf.fill',
      confidence: NutritionConfidence.high, cal: const IntRange(300, 400),
      macros: macrosFromCal(const IntRange(300, 400))));
    await repo.insert(NutritionMeal(
      id: '', timestamp: DateTime(now.year, now.month, now.day, 13), slot: 'Lunch',
      name: 'Bowl', source: NutritionSource.home, icon: 'leaf.fill',
      confidence: NutritionConfidence.med, cal: const IntRange(500, 700),
      macros: macrosFromCal(const IntRange(500, 700))));

    final state = await container.read(nutritionControllerProvider.future);
    expect(state.day.cal.lo, 800);
    expect(state.day.cal.hi, 1100);
    expect(state.day.meals, 2);
    expect(state.day.home, 2);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/controllers/nutrition_controller_test.dart`
Expected: FAIL — controller undefined.

- [ ] **Step 3: Implement** `lib/controllers/nutrition_controller.dart` per the Interfaces block. Stream pattern mirrors `RitualsController`: `await for (final meals in repo.watchMealsForDay())`, compute rollups, derive pending (read today's entries once per tick + `linkedEntryIds`, call `palService.estimateMeal` for the single unlinked food expense), build the week strip from `repo.getMealsInRange(weekStart, weekStart+7d)`, assemble `patterns` (compute the takeout-vs-home cost headline from this week's money entries; the other three are curated copy with sparkline demo data — add a `// first-pass: qualitative bodies; headline numbers are real` comment). Write methods:
  - `addManualMeal({required String slot, required String name, required MealEstimate est})` → `repo.insert(NutritionMeal(... source: manual, macros: est.macros ...))` + light haptic.
  - `confirmFromExpense(Entry e, MealEstimate guess, {required String name, required String portion})` → scale `guess.cal`/macros by portion factor (`Lighter` 0.78 / `As shown` 1 / `Larger` 1.25), `repo.insert(NutritionMeal(... source: takeout, linkedEntryId: e.id, timestamp: e.timestamp ...))`.
  - `deleteMeal(String id)` → `repo.deleteById`.
  - `Future<MealEstimate> estimateFor(String d)` → `ref.read(palServiceProvider).estimateMeal(d)`.

- [ ] **Step 4: Run codegen + test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/controllers/nutrition_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/controllers/nutrition_controller.dart lib/controllers/nutrition_controller.g.dart test/controllers/nutrition_controller_test.dart
git commit -m "feat(nutrition): add NutritionController with day/week/pattern rollups"
```

---

## Task 8: Shared Nutrition widgets

**Files:**
- Create: `lib/screens/nutrition/widgets/nutrition_widgets.dart`
- Modify: `lib/widgets/app_icon.dart` (add `'pencil'`)
- Test: `test/screens/nutrition_widgets_test.dart`

**Interfaces:**
- Produces (all take `AppColors c` or read `context.colors`): `ConfidenceChip(level, {plain})`, `CalRange(range, {size, light})`, `MacroSplit(macros, {light})`, `SourceTag(source)`, `MealRow(meal, {last, onTap})`, `SheetShell({title, onClose, primaryLabel, onPrimary, primaryEnabled, child})`, `ChipRow(options, value, onChange)`.

- [ ] **Step 1:** Add `'pencil': CupertinoIcons.pencil,` to the `_sfMap` in `lib/widgets/app_icon.dart`.

- [ ] **Step 2: Implement the widgets** porting the JSX (`ConfidenceChip`, `CalRange`, `MacroSplit`, `SourceTag`, `MealRow` from `nourish-screens.jsx`; `SheetShell`, `ChipRow` from `nourish-add.jsx`) using the token map. Key specs:
  - **CalRange:** a `Row` baseline-aligned — `≈` (AppFonts.sfr, size*0.42, ink3/white72), mid (AppFonts.sfr, size, 700, ink/white, `height: 0.95`), `cal` (AppFonts.sf, size*0.32, 600). Sub-line `"{lo}–{hi} estimated"` (AppFonts.sf 12.5). `mid = (range.lo+range.hi)/2` rounded to nearest 10.
  - **MacroSplit:** a 8px-tall rounded `Row` of 3 segments (`flex` ∝ each macro mid; colors nutrition / nutrition@60% / nutrition@30%, or white tiers when `light`), 2px gaps; legend row with 7×7 swatch, uppercase label, and `"{lo}–{hi}g"` value (AppFonts.sfr 14).
  - **ConfidenceChip:** 3 ascending bars (`4 + i*3` px tall, filled `nutrition` if `i < bars` else `nutrition@20%`) + label; `plain` drops the tinted pill background.
  - **MealRow:** time (38px, tabular) · 32px nutritionTint icon tile · name + (`slot · SourceTag`) · right column `"{lo}–{hi}"` (AppFonts.sfr) over a plain `ConfidenceChip`. Wrap in `PressScale(onTap:)`. Hairline divider unless `last`.
  - **SheetShell:** `Stack` over a scrim (`GestureDetector` → `onClose`) + a bottom sheet (`Radii` top corners, `slideUp` via `TweenAnimationBuilder` translateY). Sticky header row: Cancel (nutrition) · centered title · primary action (nutrition, disabled→ink4). Use this instead of porting the CSS `position:sticky`.
  - **ChipRow:** wrap of pill buttons; active = `nutrition` bg / white text, else `surface` / ink.

- [ ] **Step 3: Write + run a render smoke test**

```dart
// test/screens/nutrition_widgets_test.dart  (pump each widget inside a themed MaterialApp; assert it builds and shows expected text)
// e.g. CalRange(const IntRange(560, 820)) shows '560–820 estimated' and '690'.
```

Run: `flutter test test/screens/nutrition_widgets_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/nutrition/widgets/ lib/widgets/app_icon.dart test/screens/nutrition_widgets_test.dart
git commit -m "feat(nutrition): shared widgets (CalRange, MacroSplit, ConfidenceChip, MealRow, sheet shell)"
```

---

## Task 9: Navigation — Nutrition branch, tab bar, You relocation

**Files:**
- Modify: `lib/router.dart`, `lib/screens/shell/loop_shell.dart`, `lib/widgets/loop_tab_bar.dart`, `lib/screens/today/today_screen.dart`, `lib/screens/profile/profile_screen.dart`
- Create (temporary stub): `lib/screens/nutrition/nutrition_screen.dart` returning a `PlaceholderScreen(label: 'Nutrition')` so routes compile (replaced in Task 10).
- Test: `test/navigation/nutrition_nav_test.dart`

**Interfaces:**
- Produces: `AppRoute.nutrition` (`'/nutrition'`), `AppRoute.nutritionMeal` (`'meal/:id'`), `AppRoute.nutritionPatterns` (`'patterns'`); `/you` becomes a top-level pushed route (still `AppRoute.you`, path `/you`, sub-routes unchanged).

- [ ] **Step 1: Router.** In `lib/router.dart`:
  1. Add enum values: `nutrition('nutrition', '/nutrition')`, `nutritionMeal('nutritionMeal', 'meal/:id')`, `nutritionPatterns('nutritionPatterns', 'patterns')`.
  2. Add a new `StatefulShellBranch` (with a `_nutritionNavigatorKey`) **between the Move and Rituals branches** — order must be `today, move, nutrition, rituals`:

```dart
          StatefulShellBranch(
            navigatorKey: _nutritionNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.nutrition.path,
                name: AppRoute.nutrition.name,
                builder: (context, state) => const NutritionScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.nutritionMeal.path,
                    name: AppRoute.nutritionMeal.name,
                    builder: (context, state) =>
                        NutritionMealDetailScreen(mealId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: AppRoute.nutritionPatterns.path,
                    name: AppRoute.nutritionPatterns.name,
                    builder: (context, state) => const NutritionPatternsScreen(),
                  ),
                ],
              ),
            ],
          ),
```
  3. **Remove** the `you` `StatefulShellBranch` and re-add `/you` (with its existing sub-routes verbatim) as a top-level `GoRoute` in the root `routes:` list (sibling of the `StatefulShellRoute`, like `onboarding`/`palComposer`). Delete the now-unused `_youNavigatorKey`.
  4. Add a stub import for `NutritionMealDetailScreen`/`NutritionPatternsScreen` (created in Tasks 11–12; for this task, temporarily point all three at the `NutritionScreen` placeholder or create empty stubs — note this and replace in later tasks).

- [ ] **Step 2: Shell.** In `loop_shell.dart`, change `_tabIds` to `['today', 'move', 'nutrition', 'rituals']`.

- [ ] **Step 3: Tab bar.** In `loop_tab_bar.dart`, set `_tabs` to:

```dart
const _tabs = [
  LoopTab('today', 'Today', 'house.fill'),
  LoopTab('move', 'Workout', 'figure.run'),
  LoopTab('add', '', 'plus'),
  LoopTab('nutrition', 'Nutrition', 'leaf.fill'),
  LoopTab('rituals', 'Rituals', 'sparkles'),
];
```

- [ ] **Step 4: Today avatar.** In `today_screen.dart`, replace the `leading:` month-abbrev `Text(...)` with a profile avatar that pushes You:

```dart
      leading: PressScale(
        semanticLabel: 'You',
        onTap: () => context.pushNamed(AppRoute.you.name),
        child: SizedBox(
          width: 44, height: 44,
          child: Center(child: AppIcon('person.crop.circle.fill', size: 30, color: c.accent)),
        ),
      ),
```
(Drop the `_monthAbbrev()` helper if now unused; the date already shows in the subtitle.)

- [ ] **Step 5: Profile back action.** In `profile_screen.dart`, add a leading `NavAction(icon: 'chevron.left', label: 'Today', onTap: () => context.pop())` (or `NavIconButton`) to the screen's `LargeTitleScrollView`, since it's now pushed rather than a tab root.

- [ ] **Step 6: Write + run the nav test** (a widget test driving the router):

```dart
// test/navigation/nutrition_nav_test.dart
// Pump the app with overridden providers (in-memory DB + MockPalService), tap the
// Nutrition tab, expect a Nutrition title; tap the Today avatar, expect the You screen.
```

Run: `flutter test test/navigation/nutrition_nav_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/router.dart lib/screens/shell/loop_shell.dart lib/widgets/loop_tab_bar.dart lib/screens/today/today_screen.dart lib/screens/profile/profile_screen.dart lib/screens/nutrition/nutrition_screen.dart test/navigation/nutrition_nav_test.dart
git commit -m "feat(nav): add Nutrition tab branch; move You off the bar to a pushed route"
```

---

## Task 10: Nutrition landing screen

**Files:**
- Replace stub: `lib/screens/nutrition/nutrition_screen.dart`
- Test: `test/screens/nutrition_screen_test.dart`

**Interfaces:**
- Consumes: `nutritionControllerProvider` (`AsyncValue<NutritionState>`), shared widgets (Task 8), `NutritionConfirmSheet`/`NutritionAddSheet` (Task 13 — guard with a stub call until then).
- Produces: `class NutritionScreen extends ConsumerWidget`.

- [ ] **Step 1: Implement** porting `NourishTabScreen` (`nourish-screens.jsx`) with `LargeTitleScrollView(title: 'Nutrition', subtitle: "how you've been eating", trailing: <plus button → showNutritionAddSheet>)`. Sections in order:
  1. **Today hero** — terracotta gradient `Container` (mirror the `_UpNextHero` gradient/blob/`Elevation` pattern from `rituals_screen.dart`, tone = `c.nutrition`): eyebrow "TODAY", `CalRange(state.day.cal, size: 42, light: true)`, a `feel` pill, divider, `MacroSplit(state.day.macros, light: true)`, meta line `"{meals} meals · {takeout} takeout, {home} home · {note}"`.
  2. **Pending card** (if `state.pending != null`) — bordered `nutrition@40%` card; eyebrow "AN EXPENSE LOOKS LIKE A MEAL"; bag tile + `pending.guess.name` + `"{merchant} · ${amount} · {time}"` + an "Add meal" pill → opens `NutritionConfirmSheet(expense, guess)`.
  3. **Meals** — section title "Meals" + weekday; `InsetSection`-style card of `MealRow`s → `context.pushNamed(nutritionMeal, pathParameters: {'id': m.id})`.
  4. **This week** — surface card; 7 bars (`state.week`), future days a dashed box (reuse `DottedBorderBox`), today bar solid `nutrition` else `nutrition@30%`, a takeout dot above bars with `takeout > 0`; footer "dot marks a takeout day".
  5. **Connections** — section title; a featured Pal card (gradient `nutrition→money` dot, "PAL NOTICED", the takeout headline sentence) → `onOpenPal`; then a "See all patterns" row → `context.pushNamed(nutritionPatterns)`.
  - Use `async.when(loading/error/data:)` like `RitualsScreen`.
  - `onOpenPal(seed)` → `context.pushNamed(AppRoute.palComposer.name)` (the composer is the existing Pal entry; pass no seed for now — matches how other screens open it).

- [ ] **Step 2: Write + run a smoke test** — pump the app (overridden in-memory DB seeded via `Seeder`, `MockPalService`), navigate to `/nutrition`, expect "Nutrition", the seeded meal names, and "This week".

Run: `flutter test test/screens/nutrition_screen_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/nutrition/nutrition_screen.dart test/screens/nutrition_screen_test.dart
git commit -m "feat(nutrition): landing screen (hero, pending, meals, week, connections)"
```

---

## Task 11: Meal detail screen

**Files:**
- Create: `lib/screens/nutrition/nutrition_meal_detail_screen.dart`
- Test: `test/screens/nutrition_meal_detail_test.dart`

**Interfaces:**
- Consumes: `nutritionControllerProvider` (find meal by id), shared widgets.
- Produces: `class NutritionMealDetailScreen extends ConsumerWidget { final String mealId; }`.

- [ ] **Step 1: Implement** porting `NourishMealDetailScreen`: back button ("‹ Nutrition" → `context.pop()`); `SourceTag` + `slot · time`; large title `name` + `note`; estimate hero card (`CalRange(meal.cal, size: 40)` + `ConfidenceChip(meal.confidence)` + `MacroSplit(meal.macros)` + a Pal note line); tags wrap; an `InsetSection`("Where this came from") with the linked expense row (or "Added by hand"); a `move`-tinted connection card; an "Adjust estimate" button (→ opens `NutritionAddSheet` prefilled — or, until Task 13, opens the add sheet) + a "Remove" button (→ `controller.deleteMeal(id)` then `context.pop()`). If the meal id isn't found, show a centered "Meal not found" and a back affordance.

- [ ] **Step 2: Write + run smoke test** (pump seeded app, push `/nutrition/meal/<seededId>`, expect the meal name + "estimated").

Run: `flutter test test/screens/nutrition_meal_detail_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/nutrition/nutrition_meal_detail_screen.dart test/screens/nutrition_meal_detail_test.dart
git commit -m "feat(nutrition): meal detail screen"
```

---

## Task 12: Patterns (Connections) screen

**Files:**
- Create: `lib/screens/nutrition/nutrition_patterns_screen.dart`
- Test: `test/screens/nutrition_patterns_test.dart`

**Interfaces:**
- Consumes: `nutritionControllerProvider` (`state.patterns`).
- Produces: `class NutritionPatternsScreen extends ConsumerWidget`.

- [ ] **Step 1: Implement** porting `NourishPatternsScreen`: back button; large title "Connections" + sub "how eating ties to the rest of your day"; a column of pattern cards. Each card: two square dots (`nutrition` + `c.forType(p.tracker)`), eyebrow `"NUTRITION × {trackerLabel(p.tracker)}"`, the tracker glyph, title + body, and a right-aligned sparkline (bars `height ∝ v/max`, `emph` indices full `c.forType(tracker)` else 40% — render with a `Row` of `Container`s or a tiny `CustomPaint`). Card tap → `onOpenPal` (push palComposer). Add a private `String _trackerLabel(String t)` → Money/Workout/Rituals/Nutrition.

- [ ] **Step 2: Write + run smoke test** (push `/nutrition/patterns`, expect "Connections" + ≥1 pattern title).

Run: `flutter test test/screens/nutrition_patterns_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/nutrition/nutrition_patterns_screen.dart test/screens/nutrition_patterns_test.dart
git commit -m "feat(nutrition): connections (patterns) screen"
```

---

## Task 13: Add + Confirm sheets

**Files:**
- Create: `lib/screens/nutrition/nutrition_add_sheet.dart`, `lib/screens/nutrition/nutrition_confirm_sheet.dart`
- Modify: `lib/screens/nutrition/nutrition_screen.dart` + `..._meal_detail_screen.dart` to open them (replace any Task 10/11 stubs).
- Test: `test/screens/nutrition_sheets_test.dart`

**Interfaces:**
- Produces:
  - `Future<void> showNutritionAddSheet(BuildContext, WidgetRef)` and `showNutritionConfirmSheet(BuildContext, WidgetRef, {required Entry expense, required MealEstimate guess})` (or stateful sheet widgets shown via `showModalBottomSheet` / inserted into the device `Stack` with `SheetShell`).
  - On save, call `NutritionController.addManualMeal(...)` / `confirmFromExpense(...)`.

- [ ] **Step 1: Implement `NutritionAddSheet`** porting `NourishAddSheet`: slot `ChipRow` (`['Breakfast','Lunch','Dinner','Snack','Drink']`); a "What did you eat?" text field + "Estimate" button → `ref.read(nutritionControllerProvider.notifier).estimateFor(text)` (loading state + offline-safe hint); when an estimate exists, show an editable name + `CalRange`+`ConfidenceChip`+`MacroSplit` preview; else a 2-col grid of quick picks (`NUTRITION_QUICK` from the design: Greek yogurt & granola 240–320, Eggs & toast 320–440, Chicken & rice bowl 520–680, Side salad 120–220, Banana 90–120, Protein shake 160–240) that prefill via `macrosFromCal`. Save → `addManualMeal` → close.

- [ ] **Step 2: Implement `NutritionConfirmSheet`** porting `NourishConfirmSheet`: a "From your spending" row (money tile, merchant, channel·card·time, amount); editable name seeded from `guess.name`; a Portion `ChipRow` (`Lighter / As shown / Larger`) that live-scales `CalRange`+`MacroSplit` by `0.78/1/1.25`; a "Not a meal — keep as expense only" text button (→ close, no write). Save → `confirmFromExpense(expense, guess, name: ..., portion: ...)` → close.

- [ ] **Step 3:** Wire the landing's plus button + pending card + the detail "Adjust" button to these.

- [ ] **Step 4: Write + run smoke test** — open the add sheet (tap +), tap a quick pick, tap Save; assert a new meal appears (meal count rises / new name visible).

Run: `flutter test test/screens/nutrition_sheets_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/nutrition/ test/screens/nutrition_sheets_test.dart
git commit -m "feat(nutrition): add-by-hand + takeout-to-meal sheets"
```

---

## Task 14: Full verification

**Files:** none (verification only).

- [ ] **Step 1:** `dart run build_runner build --delete-conflicting-outputs` — clean.
- [ ] **Step 2:** `flutter analyze` — zero issues across the repo.
- [ ] **Step 3:** `flutter test` — all green (note any pre-existing unrelated failures explicitly; do not mark complete if a Nutrition test is red or skipped).
- [ ] **Step 4:** `flutter run -d <device/chrome>` — confirm: Nutrition tab appears (leaf glyph, 4th slot), landing renders hero + seeded meals + week + connections, a meal opens detail, the + sheet estimates + saves, the pending card opens the confirm sheet, the Today avatar opens You and back returns to Today.
- [ ] **Step 5:** Final review commit if any doc/cleanup remains:

```bash
git add -A
git commit -m "chore(nutrition): final cleanup + verification"
```

---

## Self-Review notes

- **Spec coverage:** hero/ranges/confidence (T8/T10), pending takeout→meal (T5 seed, T7 derive, T13 confirm), meals list + detail (T10/T11), week strip (T7/T10), connections (T7/T12), add-by-hand + AI estimate (T6/T13), terracotta accent (T1), Nutrition tab + You relocation (T9). All design screens 31–35 map to a task.
- **Type consistency:** `IntRange`/`Macros`/`MealEstimate`/`NutritionConfidence` defined once (T2/T6) and reused; `forType('nutrition')` (T1) consumed by T8/T12; `linkedEntryId` (T2/T3) drives pending (T4/T7).
- **Known first-pass scope (flagged, not hidden):** three of the four connection patterns use curated qualitative bodies with demo sparkline data; only the takeout-vs-home cost headline is computed from real entries (T7). Deeper cross-tracker analytics are a follow-up. The "Adjust estimate" action reuses the add sheet rather than a dedicated editor.
