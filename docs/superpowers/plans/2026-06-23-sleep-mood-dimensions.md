# Sleep & Mood Dimensions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two fully-wired dimensions — Sleep (read-only, from Apple Health) and Mood (user-logged pleasant↔unpleasant check-ins) — ported faithfully from the `Sleep & Mood.html` prototype, surfacing real cross-dimension connections through the existing correlation engine and a (now design-accurate) shared trust sheet.

**Architecture:** Each dimension mirrors the **Nutrition** dimension end-to-end: a standalone Drift table → model → mapper → repository → `@riverpod` controller → provider → demo seed (no new `EntryType`). Connections reuse `lib/analysis/correlations.dart` + `surfacedCorrelationsProvider` + the shared `CorrelationCard`/trust sheet, extended for two new `Dimension` values and a next-day, threshold-split breakdown. Screens are built only from `lib/theme` tokens + existing shared widgets. Reached via a new "Dimensions" hub off Today.

**Tech Stack:** Flutter, Drift (sqlite), Riverpod + riverpod_generator (`build_runner`), `flutter_test`. Design spec: `docs/superpowers/specs/2026-06-23-sleep-mood-dimensions-design.md`. Prototype source: Claude-Design project `b14afff0-1260-4a1b-8de4-6a50fd32f9f5`, `Sleep & Mood.html` + `src/{tokens,sleep-mood-data,sleep-screens,mood-screens,sleep-mood-trust}.jsx`.

**Conventions for every task:**
- After editing any Drift table/`@DriftDatabase` or adding any `@riverpod`/`@Riverpod` annotation, regenerate: `dart run build_runner build --delete-conflicting-outputs`.
- Analyzer is the safety net for exhaustive `switch`es over `Dimension`: `flutter analyze` must be clean before each commit.
- Run the whole suite before a phase-closing commit: `flutter test`.
- Commit messages: `type(sleep-mood): …`. Work on branch `feat/sleep-mood-dimensions` (already created).

---

## Phase 0 — Theme tokens

### Task 1: Add `sleep`/`mood` color tokens to AppColors

**Files:**
- Modify: `lib/theme/app_colors.dart` (class fields + constructor + `light()` + `dark()` + `forType` + `copyWith` + `lerp`)
- Test: `test/theme/app_colors_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  test('sleep & mood tokens resolve via forType in both brightnesses', () {
    final light = AppColors.light(AppAccent.blue);
    final dark = AppColors.dark(AppAccent.blue);
    expect(light.forType('sleep'), const Color(0xFF5B6CDB));
    expect(light.forType('mood'), const Color(0xFF2FA6BC));
    expect(dark.forType('sleep'), const Color(0xFF8491F0));
    expect(dark.forType('mood'), const Color(0xFF56C2DA));
  });

  test('lerp interpolates the new tokens', () {
    final a = AppColors.light(AppAccent.blue);
    final b = AppColors.dark(AppAccent.blue);
    final mid = a.lerp(b, 0.5) as AppColors;
    expect(mid.sleep, isNot(a.sleep)); // proves sleep is in lerp
    expect(mid.mood, isNot(a.mood));
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `flutter test test/theme/app_colors_test.dart`
Expected: FAIL — `forType('sleep')` returns `accent`, and `AppColors` has no `sleep`/`mood` getters.

- [ ] **Step 3: Implement**

In `lib/theme/app_colors.dart`:

Add to the constructor (after `nutritionTint`):
```dart
    required this.sleep,
    required this.sleepTint,
    required this.mood,
    required this.moodTint,
```
Add fields (after `nutrition, nutritionTint;`):
```dart
  final Color sleep, sleepTint;
  final Color mood, moodTint;
```
Extend `forType`:
```dart
        'nutrition' => nutrition,
        'sleep' => sleep,
        'mood' => mood,
```
In `AppColors.light(...)` (after `nutritionTint:`):
```dart
      sleep: const Color(0xFF5B6CDB),
      sleepTint: const Color.fromRGBO(91, 108, 219, 0.14),
      mood: const Color(0xFF2FA6BC),
      moodTint: const Color.fromRGBO(47, 166, 188, 0.14),
```
In `AppColors.dark(...)` (after `nutritionTint:`):
```dart
      sleep: const Color(0xFF8491F0),
      sleepTint: const Color.fromRGBO(132, 145, 240, 0.20),
      mood: const Color(0xFF56C2DA),
      moodTint: const Color.fromRGBO(86, 194, 218, 0.20),
```
In `copyWith` (after `nutrition: base.nutrition, nutritionTint: base.nutritionTint,`):
```dart
      sleep: base.sleep, sleepTint: base.sleepTint,
      mood: base.mood, moodTint: base.moodTint,
```
In `lerp` (after the `nutrition`/`nutritionTint` lines):
```dart
      sleep: c(sleep, other.sleep),
      sleepTint: c(sleepTint, other.sleepTint),
      mood: c(mood, other.mood),
      moodTint: c(moodTint, other.moodTint),
```

- [ ] **Step 4: Run, verify it passes**

Run: `flutter test test/theme/app_colors_test.dart` → PASS. Then `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_colors.dart test/theme/app_colors_test.dart
git commit -m "feat(sleep-mood): add sleep & mood color tokens to AppColors"
```

---

## Phase 1 — Data layer

### Task 2: `SleepNight` model

**Files:**
- Create: `lib/models/sleep_night.dart`
- Modify: `lib/models/models.dart` (barrel — add `export 'sleep_night.dart';`)
- Test: `test/models/sleep_night_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/sleep_night.dart';
import 'package:opal/models/enums.dart';

void main() {
  final n = SleepNight(
    id: 'n1',
    night: DateTime(2026, 6, 17),
    asleepMinutes: 432,
    inBedMinutes: 450,
    bedtime: '11:32',
    wake: '7:02',
    deepMinutes: 64,
    remMinutes: 98,
    coreMinutes: 270,
    awakeMinutes: 18,
    wakes: 2,
    source: EntrySource.health,
  );

  test('copyWith overrides one field, keeps the rest', () {
    final m = n.copyWith(asleepMinutes: 400);
    expect(m.asleepMinutes, 400);
    expect(m.inBedMinutes, 450);
    expect(m, isNot(n));
  });

  test('value equality', () {
    expect(n, n.copyWith());
    expect(n.hashCode, n.copyWith().hashCode);
  });
}
```

- [ ] **Step 2: Run, verify it fails** — `flutter test test/models/sleep_night_test.dart` → FAIL (no such file/class).

- [ ] **Step 3: Implement** `lib/models/sleep_night.dart`:

```dart
import 'enums.dart';

/// One night's sleep, synced read-only from Apple Health. Attributed to [night]
/// = the calendar date the user woke on. Stage minutes sum to ≈[inBedMinutes].
class SleepNight {
  const SleepNight({
    required this.id,
    required this.night,
    required this.asleepMinutes,
    required this.inBedMinutes,
    required this.bedtime,
    required this.wake,
    required this.deepMinutes,
    required this.remMinutes,
    required this.coreMinutes,
    required this.awakeMinutes,
    required this.wakes,
    required this.source,
    this.sourceRef,
  });

  final String id;
  final DateTime night;
  final int asleepMinutes;
  final int inBedMinutes;

  /// Display clock strings, e.g. "11:32" / "7:02".
  final String bedtime, wake;
  final int deepMinutes, remMinutes, coreMinutes, awakeMinutes;
  final int wakes;
  final EntrySource source;

  /// Health sample UUID (dedup key); null for seed/manual.
  final String? sourceRef;

  SleepNight copyWith({
    String? id,
    DateTime? night,
    int? asleepMinutes,
    int? inBedMinutes,
    String? bedtime,
    String? wake,
    int? deepMinutes,
    int? remMinutes,
    int? coreMinutes,
    int? awakeMinutes,
    int? wakes,
    EntrySource? source,
    String? sourceRef,
  }) =>
      SleepNight(
        id: id ?? this.id,
        night: night ?? this.night,
        asleepMinutes: asleepMinutes ?? this.asleepMinutes,
        inBedMinutes: inBedMinutes ?? this.inBedMinutes,
        bedtime: bedtime ?? this.bedtime,
        wake: wake ?? this.wake,
        deepMinutes: deepMinutes ?? this.deepMinutes,
        remMinutes: remMinutes ?? this.remMinutes,
        coreMinutes: coreMinutes ?? this.coreMinutes,
        awakeMinutes: awakeMinutes ?? this.awakeMinutes,
        wakes: wakes ?? this.wakes,
        source: source ?? this.source,
        sourceRef: sourceRef ?? this.sourceRef,
      );

  @override
  bool operator ==(Object other) =>
      other is SleepNight &&
      other.id == id &&
      other.night == night &&
      other.asleepMinutes == asleepMinutes &&
      other.inBedMinutes == inBedMinutes &&
      other.bedtime == bedtime &&
      other.wake == wake &&
      other.deepMinutes == deepMinutes &&
      other.remMinutes == remMinutes &&
      other.coreMinutes == coreMinutes &&
      other.awakeMinutes == awakeMinutes &&
      other.wakes == wakes &&
      other.source == source &&
      other.sourceRef == sourceRef;

