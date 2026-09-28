# AI-first Redesign (P0-P3, Today, You, log sheet) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the mockup-covered part of the AI-first Liquid Glass redesign: tokens, deterministic
goldens, token cleanup, glass foundations, the 4-tab shell, the Pal-first Today, the You tab and the
glass log sheet.

**Architecture:** Glass is drawn in Flutter (`BackdropFilter`) behind one `GlassSurface` widget. It
is used only on the tab bar, the ask bar, sheets and the collapsed top edge. The shell drops from 6
branches to 4, and old paths redirect. Today's facts come from local providers through pure
functions. Pal's text comes from the existing insights seam, cached by `todayBriefProvider`.

**Tech Stack:** Flutter 3.44.1, Riverpod 3 (codegen), go_router 16, drift, `package:clock`.

**Spec:** `docs/superpowers/specs/2026-09-28-ai-first-redesign-design.md` (decisions 1-9). Mockups:
`C:\Users\cktra\Projects\opal\.superpowers\design\ai-first\project\` (`TodayGlass`, `TodayFallback`,
`TodayScrolled`, `YouGlass`, `LogGlass` `.dc.html`). Open them in a browser to match layout.

## Global Constraints

- No backend or `PalService` contract change. No new dependency except `clock` (already in
  `pubspec.lock`).
- Glass only on the tab bar, the ask bar, sheets and the collapsed top edge bar. Never on cards or
  list content. At most 4 `BackdropFilter`s on screen.
- Chip and fallback numbers come from local providers, never from the model. The brief lead
  sentence never states numbers.
- Touch targets are at least 44 pt. Primary buttons are 52 tall.
- Top-level cards use `Radii.xxl` (28). Buttons and chips use `Radii.pill`. `Radii.card` keeps its
  meaning for inner elements.
- Every `AppRoute` path that exists today still resolves. Moved routes keep their `AppRoute` name,
  and their old path redirects.
- Comments explain why, not what, and are lower case. Match surrounding code style.
- After adding or changing any `@riverpod` annotation, run
  `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart`. CI fails on
  stale codegen.
- Goldens are machine-local (Ahem font) and tagged `golden`. Regenerate only the goldens a task
  intentionally changes (`flutter test --update-goldens <file>`), and say which ones in the commit
  body.
- Do not touch `server/`.

## Review Focus

1. **Deep links into moved routes while a different tab is active** (Siri `/sleep`, a Live Activity
   `/rituals`). The expected result is the Today branch showing the moved screen with a back
   affordance. Pinned in Task 8's router test.
2. **Zero or unset goals** (budget 0, move goal 0, 0 routines). The chip sentence and the fallback
   row must not divide by zero or show "-$5 left". Pinned in Task 6's unit tests.
3. **Brief refresh failing after an earlier success.** The last good headline stays and the
   fallback never replaces it. Pinned in Task 6's controller test.
4. **Reduce Transparency toggled while the app runs.** Glass surfaces switch to solid without a
   restart. Pinned in Task 5's widget test through a stream override.
5. **Undo on a Done by Pal entry that was already deleted elsewhere.** Undo must not throw, and the
   row disappears. Pinned in Task 9.

---

**Effort:** effort:579571b0-46fa-4c4f-8c84-43719b4b615c
**Verify:** `if [ -n "$ARC_VERIFY_CHANGED" ] && ! grep -qE '^(lib|test|ios)/|^pubspec|^analysis_options|^dart_test' "$ARC_VERIFY_CHANGED"; then echo "no app paths changed"; exit 0; fi; flutter analyze --fatal-infos && flutter test`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter build web --release`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\ai-first\project

### Task 1: Deterministic clock and the golden safety net (P1)
**Depends on:** none
**Chunk:** P1: golden safety net (all main screens, light + dark)

The current goldens fail on 2026-09-28 (`today.png` 0.47% diff, and `move` and `profile` also fail)
because the seeded data and every screen use `DateTime.now()`. Fix the cause first, then capture
the baseline.

**Files:**
- Modify: `pubspec.yaml` (add `clock: ^1.1.2` under dependencies, then `flutter pub get`)
- Modify: every `lib/**/*.dart` that calls `DateTime.now()` (58 files; list them with
  `grep -rl "DateTime.now()" lib`). This includes `lib/data/seed/`.
- Modify: `test/golden/design_system_golden_test.dart`
- Create: `test/support/golden_harness.dart`

- [ ] **Step 1:** Replace `DateTime.now()` with `clock.now()` across `lib/` and add
  `import 'package:clock/clock.dart';` to each touched file. This is a mechanical transform, so do it
  with a script (for example `sed -i 's/DateTime\.now()/clock.now()/g'`), then add the imports. Do not
  change anything else in those files.
- [ ] **Step 2:** Run `flutter analyze --fatal-infos && flutter test --exclude-tags golden`. Expected:
  all pass (692 tests on 2026-09-28).
- [ ] **Step 3:** Create `test/support/golden_harness.dart` by moving `ignoreOverflowErrors`,
  `pinSurface` and `bootApp` out of the golden test, and add:
  - `final goldenClock = Clock.fixed(DateTime(2026, 9, 28, 9, 30));` (a Monday morning, so the
    greeting reads "Good morning").
  - A `dark` flag on `bootApp`. When it is true, it sets `'settings.brightness': 'dark'` in the mock
    prefs.
  - `Future<void> goldenTest(String name, Future<void> Function(WidgetTester t, bool dark) body)`,
    which registers `testWidgets('golden: $name (light)')` and `('... (dark)')`. Each one runs its body
    inside `withClock(goldenClock, () async { ... })`.
- [ ] **Step 4:** Rewrite `design_system_golden_test.dart` to use the harness, with one golden per
  main screen per theme, saved as `goldens/<name>_<light|dark>.png`: `today`, `move`, `nutrition`,
  `rituals`, `sleep`, `mood`, `profile`, `pal`, `spending_detail`, `pal_composer` and `new_entry`.
  - Reach each screen by driving the app: `GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path)`
    with `/move`, `/nutrition`, `/rituals`, `/sleep`, `/mood`, `/you`, `/pal`, `/today/spending` and
    `/pal-composer`. Using paths instead of tab-bar taps keeps these tests working when Task 8
    replaces the tab bar.
  - Keep the existing `new_entry` standalone router.
  - Delete the old un-suffixed PNGs.
