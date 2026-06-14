# Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add complete design-system token scales (spacing, radius, elevation, type) plus on-color/scrim color tokens, then migrate every literal across `lib/screens` and `lib/widgets` to use them.

**Architecture:** Theme-invariant tokens (`Spacing`, `Radii`, `Elevation`, `AppType`) as plain `const`/`static` classes; theme-varying values (`onAccent`, `scrim`, `shadow`) added to the existing `AppColors` `ThemeExtension`. Tokens land first (Phase 0), a local golden baseline is captured (Phase 1), then migration proceeds folder-by-folder with `flutter analyze` + widget tests + golden review after each (Phase 2).

**Tech Stack:** Flutter / Dart, `flutter_test`, `flutter_riverpod`, existing `AppColors` ThemeExtension + `AppFonts` primitives.

**Spec:** `docs/superpowers/specs/2026-06-15-design-system-design.md` (read it first — it carries the full snap tables this plan references).

**Branch:** `feat/design-system` (already created; spec already committed there).

---

## Conventions for every task

- Run commands from repo root `C:\Users\cktra\Projects\opal`.
- Tests: `flutter test test/<file>`. Analyzer: `flutter analyze`.
- Commit messages: conventional commits, no co-author, WHY in the body. Commit per task.
- Token files are theme-invariant `const` — never import `BuildContext` into `spacing.dart`, `radii.dart`, or `app_type.dart`.

---

## Phase 0 — Token scaffolding

No call-site changes in this phase. Each token file is independently testable and committed on its own.

### Task 1: Spacing scale

**Files:**
- Create: `lib/theme/spacing.dart`
- Test: `test/theme/spacing_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/spacing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/spacing.dart';

void main() {
  test('Spacing exposes the 4pt ramp', () {
    expect(Spacing.xxs, 2.0);
    expect(Spacing.xs, 4.0);
    expect(Spacing.sm, 8.0);
    expect(Spacing.md, 12.0);
    expect(Spacing.lg, 16.0);
    expect(Spacing.xl, 20.0);
    expect(Spacing.xxl, 24.0);
    expect(Spacing.xxxl, 32.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/spacing_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:opal/theme/spacing.dart'`.

- [ ] **Step 3: Write the implementation**

```dart
// lib/theme/spacing.dart

/// 4pt spacing scale. Theme-invariant — use directly, no BuildContext.
/// See docs/superpowers/specs/2026-06-15-design-system-design.md for the
/// snap table mapping legacy literals onto these tokens.
class Spacing {
  Spacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/spacing_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/spacing.dart test/theme/spacing_test.dart
git commit -m "feat(theme): add Spacing 4pt scale

First of the invariant token scales; no call sites migrated yet."
```

---

### Task 2: Radii scale

**Files:**
- Create: `lib/theme/radii.dart`
- Test: `test/theme/radii_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/radii_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/radii.dart';

void main() {
  test('Radii exposes the semantic radius ramp', () {
    expect(Radii.xs, 4.0);
    expect(Radii.sm, 8.0);
    expect(Radii.md, 12.0);
    expect(Radii.card, 14.0);
    expect(Radii.lg, 16.0);
    expect(Radii.xl, 20.0);
    expect(Radii.xxl, 28.0);
    expect(Radii.pill, 999.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/radii_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/theme/radii.dart

/// Corner-radius scale. Theme-invariant. `card` (14) is the workhorse; `pill`
/// (999) means fully rounded. Snap table in the design spec.
class Radii {
  Radii._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double card = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/radii_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/radii.dart test/theme/radii_test.dart
git commit -m "feat(theme): add Radii radius scale"
```

---

### Task 3: AppType ramp

`AppType` is built on the existing `AppFonts` primitives (`lib/theme/app_text.dart`:
`sf({required size, weight, color, letterSpacing, height, tabular})`,
`sfr({required size, weight=w700, ...})`, `mono({required size, weight=w500, letterSpacing=0.5})`).
Styles carry **no color** — color is applied at call sites via `.copyWith(color:)` or inherited
from the app-level `DefaultTextStyle`.