  @override
  int get hashCode => Object.hash(id, night, asleepMinutes, inBedMinutes,
      bedtime, wake, deepMinutes, remMinutes, coreMinutes, awakeMinutes, wakes,
      source, sourceRef);
}
```
Add to `lib/models/models.dart`: `export 'sleep_night.dart';`

- [ ] **Step 4: Run, verify passes** — `flutter test test/models/sleep_night_test.dart` → PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/models/sleep_night.dart lib/models/models.dart test/models/sleep_night_test.dart
git commit -m "feat(sleep-mood): add SleepNight model"
```

### Task 3: `MoodCheckin` model

**Files:**
- Create: `lib/models/mood_checkin.dart`
- Modify: `lib/models/models.dart` (`export 'mood_checkin.dart';`)
- Test: `test/models/mood_checkin_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/mood_checkin.dart';
import 'package:opal/models/enums.dart';

void main() {
  final c = MoodCheckin(
    id: 'c1',
    timestamp: DateTime(2026, 6, 17, 13, 40),
    pleasantness: 0.62,
    tag: 'Calm',
    source: EntrySource.manual,
  );

  test('copyWith + equality', () {
    expect(c, c.copyWith());
    expect(c.copyWith(tag: null).tag, isNull);
    expect(c.copyWith(pleasantness: 0.7).pleasantness, 0.7);
  });
}
```

- [ ] **Step 2: Run, verify fails** — `flutter test test/models/mood_checkin_test.dart` → FAIL.

- [ ] **Step 3: Implement** `lib/models/mood_checkin.dart`:

```dart
import 'enums.dart';

/// One mood check-in. [pleasantness] is the 0..1 position on the
/// unpleasant↔pleasant scale (the prototype's draggable orb); the descriptive
/// word ("Slightly pleasant") is derived, never stored. [tag] is an optional
/// one-word note.
class MoodCheckin {
  const MoodCheckin({
    required this.id,
    required this.timestamp,
    required this.pleasantness,
    required this.source,
    this.tag,
  });

  final String id;
  final DateTime timestamp;
  final double pleasantness;
  final String? tag;
  final EntrySource source;

  MoodCheckin copyWith({
    String? id,
    DateTime? timestamp,
    double? pleasantness,
    Object? tag = _sentinel,
    EntrySource? source,
  }) =>
      MoodCheckin(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        pleasantness: pleasantness ?? this.pleasantness,
        tag: identical(tag, _sentinel) ? this.tag : tag as String?,
        source: source ?? this.source,
      );

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is MoodCheckin &&
      other.id == id &&
      other.timestamp == timestamp &&
      other.pleasantness == pleasantness &&
      other.tag == tag &&
      other.source == source;

  @override
  int get hashCode => Object.hash(id, timestamp, pleasantness, tag, source);
}
```
(The sentinel lets `copyWith(tag: null)` actually clear the tag.)
Add to `lib/models/models.dart`: `export 'mood_checkin.dart';`

- [ ] **Step 4: Run, verify passes** — `flutter test test/models/mood_checkin_test.dart` → PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/models/mood_checkin.dart lib/models/models.dart test/models/mood_checkin_test.dart
git commit -m "feat(sleep-mood): add MoodCheckin model"
```

### Task 4: Drift tables + schema v9 migration

**Files:**
- Modify: `lib/data/db/tables.dart` (add two table classes)
- Modify: `lib/data/db/database.dart` (`@DriftDatabase` list, `schemaVersion`, `onUpgrade`)

- [ ] **Step 1: Add tables** to `lib/data/db/tables.dart` (append):

```dart
/// One night of sleep, synced read-only from Apple Health. `night` is the
/// calendar date the user woke on (the morning's date).
@DataClassName('SleepNightRow')
class SleepNights extends Table {
  TextColumn get id => text()();
  DateTimeColumn get night => dateTime()();
  IntColumn get asleepMinutes => integer()();
  IntColumn get inBedMinutes => integer()();
  TextColumn get bedtime => text()();
  TextColumn get wake => text()();
  IntColumn get deepMinutes => integer()();
  IntColumn get remMinutes => integer()();
  IntColumn get coreMinutes => integer()();
  IntColumn get awakeMinutes => integer()();
  IntColumn get wakes => integer().withDefault(const Constant(0))();

  /// [EntrySource.wire] — 'health'.
  TextColumn get source => text()();

  /// Health sample UUID (dedup); null for seed.
  TextColumn get sourceRef => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One user-logged mood check-in. `pleasantness` is the 0..1 scale position.
@DataClassName('MoodCheckinRow')
class MoodCheckins extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get pleasantness => real()();
  TextColumn get tag => text().nullable()();