- [ ] **Step 5:** Run `flutter test --update-goldens test/golden`, then run `flutter test test/golden`
  twice. Expected: pass both times. Add a check that the fixed clock actually reaches the UI: the
  `today_light` test asserts `find.textContaining(RegExp('september 28', caseSensitive: false))`
  before capture, so a stray `DateTime.now()` shows up as a failure rather than as silent drift.
  Match case-insensitively, because Task 9's eyebrow renders the date in upper case.
- [ ] **Step 6:** Commit: `test(golden): pin the clock and baseline every main screen in both themes`.

### Task 2: Tokens: glass, area inks, accent inks, brief type (P0)
**Depends on:** Task 1
**Chunk:** P0: translate direction into token values

**Files:**
- Modify: `lib/theme/app_colors.dart`, `lib/theme/app_type.dart`
- Create: `lib/theme/contrast.dart`
- Test: `test/theme/contrast_test.dart`, `test/theme/app_colors_test.dart`, `test/theme/app_type_test.dart`

**Interfaces (produces):**
- `AppColors` fields: `glass`, `glassBorder`, `glassHighlight`, `moneyInk`, `moveInk`, `ritualsInk`,
  `nutritionInk`, `sleepInk`, `moodInk`, `accentInk`. Also `Color inkForType(String type)`, which
  mirrors `forType`.
- `AppAccentInfo.inkLight()` and `AppAccentInfo.inkDark()`, both returning `Color`.
- `AppType.brief` (28/38, w600, letterSpacing -0.4).
- `double contrastRatio(Color fg, Color bg)` and `Color composite(Color top, Color bottom)` in
  `lib/theme/contrast.dart`.

- [ ] **Step 1: Write the failing contrast test.**

```dart
// test/theme/contrast_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/theme/contrast.dart';

void main() {
  test('contrastRatio matches WCAG reference values', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFF777777), const Color(0xFFFFFFFF)), closeTo(4.48, 0.01));
  });

  for (final accent in AppAccent.values) {
    for (final dark in [false, true]) {
      final c = dark ? AppColors.dark(accent) : AppColors.light(accent);
      final mode = dark ? 'dark' : 'light';
      test('${accent.name}/$mode: every ink passes 4.5:1 on its tint over surface', () {
        final pairs = {
          'money': (c.moneyInk, c.moneyTint),
          'move': (c.moveInk, c.moveTint),
          'rituals': (c.ritualsInk, c.ritualsTint),
          'nutrition': (c.nutritionInk, c.nutritionTint),
          'sleep': (c.sleepInk, c.sleepTint),
          'mood': (c.moodInk, c.moodTint),
          'accent': (c.accentInk, c.accentTint),
        };
        pairs.forEach((name, p) {
          final bg = composite(p.$2, c.surface);
          expect(contrastRatio(p.$1, bg), greaterThanOrEqualTo(4.5), reason: name);
        });
      });
    }
  }
}
```

- [ ] **Step 2:** Run `flutter test test/theme/contrast_test.dart`. Expected: compile failure
  (`contrast.dart` is missing).
- [ ] **Step 3:** Implement `lib/theme/contrast.dart`: WCAG 2.x relative luminance (sRGB channel
  linearisation: `c <= 0.04045 ? c/12.92 : pow((c+0.055)/1.055, 2.4)`), the ratio
  `(L1+0.05)/(L2+0.05)`, and `composite` as source-over alpha blending. Make it pure, with no Flutter
  widgets.
- [ ] **Step 4:** Add the fields to `AppColors`: the constructor, `light`/`dark` factories,
  `copyWith` (add an optional `Color? accentInk`; when `accent` is passed without it, keep
  `this.accentInk`) and `lerp`. Starting values, from the spec (light / dark):
  - moneyInk `#B45400` / `#FFB340`
  - moveInk `#1E7B34` / `#4CDB73`
  - ritualsInk `#8A2FB8` / `#D08CF7`
  - sleepInk `#3F4FBF` / `#A3ADF5`
  - moodInk `#1B7688` / `#7FD3E6`
  - nutritionInk: start from `#0B7F8E` / `#6FE0EC`
  - glass `rgba(255,255,255,.52)` / `rgba(44,44,48,.52)`
  - glassBorder `rgba(255,255,255,.70)` / `rgba(255,255,255,.14)`
  - glassHighlight `rgba(255,255,255,.95)` / `rgba(255,255,255,.18)`

  `accentInk` comes from a new explicit table in `AppAccentInfo` (`inkLight()` and `inkDark()`,
  8 × 2 `const Color`s). Start blue at `#0060DF` / `#5AAEFF`. For every other accent, darken (light
  mode) or lighten (dark mode) the accent until the test passes. Write the final values as literal
  consts; do not compute them at runtime.
- [ ] **Step 5:** Run the contrast test. Adjust any value that fails and re-run until it is green.
- [ ] **Step 6:** Add `AppType.brief` and extend `app_type_test.dart` (size 28, height 38/28). Extend
  `app_colors_test.dart`:
  - `lerp(a, b, 0)` keeps the new fields.
  - `copyWith(accent:)` keeps `accentInk` unless one is passed.
  - `inkForType('sleep') == sleepInk`, and an unknown type gives `accentInk`.
- [ ] **Step 7:** Run `flutter test test/theme test/golden`. Expected: pass. The goldens are unchanged
  because nothing reads the new tokens yet.
- [ ] **Step 8:** Commit: `feat(theme): add glass, area-ink and accent-ink tokens checked for 4.5:1`.

### Task 3: Token cleanup, part A: widgets and the workout, money and nutrition screens (P2)
**Depends on:** Task 1