**Files:**
- Create: `lib/theme/app_type.dart`
- Test: `test/theme/app_type_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/app_type_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_type.dart';

void main() {
  test('AppType ramp has the expected sizes and carries no color', () {
    expect(AppType.caption2.fontSize, 11);
    expect(AppType.caption.fontSize, 12);
    expect(AppType.footnote.fontSize, 13);
    expect(AppType.subhead.fontSize, 15);
    expect(AppType.callout.fontSize, 16);
    expect(AppType.body.fontSize, 17);
    expect(AppType.headline.fontSize, 17);
    expect(AppType.headline.fontWeight, FontWeight.w600);
    expect(AppType.title3.fontSize, 20);
    expect(AppType.title2.fontSize, 22);
    expect(AppType.title1.fontSize, 28);
    expect(AppType.large.fontSize, 34);
    expect(AppType.amount.fontSize, 34);
    expect(AppType.amountLg.fontSize, 48);
    expect(AppType.eyebrow.fontSize, 12);

    // Color is theme-varying — never baked into the ramp.
    expect(AppType.body.color, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/app_type_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/theme/app_type.dart
import 'package:flutter/widgets.dart';

import 'app_text.dart';

/// Named type ramp built on [AppFonts]. Theme-invariant: NO color baked in.
/// Apply color at the call site (`AppType.body.copyWith(color: context.colors.ink)`)
/// or let it inherit from the app-level DefaultTextStyle.
class AppType {
  AppType._();

  static final TextStyle caption2 = AppFonts.sf(size: 11);
  static final TextStyle caption = AppFonts.sf(size: 12);
  static final TextStyle footnote = AppFonts.sf(size: 13);
  static final TextStyle subhead = AppFonts.sf(size: 15, letterSpacing: -0.23);
  static final TextStyle callout = AppFonts.sf(size: 16);
  static final TextStyle body = AppFonts.sf(size: 17, letterSpacing: -0.43);
  static final TextStyle headline =
      AppFonts.sf(size: 17, weight: FontWeight.w600, letterSpacing: -0.43);
  static final TextStyle title3 = AppFonts.sf(size: 20, weight: FontWeight.w600);
  static final TextStyle title2 = AppFonts.sf(size: 22, weight: FontWeight.w700);
  static final TextStyle title1 = AppFonts.sf(size: 28, weight: FontWeight.w700);
  static final TextStyle large = AppFonts.sf(size: 34, weight: FontWeight.w700);

  // Rounded + tabular — amounts, counts, timers.
  static final TextStyle amount = AppFonts.sfr(size: 34);
  static final TextStyle amountLg = AppFonts.sfr(size: 48);

  // Mono — eyebrows, timestamps.
  static final TextStyle eyebrow = AppFonts.mono(size: 12);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/app_type_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_type.dart test/theme/app_type_test.dart
git commit -m "feat(theme): add AppType named type ramp over AppFonts"
```

---

### Task 4: AppColors on-color / scrim / shadow tokens

Add three fields to `AppColors` (`lib/theme/app_colors.dart`). This touches the constructor, both
factories, `copyWith`, and `lerp` — all must stay consistent or the analyzer/lerp will break.

`onAccent` is white in both modes (matches the 64 existing hardcoded `0xFFFFFFFF` foregrounds).
Pre-existing edge case, out of scope: the `graphite` accent in dark mode is near-white, so
white-on-graphite is low-contrast — this already exists today and is not addressed here.