  /// [EntrySource.wire] — 'manual'.
  TextColumn get source => text()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Register + migrate** in `lib/data/db/database.dart`:

Add to the `@DriftDatabase(tables: [...])` list after `NutritionMeals,`:
```dart
    SleepNights,
    MoodCheckins,
```
Bump version:
```dart
  @override
  int get schemaVersion => 9;
```
Add a migration comment above `onUpgrade` (after the v7→v8 note):
```dart
        // v8 -> v9: new sleep_nights + mood_checkins tables back the Sleep &
        // Mood dimensions. Brand-new tables; creating them leaves existing data
        // untouched; the seeder (marker bump) populates demo nights/check-ins.
```
Add inside `onUpgrade`, after the `if (from < 8)` block:
```dart
          if (from < 9) {
            await m.createTable(sleepNights);
            await m.createTable(moodCheckins);
          }
```

- [ ] **Step 3: Regenerate** — `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` regenerates with `SleepNightRow`, `MoodCheckinRow`, `SleepNightsCompanion`, `MoodCheckinsCompanion`, and `db.sleepNights` / `db.moodCheckins` accessors.

- [ ] **Step 4: Verify it compiles** — `flutter analyze` → clean.

- [ ] **Step 5: Commit**
```bash
git add lib/data/db/tables.dart lib/data/db/database.dart lib/data/db/database.g.dart
git commit -m "feat(sleep-mood): add sleep_nights & mood_checkins tables (schema v9)"
```

### Task 5: Mappers

**Files:**
- Modify: `lib/data/db/mappers.dart` (append two pairs of extensions)
- Test: covered by the repository tests in Tasks 6–7.

- [ ] **Step 1: Implement** — append to `lib/data/db/mappers.dart`:

```dart
// ---------------------------------------------------------------------------
// SleepNight
// ---------------------------------------------------------------------------

extension SleepNightRowMapper on SleepNightRow {
  SleepNight toModel() => SleepNight(
        id: id,
        night: night,
        asleepMinutes: asleepMinutes,
        inBedMinutes: inBedMinutes,
        bedtime: bedtime,
        wake: wake,
        deepMinutes: deepMinutes,
        remMinutes: remMinutes,
        coreMinutes: coreMinutes,
        awakeMinutes: awakeMinutes,
        wakes: wakes,
        source: EntrySource.fromWire(source),
        sourceRef: sourceRef,
      );
}

extension SleepNightModelMapper on SleepNight {
  SleepNightsCompanion toCompanion() => SleepNightsCompanion(
        id: Value(id),
        night: Value(night),
        asleepMinutes: Value(asleepMinutes),
        inBedMinutes: Value(inBedMinutes),
        bedtime: Value(bedtime),
        wake: Value(wake),
        deepMinutes: Value(deepMinutes),
        remMinutes: Value(remMinutes),
        coreMinutes: Value(coreMinutes),
        awakeMinutes: Value(awakeMinutes),
        wakes: Value(wakes),
        source: Value(source.wire),
        sourceRef: Value(sourceRef),
      );
}

// ---------------------------------------------------------------------------
// MoodCheckin
// ---------------------------------------------------------------------------

extension MoodCheckinRowMapper on MoodCheckinRow {
  MoodCheckin toModel() => MoodCheckin(
        id: id,
        timestamp: timestamp,
        pleasantness: pleasantness,
        tag: tag,
        source: EntrySource.fromWire(source),
      );
}

extension MoodCheckinModelMapper on MoodCheckin {
  MoodCheckinsCompanion toCompanion() => MoodCheckinsCompanion(
        id: Value(id),
        timestamp: Value(timestamp),
        pleasantness: Value(pleasantness),
        tag: Value(tag),
        source: Value(source.wire),
      );
}
```

- [ ] **Step 2: Verify compiles** — `flutter analyze` → clean.

- [ ] **Step 3: Commit**
```bash
git add lib/data/db/mappers.dart
git commit -m "feat(sleep-mood): add sleep/mood row<->model mappers"
```

### Task 6: `SleepRepository`

**Files:**
- Create: `lib/data/repositories/sleep_repository.dart`
- Modify: `lib/data/repositories/repositories.dart` (barrel — `export 'sleep_repository.dart';`)
- Test: `test/repository_test.dart` (add a `group`)

- [ ] **Step 1: Write the failing test** — append inside `main()` of `test/repository_test.dart` (it already sets up `db` in `setUp`/`tearDown`; reuse that pattern — if the existing file scopes `db` per group, mirror its existing structure):

```dart
  group('SleepRepository', () {
    test('insert assigns a uuid when id empty; round-trips fields', () async {
      final repo = SleepRepository(db);
      final id = await repo.insert(SleepNight(
        id: '',
        night: DateTime(2026, 6, 17),
        asleepMinutes: 432,
        inBedMinutes: 450,
        bedtime: '11:32',
        wake: '7:02',
        deepMinutes: 64,
        remMinutes: 98,
        coreMinutes: 270,
        awakeMinutes: 18,
        wakes: 2,
        source: EntrySource.health,
      ));
      expect(id, isNotEmpty);
      final all = await repo.getNightsInRange(
          DateTime(2026, 6, 1), DateTime(2026, 7, 1));
      expect(all, hasLength(1));
      expect(all.single.asleepMinutes, 432);
      expect(all.single.deepMinutes, 64);
    });

    test('watchNightsInRange respects bounds and emits on change', () async {
      final repo = SleepRepository(db);
      final stream = repo.watchNightsInRange(
          DateTime(2026, 6, 16), DateTime(2026, 6, 18));
      expect(await stream.first, isEmpty);
      await repo.insert(_night(DateTime(2026, 6, 17)));
      expect(await stream.firstWhere((r) => r.isNotEmpty), hasLength(1));
    });

    test('upsert dedups by id', () async {
      final repo = SleepRepository(db);
      await repo.upsert(_night(DateTime(2026, 6, 17)).copyWith(id: 'x'));
      await repo.upsert(
          _night(DateTime(2026, 6, 17)).copyWith(id: 'x', asleepMinutes: 400));
      final all =
          await repo.getNightsInRange(DateTime(2026, 6, 1), DateTime(2026, 7, 1));
      expect(all, hasLength(1));
      expect(all.single.asleepMinutes, 400);
    });
  });
```
Add this helper near the top of the test file (after imports):
```dart
SleepNight _night(DateTime night) => SleepNight(
      id: '', night: night, asleepMinutes: 420, inBedMinutes: 440,
      bedtime: '23:30', wake: '7:00', deepMinutes: 60, remMinutes: 90,
      coreMinutes: 260, awakeMinutes: 16, wakes: 1, source: EntrySource.health);
```
Ensure imports include `package:opal/data/repositories/repositories.dart`, `package:opal/models/models.dart`.

- [ ] **Step 2: Run, verify fails** — `flutter test test/repository_test.dart` → FAIL (`SleepRepository` undefined).

- [ ] **Step 3: Implement** `lib/data/repositories/sleep_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [SleepNight]s. Read-only to the user — only the sleep sync and
/// the seeder write here. Reactive via `watch*`. Assigns a uuid on insert when
/// the caller passes an empty id.
class SleepRepository {
  SleepRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  Stream<List<SleepNight>> watchNightsInRange(DateTime from, DateTime to) {
    final q = _db.select(_db.sleepNights)
      ..where((t) =>
          t.night.isBiggerOrEqualValue(from) &
          t.night.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.night)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  Future<List<SleepNight>> getNightsInRange(DateTime from, DateTime to) async {
    final q = _db.select(_db.sleepNights)
      ..where((t) =>
          t.night.isBiggerOrEqualValue(from) &
          t.night.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.night)]);
    return (await q.get()).map((r) => r.toModel()).toList();
  }

  Future<String> insert(SleepNight night) async {
    final id = night.id.isEmpty ? _uuid.v4() : night.id;
    await _db.into(_db.sleepNights).insert(night.copyWith(id: id).toCompanion());
    return id;
  }

  Future<void> upsert(SleepNight night) =>
      _db.into(_db.sleepNights).insertOnConflictUpdate(night.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.sleepNights)..where((t) => t.id.equals(id))).go();
}
```
Add to `lib/data/repositories/repositories.dart`: `export 'sleep_repository.dart';`

- [ ] **Step 4: Run, verify passes** — `flutter test test/repository_test.dart` → the new group PASSES.

- [ ] **Step 5: Commit**
```bash
git add lib/data/repositories/sleep_repository.dart lib/data/repositories/repositories.dart test/repository_test.dart
git commit -m "feat(sleep-mood): add SleepRepository"
```

### Task 7: `MoodRepository`

**Files:**
- Create: `lib/data/repositories/mood_repository.dart`
- Modify: `lib/data/repositories/repositories.dart` (`export 'mood_repository.dart';`)
- Test: `test/repository_test.dart` (add a `group`)

- [ ] **Step 1: Write the failing test** — append to `test/repository_test.dart`:

```dart
  group('MoodRepository', () {
    test('insert assigns uuid; watchCheckinsForDay returns same-day, asc', () async {
      final repo = MoodRepository(db);
      final stream = repo.watchCheckinsForDay(DateTime(2026, 6, 17));
      expect(await stream.first, isEmpty);
      await repo.insert(MoodCheckin(
        id: '', timestamp: DateTime(2026, 6, 17, 8, 5),
        pleasantness: 0.46, tag: 'Tired', source: EntrySource.manual));
      await repo.insert(MoodCheckin(
        id: '', timestamp: DateTime(2026, 6, 17, 13, 40),
        pleasantness: 0.62, tag: 'Calm', source: EntrySource.manual));
      // a different day is excluded
      await repo.insert(MoodCheckin(
        id: '', timestamp: DateTime(2026, 6, 16, 9, 0),
        pleasantness: 0.5, source: EntrySource.manual));
      final today = await stream.firstWhere((r) => r.length == 2);
      expect(today.first.timestamp.hour, 8); // ascending
      expect(today.last.pleasantness, 0.62);
    });
  });
```

- [ ] **Step 2: Run, verify fails** — `flutter test test/repository_test.dart` → FAIL.

- [ ] **Step 3: Implement** `lib/data/repositories/mood_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Reads/writes [MoodCheckin]s. Reactive via `watch*`. Assigns a uuid on insert
/// when the caller passes an empty id.
class MoodRepository {
  MoodRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LoopDatabase _db;
  final Uuid _uuid;

  Stream<List<MoodCheckin>> watchCheckinsForDay([DateTime? day]) {
    final d = day ?? DateTime.now();
    final start = DateTime(d.year, d.month, d.day);
    return watchCheckinsInRange(start, start.add(const Duration(days: 1)));
  }

  Stream<List<MoodCheckin>> watchCheckinsInRange(DateTime from, DateTime to) {
    final q = _db.select(_db.moodCheckins)
      ..where((t) =>
          t.timestamp.isBiggerOrEqualValue(from) &
          t.timestamp.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    return q.watch().map((rows) => rows.map((r) => r.toModel()).toList());
  }

  Future<List<MoodCheckin>> getCheckinsInRange(DateTime from, DateTime to) async {
    final q = _db.select(_db.moodCheckins)
      ..where((t) =>
          t.timestamp.isBiggerOrEqualValue(from) &
          t.timestamp.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    return (await q.get()).map((r) => r.toModel()).toList();
  }

  Future<String> insert(MoodCheckin checkin) async {
    final id = checkin.id.isEmpty ? _uuid.v4() : checkin.id;
    await _db
        .into(_db.moodCheckins)
        .insert(checkin.copyWith(id: id).toCompanion());
    return id;
  }

  Future<void> upsert(MoodCheckin checkin) =>
      _db.into(_db.moodCheckins).insertOnConflictUpdate(checkin.toCompanion());

  Future<void> deleteById(String id) =>
      (_db.delete(_db.moodCheckins)..where((t) => t.id.equals(id))).go();
}
```
Add to `lib/data/repositories/repositories.dart`: `export 'mood_repository.dart';`

- [ ] **Step 4: Run, verify passes** — `flutter test test/repository_test.dart` → PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/data/repositories/mood_repository.dart lib/data/repositories/repositories.dart test/repository_test.dart
git commit -m "feat(sleep-mood): add MoodRepository"
```

### Task 8: Provider wiring

**Files:**
- Modify: `lib/controllers/providers.dart` (add two repository providers)

- [ ] **Step 1: Implement** — in `lib/controllers/providers.dart`, after the `nutritionRepository` provider (line ~86):

```dart
@Riverpod(keepAlive: true)
SleepRepository sleepRepository(Ref ref) =>
    SleepRepository(ref.watch(loopDatabaseProvider));

@Riverpod(keepAlive: true)
MoodRepository moodRepository(Ref ref) =>
    MoodRepository(ref.watch(loopDatabaseProvider));
```

- [ ] **Step 2: Regenerate** — `dart run build_runner build --delete-conflicting-outputs` (emits `sleepRepositoryProvider`, `moodRepositoryProvider` in `providers.g.dart`).

- [ ] **Step 3: Verify** — `flutter analyze` → clean.

- [ ] **Step 4: Commit**
```bash
git add lib/controllers/providers.dart lib/controllers/providers.g.dart
git commit -m "feat(sleep-mood): provide sleep & mood repositories"
```

---

## Phase 2 — Mood scale helpers

### Task 9: `lib/util/mood_scale.dart` (pure helpers)

**Files:**
- Create: `lib/util/mood_scale.dart`
- Test: `test/util/mood_scale_test.dart` (create)

These port `moodWord`, `moodColor`, `hm`, `hmShort` from `sleep-mood-data.jsx` exactly.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/util/mood_scale.dart';

void main() {
  test('moodWord maps the 7 stops', () {
    expect(moodWord(0.0), 'Very unpleasant');
    expect(moodWord(0.5), 'Neutral');
    expect(moodWord(1.0), 'Very pleasant');
    expect(moodWord(0.62), 'Slightly pleasant'); // round(0.62*6)=4
  });

  test('hm / hmShort format minutes', () {
    expect(hm(432), '7h 12m');
    expect(hm(420), '7h');
    expect(hm(18), '18m');
    expect(hmShort(432), '7h12');
    expect(hmShort(420), '7h');
  });

  test('moodColor returns a Color and clamps', () {
    expect(moodColor(-1, false), isA<Color>());
    expect(moodColor(2, true), isA<Color>());
  });
}
```

- [ ] **Step 2: Run, verify fails** — `flutter test test/util/mood_scale_test.dart` → FAIL.

- [ ] **Step 3: Implement** `lib/util/mood_scale.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

const List<String> moodWords = [
  'Very unpleasant', 'Unpleasant', 'Slightly unpleasant',
  'Neutral', 'Slightly pleasant', 'Pleasant', 'Very pleasant',
];

/// The descriptive word for a 0..1 pleasantness [t] (7 evenly-spaced stops).
String moodWord(double t) =>
    moodWords[(t.clamp(0.0, 1.0) * 6).round().clamp(0, 6)];

/// "432" -> "7h 12m", "420" -> "7h", "18" -> "18m".
String hm(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// "432" -> "7h12", "420" -> "7h".
String hmShort(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

/// Cool→warm arc through the mood teal: muted blue → teal → calm honey. Dark
/// mode lifts each stop. [t] in [0,1].
Color moodColor(double t, bool dark) {
  final stops = dark
      ? const [
          [120, 138, 178],
          [86, 194, 218],
          [226, 190, 122]
        ]
      : const [
          [100, 120, 166],
          [47, 166, 188],
          [206, 166, 96]
        ];
  final c = t.clamp(0.0, 1.0);
  int lerp(int a, int b, double f) => (a + (b - a) * f).round();
  Color mix(List<int> a, List<int> b, double f) =>
      Color.fromARGB(255, lerp(a[0], b[0], f), lerp(a[1], b[1], f), lerp(a[2], b[2], f));
  return c <= 0.5
      ? mix(stops[0], stops[1], c / 0.5)
      : mix(stops[1], stops[2], (c - 0.5) / 0.5);
}
```

- [ ] **Step 4: Run, verify passes** — `flutter test test/util/mood_scale_test.dart` → PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/util/mood_scale.dart test/util/mood_scale_test.dart
git commit -m "feat(sleep-mood): port mood scale + duration helpers"
```

---

## Phase 3 — Correlation engine extension

### Task 10: Add `sleep`/`mood` to `Dimension` + label/format switches

**Files:**
- Modify: `lib/analysis/correlations.dart`
- Modify: `lib/widgets/correlation_card.dart` (`_label`/`_token` switches)
- Test: `test/analysis/correlations_test.dart` (add cases — file exists per spec; if not, create it)

- [ ] **Step 1: Write the failing test** — add to `test/analysis/correlations_test.dart`:

```dart
  test('label/format switches cover sleep & mood', () {
    expect(dimensionNoun(Dimension.sleep), 'sleep');
    expect(dimensionNoun(Dimension.mood), 'mood');
    expect(activeDayLabel(Dimension.sleep), 'short nights');
    expect(inactiveDayLabel(Dimension.sleep), 'other nights');
    expect(formatValue(Dimension.sleep, 414), '6h 54m');
    expect(formatValue(Dimension.mood, 0.64), 'Pleasant (0.64)');
  });
```

- [ ] **Step 2: Run, verify fails** — `flutter test test/analysis/correlations_test.dart` → FAIL (enum has no `sleep`/`mood`; switches non-exhaustive → compile error).

- [ ] **Step 3: Implement** in `lib/analysis/correlations.dart`:

Top of file, add import:
```dart
import '../util/mood_scale.dart' show moodWord, hm;
```
Extend the enum (line 13):
```dart
enum Dimension { money, move, rituals, nutrition, sleep, mood }
```
Add the short-night threshold near the other consts (after `kAlpha`):
```dart
/// Nights below this many minutes asleep count as "short" for the sleep
/// breakdown split (6h 30m).
const int kShortNightMinutes = 390;
```
Add arms to the four switches:
```dart
String dimensionNoun(Dimension d) => switch (d) {
      Dimension.money => 'spending',
      Dimension.move => 'activity',
      Dimension.rituals => 'rituals',
      Dimension.nutrition => 'calories',
      Dimension.sleep => 'sleep',
      Dimension.mood => 'mood',
    };

String activeDayLabel(Dimension binaryDim) => switch (binaryDim) {
      Dimension.move => 'workout days',
      Dimension.rituals => 'ritual days',
      Dimension.sleep => 'short nights',
      _ => 'active days',
    };

String inactiveDayLabel(Dimension binaryDim) => switch (binaryDim) {
      Dimension.move => 'rest days',
      Dimension.rituals => 'days you skipped',
      Dimension.sleep => 'other nights',
      _ => 'other days',
    };

String formatValue(Dimension d, double v) => switch (d) {
      Dimension.money => '\$${v.round()}',
      Dimension.move => '${v.round()} kcal',
      Dimension.nutrition => '${v.round()} cal',
      Dimension.rituals => v.round().toString(),
      Dimension.sleep => hm(v.round()),
      Dimension.mood => '${moodWord(v)} (${v.toStringAsFixed(2)})',
    };
```
In `lib/widgets/correlation_card.dart`, extend `_label`:
```dart
  static String _label(Dimension d) => switch (d) {
        Dimension.money => 'Money',
        Dimension.move => 'Move',
        Dimension.rituals => 'Rituals',
        Dimension.nutrition => 'Nutrition',
        Dimension.sleep => 'Sleep',
        Dimension.mood => 'Mood',
      };
```
(`_token` derives from `_label().toLowerCase()` → `'sleep'`/`'mood'`, which `forType` now maps from Task 1.)

- [ ] **Step 4: Run, verify passes** — `flutter test test/analysis/correlations_test.dart` → PASS. `flutter analyze` → clean (no remaining non-exhaustive switches; if the analyzer flags another `switch (Dimension)` elsewhere, add the matching arms).

- [ ] **Step 5: Commit**
```bash
git add lib/analysis/correlations.dart lib/widgets/correlation_card.dart test/analysis/correlations_test.dart
git commit -m "feat(sleep-mood): add sleep & mood dimensions to correlation engine"
```

### Task 11: Next-day sleep series, mood mean, threshold-split breakdown

**Files:**
- Modify: `lib/analysis/correlations.dart` (`buildDailyVectors` signature/body; `_toCorrelation` breakdown)
- Test: `test/analysis/correlations_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:opal/models/models.dart';
// ...
  test('sleep attributed to the next day; short-night split + means', () {
    // night of the 1st (short, 360) -> pairs with money on the 2nd ($80);
    // night of the 2nd (long, 450) -> pairs with money on the 3rd ($20).
    final nights = [
      SleepNight(id: '1', night: DateTime(2026, 6, 1), asleepMinutes: 360,
        inBedMinutes: 380, bedtime: '1:00', wake: '7:00', deepMinutes: 40,
        remMinutes: 80, coreMinutes: 240, awakeMinutes: 20, wakes: 2,
        source: EntrySource.health),
      SleepNight(id: '2', night: DateTime(2026, 6, 2), asleepMinutes: 450,
        inBedMinutes: 470, bedtime: '23:00', wake: '7:00', deepMinutes: 70,
        remMinutes: 100, coreMinutes: 280, awakeMinutes: 20, wakes: 1,
        source: EntrySource.health),
    ];
    final entries = [
      Entry(id: 'm1', timestamp: DateTime(2026, 6, 2, 9), type: EntryType.money,
        title: 'x', amount: -80, source: EntrySource.manual),
      Entry(id: 'm2', timestamp: DateTime(2026, 6, 3, 9), type: EntryType.money,
        title: 'y', amount: -20, source: EntrySource.manual),
    ];
    final vectors = buildDailyVectors(entries, const [], const [], const [],
        now: DateTime(2026, 6, 3));
    final sleep = vectors[Dimension.sleep]!.byDay;
    // night-of-1st shows up under day-2 ordinal
    expect(sleep[20260602], 360);
    expect(sleep[20260603], 450);
  });