Zero visual change. Scope: these existing widget files, by name: `activity_rings.dart`,
`app_icon.dart`, `bar_chart.dart`, `budget_sheet.dart`, `controls.dart`, `correlation_card.dart`,
`correlation_view.dart`, `dashed_border.dart`, `donut_chart.dart`, `gmail_glyph.dart`,
`inset_section.dart`, `keypad.dart`, `nav_bar.dart`, `pal_avatar.dart`, `press_scale.dart`,
`spend_ring.dart` and `summary_tile.dart`, all in `lib/widgets/`. Never touch the new widget files
Tasks 5-7 create. Also in scope:
`lib/screens/{workout,move,nutrition,email,money,library,entry,detail}/**`. Do NOT touch
`today_screen.dart`, `loop_shell.dart`, `loop_tab_bar.dart`, `pal_screen.dart` or
`profile_screen.dart` (later tasks rewrite them) or any file outside this scope (Task 4 owns it).

- [ ] **Step 1:** List the candidates in scope:
  `grep -nE "Color\(0x|Color\.fromRGBO|circular\([0-9]|EdgeInsets\.[a-zA-Z]+\([^)]*[0-9]|SizedBox\((width|height): [0-9]|size: [0-9]" <files>`.
- [ ] **Step 2:** For each hit, replace the value only when it exactly equals an existing token:
  - `Spacing` 2/4/8/12/16/20/24/32
  - `Radii` 4/8/12/14/16/20/28/999
  - an `AppType` style whose size and weight match exactly
  - an `AppColors` token whose value is identical in both themes, or a pair that already exists as a
    token (for example `Color(0xFFFFFFFF)` used as text on accent is `c.onAccent`)

  Any other value stays, with a trailing `// kept literal: <why>` comment, which is the existing
  convention (8 uses today). Never round a value to a nearby token.
- [ ] **Step 3:** Run `flutter test test/golden`. Expected: PASS with no `--update-goldens`. A golden
  diff means a replacement changed a value, so revert it.
- [ ] **Step 4:** Run `flutter analyze --fatal-infos && flutter test`. Expected: all pass.
- [ ] **Step 5:** Commit: `refactor(theme): move widget and workout/money/nutrition literals onto tokens`.

### Task 4: Token cleanup, part B: rituals, sleep, mood, Pal composer and the other screens (P2)
**Depends on:** Task 1

The same rules as Task 3, steps 1-5. Scope:
- `lib/screens/{mood,sleep,onboarding,recap,reflect,rituals,settings}/**`
- `lib/screens/pal/pal_composer_screen.dart`, `lib/screens/pal/pal_noticed_section.dart`

Do NOT touch `tab_header.dart`, `loop_shell.dart`, `today_screen.dart`, `pal_screen.dart`,
`profile_screen.dart` or Task 3's scope. The goldens must pass unchanged.

Commit: `refactor(theme): move rituals/sleep/mood/pal/settings literals onto tokens`.

### Task 5: GlassSurface and the Reduce Transparency bridge
**Depends on:** Task 2

**Files:**
- Create: `lib/widgets/glass_surface.dart`, `lib/services/accessibility/reduce_transparency_service.dart`
- Modify: `lib/controllers/providers.dart` (plus the regenerated `.g.dart`), `ios/Runner/AppDelegate.swift`
- Test: `test/widgets/glass_surface_test.dart`

**Interfaces (produces):**
- `abstract class ReduceTransparencyService { Stream<bool> watch(); }`
- `NoopReduceTransparencyService` emits `false` once.
- `MethodChannelReduceTransparencyService` uses `MethodChannel('opal/accessibility')`. It calls
  `isReduceTransparencyEnabled` for the first value, then handles the native `reduceTransparencyChanged(bool)`
  calls. On a `MissingPluginException` or `PlatformException` it emits `false` and logs
  `debugPrint('reduce transparency bridge unavailable: $e')`, so it degrades visibly instead of
  swallowing the error.
- `@Riverpod(keepAlive: true) ReduceTransparencyService reduceTransparencyService(Ref)` uses the
  iOS-only selection, the same as `liveActivityService`.
- `@riverpod Stream<bool> reduceTransparency(Ref)` returns `service.watch()`.
- `GlassSurface({required Widget child, BorderRadius borderRadius = const BorderRadius.all(Radius.circular(Radii.pill)), EdgeInsetsGeometry? padding})`
  is a `ConsumerWidget`. `static const double blurSigma = 30;` is the single knob for the manual
  device raster check.

- [ ] **Step 1: Write the failing widget tests.** Pump a `GlassSurface` inside a `ProviderScope`,
  with `reduceTransparencyProvider.overrideWith((ref) => stream)`, under a themed `MaterialApp`:
  - With the stream at `false`: `find.byType(BackdropFilter)` finds one, and the decoration color
    equals `c.glass`.
  - With a `StreamController<bool>` that emits `false` and then `true` (pump between the two): the
    `BackdropFilter` is gone, and the color is `c.surface` with a 0.5 hairline border in `c.hair`.
    This pins Review Focus 4.
  - With `MediaQuery(data: MediaQueryData(highContrast: true))`: no transparency, the fill is
    opaque `c.surface`, and the border is 1.0 in `c.ink3`.
  - While the stream is loading: the widget renders glass (the default is off).
- [ ] **Step 2:** Run it and expect a FAIL.
- [ ] **Step 3:** Implement it:
  - `ClipRRect` → `BackdropFilter(filter: ImageFilter.compose(outer: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma), inner: ColorFilter.matrix(<saturation 1.8 matrix>)))`
    → `DecoratedBox` with the `glass` fill, a 0.5 `glassBorder` border and `boxShadow: Elevation.card(c.shadow)`.
  - Draw the 1 px `glassHighlight` top line as a `Positioned` line inside a `Stack`.
  - Add the solid branch from Step 1.
  - Implement the service, the providers and codegen.
- [ ] **Step 4:** In `AppDelegate.swift`, inside the existing `if let registrar` block, create
  `FlutterMethodChannel(name: "opal/accessibility", binaryMessenger: messenger)`:
  - Handle `isReduceTransparencyEnabled` by returning `UIAccessibility.isReduceTransparencyEnabled`.
  - Observe `UIAccessibility.reduceTransparencyStatusDidChangeNotification` and call
    `channel.invokeMethod("reduceTransparencyChanged", arguments: UIAccessibility.isReduceTransparencyEnabled)`.
  - Keep it inline in `AppDelegate.swift`, so no `project.pbxproj` edit is needed.
