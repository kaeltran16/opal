# Design System — Token Scales & Full Migration

Date: 2026-06-15
Status: Approved design, ready for implementation planning

## Problem

The app has a genuine *theme* — color and typography are tokenized — but not a complete
*design system*. Geometry and elevation are magic numbers scattered across ~47 screen and
widget files:

- **Color** (`lib/theme/app_colors.dart`): semantic `AppColors` `ThemeExtension`, light/dark,
  8 accents, accessed via `context.colors`. Adopted in 49 files. Solid.
- **Typography** (`lib/theme/app_text.dart`): `AppFonts.sf` / `sfr` / `mono` helpers. Adopted in
  43 files. But call sites pass raw `size:` values — font sizes are still magic numbers.
- **Spacing**: 873 raw `EdgeInsets` / `SizedBox` literals. No scale.
- **Radius**: 236 raw `BorderRadius.circular(...)` literals. No scale.
- **Elevation**: 27 inline `BoxShadow(...)` definitions. No tokens.
- **On-color / scrim**: ~80 hardcoded colors — `0xFFFFFFFF` foregrounds (64×), black-alpha
  scrims, shadow alphas, plus a handful of duplicated domain hues.

## Goal

Close all four gaps so spacing, radius, elevation, type, and on-color values are named tokens,
then migrate every existing literal in `lib/` to use them. Rationalize irregular values to clean
ramps (approved: snap outliers, accept sub-2px visual nudges).

Non-goals: redesigning any screen, changing the existing color palette or accent system,
restructuring the widget layer, or touching native iOS / widget extension code.

## Decisions (locked)

1. **Scope** — all four categories: spacing + radius, elevation/shadow, on-color/scrim, type ramp.
2. **Migration** — scaffold tokens AND fully migrate all literals across the ~47 files.
3. **Structure** — split by variance:
   - Theme-*invariant* tokens (`Spacing`, `Radii`, `Elevation` geometry, `AppType`) as plain
     `const`/`static` classes — no `BuildContext`.
   - Theme-*varying* values (`onAccent`, `scrim`, `shadow`) added to the existing `AppColors`
     `ThemeExtension`, accessed via `context.colors`.
4. **Fidelity** — rationalize to clean ramps. Outliers snap to the nearest token. The high-frequency
   loose values `10` and `14` snap up (`10→12`, `14→16`); radius `18→16`. Full snap tables below.

## File layout

```
lib/theme/
  app_colors.dart    (EXTEND — add onAccent, scrim, shadow)
  app_text.dart      (KEEP — AppFonts stays the low-level primitive)
  app_type.dart      (NEW — named type ramp built on AppFonts)
  spacing.dart       (NEW — const Spacing)
  radii.dart         (NEW — const Radii)
  elevation.dart     (NEW — Elevation geometry presets; take themed shadow color)
  theme.dart         (NEW — barrel export: one import for screens)
```

## Token definitions

### Spacing (4pt grid)

```dart
class Spacing {
  static const xxs  = 2.0;
  static const xs   = 4.0;
  static const sm   = 8.0;
  static const md   = 12.0;
  static const lg   = 16.0;
  static const xl   = 20.0;
  static const xxl  = 24.0;
  static const xxxl = 32.0;
}
```

Snap table (value in use → token):

| In use | Token | Δpx |
|--------|-------|-----|
| 2 | xxs | 0 |
| 3 | xs (4) | +1 |
| 4 | xs | 0 |
| 5 | xs (4) | -1 |
| 6 | sm (8) | +2 |
| 7 | sm (8) | +1 |
| 8 | sm | 0 |
| 10 | md (12) | +2 (49 uses — most visible snap) |
| 12 | md | 0 |
| 14 | lg (16) | +2 (24 uses) |
| 16 | lg | 0 |
| 18 | xl (20) | +2 |
| 20 | xl | 0 |
| 22 | xxl (24) | +2 |
| 24 | xxl | 0 |
| 32 | xxxl | 0 |

Net effect: a subtle, app-wide tightening/loosening of ≤2px on elements that used off-grid values.
Approved.

### Radii

```dart
class Radii {
  static const xs   = 4.0;   // dots, tiny chips
  static const sm   = 8.0;
  static const md   = 12.0;
  static const card = 14.0;  // workhorse (37 uses)
  static const lg   = 16.0;  // large cards
  static const xl   = 20.0;
  static const xxl  = 28.0;  // sheets
  static const pill = 999.0; // capsules / fully rounded
}
```