  test('mood daily mean is sparse (only days with a check-in)', () {
    final moods = [
      MoodCheckin(id: 'a', timestamp: DateTime(2026, 6, 2, 8), pleasantness: 0.4, source: EntrySource.manual),
      MoodCheckin(id: 'b', timestamp: DateTime(2026, 6, 2, 20), pleasantness: 0.6, source: EntrySource.manual),
    ];
    final v = buildDailyVectors(const [], const [], const [], moods,
        now: DateTime(2026, 6, 3));
    expect(v[Dimension.mood]!.byDay[20260602], closeTo(0.5, 1e-9));
    expect(v[Dimension.mood]!.byDay.containsKey(20260603), isFalse);
  });
```

- [ ] **Step 2: Run, verify fails** — FAIL: `buildDailyVectors` takes only `(entries, meals, …)`.

- [ ] **Step 3: Implement** in `lib/analysis/correlations.dart`:

Replace the `_binaryDims` constant + the breakdown classification with a per-dim signal:
```dart
/// Dimensions whose daily scalar drives the trust sheet's two-group breakdown.
const _breakdownDrivers = {Dimension.move, Dimension.rituals, Dimension.sleep};

/// Whether [v] (this dim's daily scalar) is the highlighted/"active" group.
/// move/rituals: did the thing (>0). sleep: a short night (<threshold).
bool _isActiveSignal(Dimension d, double v) => switch (d) {
      Dimension.sleep => v > 0 && v < kShortNightMinutes,
      _ => v > 0,
    };
```
In `_toCorrelation`, change driver selection + the loop:
```dart
  Dimension? binary;
  Dimension? cont;
  if (_breakdownDrivers.contains(s.a) && !_breakdownDrivers.contains(s.b)) {
    binary = s.a; cont = s.b;
  } else if (_breakdownDrivers.contains(s.b) && !_breakdownDrivers.contains(s.a)) {
    binary = s.b; cont = s.a;
  }
```
and inside the means loop, replace `if (binaryXs[i] > 0)` with:
```dart
      if (_isActiveSignal(binary, binaryXs[i])) {
```
Update `buildDailyVectors` signature + body. New signature:
```dart
Map<Dimension, DailySeries> buildDailyVectors(
  List<Entry> entries,
  List<NutritionMeal> meals,
  List<SleepNight> nights,
  List<MoodCheckin> moods, {
  required DateTime now,
  int windowDays = kCorrelationWindowDays,
}) {
```
Before the final `return {`, add the two new sparse series:
```dart
  // Sleep: minutes asleep, attributed to the NEXT calendar day so the engine's
  // same-day pairing yields the "last night -> today" relationship. Sparse.
  final sleep = <int, double>{};
  for (final n in nights) {
    final attributed = DateTime(n.night.year, n.night.month, n.night.day)
        .add(const Duration(days: 1));
    if (!inWindow(attributed)) continue;
    sleep[_dayOrd(attributed)] = n.asleepMinutes.toDouble();
  }

  // Mood: mean pleasantness per day. Sparse (only days with a check-in).
  final moodSum = <int, double>{};
  final moodCount = <int, int>{};
  for (final c in moods) {
    if (!inWindow(c.timestamp)) continue;
    final k = _dayOrd(
        DateTime(c.timestamp.year, c.timestamp.month, c.timestamp.day));
    moodSum[k] = (moodSum[k] ?? 0) + c.pleasantness;
    moodCount[k] = (moodCount[k] ?? 0) + 1;
  }
  final mood = <int, double>{
    for (final k in moodSum.keys) k: moodSum[k]! / moodCount[k]!
  };
```
Extend the returned map:
```dart
    Dimension.sleep: DailySeries(dim: Dimension.sleep, byDay: sleep),
    Dimension.mood: DailySeries(dim: Dimension.mood, byDay: mood),
```

**Fix the broken call sites.** Changing the signature breaks every existing caller. Find them: `grep -rn "buildDailyVectors(" lib/ test/`. The only non-test caller is `correlations_controller.dart` (updated in Task 12). For existing **test** call sites in `test/analysis/correlations_test.dart` that pass `(entries, meals, now: …)`, insert two empty lists: `buildDailyVectors(entries, meals, const [], const [], now: …)`. Update them now so the file compiles.

- [ ] **Step 4: Run, verify passes** — `flutter test test/analysis/correlations_test.dart` → PASS. `flutter analyze` → clean.

- [ ] **Step 5: Commit**
```bash
git add lib/analysis/correlations.dart test/analysis/correlations_test.dart
git commit -m "feat(sleep-mood): next-day sleep series, mood mean, short-night split"
```

### Task 12: Wire the two repos into `surfacedCorrelationsProvider`

**Files:**
- Modify: `lib/controllers/correlations_controller.dart`

- [ ] **Step 1: Implement** — update `surfacedCorrelations` in `lib/controllers/correlations_controller.dart`:

```dart
@riverpod
Future<List<corr.Correlation>> surfacedCorrelations(Ref ref) async {
  final entryRepo = ref.watch(entryRepositoryProvider);
  final nutritionRepo = ref.watch(nutritionRepositoryProvider);
  final sleepRepo = ref.watch(sleepRepositoryProvider);
  final moodRepo = ref.watch(moodRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start =
      today.subtract(const Duration(days: corr.kCorrelationWindowDays - 1));
  final end = today.add(const Duration(days: 1));

  final entries = await entryRepo.getEntriesInRange(start, end);
  final meals = await nutritionRepo.getMealsInRange(start, end);
  // include the night BEFORE the window so its next-day attribution can pair.
  final nights = await sleepRepo.getNightsInRange(
      start.subtract(const Duration(days: 1)), end);
  final moods = await moodRepo.getCheckinsInRange(start, end);

  final vectors = corr.buildDailyVectors(entries, meals, nights, moods, now: now);
  return corr.surfacedCorrelations(vectors);
}
```

- [ ] **Step 2: Verify** — `flutter analyze` → clean (the provider already has its `.g.dart`; no new annotation, so no regen needed — but run `flutter test` to be safe).

- [ ] **Step 3: Commit**
```bash
git add lib/controllers/correlations_controller.dart
git commit -m "feat(sleep-mood): feed sleep & mood into surfaced correlations"
```

---

## Phase 4 — Health sleep ingestion

### Task 13: `HealthSleep` + `fetchSleep` on the service

**Files:**
- Modify: `lib/services/health/health_service.dart` (add `HealthSleep` + interface method)
- Modify: `lib/services/health/mock_health_service.dart` (implement, returns `[]`)
- Modify: `lib/services/health/http_health_service.dart` (implement real fetch)
- Test: `test/services/http_health_service_test.dart` (extend if present, else a focused mapping test)

- [ ] **Step 1: Implement the interface** — `lib/services/health/health_service.dart`:

```dart
/// One night of sleep read from Apple Health. Minutes are integer; clock
/// strings are display-ready ("23:32" / "7:02").
class HealthSleep {
  const HealthSleep({
    required this.night,
    required this.asleepMinutes,
    required this.inBedMinutes,
    required this.bedtime,
    required this.wake,
    required this.deepMinutes,
    required this.remMinutes,
    required this.coreMinutes,
    required this.awakeMinutes,
    required this.wakes,
    this.sourceRef,
  });
  final DateTime night;
  final int asleepMinutes, inBedMinutes;
  final String bedtime, wake;
  final int deepMinutes, remMinutes, coreMinutes, awakeMinutes, wakes;
  final String? sourceRef;
}

abstract interface class HealthService {
  /// GET /v1/health/day?date=YYYY-MM-DD
  Future<HealthDay> fetchDay(DateTime day);

  /// GET /v1/health/sleep?from=YYYY-MM-DD&to=YYYY-MM-DD — nights in [from, to).
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to);
}
```

- [ ] **Step 2: Mock returns no data** — `lib/services/health/mock_health_service.dart`, add:
```dart
  @override
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to) async =>
      const [];
```

- [ ] **Step 3: Real fetch** — `lib/services/health/http_health_service.dart`, add a `fetchSleep` mirroring `fetchDay`'s auth/retry/error handling, decoding a `{"nights": [ { night, asleepMinutes, inBedMinutes, bedtime, wake, stages:{deep,rem,core,awake}, wakes, sourceRef } ]}` payload:

```dart
  @override
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to) async {
    final query = {'from': _formatDate(from), 'to': _formatDate(to)};

    Future<http.Response> send() async {
      final token = await tokens.token();
      return _http
          .get(
            _base.replace(path: '/v1/health/sleep', queryParameters: query),
            headers: {'authorization': 'Bearer $token'},
          )
          .timeout(timeout);
    }

    http.Response res;
    try {
      res = await send();
      if (res.statusCode == 401) {
        await tokens.clear();
        res = await send();
      }
    } on TimeoutException {
      throw const PalException('request timed out');
    } catch (e) {
      throw PalException('network error: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PalException('proxy returned ${res.statusCode}');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const PalException('malformed sleep response');
    }
    final nights = (json['nights'] as List?) ?? const [];
    return [
      for (final raw in nights.whereType<Map<String, dynamic>>())
        _sleepFromJson(raw)
    ];
  }

  static HealthSleep _sleepFromJson(Map<String, dynamic> j) {
    final stages = (j['stages'] as Map<String, dynamic>?) ?? const {};
    int i(Object? v) => (v as num?)?.round() ?? 0;
    return HealthSleep(
      night: DateTime.parse(j['night'] as String),
      asleepMinutes: i(j['asleepMinutes']),
      inBedMinutes: i(j['inBedMinutes']),
      bedtime: (j['bedtime'] as String?) ?? '',
      wake: (j['wake'] as String?) ?? '',
      deepMinutes: i(stages['deep']),
      remMinutes: i(stages['rem']),
      coreMinutes: i(stages['core']),
      awakeMinutes: i(stages['awake']),
      wakes: i(j['wakes']),
      sourceRef: j['sourceRef'] as String?,
    );
  }
```

- [ ] **Step 4: Test the mapping** — add `test/services/http_health_service_test.dart` (or extend) feeding a `MockClient` that returns a known sleep JSON body and asserting `_sleepFromJson` round-trips (via a public `fetchSleep` with an injected client). Mirror any existing `fetchDay` test in that file. Run it → PASS.

- [ ] **Step 5: Verify + commit**
`flutter analyze` → clean.
```bash
git add lib/services/health/health_service.dart lib/services/health/mock_health_service.dart lib/services/health/http_health_service.dart test/services/http_health_service_test.dart
git commit -m "feat(sleep-mood): add fetchSleep to HealthService (http + mock)"
```

### Task 14: `SleepSyncController`

**Files:**
- Create: `lib/controllers/sleep_sync_controller.dart`
- Modify: wherever `HealthSyncController` is instantiated at startup (`lib/app.dart` — confirm by grepping `healthSyncControllerProvider`) to also read `sleepSyncControllerProvider`.
- Test: `test/controllers/sleep_sync_controller_test.dart`

- [ ] **Step 1: Write the failing test** — with a fake `HealthService` returning two nights, assert the controller upserts them into an in-memory `SleepRepository`; with `[]`, nothing is written:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/sleep_sync_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/services/health/health_service.dart';

class _FakeHealth implements HealthService {
  _FakeHealth(this.nights);
  final List<HealthSleep> nights;
  @override
  Future<HealthDay> fetchDay(DateTime day) async =>
      const HealthDay(activeEnergyKcal: 0, steps: 0);
  @override
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to) async => nights;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('syncs nights from Health into the repo', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      healthServiceProvider.overrideWithValue(_FakeHealth([
        HealthSleep(night: DateTime(2026, 6, 17), asleepMinutes: 432,
          inBedMinutes: 450, bedtime: '23:32', wake: '7:02', deepMinutes: 64,
          remMinutes: 98, coreMinutes: 270, awakeMinutes: 18, wakes: 2,
          sourceRef: 'h1'),
      ])),
    ]);
    addTearDown(container.dispose);

    container.read(sleepSyncControllerProvider);
    await container.read(sleepSyncControllerProvider.notifier).syncOnce();

    final nights = await container.read(sleepRepositoryProvider)
        .getNightsInRange(DateTime(2026, 6, 1), DateTime(2026, 7, 1));
    expect(nights, hasLength(1));
    expect(nights.single.asleepMinutes, 432);
    expect(nights.single.sourceRef, 'h1');
  });
}
```

- [ ] **Step 2: Run, verify fails** — FAIL (`sleepSyncControllerProvider` undefined).

- [ ] **Step 3: Implement** `lib/controllers/sleep_sync_controller.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/repositories.dart';
import '../models/models.dart';
import '../services/health/health_service.dart';
import 'providers.dart';

part 'sleep_sync_controller.g.dart';

/// Pulls recent nights from Health and upserts them into [SleepRepository].
/// Deterministic id (`health:sleep:<date>` or the Health sourceRef) so a
/// re-sync overwrites rather than duplicates. Best-effort: a failed pull must
/// not crash startup. `fireImmediately` syncs on launch.
@Riverpod(keepAlive: true)
class SleepSyncController extends _$SleepSyncController {
  static const int _windowDays = 30;

  @override
  void build() {
    // fire-and-forget on construction
    syncOnce();
  }

  Future<void> syncOnce() async {
    try {
      final service = ref.read(healthServiceProvider);
      final repo = ref.read(sleepRepositoryProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = today.subtract(const Duration(days: _windowDays - 1));
      final to = today.add(const Duration(days: 1));
      final nights = await service.fetchSleep(from, to);
      for (final n in nights) {
        final date = _date(n.night);
        await repo.upsert(SleepNight(
          id: n.sourceRef ?? 'health:sleep:$date',
          night: n.night,
          asleepMinutes: n.asleepMinutes,
          inBedMinutes: n.inBedMinutes,
          bedtime: n.bedtime,
          wake: n.wake,
          deepMinutes: n.deepMinutes,
          remMinutes: n.remMinutes,
          coreMinutes: n.coreMinutes,
          awakeMinutes: n.awakeMinutes,
          wakes: n.wakes,
          source: EntrySource.health,
          sourceRef: n.sourceRef,
        ));
      }
    } catch (_) {
      // swallow: sleep is supplementary; the screen just shows needs-sync.
    }
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
```

- [ ] **Step 4: Regenerate + wire startup** — `dart run build_runner build --delete-conflicting-outputs`. Then grep for how `healthSyncControllerProvider` is read at startup (`grep -rn "healthSyncControllerProvider" lib/`) and add an identical `ref.read(sleepSyncControllerProvider)` beside it (likely in `lib/app.dart`'s init).

- [ ] **Step 5: Run, verify passes + commit**
`flutter test test/controllers/sleep_sync_controller_test.dart` → PASS. `flutter analyze` → clean.
```bash
git add lib/controllers/sleep_sync_controller.dart lib/controllers/sleep_sync_controller.g.dart lib/app.dart test/controllers/sleep_sync_controller_test.dart
git commit -m "feat(sleep-mood): sync sleep nights from Health on launch"
```

---

## Phase 5 — Dimension controllers

### Task 15: `SleepController` + `SleepState`

**Files:**
- Create: `lib/controllers/sleep_controller.dart`
- Test: `test/controllers/sleep_controller_test.dart`

`SleepState` exposes: `lastNight` (SleepNight?), `usualMinutes` (trailing-2-week median of asleep), `read` (derived qualitative word), `week` (last-7 `SleepBar`s), `month` (last-30 ints), `syncedNights` (count → needs-sync when `< 3`).

- [ ] **Step 1: Write the failing test** — seed an in-memory `SleepRepository` with several nights; assert `usualMinutes` is the median, `lastNight` is the most recent, `syncedNights` counts them, and `week` has 7 entries. (Use the `ProviderContainer` + override pattern from Task 14.) Assert needs-sync boundary: with 2 nights, `state.syncedNights == 2` (screen treats `< 3` as needs-sync).

- [ ] **Step 2: Run, verify fails.**

- [ ] **Step 3: Implement** — `@riverpod class SleepController extends _$SleepController` with `Stream<SleepState> build()` that `ref.watch(sleepRepositoryProvider)` and `await for (final nights in repo.watchNightsInRange(windowStart, tomorrow))`, deriving:
  - `lastNight` = nights.last (repo returns ascending).
  - `usualMinutes` = median of the trailing 14 nights' `asleepMinutes`.
  - `read` = pure helper: `asleep >= usual && wakes <= 2 ? 'restful' : asleep < usual - 30 ? 'short' : 'broken'` (qualitative, never a score).
  - `week` = last 7 nights mapped to `SleepBar(dayLetter, minutes, isToday)`.
  - `month` = last 30 nights' minutes.
  - `syncedNights` = nights.length.
  Keep the median + read helpers as private top-level functions for direct unit testing. No write actions.

- [ ] **Step 4: Regenerate, run, verify passes.** `dart run build_runner build --delete-conflicting-outputs`; `flutter test test/controllers/sleep_controller_test.dart` → PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/controllers/sleep_controller.dart lib/controllers/sleep_controller.g.dart test/controllers/sleep_controller_test.dart
git commit -m "feat(sleep-mood): SleepController + derived state"
```

### Task 16: `MoodController` + `MoodState` + `logCheckin`

**Files:**
- Create: `lib/controllers/mood_controller.dart`
- Test: `test/controllers/mood_controller_test.dart`

`MoodState` exposes: `todayCheckins` (List, ascending), `todayLean` (mean pleasantness), `mostTag` (most frequent today), `lastCheckin`, `week` (7 daily-mean `MoodBar`s). Action: `Future<void> logCheckin(double pleasantness, String? tag)`.

- [ ] **Step 1: Write the failing test** — override `moodRepositoryProvider` (and `hapticsServiceProvider` with a no-op fake) in a `ProviderContainer`; call `logCheckin(0.7, 'Calm')`; assert a row persisted and `state` re-emits with `todayLean` reflecting it and `mostTag == 'Calm'`.

- [ ] **Step 2: Run, verify fails.**

- [ ] **Step 3: Implement** — `@riverpod class MoodController` with `Stream<MoodState> build()` that watches `moodRepository.watchCheckinsForDay(now)` and, per emission, fetches the week range to build the 7 daily means. `logCheckin` does `ref.read(moodRepositoryProvider).insert(MoodCheckin(id:'', timestamp: DateTime.now(), pleasantness: t, tag: tag, source: EntrySource.manual))` then `ref.read(hapticsServiceProvider).light()` (mirror `NutritionController.addManualMeal`). Compute `todayLean`/`mostTag`/`week` in pure helpers.

- [ ] **Step 4: Regenerate, run, verify passes + commit**
```bash
git add lib/controllers/mood_controller.dart lib/controllers/mood_controller.g.dart test/controllers/mood_controller_test.dart
git commit -m "feat(sleep-mood): MoodController + logCheckin"
```

---

## Phase 6 — Demo seed

### Task 17: Seed sleep nights + mood check-ins (engineered to surface connections)

**Files:**
- Modify: `lib/data/seed/seed_data.dart` (add `sleepNights()` + `moodCheckins()`)
- Modify: `lib/data/seed/seeder.dart` (insert both in `seedDemoData()`)
- Test: `test/seed/sleep_mood_seed_test.dart` (create) — proves the two connections surface

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run, verify fails** — FAIL (no seeded nights/moods; `SeedData.sleepNights`/`moodCheckins` undefined).

- [ ] **Step 3: Implement the seed** — in `lib/data/seed/seed_data.dart` add `static List<SleepNight> sleepNights()` and `static List<MoodCheckin> moodCheckins()`. Build ~30 days relative to "today" (use the same date anchor the existing demo `entries()`/`nutritionMeals()` use — grep for how they compute dates). Engineering rules so the engine clears `n≥21, |r|≥0.4, Holm p<0.05`:
  - **Sleep×Spending:** ~8 short nights (`asleepMinutes` 330–380, i.e. `< 390`) and ~22 normal nights (410–470). For each night, ensure a **next-day** money entry exists (the demo `entries()` already seed daily spend; if not dense enough, the spending seed must cover the window). Make next-day spend after short nights materially higher (≈$60–75) than after normal nights (≈$30–40) so |r| is strong and the short-night group mean ≈1.5–1.6× the other. Last night = Wed: asleep 432, inBed 450, bedtime '23:32', wake '7:02', stages 64/98/270/18, wakes 2.
  - **Mood×Routine:** one+ check-in on most days; on days the morning ritual was completed (the demo `entries()` seed `EntryType.rituals` rows — align to those days), use higher pleasantness (0.6–0.75); on skipped days use lower (0.35–0.5). Today = three check-ins: (08:05, 0.46, 'Tired'), (13:40, 0.62, 'Calm'), (21:12, 0.70, 'Calm'). Use stable ids (`seed-sleep-<n>`, `seed-mood-<n>`).
  - Set `EntrySource.health` for nights, `EntrySource.manual` for moods.

  In `lib/data/seed/seeder.dart`, inside `seedDemoData()`'s transaction, after the nutrition loop:
```dart
      // Sleep nights (no FK; standalone).
      for (final n in SeedData.sleepNights()) {
        await _db.into(_db.sleepNights).insert(n.toCompanion(), mode: replace);
      }
      // Mood check-ins (no FK; standalone).
      for (final c in SeedData.moodCheckins()) {
        await _db.into(_db.moodCheckins).insert(c.toCompanion(), mode: replace);
      }
```
  Import the mappers extension (the file already imports `'../db/mappers.dart'`). If the demo marker must re-run on existing dev DBs, bump `_demoMarker` to `'demo_seed_v2'` in `seeder.dart`.

- [ ] **Step 4: Run, verify passes** — `flutter test test/seed/sleep_mood_seed_test.dart` → PASS. Iterate the seed numbers until both connections clear the bar (this test is the acceptance gate for the "engineered seed" decision). Keep the data plausible — don't fabricate an absurdly perfect correlation.

- [ ] **Step 5: Commit**
```bash
git add lib/data/seed/seed_data.dart lib/data/seed/seeder.dart test/seed/sleep_mood_seed_test.dart
git commit -m "feat(sleep-mood): seed demo nights & check-ins that surface connections"
```

---

## Phase 7 — Shared connection card & trust sheet upgrade

> Before this phase, read the prototype `src/sleep-mood-trust.jsx` (the `TrustSheet`, `ConnLine`, `PairTag`) and `src/sleep-screens.jsx`/`src/mood-screens.jsx` connection-card markup, plus `lib/widgets/app_icon.dart`, `lib/widgets/press_scale.dart`, and `lib/theme/*` for exact APIs. The card/sheet render generically from a `Correlation` (+ `breakdown`); nothing is authored per-pair.

### Task 18: `CorrelationView` presentation helper

**Files:**
- Create: `lib/widgets/correlation_view.dart` (a pure mapping from `Correlation` → display sections)
- Test: `test/widgets/correlation_view_test.dart`

- [ ] **Step 1: Write the failing test** — given a `Correlation` with a `GroupBreakdown` (sleep×money), assert:
  - `pairLabel == 'Sleep × Spending'`
  - `compareLow.label == 'After short nights'`, `compareHigh.label == 'After other nights'`, values formatted via `formatValue`, fractions in [0,1] with the stronger group = 1.0.
  - `numbers` is a non-empty list of `(label, value)` pairs (group counts + the two means + the ratio).
  - `source` contains "last ${n} days".
  - `why` is non-empty.
  And for a breakdown-less `Correlation`, `compareLow == null` and the templated `line`/`claim` fall back to `correlation.summary`.

- [ ] **Step 2: Run, verify fails.**

- [ ] **Step 3: Implement** a `CorrelationView` class with named getters deriving each section from the `Correlation`. Map dimension → display noun via `dimensionNoun`/`_label`. For `pairLabel`, Title-case both labels with "×". For `compare`, normalize the two breakdown means to fractions (max → 1.0). For `numbers`, emit: `['${countActive} ${activeDayLabel(binary)}', formatValue(cont, meanActive)]`, the inactive row, and `['Difference', '${(meanActive/meanInactive).toStringAsFixed(1)}×']` when meaningful. For `source`, `'Computed from your data · last ${n} days'` (or, when sleep is involved, prefix 'Apple Health + '). For `why`, the generic honest note: "Opal shows this because it held across enough days to be more than noise. An observation about two things moving together — not a cause."

- [ ] **Step 4: Run, verify passes + commit**
```bash
git add lib/widgets/correlation_view.dart test/widgets/correlation_view_test.dart
git commit -m "feat(sleep-mood): CorrelationView presentation helper"
```

### Task 19: Rewrite `CorrelationCard` to the prototype

**Files:**
- Modify: `lib/widgets/correlation_card.dart`
- Test: `test/widgets/correlation_card_test.dart`

- [ ] **Step 1: Write the failing widget test** — pump a `CorrelationCard(correlation: <breakdown sample>)` inside a themed `MaterialApp`; assert it shows the `PAL NOTICED` eyebrow text and the templated line; tapping it opens a bottom sheet (the trust sheet) showing the comparison labels. (Wrap with a `ProviderScope` if needed; provide `AppColors` via the app theme as the app does.)

- [ ] **Step 2: Run, verify fails** (old card has no "PAL NOTICED").

- [ ] **Step 3: Implement** — rebuild the card body to match the prototype connection card: a gradient a→b dot, `PAL NOTICED` eyebrow (`AppType.caption2`, `c.ink3`, letterSpacing 0.3, uppercase), the templated line (bold figures + the key delta in the a-dimension accent via `CorrelationView`), and a "Tap to see the numbers." subline (`AppType.footnote`, `c.ink3`). Keep `narration` override winning over the templated line. Keep `onTap: () => showCorrelationTrustSheet(context, correlation)` and `PressScale`. Use `Spacing`/`Radii`/`context.colors` only.

- [ ] **Step 4: Run, verify passes + commit**
```bash
git add lib/widgets/correlation_card.dart test/widgets/correlation_card_test.dart
git commit -m "feat(sleep-mood): redesign CorrelationCard to match prototype"
```

### Task 20: Rewrite the trust sheet to the prototype

**Files:**
- Modify: `lib/widgets/correlation_card.dart` (the `showCorrelationTrustSheet` function + private sheet widgets)
- Test: `test/widgets/correlation_card_test.dart` (extend)

- [ ] **Step 1: Write the failing test** — open the sheet for a breakdown sample; assert it renders: the two-dot `PairTag` + pair label, the restated claim, a "Side by side" section with two comparison bars + values, an underlying-numbers list (≥3 rows), a source row, a "Why you're seeing this" box, and an "Ask Pal about this" button. Tapping "Ask Pal" calls `context.go('/pal-composer?seed=...')` (assert via a spy `GoRouter` or by checking navigation; if hard to assert, at minimum assert the button exists and is tappable).

- [ ] **Step 2: Run, verify fails.**

- [ ] **Step 3: Implement** — rebuild `showCorrelationTrustSheet` as a `showModalBottomSheet` (keep the signature `showCorrelationTrustSheet(context, correlation)`) whose content is a scrollable column built from `CorrelationView`: grabber, `PairTag` (two dots in the two dims' colors + uppercase pair label), restated claim (`AppType.title3`), the "Side by side" card (two rows: label + value + a proportional bar `frac*100%` in the a-dim color/`+'80'`), the underlying-numbers list (hairline-separated rows), the source row (heart/sparkles icon + source text), the "Why you're seeing this" box (`c.fill` rounded, eyebrow + body), and the "Ask Pal about this" button (`context.go('/pal-composer?seed=${Uri.encodeComponent(view.claim)}')`). Tokens only.

- [ ] **Step 4: Run, verify passes.** Then **visual regression check**: run the app (Phase 9) and open Recap + Nutrition Patterns; confirm their existing connection cards/sheets still render correctly with the new design (same data).

- [ ] **Step 5: Commit**
```bash
git add lib/widgets/correlation_card.dart test/widgets/correlation_card_test.dart
git commit -m "feat(sleep-mood): redesign shared trust sheet to match prototype"
```

---

## Phase 8 — Screens

> Before this phase, read these shared widgets for exact constructors: `lib/widgets/nav_bar.dart` (`TabHeaderScrollView`, `LargeTitleScrollView`, `NavIconButton`), `lib/widgets/inset_section.dart` (`InsetSection`, `ListRow`), `lib/widgets/controls.dart` (`Segmented`, `ProgressBar`), `lib/widgets/app_icon.dart`, `lib/widgets/press_scale.dart`, and an existing tab screen `lib/screens/nutrition/nutrition_screen.dart` as the structural reference. Each new screen is a `ConsumerWidget` that `ref.watch`es its controller and renders `.when(loading/error/data)`. Port the prototype component-by-component; all values (paddings, radii, font sizes, gradients) come from the referenced JSX, mapped to `AppType`/`Spacing`/`Radii`/`Elevation`/`context.colors`.

### Task 21: Sleep visual components (painters/widgets)

**Files:**
- Create: `lib/screens/sleep/widgets/sleep_widgets.dart` (`StageSplitBar`, `DurationBig`, `SleepTrendChart`)
- Test: `test/screens/sleep/sleep_widgets_test.dart` (pump each; assert it builds + shows key text like "7h 12m" and stage labels)

- [ ] **Step 1–4 (TDD):** For each component, write a pump test asserting it renders, run→fail, implement from the prototype `src/sleep-screens.jsx` (`StageSplit`, `DurationBig`, `SleepTrend`), run→pass.
  - `StageSplitBar(stages, light)` — the 4-segment proportional bar + Deep/REM/Core/Awake legend with `hmShort` values.
  - `DurationBig(minutes, usualMinutes, light)` — big `Hh Mm` + "x more/less than your usual" line with arrow.
  - `SleepTrendChart(week, month, usualMinutes)` — `Segmented` Week/Month, bars with a dashed "usual" band, footer sentence.
- [ ] **Step 5: Commit** `feat(sleep-mood): sleep visual components`.

### Task 22: `SleepScreen` (+ needs-sync state)

**Files:**
- Create: `lib/screens/sleep/sleep_screen.dart`
- Test: `test/screens/sleep/sleep_screen_test.dart`

- [ ] **Step 1: Write the failing widget test** — override `sleepControllerProvider` with a fake `AsyncData(SleepState(...))` and `surfacedCorrelationsProvider` with `[]`; pump inside the app theme; assert the hero shows the last-night duration + a stage label; with `syncedNights < 3`, assert the needs-sync copy ("A few more nights") shows instead.
- [ ] **Step 2: fail → Step 3: implement** — `ConsumerWidget` using `TabHeaderScrollView`(title 'Sleep', subtitle 'synced from Health', a Health pill as `contextualAction`/trailing). Body: the indigo gradient hero (`DurationBig`, "restful" chip from `state.read`, `StageSplitBar`, the in-bed line), the `SleepTrendChart` card, and a Connections section rendering the first `surfacedCorrelations` that `involves(Dimension.sleep)` via `CorrelationCard`. Needs-sync variant per prototype `SleepEmptyScreen` when `state.syncedNights < 3`. Gradient: `LinearGradient(155°, [c.sleep, c.sleep@0.9, c.sleep@0.7])` with `Elevation.card`.
- [ ] **Step 4: pass → Step 5: commit** `feat(sleep-mood): Sleep landing + needs-sync screen`.

### Task 23: Mood visual components + `MoodWeekChart`

**Files:**
- Create: `lib/screens/mood/widgets/mood_widgets.dart` (`MoodMiniScale`, `MoodWeekChart`, `MoodOrb`, `MoodScaleTrack`)
- Test: `test/screens/mood/mood_widgets_test.dart`

- [ ] **TDD each:** port from `src/mood-screens.jsx` (`MoodMiniScale`, `MoodWeek`) + `src/mood-screens.jsx` logger orb/track. `MoodOrb(t, dark)` is a `Container` with a radial gradient + morphing `BorderRadius`/scale per `t`. `MoodScaleTrack(t, onChanged)` is a `GestureDetector`/`Listener` over a gradient rail with a draggable thumb (pointer-x → `t`, mirroring the prototype `setFromX`). Pump tests assert build + that dragging changes the reported `t`.
- [ ] **Commit** `feat(sleep-mood): mood visual components (orb, scale, week)`.

### Task 24: `MoodScreen`

**Files:**
- Create: `lib/screens/mood/mood_screen.dart`
- Test: `test/screens/mood/mood_screen_test.dart`

- [ ] **TDD:** override `moodControllerProvider` with fake state; assert the "today leans" hero word, the check-ins list rows, the week chart, and a Connections card render; the teal "+" opens the logger sheet (Task 25). `ConsumerWidget` + `TabHeaderScrollView`(title 'Mood', subtitle 'how you've been feeling', trailing "+" `NavIconButton`/teal button). Body per prototype `MoodTabScreen`.
- [ ] **Commit** `feat(sleep-mood): Mood landing screen`.

### Task 25: `MoodLoggerSheet`

**Files:**
- Create: `lib/screens/mood/mood_logger_sheet.dart` (+ a `showMoodLogger(context)` helper)
- Test: `test/screens/mood/mood_logger_sheet_test.dart`

- [ ] **TDD:** pump the sheet; assert the word readout updates when `t` changes (drag the track), tag chips toggle, and tapping "Log mood" calls `moodController.logCheckin(t, tag)` (override the controller with a spy/fake) then closes. Build from prototype `MoodLoggerSheet`/`MoodSheet`: title "Check in", the `MoodOrb`, the live `moodWord` readout colored via `moodColor`, the `MoodScaleTrack`, optional one-word tag chips (a `MOOD_TAGS` const ported into the file or `mood_scale.dart`), the helper line, and a "Log mood" primary button tinted by `moodColor(t)`. Present via `showModalBottomSheet` (or the router `_sheetPage` if launched as a route).
- [ ] **Commit** `feat(sleep-mood): mood check-in logger sheet`.

---

## Phase 9 — Navigation hub + final verification

### Task 26: Dimensions hub + routes + Today entry

**Files:**
- Modify: `lib/router.dart` (`AppRoute` enum + `GoRoute`s under the Today branch)
- Create: `lib/screens/dimensions/dimensions_hub_screen.dart`
- Modify: `lib/screens/today/today_screen.dart` (add a "Dimensions" entry row → hub)
- Modify: `lib/widgets/app_icon.dart` (add any missing SF Symbol mappings: `moon.stars.fill`, `heart.fill`, `sparkles`, `arrow.up`, `arrow.down`, `xmark`, `plus`)
- Test: `test/router_test.dart` (or a focused nav widget test)

- [ ] **Step 1: Add routes** — in `lib/router.dart`, add to `AppRoute`:
```dart
  dimensionsHub('dimensionsHub', 'dimensions'),       // -> /today/dimensions
  sleep('sleep', 'dimensions/sleep'),                 // -> /today/dimensions/sleep
  mood('mood', 'dimensions/mood'),                    // -> /today/dimensions/mood
```
and nest three `GoRoute`s under the Today branch (sibling to `spendingDetail`), each `builder` returning the matching screen.

- [ ] **Step 2: Hub screen** — `DimensionsHubScreen` (`LargeTitleScrollView` title 'Dimensions') with one `InsetSection` of two `ListRow`s: Sleep (`moon.stars.fill`, `sleepTint` tile, `onTap` → `context.pushNamed(AppRoute.sleep.name)`) and Mood (`heart.fill`, `moodTint` tile → `AppRoute.mood`). Built to extend with future rows.

- [ ] **Step 3: Today entry** — add a single `ListRow`/section on `today_screen.dart` ("Dimensions", chevron) → `context.pushNamed(AppRoute.dimensionsHub.name)`. Match the placement/format of existing Today rows (read the file first).

- [ ] **Step 4: AppIcon mappings** — add any missing glyphs to `app_icon.dart`'s map (Cupertino fallbacks): `moon.stars.fill`, `heart.fill`, `sparkles`, `arrow.up`, `arrow.down`, `xmark`, `plus`.

- [ ] **Step 5: Test + commit** — widget/router test: navigating `/today/dimensions` shows the hub with Sleep & Mood rows; tapping each pushes the right screen; the three deep-link paths resolve.
```bash
git add lib/router.dart lib/screens/dimensions/dimensions_hub_screen.dart lib/screens/today/today_screen.dart lib/widgets/app_icon.dart test/router_test.dart
git commit -m "feat(sleep-mood): Dimensions hub off Today + routes"
```

### Task 27: Full verification pass

- [ ] **Step 1:** `dart run build_runner build --delete-conflicting-outputs` → no errors.
- [ ] **Step 2:** `flutter analyze` → zero issues.
- [ ] **Step 3:** `flutter test` → all green (existing + new).
- [ ] **Step 4:** Run the app with the demo seed and walk the prototype's 7 states:
  `flutter run --dart-define=SEED_DATA=true` (use the project's usual run target). Verify: Today → Dimensions → Sleep (hero, stage split, Week/Month trend, connection → trust sheet); Sleep needs-sync (temporarily with `< 3` nights); Mood (hero, check-ins, week, connection → trust sheet); Mood logger (orb morphs, drag sets the word, tag chips, Log mood persists and the new check-in appears). Confirm light + dark.
- [ ] **Step 5:** Confirm Recap + Nutrition Patterns still render their connections correctly (shared-widget regression).
- [ ] **Step 6: Final commit** (if any cleanup): `chore(sleep-mood): verification pass`.

---

## Self-review notes (coverage vs spec)

- Area 1 (theme) → Task 1. Area 2 (data) → Tasks 2–8. Area 3 (health) → Tasks 13–14. Area 4 (engine) → Tasks 10–12 (+ Task 9 for mood helpers it imports). Area 5 (shared card/sheet) → Tasks 18–20. Area 6 (controllers) → Tasks 15–16. Area 7 (seed) → Task 17. Area 8 (screens) → Tasks 21–25. Area 9 (nav) → Task 26. Verification → Task 27.
- "Restful" read: derived in `SleepController` (Task 15), not a stored column — keeps the migration to exactly two `createTable`s (matches Area 2's column list).
- The engineered-seed acceptance is enforced by a real test (Task 17 Step 1), not eyeballing.
- Numbers are computed, not authored (Area 5 source/numbers derive from the `Correlation`).