- [ ] **Step 5:** Run `flutter test test/widgets/glass_surface_test.dart`, then `flutter analyze --fatal-infos`.
  Expected: pass.
- [ ] **Step 6:** Commit: `feat(ui): add GlassSurface with a Reduce Transparency bridge`.

### Task 6: Today brief controller and Today's pure logic
**Depends on:** Task 2

**Files:**
- Create: `lib/controllers/today_brief_controller.dart` (plus `.g.dart`), `lib/screens/today/today_logic.dart`,
  `lib/widgets/brief_text.dart`, `lib/widgets/whats_left_row.dart`
- Test: `test/controllers/today_brief_controller_test.dart`, `test/screens/today_logic_test.dart`,
  `test/widgets/brief_text_test.dart`

**Interfaces (produces):**

```dart
// lib/controllers/today_brief_controller.dart
// holds the last good headline so a later failure never blanks the brief.
@riverpod
class TodayBrief extends _$TodayBrief {
  @override
  Future<String?> build();        // null until a non-empty headline has loaded
  Future<void> refresh();         // re-fetches; keeps the previous value on failure/empty
}

// lib/screens/today/today_logic.dart
enum TodayArea { routines, sleep, mood, money, move, nutrition }

class AreaStatus {
  const AreaStatus({required this.area, required this.complete, required this.minuteOfDay});
  final TodayArea area;
  final bool complete;
  final int minuteOfDay; // when the area is naturally due (sleep 0, mood 480, ...)
}

/// incomplete first, then by minuteOfDay, then by enum index (stable).
List<TodayArea> orderAreas(List<AreaStatus> statuses);

class GlanceNumbers {
  const GlanceNumbers({required this.spent, required this.budget, required this.moveKcal,
      required this.moveGoal, required this.routinesDone, required this.routinesTotal});
  final double spent, budget;
  final int moveKcal, moveGoal, routinesDone, routinesTotal;
  double get moneyLeft => (budget - spent).clamp(0, double.infinity);
  int get kcalToGo => (moveGoal - moveKcal).clamp(0, 1 << 31);
  int get routinesLeft => (routinesTotal - routinesDone).clamp(0, 1 << 31);
}

enum BriefMode { brief, fallback }
BriefMode briefMode(AsyncValue<String?> brief); // brief iff brief.value is non-empty

bool isDoneByPal(Entry e, DateTime now); // e.source == EntrySource.email && same local day as now
```

`BriefText({required String lead, required GlanceNumbers numbers, required String currency, required void Function(TodayArea) onChip})`
renders the lead in `AppType.brief` in `c.ink`, then the number sentence:
"You've spent [$38 of $60], moved [412 kcal] and done [4 of 5 routines]."
- Each bracket is a chip: an `AppFonts.sfr(weight: FontWeight.w800)` number in the area ink on the
  area tint, with `Radii.pill`, a minimum height of 44 and `Semantics(button: true, label: ...)`.
- The labels are exactly `'Spent $38 of $60, open Money'`, `'Moved 412 of 500 kcal, open Move'`
  and `'4 of 5 routines done, open Routines'`.
- When `budget == 0` the money chip reads `$38 spent`. When `routinesTotal == 0` the routines clause
  is omitted.
- Use `WidgetSpan`s inside one `Text.rich`, so it wraps like prose.

`WhatsLeftRow({required GlanceNumbers numbers, required String currency, required void Function(TodayArea) onTap})`
is three columns with 0.5 `c.hair` separators and no card. It shows the `$ left to spend`,
`kcal to go` and `routine(s) left` values in the area inks.
- Semantic labels: `'Spent $38 of $60, $22 left'`, `'Workout 412 of 500 kcal, 88 to go'` and
  `'Routines 4 of 5, 1 left'`.
- Below the row, a `c.ink3` footnote reads `Pal's brief is catching up`.

- [ ] **Step 1: Write the failing tests.**
  - `orderAreas`: incomplete ones come before complete ones, ties break by `minuteOfDay` and then by
    enum index, and an empty list gives an empty list.
  - `GlanceNumbers`: with spent 70 and budget 60, `moneyLeft` is 0 (never negative). With budget 0,
    it is 0. `routinesLeft` is 0 when the total is 0. This pins Review Focus 2.
  - `briefMode`:
    - `AsyncData('x')` gives brief.
    - `AsyncData(null)` and `AsyncData('')` give fallback.
    - `AsyncLoading()` gives fallback.
    - Do not build states with `copyWithPrevious`: it is `@internal` in riverpod 3 and fails
      `analyze --fatal-infos`. The "previous value survives" case is covered through the real
      controller below.
  - `isDoneByPal`: an email entry today is true, an email entry yesterday is false, and a manual
    entry today is false.
  - `TodayBrief`, with `palServiceProvider` overridden by a test-local
    `class _FakePal extends MockPalService` that overrides `insights()`. `MockPalService` takes only
    latency and a seed, so it can neither set a headline nor throw. The fake returns
    `PalInsights(headline: 'Steady start.')` on the first call and throws on the next:
    - After `build`, the state is `'Steady start.'`.
    - After `refresh()` throws, the state is still `AsyncData('Steady start.')`, and
      `briefMode(container.read(todayBriefProvider)) == BriefMode.brief`. Use a `ProviderContainer`.
      This pins Review Focus 3.
    - A first-load failure gives `AsyncData(null)`, not an error.
  - `BriefText`: the three chip semantics labels exist exactly as written above, and tapping the
    money chip calls `onChip(TodayArea.money)`. With `routinesTotal: 0` there is no routines chip.
    With `budget: 0` the chip text is `$38 spent`.