**Files:**
- Modify: `lib/theme/app_colors.dart`
- Test: `test/theme/app_colors_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/app_colors_test.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  test('light/dark carry onAccent, scrim, shadow', () {
    final light = AppColors.light(AppAccent.blue);
    final dark = AppColors.dark(AppAccent.blue);

    expect(light.onAccent, const Color(0xFFFFFFFF));
    expect(dark.onAccent, const Color(0xFFFFFFFF));
    expect(light.scrim.a, closeTo(0.40, 0.001)); // black 40%
    expect(dark.scrim.a, closeTo(0.40, 0.001));
    expect(light.shadow.a, lessThan(dark.shadow.a)); // dark needs more to show
  });

  test('copyWith preserves the new tokens across brightness flip', () {
    final dark = AppColors.light(AppAccent.blue)
        .copyWith(brightness: Brightness.dark);
    expect(dark.onAccent, const Color(0xFFFFFFFF));
    expect(dark.scrim.a, closeTo(0.40, 0.001));
  });

  test('lerp interpolates the new tokens', () {
    final a = AppColors.light(AppAccent.blue);
    final b = AppColors.dark(AppAccent.blue);
    final mid = a.lerp(b, 0.5) as AppColors;
    expect(mid.shadow, Color.lerp(a.shadow, b.shadow, 0.5));
    expect(mid.scrim, Color.lerp(a.scrim, b.scrim, 0.5));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/app_colors_test.dart`
Expected: FAIL — `The getter 'onAccent' isn't defined for the class 'AppColors'`.

- [ ] **Step 3: Add the fields to the constructor and declarations**

In `lib/theme/app_colors.dart`, add to the constructor parameter list (after `required this.red,`):

```dart
    required this.onAccent,
    required this.scrim,
    required this.shadow,
```

Add to the field declarations (after `final Color red;`):

```dart
  final Color onAccent;
  final Color scrim;
  final Color shadow;
```

- [ ] **Step 4: Set the values in both factories**

In `AppColors.light(...)`, before the closing `);`, add:

```dart
      onAccent: const Color(0xFFFFFFFF),
      scrim: const Color.fromRGBO(0, 0, 0, 0.40),
      shadow: const Color.fromRGBO(0, 0, 0, 0.12),
```

In `AppColors.dark(...)`, before the closing `);`, add:

```dart
      onAccent: const Color(0xFFFFFFFF),
      scrim: const Color.fromRGBO(0, 0, 0, 0.40),
      shadow: const Color.fromRGBO(0, 0, 0, 0.40),
```

- [ ] **Step 5: Update `copyWith` to carry the tokens from base**

In `copyWith`, add these three lines before the closing `);` (they read from the rebuilt `base`,
matching how the other neutral tokens are handled):

```dart
      onAccent: base.onAccent,
      scrim: base.scrim,
      shadow: base.shadow,
```

- [ ] **Step 6: Update `lerp` to interpolate the tokens**

In `lerp`, add before the closing `);`:

```dart
      onAccent: c(onAccent, other.onAccent),
      scrim: c(scrim, other.scrim),
      shadow: c(shadow, other.shadow),
```

- [ ] **Step 7: Run test + analyzer**

Run: `flutter test test/theme/app_colors_test.dart && flutter analyze lib/theme/app_colors.dart`
Expected: PASS, analyzer clean.

- [ ] **Step 8: Commit**

```bash
git add lib/theme/app_colors.dart test/theme/app_colors_test.dart
git commit -m "feat(theme): add onAccent, scrim, shadow tokens to AppColors

Theme-varying values for foreground-on-fill, modal backdrops, and
elevation; wired through constructor, factories, copyWith, and lerp."
```

---

### Task 5: Elevation presets

Geometry presets that take the themed shadow color (`context.colors.shadow`), so elevation respects
light/dark. Collapses the 27 inline `BoxShadow`s onto three levels.