Snap table:

| In use (freq) | Token | Δpx |
|---------------|-------|-----|
| 1, 2, 2.5, 3, 4, 5 | xs (4) | ≤ +3 / -1 |
| 6, 7, 8, 9 | sm (8) | ≤ ±2 |
| 10, 11, 12, 13 | md (12) | ≤ ±2 |
| 14 (37) | card | 0 |
| 16 (22) | lg | 0 |
| 18 (25) | lg (16) | -2 |
| 20 (3), 22 (2) | xl (20) | 0 / -2 |
| 26 (1), 28 (2) | xxl (28) | +2 / 0 |
| 100 (34), 999 (1) | pill | n/a (both mean "fully rounded") |

Note `18→16`: both 16 and 18 are common and distinct; folding into one `lg=16` avoids two adjacent
tokens. Approved.

### Elevation

Geometry presets as a small class; shadow **color** is themed and passed in (shadows are
near-invisible on the dark `#000` background, so the color legitimately varies by mode):

```dart
class Elevation {
  static List<BoxShadow> sm(Color c) =>
      [BoxShadow(color: c, blurRadius: 8,  offset: const Offset(0, 2))];
  static List<BoxShadow> card(Color c) =>
      [BoxShadow(color: c, blurRadius: 16, offset: const Offset(0, 6))];
  static List<BoxShadow> fab(Color c) =>
      [BoxShadow(color: c, blurRadius: 24, offset: const Offset(0, 8))];
}
// usage: boxShadow: Elevation.card(context.colors.shadow)
```

The 27 inline `BoxShadow`s collapse onto these three levels by blur radius (≤8 → sm, ~16 → card,
≥24 → fab). Exact per-site mapping is decided during migration; any site that doesn't fit the three
levels is recorded in the implementation plan rather than force-fit.

### Type ramp

Named styles built on the existing `AppFonts` primitives. **No color baked in** — color is
theme-varying, applied at the call site via `.copyWith(color: context.colors.x)` or inherited from
the app-level `DefaultTextStyle`.

```dart
class AppType {
  static final caption2 = AppFonts.sf(size: 11, weight: FontWeight.w400);
  static final caption  = AppFonts.sf(size: 12, weight: FontWeight.w400);
  static final footnote = AppFonts.sf(size: 13, weight: FontWeight.w400);
  static final subhead  = AppFonts.sf(size: 15, weight: FontWeight.w400, letterSpacing: -0.23);
  static final callout  = AppFonts.sf(size: 16, weight: FontWeight.w400);
  static final body     = AppFonts.sf(size: 17, weight: FontWeight.w400, letterSpacing: -0.43);
  static final headline = AppFonts.sf(size: 17, weight: FontWeight.w600, letterSpacing: -0.43);
  static final title3   = AppFonts.sf(size: 20, weight: FontWeight.w600);
  static final title2   = AppFonts.sf(size: 22, weight: FontWeight.w700);
  static final title1   = AppFonts.sf(size: 28, weight: FontWeight.w700);
  static final large    = AppFonts.sf(size: 34, weight: FontWeight.w700);
  // rounded + tabular — amounts, counts, timers:
  static final amount   = AppFonts.sfr(size: 34);
  static final amountLg = AppFonts.sfr(size: 48);
  // mono — eyebrows, timestamps:
  static final eyebrow  = AppFonts.mono(size: 12);
}
```

Size snap table:

| In use (freq) | Token |
|---------------|-------|
| 8, 9, 10 | caption2 (11) |
| 11 (46) | caption2 |
| 12 (75) | caption |
| 13 (78) | footnote |
| 14 (48) | footnote (13) or subhead (15) — pick per role during migration |
| 15 (119) | subhead |
| 16 (38) | callout |
| 17 (73) | body / headline (by weight) |
| 18 (12), 20 (11) | title3 (20) |
| 22 (19) | title2 |
| 24 (6), 26 (7), 28 (10) | title1 (28) |
| 30, 32, 34 | large (34) / amount |
| 40, 44, 46, 48, 54 | amountLg (48) |
| 56, 72, 180, 220 | case-by-case (hero numerics) — kept inline if outside the ramp |

`size: 14` is the one genuinely ambiguous step (between footnote and subhead); resolved per call
site by role (secondary label vs. body-ish), recorded in the plan.