- [ ] **Step 2:** Run them and expect a FAIL.
- [ ] **Step 3:** Implement. `TodayBrief.build` calls `ref.read(palServiceProvider).insights(InsightRange.day)`
  and trims the headline, the same seam as `_PalScreenState._refreshBrief` (`lib/screens/pal/pal_screen.dart:56`).
  Catch errors at this boundary: keep the previous value and `debugPrint` the error with context.
  `refresh()` does not put the state into loading. It fetches, and assigns
  `state = AsyncData(headline)` only when the trimmed headline is non-empty, so a failed or empty
  refresh leaves the state untouched. Run the codegen.
- [ ] **Step 4:** Run the tests and `flutter analyze --fatal-infos`. Expected: pass.
- [ ] **Step 5:** Commit: `feat(today): brief controller, area ordering and glance widgets`.

### Task 7: GlassTabBar and PalAskBar
**Depends on:** Task 5, Task 3

**Files:**
- Create: `lib/widgets/glass_tab_bar.dart`, `lib/widgets/pal_ask_bar.dart`
- Modify: `lib/widgets/app_icon.dart`. Add `'mic.fill': CupertinoIcons.mic_fill` to the map; there
  is no mic icon today. Task 3 cleans this file first, hence the dependency.
- Test: `test/widgets/glass_tab_bar_test.dart`, `test/widgets/pal_ask_bar_test.dart`

**Interfaces (produces):**
- `class GlassTab { const GlassTab(this.id, this.label, this.icon); final String id, label, icon; }`
- `GlassTabBar({required List<GlassTab> tabs, required String activeId, required ValueChanged<String> onTab, required bool minimized, required VoidCallback onRestore})`
  - Expanded, it is a floating `GlassSurface` capsule with the tabs. The active tab uses
    `c.accent` for its icon and label and has a `c.fill` lens behind it.
  - Minimized, it is a 52 pt `GlassSurface` circle showing the active tab's icon. A tap calls
    `onRestore`.
  - Tabs use `Semantics(selected: id == activeId, button: true, label: label)`.
  - The minimize/restore transition is an `AnimatedSize` plus `AnimatedSwitcher` over 240 ms. When
    `MediaQuery.disableAnimationsOf(context)` is true, the duration is `Duration.zero` (Reduce
    Motion: a state swap only).
- `PalAskBar({required VoidCallback onAsk, required VoidCallback onMic})` is a `GlassSurface`
  capsule 52 tall with a `PalAvatar` sparkle, the placeholder `Ask or log anything` in `c.ink3` and
  a 44 × 44 mic button.
  - The whole bar has the semantics label `Ask or log anything`. The mic has `Dictate`.

- [ ] **Step 1: Write the failing tests.**
  - Tab bar: 4 tabs render their labels, tapping `Nutrition` calls `onTab('nutrition')`, and the
    active tab has the `selected` flag.
  - With `minimized: true`, only the active icon shows, with no labels. A tap calls `onRestore`.
  - With `MediaQueryData(disableAnimations: true)` and `minimized` flipped, one `pump()` (no
    duration) shows the final state.
  - Ask bar: tapping the bar calls `onAsk`, tapping the mic calls `onMic`, and every tap target is at
    least 44 × 44 (`tester.getSize`).