**Files:**
- Create: `lib/theme/elevation.dart`
- Test: `test/theme/elevation_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/elevation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/elevation.dart';

void main() {
  test('Elevation presets use the supplied color and rise by blur', () {
    const c = Color(0x1F000000);
    expect(Elevation.sm(c).single.blurRadius, 8);
    expect(Elevation.card(c).single.blurRadius, 16);
    expect(Elevation.fab(c).single.blurRadius, 24);
    expect(Elevation.card(c).single.color, c);
    expect(Elevation.card(c).single.offset, const Offset(0, 6));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/elevation_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/theme/elevation.dart
import 'package:flutter/painting.dart';

/// Elevation presets. Pass the themed shadow color (`context.colors.shadow`):
/// shadows vary by mode, so the color is not baked in.
///   boxShadow: Elevation.card(context.colors.shadow)
class Elevation {
  Elevation._();

  static List<BoxShadow> sm(Color color) =>
      [BoxShadow(color: color, blurRadius: 8, offset: const Offset(0, 2))];

  static List<BoxShadow> card(Color color) =>
      [BoxShadow(color: color, blurRadius: 16, offset: const Offset(0, 6))];

  static List<BoxShadow> fab(Color color) =>
      [BoxShadow(color: color, blurRadius: 24, offset: const Offset(0, 8))];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/elevation_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/elevation.dart test/theme/elevation_test.dart
git commit -m "feat(theme): add Elevation presets taking themed shadow color"
```

---

### Task 6: Theme barrel export

One import for migration call sites: `import 'package:opal/theme/theme.dart';`.

**Files:**
- Create: `lib/theme/theme.dart`

- [ ] **Step 1: Write the barrel**

```dart
// lib/theme/theme.dart
export 'app_colors.dart';
export 'app_text.dart';
export 'app_type.dart';
export 'elevation.dart';
export 'radii.dart';
export 'spacing.dart';
```

- [ ] **Step 2: Verify it analyzes**

Run: `flutter analyze lib/theme/theme.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/theme/theme.dart
git commit -m "feat(theme): add theme.dart barrel export"
```

---

## Phase 1 — Golden baseline (pre-migration)

Capture the current pixels for the key screens BEFORE any literal moves, so the migration's
intentional snaps show up as reviewable golden diffs. Goldens are a **local migration-verification
harness**, captured on this machine; they are not added to CI (Flutter goldens are platform-sensitive
on text anti-aliasing, and the repo has no CI goldens today). They may be deleted after the migration
lands, or kept — decide at the finish step.

Five screens with existing widget-test harnesses to reuse: `today`, `move`, `profile`, `rituals`,
and the `new_entry` sheet.

### Task 7: Golden baseline for 5 key screens

**Files:**
- Create: `test/golden/design_system_golden_test.dart`
- Create (generated): `test/golden/goldens/*.png`

- [ ] **Step 1: Write the golden test**

Follow the existing harness (ProviderScope + `sharedPreferencesProvider` / `loopDatabaseProvider`
overrides + `LoopApp` + `flushProviderTimers`, see `test/today_screen_test.dart`). One pumped
seeded app, one golden per screen reached by navigation. Pin a fixed surface so goldens are stable.

```dart
// test/golden/design_system_golden_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/flush_provider_timers.dart';

void main() {
  testWidgets('Today golden', (tester) async {
    tester.view.physicalSize = const Size(390, 844); // iPhone logical-ish
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'settings.onboardingComplete': true});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
      ],
      child: const LoopApp(),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/today.png'),
    );
    await flushProviderTimers(tester);
  });

  // Repeat the same harness for the other four screens, navigating to each via
  // its bottom-nav tab / entry point before expectLater:
  //   - move:     tap the Move/Workout tab, golden 'goldens/move.png'
  //   - rituals:  tap the Rituals tab, golden 'goldens/rituals.png'
  //   - profile:  tap the You tab, golden 'goldens/profile.png'
  //   - new_entry: tap the + FAB to open the sheet, golden 'goldens/new_entry.png'
  // Use find.text(<tab label>) + tester.tap + pumpAndSettle to navigate, mirroring
  // the navigation already exercised in test/move_screen_test.dart and
  // test/new_entry_test.dart.
}
```