Weight nuance: existing call sites pass varied weights for the same size. The ramp encodes the
**default** weight per role; sites needing a different weight use `AppType.body.copyWith(fontWeight: …)`.
Where an existing site's (size, weight) pair has no clean ramp entry, prefer the nearest role and
record it; do not invent new ramp steps.

### Color additions to `AppColors`

Add three fields to the `AppColors` `ThemeExtension` (constructor, both `light`/`dark` factories,
`copyWith`, and `lerp`):

```dart
final Color onAccent;  // foreground on accent / colored fills — 0xFFFFFFFF both modes
final Color scrim;     // modal / barrier backdrop — black ~40%
final Color shadow;    // shadow color feeding Elevation (lighter/near-zero in dark)
```

Migration also folds these existing hardcoded colors into tokens:

- `0xFFFFFFFF` foregrounds on colored fills → `context.colors.onAccent` (64 uses).
- `0x66000000` / `0x59000000` / `0x33000000`-as-backdrop → `context.colors.scrim`.
- Shadow alphas (`0x14000000`, `0x1F000000`, `0x24000000`) → consumed by `Elevation` via
  `context.colors.shadow`.
- Duplicated domain hues (`0xFFFF9500`/`0xFFFF9F0A` → `money`, `0xFFBF5AF2`/`0xFFAF52DE` → `rituals`,
  green variants → `move`, accent variants → `accent`) → the existing `context.colors.*` tokens.
- `0x00000000` → `Colors.transparent`.

**Explicitly left alone:** Gmail brand colors in `lib/widgets/gmail_glyph.dart`
(`0xFF4285F4`, `0xFFEA4335`, `0xFFFBBC04`, `0xFF34A853`) and the Google-grey `gmail` surfaces —
these are real brand values, not theme tokens. Any white/black used as a *literal brand* element
(not a themed foreground) stays inline, judged per site.

## Migration approach

**Tokens first, then migrate file-by-file, batched by feature area** (approach A):

1. Land all token files in one commit (no call-site changes yet) — `Spacing`, `Radii`, `Elevation`,
   `AppType`, `theme.dart` barrel, and the `AppColors` additions with light/dark/copyWith/lerp updated.
2. Migrate `lib/widgets/` first (the shared layer — establishes the pattern and fixes the most reuse).
3. Then each `lib/screens/<area>/` folder, one batch per area.
4. After each batch: `flutter analyze` clean + the area's existing widget tests pass.

Rationale: localizes review per area and lets tests catch regressions incrementally, rather than one
47-file diff. Each batch is a reviewable commit.

## Verification

- `flutter analyze` must stay clean after every batch.
- Existing widget tests (`today_screen_test`, `move_screen_test`, `profile_test`,
  `rituals_test`, `onboarding_test`, `new_entry_test`, etc.) must pass after each batch.
- **Gap — no golden tests exist.** `grep matchesGoldenFile` over `test/` returns nothing, so the
  pixel snaps from rationalization are **not** caught automatically. Two options for the plan to
  resolve:
  - (a) Add golden tests for 3–5 key screens *before* migrating, capturing the pre-snap baseline,
    then review the post-migration goldens as the explicit record of every visual change. Recommended
    given "rationalize" was chosen.
  - (b) Manual visual spot-check of the running build per area, accepting that ≤2px nudges are
    intended and unverified by CI.
- Token-value sanity: after migration, a repo grep should show near-zero raw `circular(`,
  `EdgeInsets.all(<number>`, and `BoxShadow(` outside `lib/theme/` (excepting the documented
  brand/hero exceptions, which the plan enumerates).

## Risks

- **Silent visual drift.** Rationalization moves real pixels; without goldens, regressions ship
  unnoticed. Mitigated by verification option (a).
- **Ambiguous snaps** (`size: 14`, weight mismatches, off-ramp radii) require per-site judgment;
  risk of inconsistent choices across 47 files. Mitigated by migrating the shared `lib/widgets/`
  layer first to set precedent, and recording every non-obvious snap in the plan.
- **Scope creep into redesign.** The migration must preserve intent, not "improve" layouts. Any site
  where the current value looks wrong is flagged, not silently changed.

## Open items for the implementation plan

- Choose verification option (a) goldens vs (b) manual; if (a), which 3–5 screens.
- Resolve the `size: 14` → footnote/subhead split and any off-ramp (size, weight) pairs per site.
- Enumerate the brand/hero color and numeric exceptions that stay inline.