- [ ] **Step 2:** Run them and expect a FAIL.
- [ ] **Step 3:** Implement to match the TodayGlass and TodayScrolled mockups. Put the capsule 8 pt
  above the bottom safe area, with 16 pt side insets.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(ui): glass tab bar with scroll minimize and the Pal ask bar`.

### Task 8: Four-branch shell, route redirects and the glass composer sheet (P3)
**Depends on:** Task 7, Task 3, Task 4, Task 6
**Chunk:** P3: new foundations (tokens + 23 shared widgets)

**Files:**
- Modify: `lib/router.dart`, `lib/screens/shell/loop_shell.dart`, `lib/screens/shell/tab_header.dart`,
  `lib/widgets/nav_bar.dart` (the collapsed pinned bar becomes glass; Task 3 cleaned this file first),
  `lib/screens/profile/profile_screen.dart` (remove only the back `leading`),
  `lib/screens/pal/pal_composer_screen.dart` (sheet container only)
- Delete: `lib/widgets/loop_tab_bar.dart`
- Test: create `test/navigation/route_compat_test.dart` and `test/screens/shell_test.dart`, modify
  `test/large_title_scroll_view_test.dart`, and update the tests that reference
  `LoopTabBar`, `'More'`, `bySemanticsLabel('You')` or the header orb. Find them with
  `grep -rln "LoopTabBar\|'More'\|bySemanticsLabel('You')\|Open Pal" test`.
- Goldens: regenerate every golden, because the chrome changed on every tab screen.

**Interfaces (consumes):** `GlassTabBar`, `GlassTab`, `PalAskBar` (Task 7) and `GlassSurface` (Task 5).

- [ ] **Step 1: Write the failing route-compat test.** Boot `LoopApp` the same way
  `deep_link_routing_test.dart` does. For each path, `router.go(path)`, pump, and assert
  `router.state.uri.path` (or the `GoRouter.of(...).routerDelegate.currentConfiguration.uri`) equals
  the expected path:

```dart
const cases = {
  '/today': '/today', '/move': '/move', '/nutrition': '/nutrition',
  '/rituals': '/today/rituals', '/rituals/manage': '/today/rituals/manage',
  '/sleep': '/today/sleep', '/mood': '/today/mood',
  '/today/spending': '/today/spending', '/today/move-detail': '/today/move-detail',
  '/today/rituals-detail': '/today/rituals-detail',
  '/move/start': '/move/start', '/move/history': '/move/history',
  '/move/routine-editor': '/move/routine-editor', '/move/weekly-plan': '/move/weekly-plan',
  '/move/routine-generator': '/move/routine-generator',
  '/nutrition/patterns': '/nutrition/patterns',
  '/you': '/you', '/you/budgets': '/you/budgets', '/you/insights': '/you/insights',
  '/you/budgets-goals': '/you/budgets-goals', '/you/notifications': '/you/notifications',
  '/you/appearance': '/you/appearance', '/you/privacy': '/you/privacy',
  '/you/export': '/you/export', '/you/about': '/you/about',
  '/entry/new': '/entry/new', '/library': '/library', '/recap': '/recap',
  '/monthly-review': '/recap', '/weekly-review': '/recap',
  '/email': '/email', '/email/setup': '/email/setup', '/email/dashboard': '/email/dashboard',
  '/pal-composer': '/pal-composer', '/pal': '/pal', '/pal-home': '/pal', '/pal-inbox': '/pal',
  '/close-out': '/close-out', '/streak': '/streak',
  '/post-workout': '/post-workout',
  '/onboarding': '/today', // onboarding is complete in the test, so the gate bounces to Today
};
```

  Also add these cases:
  - Start on `/nutrition`, go to `/sleep`. The Today tab is selected
    (`Semantics selected` on `Today`), a `Back` button is shown, and tapping it lands on `/today`.
    This pins Review Focus 1.
  - `/rituals/player/<seeded ritual routine id>` still opens `RoutinePlayerScreen`.
  - `/session/<seeded workout routine id>` still opens `ActiveSessionScreen`. Take the id from
    `ref.read(workoutRoutinesStreamProvider.future)` through the `ProviderScope`'s container.
  - Every `AppRoute` value whose path starts with `/` and contains no `:` appears as a key in
    `cases`. Iterate `AppRoute.values`, so a newly added route without a case fails. The two
    parameterised root paths (`activeSession`, `routinePlayer`) are covered by the explicit cases
    above.
- [ ] **Step 2:** Run it and expect a FAIL (`/rituals` is not redirected yet).
- [ ] **Step 3:** Restructure `router.dart`:
  - The branches become `today`, `move`, `nutrition` and `you`.
  - Under `/today`, add child `GoRoute`s `rituals` (with its `manage` child), `sleep` and `mood`,
    using new `AppRoute` values:
    - `todayRituals('todayRituals', 'rituals')`
    - `todayManageRituals('todayManageRituals', 'manage')`
    - `todaySleep('todaySleep', 'sleep')`
    - `todayMood('todayMood', 'mood')`

    Route names must be unique, so the new children never reuse the old names.
  - The existing `AppRoute.rituals`, `sleep`, `mood` and `manageRituals` become top-level redirect
    routes to the new locations, keeping their names and paths. A route-level redirect on the
    parent `/rituals` also fires for `/rituals/manage`, so the `/rituals` redirect must map by
    path: `redirect: (context, state) => '/today${state.uri.path}'`. That turns `/rituals` into
    `/today/rituals` and `/rituals/manage` into `/today/rituals/manage`, and it preserves the query
    string by appending `state.uri.query` when it is non-empty. The route-compat cases pin both.
  - Move the `/you` route and its children into the fourth branch and drop its
    `parentNavigatorKey`.
  - Remove the rituals, sleep and mood navigator keys.
  - Leave `/pal` untouched (Task 10 redirects it).
  - Update every `pushNamed`/`goNamed` of `AppRoute.rituals`/`sleep`/`mood`/`manageRituals` in
    `lib/` to `todayRituals`/`todaySleep`/`todayMood`/`todayManageRituals`
    (`grep -rn "AppRoute\.\(rituals\|sleep\|mood\|manageRituals\)\b" lib`).
- [ ] **Step 4:** Rewrite `LoopShell`:
  - Remove the More overflow, `_MoreOverflowMenu` and the FAB.
  - The branch ids are `['today','move','nutrition','you']`, and the tabs are
    `GlassTab('today','Today','sun.max.fill')`, `('move','Workout','figure.run')`,
    `('nutrition','Nutrition','fork.knife')` and `('you','You','person.crop.circle.fill')`. Check
    each name exists in `lib/widgets/app_icon.dart`'s map and add it if missing.
  - Wrap `navigationShell` in a `NotificationListener<UserScrollNotification>`. A `reverse`
    direction sets `_minimized = true`, and `forward` sets it to `false`. Restore on tab change.
  - The bottom overlay is a `Row`. Expanded, it holds the `GlassTabBar` over the full width with the
    `PalAskBar` above it. Minimized, it holds the 52 pt circle plus an `Expanded(PalAskBar)` beside
    it, as in TodayScrolled.
  - Both `onAsk` and `onMic` call `context.pushNamed(AppRoute.palComposer.name)`.
  - Delete `lib/widgets/loop_tab_bar.dart`.
- [ ] **Step 5:** Update the headers:
  - In `TabHeaderScrollView`, remove the You avatar and the Pal orb, because You is a tab and the ask
    bar replaces the orb. Keep `contextualAction` as the only trailing widget.
  - The leading is now a back button when the route can pop:
    `GoRouter.of(context).canPop() ? NavAction(icon: 'chevron.left', label: 'Back', semanticLabel: 'Back', onTap: () => context.pop()) : null`.
    Sleep, Mood and Rituals keep using `TabHeaderScrollView` and get their back affordance to Today
    from this.
  - In `ProfileScreen`, remove only the back `leading`. Task 10 restyles the rest.
  - The glass collapsed top edge (spec, Glass rules). In `LargeTitleScrollView`'s pinned bar
    (`lib/widgets/nav_bar.dart`), the background is `c.bg` while fully expanded (`t == 0`). Once it
    starts collapsing, it becomes `GlassSurface(borderRadius: BorderRadius.zero, child: ...)`, and
    the hairline stays. This covers the tab roots and the pushed screens alike. The glass count at
    most is tab bar + ask bar + top edge + sheet = 4.
  - Test in `test/large_title_scroll_view_test.dart`: there is no `BackdropFilter` at rest, and there
    is one after dragging the list up by 200.
- [ ] **Step 6:** Make the composer a glass sheet. In the `palComposer` `pageBuilder`, set
  `barrierColor` to `c.scrim.withValues(alpha: 0.12)` in light mode and `0.35` in dark mode (the
  LogGlass values). In `PalComposerSheet`, wrap the outermost sheet container in
  `GlassSurface(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxl)))` in place of
  its solid decoration. Composer logic must not change: the diff to `pal_composer_screen.dart` should
  touch only the container and decoration lines.
- [ ] **Step 7:** Add widget tests in `test/screens/shell_test.dart`:
  - A drag-up scroll on Today minimizes the tab bar (only one tab icon is visible), and a drag-down
    restores it.
  - Tapping the ask bar opens `PalComposerSheet`, and so does tapping the mic.
  - The tabs carry the semantic labels `Today`, `Workout`, `Nutrition` and `You`.
- [ ] **Step 8:** Fix the existing tests found in Files. Run `flutter test --update-goldens test/golden`,
  review each PNG for chrome-only changes (tab bar and header), then run `flutter analyze --fatal-infos && flutter test`.
  Expected: all pass.
- [ ] **Step 9:** Point the tracker's manual raster-check item at the knob. The deferred dictation
  item (chunk 17) and the device raster check (chunk 18) were already added to the tracker at spec
  approval, so do not add new chunks. Run:
  `wsh effort chunk note 579571b0-46fa-4c4f-8c84-43719b4b615c 18 --note "blur knob: GlassSurface.blurSigma in lib/widgets/glass_surface.dart; glass surfaces: tab bar, ask bar, collapsed top edge, composer sheet"`.
- [ ] **Step 10:** Commit: `feat(shell): four glass tabs with an ask bar; old paths redirect`.

### Task 9: Pal-first Today (P4 Today)
**Depends on:** Task 8
**Chunk:** P4: redesign Today + detail

**Files:**
- Modify: `lib/screens/today/today_screen.dart` (rewrite the body)
- Modify: `lib/screens/pal/pal_screen.dart` (import the extracted agenda widgets, and use
  `greetingFor` in place of `_Hero._greeting`)
- Modify: `test/golden/design_system_golden_test.dart` (keep the case-insensitive date assertion from
  Task 1 matching the new `MONDAY, SEPTEMBER 28` eyebrow)
- Create: `lib/screens/pal/pal_agenda_widgets.dart`. Move `_NeedsYou`, `_AgentCard` and the card
  status logic out of `pal_screen.dart` as public `NeedsYouSection` and `AgentCard`. `PalScreen`
  imports them, so its behaviour is unchanged.
- Create: `lib/screens/today/today_area_cards.dart`
- Test: rewrite `test/today_screen_test.dart`. Goldens: regenerate `today_light` and `today_dark`
  only.

**Interfaces (consumes):** `todayBriefProvider`, `orderAreas`, `AreaStatus`, `GlanceNumbers`,
`briefMode`, `isDoneByPal`, `BriefText` and `WhatsLeftRow` (Task 6), plus `todayStateProvider`,
`sleepControllerProvider`, `moodControllerProvider`, `nutritionControllerProvider`,
`palAgendaProvider`, `entryRepositoryProvider.deleteById` and `settingsRepositoryProvider.displayNameOrDefault`.

Layout, top to bottom (TodayGlass, TodayFallback and TodayScrolled):
1. Header: the date eyebrow (`AppType.eyebrow`, `c.ink3`, e.g. `MONDAY, SEPTEMBER 28`), then the
   greeting in `AppType.large`: `Good morning|afternoon|evening, <name>`. Move the `_greeting` hour
   rule out of `pal_screen.dart:288` into `today_logic.dart` as `String greetingFor(DateTime now)`,
   and use it from both places.
2. `briefMode(ref.watch(todayBriefProvider))`:
   - `brief` shows a `Pal` label and `BriefText`.
   - `fallback` shows `WhatsLeftRow`.
   - Chip and column taps: money goes to `spendingDetail`, move to `moveDetail` and routines to
     `ritualsDetail`.
3. `NeedsYouSection`: pending proposals and a count badge, hidden when there are none.
4. Done by Pal: today's entries filtered with `isDoneByPal`. Each row shows its title and amount,
   the line `Done by Pal · from your Gmail receipt`, and an `Undo` button (44 pt) that calls
   `deleteById`. Wrap Undo in a try/catch. On failure, show a SnackBar
   `Couldn't undo. Try again.` and `debugPrint` the error. A row whose entry is already gone simply
   disappears on the next stream emit. This pins Review Focus 5. Hide the section when it is empty.