- [ ] **Step 2: Capture the baseline**

Run: `flutter test --update-goldens test/golden/design_system_golden_test.dart`
Expected: PASS; `test/golden/goldens/*.png` created. Eyeball each PNG — it must look like the
current app. If a screen failed to navigate, fix the tap/finder before proceeding.

- [ ] **Step 3: Verify the goldens now match (no-update run)**

Run: `flutter test test/golden/design_system_golden_test.dart`
Expected: PASS (the just-captured goldens match).

- [ ] **Step 4: Commit**

```bash
git add test/golden/
git commit -m "test(theme): capture pre-migration golden baseline for 5 screens

Local migration-verification harness; not wired into CI."
```

---

## Phase 2 — Migration

### Per-folder migration procedure (apply to every Task 8–N)

This procedure is identical for each batch; the only thing that changes is the file list. For each
file in the batch:

1. Add `import 'package:opal/theme/theme.dart';` (or the specific token import) and remove now-dead
   color/style imports if any.
2. **Radius:** replace `BorderRadius.circular(N)` / `Radius.circular(N)` per the spec's radius snap
   table (e.g. `circular(18)` → `Radii.lg`, `circular(11)` → `Radii.md`, `circular(100)` → `Radii.pill`).
3. **Spacing:** replace numeric `EdgeInsets.*`, `SizedBox(width/height: N)`, and gap values per the
   spec's spacing snap table (e.g. `EdgeInsets.all(14)` → `EdgeInsets.all(Spacing.lg)`,
   `SizedBox(height: 10)` → `SizedBox(height: Spacing.md)`). `1.0`/`0.5` hairline values stay literal.
4. **Type:** replace `AppFonts.sf(size: N, ...)` call sites with the matching `AppType.*` style per
   the spec's size snap table, moving any `color:` into `.copyWith(color: …)`. Where an existing
   `(size, weight)` pair has no clean ramp entry, pick the nearest role and note it in the commit body.
5. **Color:** `0xFFFFFFFF` foreground-on-fill → `context.colors.onAccent`; backdrop blacks
   (`0x66000000`, `0x59000000`, `0x33000000`-as-scrim) → `context.colors.scrim`; duplicated domain
   hues → `context.colors.money|move|rituals|accent`; `0x00000000` → `Colors.transparent`. Inline
   `BoxShadow(...)` → `Elevation.sm|card|fab(context.colors.shadow)` by blur radius.
6. **Leave inline (do NOT migrate):** Gmail brand colors in `lib/widgets/gmail_glyph.dart`; literal
   brand glyph colors; hero numerics outside the ramp (`size: 72/180/220`) — keep literal, note them.

**Worked example** (before → after):

```dart
// before
Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  decoration: BoxDecoration(
    color: context.colors.accent,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 6))],
  ),
  child: Text('Save',
      style: AppFonts.sf(size: 15, weight: FontWeight.w600, color: const Color(0xFFFFFFFF))),
)

// after
Container(
  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
  decoration: BoxDecoration(
    color: context.colors.accent,
    borderRadius: BorderRadius.circular(Radii.lg),
    boxShadow: Elevation.card(context.colors.shadow),
  ),
  child: Text('Save',
      style: AppType.subhead.copyWith(
          fontWeight: FontWeight.w600, color: context.colors.onAccent)),
)
```

Note `horizontal: 14 → Spacing.lg (16)` and `vertical: 12 → Spacing.md (12)` per snap table; the
`14→16` move is one of the documented intentional nudges.

**Verification after each batch:**