5. `Your day` with an `Ordered by Pal` caption: cards in `orderAreas(...)` order. The completion
   rules:
   - routines: `ritualsRemaining == 0`
   - sleep: `lastNight` is today, at minute 0
   - mood: `lastCheckin != null`, at minute 480
   - money: never complete (the budget runs all day), at minute 720
   - move: `moveKcal >= goal`, at minute 1020
   - nutrition: at least one meal today, at minute 750
   - routines' minute is the next incomplete routine's slot, or 1260 for evening.

   The card content follows TodayScrolled:
   - Routines: the next routine's name, its detail line and a `Start` pill button that opens
     `routinePlayer`.
   - Sleep: the time range, asleep duration, wake-ups and Deep/REM/Core stage figures.
   - Mood: the last check-in plus `How are you now?` with the 5 mood faces, which open the existing
     mood logger sheet.
   - Money, Move and Nutrition: the same card shell with their headline figure.

   Cards are `c.surface` with `Radii.xxl`, never glass. The taps are the ones listed in the spec's
   Today section 6.
6. Remove the rings hero, the summary tiles, the timeline and search, and delete their private
   widgets from `today_screen.dart`. Delete `RingStat`/`SummaryTile` only if nothing else references
   them (`grep`).

Bottom padding clears the shell overlay: keep the existing literal pattern with a `kept literal`
comment.

Refresh (spec, Today section 3): `TodayScreen` becomes a `ConsumerStatefulWidget`.
- Wrap the `TabHeaderScrollView` in a `RefreshIndicator` whose `onRefresh` awaits
  `ref.read(todayBriefProvider.notifier).refresh()` and calls `ref.invalidate(palAgendaProvider)`.
- Create an `AppLifecycleListener(onResume: _refresh)` in `initState`, pointing at the same method,
  and dispose it in `dispose`.
- There is no visible refresh button.

- [ ] **Step 1: Write the failing widget tests** in `test/today_screen_test.dart`, booting the
  seeded app under `withClock(Clock.fixed(DateTime(2026,9,28,9,30)))`:
  - Use a test-local subclass of `MockPalService` that overrides `insights()`. `MockPalService`
    itself only takes latency and a seed.
    - When it returns `'Steady start.'`, the text shows, and
      `find.bySemanticsLabel(RegExp(r'^Spent .* open Money$'))` taps through to the spending detail.
    - When it throws, `Pal's brief is catching up` shows, and there are three column semantics
      labels.
  - Needs you: override `palAgendaProvider.overrideWith((ref) async => PalAgenda(proposals: [...]))`.
    It is hidden with `const PalAgenda()` and shows the count `2` with two proposals.
  - With a seeded email entry today, `Undo` removes it (the repository no longer has it). Calling
    Undo on an id already deleted through the repository shows no exception.
  - With the Routines area complete and Sleep incomplete, the Sleep card appears above the Routines
    card (compare `tester.getTopLeft` dy).
  - There is no `ActivityRings`, and no `magnifyingglass` search button.
  - Refresh: the fake `insights()` counts its calls.
    - A fling down on the list (`tester.fling(find.byType(CustomScrollView).first, const Offset(0, 400), 1000)`
      plus `pumpAndSettle`) raises the count by 1, and a new headline returned on that call shows.
    - Driving `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused)` and then
      `.resumed` also raises the count by 1.
- [ ] **Step 2:** Run them and expect a FAIL.
- [ ] **Step 3:** Implement per the layout above.
- [ ] **Step 4:** Run `flutter test test/pal_home_test.dart test/screens/pal_home_memory_test.dart`.
  `PalScreen` must be unchanged after the extraction.
- [ ] **Step 5:** Run `flutter test --update-goldens test/golden/design_system_golden_test.dart --plain-name today`,
  and compare the PNGs against the TodayGlass mockup. Then run `flutter analyze --fatal-infos && flutter test`.
- [ ] **Step 6:** Commit: `feat(today): Pal-first Today with brief chips, needs-you and your-day cards`.

### Task 10: You tab carries the Pal hub; retire PalScreen
**Depends on:** Task 9

**Files:**
- Modify: `lib/app.dart`. In `_isOverlayRoute`, remove `/pal`, `/pal-inbox` and `/pal-home` from
  `overlays`. They now redirect into the `/you` shell branch, so a deep link must `go`, not `push`.
  Cover this in `test/deep_link_routing_test.dart`: emit `/pal`, and expect the You tab selected with
  the `What Pal remembers` text visible.
- Modify: `lib/screens/profile/profile_screen.dart`, `lib/router.dart`,
  `lib/screens/pal/pal_agenda_widgets.dart` (add `MemoryCard`, `AutopilotRow` and the toggle, moved
  from `pal_screen.dart`)
- Delete: `lib/screens/pal/pal_screen.dart`, and any leftover references to `AppRoute.pal` pushes in
  `lib/` (point them at `AppRoute.you`)
- Test: update `test/pal_home_test.dart`, `test/screens/pal_home_memory_test.dart` and
  `test/profile_test.dart` to target the You tab, plus the `route_compat_test.dart` expectations for
  `/pal`, `/pal-home` and `/pal-inbox`, which now go to `/you`. Goldens: regenerate `profile_*`, and
  delete the `pal_*` goldens and their test case.

The layout follows YouGlass:
1. The profile card: initial avatar, name, and `<n>-day workout streak` from
   `moveStreakDays(allEntries)`. This is the same source `PalScreen` used, so it never uses the
   agenda's `streakDays`.
2. `Pal`: `MemoryCard` ("What Pal remembers"), the autopilot rows with toggles (keep the optimistic
   override map, moved into You's state), then `PalNoticedSection`.
3. `Goals`, then the existing Money, Reviews (without the Pal row), Integrations, Data and Account
   sections. Top-level cards are `Radii.xxl` on `c.surface`. The goal glyph squares use the area
   inks.

- [ ] **Step 1:** Port the assertions from `pal_home_test.dart` and `pal_home_memory_test.dart` to
  the You tab (memory delete, autopilot toggle, noticed section). Add the three redirect expectations
  to `route_compat_test.dart`. Run them and expect a FAIL.
- [ ] **Step 2:** Implement. The `/pal`, `/pal-home` and `/pal-inbox` routes become redirects to
  `/you`, keeping their `AppRoute` names. Delete `PalScreen` and its hero.
- [ ] **Step 3:** Run `flutter test --update-goldens test/golden/design_system_golden_test.dart --plain-name profile`,
  remove the `pal` golden case and its PNGs, then run `flutter analyze --fatal-infos && flutter test`.
  Expected: all pass.
- [ ] **Step 4:** Commit: `feat(you): Pal memory, autopilot and noticed live in the You tab`.

### Task 11: Token guard test
**Depends on:** Task 3, Task 4, Task 10
**Chunk:** P2: token cleanup (~290 hardcoded values, zero visual change)

**Files:**
- Create: `test/theme/token_guard_test.dart`

- [ ] **Step 1:** Write the test. It walks `Directory('lib')` recursively for `.dart` files, skipping
  `lib/theme/` and `*.g.dart`. For every line matching `Color\(0x[0-9A-Fa-f]{8}\)` or
  `BorderRadius\.circular\(\s*[0-9]`, it fails unless the same line or the line above contains
  `kept literal`. The failure message lists `path:line` for every offender.
- [ ] **Step 2:** Run it. If it fails, fix each offender by replacing it with its exact-match token or
  annotating it, following Task 3's rules. The files rewritten by Tasks 8-10 are in scope now.
  Goldens must pass unchanged.
- [ ] **Step 3:** Check the test fails when intent is violated: temporarily add
  `const x = Color(0xFF123456);` to `lib/widgets/app_icon.dart`, confirm the test fails, then remove
  it.
- [ ] **Step 4:** Run `flutter analyze --fatal-infos && flutter test`. Expected: all pass.
- [ ] **Step 5:** Commit: `test(theme): guard against raw colours and radii outside the theme`.