1. `flutter analyze` — must be clean (no new issues).
2. Run the batch's existing widget tests (these assert text/structure, not pixels — they must still
   PASS). Mapping of folders → tests:
   - `widgets/`: `flutter test test/widget_test.dart test/today_screen_test.dart`
   - `today/`, `shell/`: `flutter test test/today_screen_test.dart test/widget_test.dart`
   - `move/`, `library/`: `flutter test test/move_screen_test.dart test/exercise_library_test.dart test/weekly_plan_test.dart`
   - `rituals/`: `flutter test test/rituals_test.dart test/rituals_builder_test.dart test/routine_editor_test.dart`
   - `workout/`: `flutter test test/active_session_test.dart test/start_workout_test.dart test/post_workout_test.dart`
   - `pal/`: `flutter test test/ask_pal_test.dart test/quick_actions_test.dart`
   - `entry/`, `quick_actions/`, `detail/`: `flutter test test/new_entry_test.dart test/spending_detail_test.dart test/quick_actions_test.dart`
   - `email/`: `flutter test test/email_sync_test.dart`
   - `profile/`, `settings/`: `flutter test test/profile_test.dart test/settings_repository_test.dart`
   - `onboarding/`: `flutter test test/onboarding_test.dart`
   - `reflect/`, `review/`: `flutter test test/monthly_review_test.dart test/weekly_review_test.dart`
   - `money/`: `flutter test test/spending_detail_test.dart`
3. Golden review (only batches that touch a goldened screen — today/move/rituals/profile/new_entry):
   - `flutter test test/golden/design_system_golden_test.dart` → expected to FAIL with pixel diffs.
   - Open the `*_masked_diff.png` / failure output. Confirm every diff is an intended snap (≤2px
     geometry shift, radius/type change from the tables). If a diff is unexpected (color wrong,
     element moved/disappeared), the migration broke something — fix before regenerating.
   - Re-baseline: `flutter test --update-goldens test/golden/design_system_golden_test.dart`.
   - This re-baselining IS the review record; include the updated goldens in the batch commit.

---

### Task 8: Migrate `lib/widgets/` (shared layer — do first)

**Files (Modify):** `lib/widgets/activity_rings.dart`, `app_icon.dart`, `budget_sheet.dart`,
`controls.dart`, `gmail_glyph.dart` (color-exempt — only spacing/radius/type), `inset_section.dart`,
`keypad.dart`, `loop_tab_bar.dart`, `nav_bar.dart`, `press_scale.dart`, `summary_tile.dart`.

- [ ] **Step 1:** Apply the per-folder migration procedure to each file above.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/widget_test.dart test/today_screen_test.dart` — PASS.
- [ ] **Step 4:** Golden review (this layer affects every screen): run goldens, confirm diffs are only intended snaps, re-baseline.
- [ ] **Step 5: Commit**

```bash
git add lib/widgets/ test/golden/
git commit -m "refactor(widgets): migrate shared widgets to design tokens

Establishes the token-usage pattern; golden baseline updated for the
intended geometry/type snaps."
```

---

### Task 9: Migrate `lib/screens/today/` and `lib/screens/shell/`

**Files (Modify):** `lib/screens/today/today_screen.dart`, `lib/screens/shell/*.dart`.

- [ ] **Step 1:** Apply the migration procedure to each file.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/today_screen_test.dart test/widget_test.dart` — PASS.
- [ ] **Step 4:** Golden review (today): confirm intended diffs, re-baseline.
- [ ] **Step 5: Commit**

```bash
git add lib/screens/today/ lib/screens/shell/ test/golden/
git commit -m "refactor(today): migrate Today + shell to design tokens"
```

---

### Task 10: Migrate `lib/screens/move/` and `lib/screens/library/`

**Files (Modify):** `lib/screens/move/move_screen.dart`, `lib/screens/move/weekly_plan_screen.dart`,
`lib/screens/library/exercise_library_screen.dart`. Note the local `const _white = Color(0xFFFFFFFF)`
in `move_screen.dart` / `weekly_plan_screen.dart` / `exercise_library_screen.dart` → replace usages
with `context.colors.onAccent` and delete the `_white` const.

- [ ] **Step 1:** Apply the migration procedure to each file; remove the `_white` consts.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/move_screen_test.dart test/exercise_library_test.dart test/weekly_plan_test.dart` — PASS.
- [ ] **Step 4:** Golden review (move): confirm intended diffs, re-baseline.
- [ ] **Step 5: Commit**

```bash
git add lib/screens/move/ lib/screens/library/ test/golden/
git commit -m "refactor(move): migrate Move + library to design tokens"
```

---

### Task 11: Migrate `lib/screens/rituals/`

**Files (Modify):** `lib/screens/rituals/rituals_screen.dart`, `rituals_builder_screen.dart`,
`routine_player_screen.dart`.

- [ ] **Step 1:** Apply the migration procedure to each file.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/rituals_test.dart test/rituals_builder_test.dart test/routine_editor_test.dart` — PASS.
- [ ] **Step 4:** Golden review (rituals): confirm intended diffs, re-baseline.
- [ ] **Step 5: Commit**

```bash
git add lib/screens/rituals/ test/golden/
git commit -m "refactor(rituals): migrate Rituals screens to design tokens"
```

---

### Task 12: Migrate `lib/screens/workout/`

**Files (Modify):** `active_session_screen.dart`, `post_workout_screen.dart`,
`routine_editor_screen.dart`, `routine_generator_screen.dart`, `start_workout_screen.dart`,
`workout_detail_screen.dart`.

- [ ] **Step 1:** Apply the migration procedure to each file.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/active_session_test.dart test/start_workout_test.dart test/post_workout_test.dart test/routine_editor_test.dart` — PASS.
- [ ] **Step 4: Commit** (no goldened screen here)

```bash
git add lib/screens/workout/
git commit -m "refactor(workout): migrate Workout screens to design tokens"
```

---

### Task 13: Migrate `lib/screens/pal/`

**Files (Modify):** `ask_pal_screen.dart`, `pal_composer_screen.dart`, `pal_inbox_screen.dart`.

- [ ] **Step 1:** Apply the migration procedure to each file.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/ask_pal_test.dart test/ask_pal_controller_test.dart test/quick_actions_test.dart` — PASS.
- [ ] **Step 4: Commit**

```bash
git add lib/screens/pal/
git commit -m "refactor(pal): migrate Pal screens to design tokens"
```

---

### Task 14: Migrate `lib/screens/entry/`, `quick_actions/`, `detail/`

**Files (Modify):** `entry/new_entry_sheet.dart`, `quick_actions/quick_actions_overlay.dart`,
`detail/detail_screen.dart`.

- [ ] **Step 1:** Apply the migration procedure to each file.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/new_entry_test.dart test/spending_detail_test.dart test/quick_actions_test.dart` — PASS.
- [ ] **Step 4:** Golden review (new_entry): confirm intended diffs, re-baseline.
- [ ] **Step 5: Commit**

```bash
git add lib/screens/entry/ lib/screens/quick_actions/ lib/screens/detail/ test/golden/
git commit -m "refactor(entry): migrate entry/quick-actions/detail to design tokens"
```

---

### Task 15: Migrate `lib/screens/email/`

**Files (Modify):** `email_dashboard_screen.dart`, `email_intro_screen.dart`, `email_setup_screen.dart`,
`email_nav.dart`. Keep Gmail brand colors literal where they represent the Gmail brand.

- [ ] **Step 1:** Apply the migration procedure to each file (brand-color exemption applies).
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/email_sync_test.dart` — PASS.
- [ ] **Step 4: Commit**

```bash
git add lib/screens/email/
git commit -m "refactor(email): migrate Email screens to design tokens"
```

---

### Task 16: Migrate `lib/screens/profile/` and `lib/screens/settings/`

**Files (Modify):** `profile/profile_screen.dart`, `settings/about_screen.dart`,
`appearance_screen.dart`, `budgets_goals_screen.dart`, `export_data_screen.dart`,
`notifications_screen.dart`.

- [ ] **Step 1:** Apply the migration procedure to each file.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/profile_test.dart test/settings_repository_test.dart` — PASS.
- [ ] **Step 4:** Golden review (profile): confirm intended diffs, re-baseline.
- [ ] **Step 5: Commit**

```bash
git add lib/screens/profile/ lib/screens/settings/ test/golden/
git commit -m "refactor(profile): migrate Profile + Settings to design tokens"
```

---

### Task 17: Migrate `lib/screens/onboarding/`

**Files (Modify):** `onboarding/onboarding_screen.dart`.

- [ ] **Step 1:** Apply the migration procedure.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/onboarding_test.dart` — PASS.
- [ ] **Step 4: Commit**

```bash
git add lib/screens/onboarding/
git commit -m "refactor(onboarding): migrate Onboarding to design tokens"
```

---

### Task 18: Migrate `lib/screens/reflect/`, `review/`, `money/`

**Files (Modify):** `reflect/evening_close_out_screen.dart`, `reflect/streak_celebration_screen.dart`,
`review/monthly_review_screen.dart`, `review/weekly_review_screen.dart`, and any `money/` screen files.

- [ ] **Step 1:** Apply the migration procedure to each file.
- [ ] **Step 2:** `flutter analyze` — clean.
- [ ] **Step 3:** `flutter test test/monthly_review_test.dart test/weekly_review_test.dart test/spending_detail_test.dart` — PASS.
- [ ] **Step 4: Commit**

```bash
git add lib/screens/reflect/ lib/screens/review/ lib/screens/money/
git commit -m "refactor(reflect): migrate Reflect/Review/Money to design tokens"
```

---

### Task 19: Sweep for stragglers + final verification

**Files:** any remaining file under `lib/` flagged by the grep below (e.g. `lib/router.dart`
barrier colors, `app.dart` DefaultTextStyle).

- [ ] **Step 1: Find remaining literals**

```bash
git grep -nE "circular\([0-9]|EdgeInsets\.(all|symmetric)\([^A-Za-z]*[0-9]|BoxShadow\(|Color\(0x" -- lib ':!lib/theme/*' ':!*.g.dart' ':!lib/widgets/gmail_glyph.dart'
```
Expected: only the documented exemptions remain (brand colors, hero numerics, hairline `1.0`/`0.5`
sizes, transparent). Investigate anything else.

- [ ] **Step 2:** Migrate any stragglers found (router barrier colors → `context.colors.scrim`, etc.) per the procedure.
- [ ] **Step 3: Full suite + analyzer**

Run: `flutter analyze && flutter test`
Expected: analyzer clean; all tests PASS (goldens already re-baselined per batch).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(theme): migrate remaining literals; close design-system migration"
```

---

## Self-review notes (spec coverage)

- Spacing / Radii / Elevation / AppType scales → Tasks 1, 2, 5, 3. ✓
- on-color / scrim / shadow on AppColors → Task 4. ✓
- File layout (theme.dart barrel, split-by-variance) → Tasks 1–6. ✓
- Full migration of ~47 files (widgets + every screen folder) → Tasks 8–19. ✓
- Approach A (tokens first, widgets first, folder batches, analyze + tests per batch) → phase order. ✓
- Verification gap (no goldens) → Phase 1 golden baseline + per-batch golden review. ✓
- Rationalize/snap decisions → referenced via spec snap tables in the migration procedure. ✓
- Exemptions (Gmail brand, hero numerics) → procedure step 6 + Task 15. ✓

## Open items carried from the spec (resolve during execution)

- `size: 14` (48 uses): footnote-13 vs subhead-15 per call-site role — decided per file in Phase 2.
- Whether to keep the golden harness after migration or delete it — decide at the finishing step
  (`superpowers:finishing-a-development-branch`).
