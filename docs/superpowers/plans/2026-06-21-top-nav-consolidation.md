# Top Nav Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the four tab-root screens (Today, Workout, Nutrition, Routines) one consistent header — a Profile leading anchor, a Pal trailing anchor, and exactly one contextual action per tab — driven by a single shared component.

**Architecture:** Introduce `TabHeaderScrollView`, a thin app-shell wrapper around the existing `LargeTitleScrollView` that hard-codes the Profile (leading) and Pal-orb (trailing) anchors and takes one `contextualAction` widget. The four tab roots adopt it; pushed/secondary screens keep using `LargeTitleScrollView` directly so they don't inherit the anchors. Workout's overflow menu collapses to a single `+` and its "Generate with AI" entry moves into the Move body's quick-links. Subtitles become a live status line, read from data each controller already exposes.

**Tech Stack:** Flutter, Riverpod, go_router, drift (tests use an in-memory DB + `Seeder`).

## Global Constraints

- No emojis anywhere. Comments explain "why" only, lowercase, only when necessary.
- Match existing patterns: `LargeTitleScrollView` for headers, `NavIconButton` for icon actions, `PressScale` for tappable brand glyphs, `AppRoute.<name>.name` with `context.pushNamed`/`context.go`.
- Profile and Pal keep their distinct look (avatar + gradient orb); only the contextual action is a `NavIconButton`.
- No router changes. No changes to pushed/secondary screens.
- Subtitles read existing controller fields only — no new computation/state.
- Spacing/color via theme tokens (`Spacing.*`, `context.colors.*`); no magic numbers beyond those already used in the source widgets.

---

## File Structure

- **Create** `lib/screens/shell/tab_header.dart` — `TabHeaderScrollView`, the single source of truth for the tab-header pattern (Profile + Pal anchors + one contextual slot).
- **Create** `test/screens/tab_header_test.dart` — unit test for the wrapper's slots.
- **Modify** `lib/screens/today/today_screen.dart` — adopt wrapper; drop the inbox-tray button; keep search as the contextual action; remove the now-duplicated profile/Pal slot code.
- **Modify** `lib/screens/move/move_screen.dart` — adopt wrapper; contextual `+` = New routine; delete `_showMoveMenu`; add "Generate with AI" to `_QuickLinks`; status-line subtitle.
- **Modify** `lib/screens/nutrition/nutrition_screen.dart` — adopt wrapper; contextual `+` = add meal; status-line subtitle.
- **Modify** `lib/screens/rituals/rituals_screen.dart` — adopt wrapper; contextual `+` = new routine; status-line subtitle (already a status line — keep).
- **Modify** `test/move_screen_test.dart` — assert the overflow menu is gone and "Generate with AI" lives in the body.

---

### Task 1: `TabHeaderScrollView` shell component

**Files:**
- Create: `lib/screens/shell/tab_header.dart`
- Test: `test/screens/tab_header_test.dart`

**Interfaces:**
- Consumes: `LargeTitleScrollView` (from `lib/widgets/nav_bar.dart`), `NavIconButton`, `PressScale`, `AppIcon`, `PalAvatar`, `AppRoute`.
- Produces: `TabHeaderScrollView({required String title, String? subtitle, Widget? contextualAction, required List<Widget> children, EdgeInsetsGeometry padding = EdgeInsets.zero, ScrollController? controller})`. Renders a Profile avatar in the leading slot (→ `AppRoute.you`) and a Row of `[Pal orb (→ AppRoute.pal), if contextualAction != null: gap + contextualAction]` in the trailing slot.

- [ ] **Step 1: Write the failing test**

Create `test/screens/tab_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/screens/shell/tab_header.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/nav_bar.dart';

void main() {
  testWidgets('TabHeaderScrollView renders profile, Pal, and the contextual action',
      (tester) async {
    final colors = AppColors.light(AppAccent.blue);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (c, s) => TabHeaderScrollView(
            title: 'Demo',
            subtitle: 'a status line',
            contextualAction: NavIconButton(
                name: 'plus', semanticLabel: 'Add thing', onTap: () {}),
            children: const [SizedBox(height: 40)],
          ),
        ),
        // Names must match AppRoute.you.name / AppRoute.pal.name.
        GoRoute(path: '/you', name: 'you', builder: (c, s) => const SizedBox()),
        GoRoute(path: '/pal', name: 'pal', builder: (c, s) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('You'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Pal'), findsOneWidget);
    expect(find.bySemanticsLabel('Add thing'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('TabHeaderScrollView omits the contextual slot when null',
      (tester) async {
    final colors = AppColors.light(AppAccent.blue);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (c, s) => const TabHeaderScrollView(
            title: 'Demo',
            children: [SizedBox(height: 40)],
          ),
        ),
        GoRoute(path: '/you', name: 'you', builder: (c, s) => const SizedBox()),
        GoRoute(path: '/pal', name: 'pal', builder: (c, s) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('You'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Pal'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/tab_header_test.dart`
Expected: FAIL — `tab_header.dart` does not exist / `TabHeaderScrollView` undefined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/screens/shell/tab_header.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/pal_avatar.dart';
import '../../widgets/press_scale.dart';

/// The shared header for the four tab roots. Single source of truth for the
/// top-nav pattern: a Profile avatar (leading) and a Pal orb (trailing) on
/// every tab, plus one tab-specific [contextualAction] after the orb.
///
/// Pushed/secondary screens keep using [LargeTitleScrollView] directly — they
/// must not inherit these anchors, so the anchors live here, not in the base.
class TabHeaderScrollView extends StatelessWidget {
  const TabHeaderScrollView({
    super.key,
    required this.title,
    this.subtitle,
    this.contextualAction,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final String title;
  final String? subtitle;

  /// The single tab-specific action shown after the Pal orb; null = none.
  final Widget? contextualAction;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LargeTitleScrollView(
      title: title,
      subtitle: subtitle,
      controller: controller,
      padding: padding,
      leading: PressScale(
        semanticLabel: 'You',
        onTap: () => context.pushNamed(AppRoute.you.name),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AppIcon('person.crop.circle.fill', size: 30, color: c.accent),
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressScale(
            semanticLabel: 'Open Pal',
            onTap: () => context.pushNamed(AppRoute.pal.name),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                  child: PalAvatar(size: 32, glyphSize: 16, glow: true)),
            ),
          ),
          if (contextualAction != null) ...[
            const SizedBox(width: Spacing.sm),
            contextualAction!,
          ],
        ],
      ),
      children: children,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/tab_header_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/shell/tab_header.dart test/screens/tab_header_test.dart
git commit -m "feat(nav): add shared TabHeaderScrollView with profile + Pal anchors"
```

---

### Task 2: Today adopts the wrapper, drops the inbox tray

**Files:**
- Modify: `lib/screens/today/today_screen.dart` (header block around lines 87–125; helper imports)
- Test: `test/today_screen_test.dart` (create if absent — see Step 1)

**Interfaces:**
- Consumes: `TabHeaderScrollView` (Task 1). Today's contextual action is the existing search button (`NavIconButton(name: 'magnifyingglass', semanticLabel: 'Search', onTap: () => _openSearch(...))`).
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Create `test/today_screen_test.dart` (mirrors `test/move_screen_test.dart` setup):

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';

void main() {
  testWidgets('Today header: profile + Pal + search, no inbox tray',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final router = createRouter(initialLocation: '/today');
    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          palServiceProvider.overrideWithValue(
              MockPalService(latency: const Duration(milliseconds: 1))),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('You'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Pal'), findsOneWidget);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    // The redundant inbox tray is gone — the Pal orb already opens /pal.
    expect(find.bySemanticsLabel('Pal inbox'), findsNothing);

    await flushProviderTimers(tester);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/today_screen_test.dart`
Expected: FAIL — `find.bySemanticsLabel('Pal inbox')` still finds the tray button (currently rendered).

- [ ] **Step 3: Write minimal implementation**

In `lib/screens/today/today_screen.dart`, replace the `LargeTitleScrollView(...)` header (the `return LargeTitleScrollView(` block starting ~line 87 with its `leading:` avatar and `trailing: Row([... Pal orb, inbox tray, search ...])`) with `TabHeaderScrollView`, keeping only search as the contextual action:

```dart
    return TabHeaderScrollView(
      title: 'Today',
      subtitle: _dateSubtitle,
      contextualAction: NavIconButton(
        name: 'magnifyingglass',
        semanticLabel: 'Search',
        onTap: () => _openSearch(context, today.timelineEntries),
      ),
      // kept literal: fixed bottom inset clearing the floating tab bar / FAB.
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        // ...existing children unchanged...
      ],
    );
```

Add the import near the other screen imports:

```dart
import '../shell/tab_header.dart';
```

Remove now-unused imports if the analyzer flags them: `pal_avatar.dart` and `app_icon.dart` may still be used elsewhere in the file (the rings hero / glyphs) — only remove an import if `flutter analyze` reports it unused. Keep `nav_bar.dart` (still provides `NavIconButton`).

- [ ] **Step 4: Run test + analyzer**

Run: `flutter test test/today_screen_test.dart`
Expected: PASS.

Run: `flutter analyze lib/screens/today/today_screen.dart`
Expected: No issues (resolve any unused-import warning by removing that import).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/today/today_screen.dart test/today_screen_test.dart
git commit -m "refactor(nav): Today adopts TabHeaderScrollView, drops duplicate inbox tray"
```

---

### Task 3: Workout adopts the wrapper; single `+`; move "Generate with AI"

**Files:**
- Modify: `lib/screens/move/move_screen.dart` (header ~lines 58–66; delete `_showMoveMenu` ~lines 93–132; `_QuickLinks` ~lines 593–624)
- Test: `test/move_screen_test.dart` (extend the existing test)

**Interfaces:**
- Consumes: `TabHeaderScrollView` (Task 1); `MoveState.weekWorkouts` (int), `MoveState.weekGoal` (int) for the subtitle.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Append to the existing test body in `test/move_screen_test.dart`, before `await flushProviderTimers(tester);`:

```dart
    // Header consolidation: single direct "+" (New routine), profile + Pal
    // anchors, and NO overflow menu.
    expect(find.bySemanticsLabel('You'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Pal'), findsOneWidget);
    expect(find.bySemanticsLabel('New routine'), findsOneWidget);
    expect(find.bySemanticsLabel('More options'), findsNothing);

    // "Generate with AI" now lives in the body quick-links, not a header menu.
    await tester.scrollUntilVisible(find.text('Generate with AI'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Generate with AI'), findsOneWidget);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/move_screen_test.dart`
Expected: FAIL — `New routine` semantics not found / `More options` still present.

- [ ] **Step 3: Write minimal implementation**

3a. Replace the header in `_MoveBody.build` (the `return LargeTitleScrollView(` block with `title: 'Workout'`, the descriptor subtitle, and the `trailing: Builder(... NavIconButton 'ellipsis' ... _showMoveMenu ...)`):

```dart
    return TabHeaderScrollView(
      title: 'Workout',
      subtitle: state.weekGoal == 0
          ? 'No weekly plan yet'
          : '${state.weekWorkouts} of ${state.weekGoal} workouts this week',
      contextualAction: NavIconButton(
        name: 'plus',
        semanticLabel: 'New routine',
        onTap: () => context.pushNamed(AppRoute.routineEditor.name),
      ),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        // ...existing children unchanged...
      ],
    );
```

`_MoveBody` is currently a `StatelessWidget` whose `build` has no `context.pushNamed` — `context` is already the `build` parameter, so the `onTap` closure can use it directly. Confirm `import 'package:go_router/go_router.dart';` and `import '../../router.dart';` are present (they are — `_QuickLinks` already uses `context.pushNamed(AppRoute.*)`).

3b. Delete the entire `_showMoveMenu` function (the `Future<void> _showMoveMenu(BuildContext context) { ... }` block and its doc comment).

3c. In `_QuickLinks.build`, insert a "Generate with AI" row after the "My routines" row (it is routine-related; keep "History & trends" as the `last: true` row):

```dart
        ListRow(
          icon: 'sparkles',
          iconBg: c.rituals,
          title: 'Generate with AI',
          onTap: () => context.pushNamed(AppRoute.routineGenerator.name),
        ),
```

3d. Add the import near the other screen imports:

```dart
import '../shell/tab_header.dart';
```

- [ ] **Step 4: Run test + analyzer**

Run: `flutter test test/move_screen_test.dart`
Expected: PASS (existing assertions + new ones).

Run: `flutter analyze lib/screens/move/move_screen.dart`
Expected: No issues. If `InsetSection`/`ListRow` import (`inset_section.dart`) is now unused because `_showMoveMenu` was its only consumer — it is NOT; `_QuickLinks` still uses `InsetSection`/`ListRow` — so keep it. Remove only imports the analyzer flags (e.g. `app_icon.dart` if `_showMoveMenu` was its only user; verify before removing).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/move/move_screen.dart test/move_screen_test.dart
git commit -m "refactor(nav): Workout single +, move Generate-with-AI to quick-links"
```

---

### Task 4: Nutrition adopts the wrapper + status-line subtitle

**Files:**
- Modify: `lib/screens/nutrition/nutrition_screen.dart` (header ~lines 54–66)
- Test: `test/screens/nutrition_screen_test.dart` (extend) — or create `test/nutrition_header_test.dart` if the existing test's setup is hard to extend.

**Interfaces:**
- Consumes: `TabHeaderScrollView` (Task 1); `NutritionState.day.meals` (int) for the subtitle.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Inspect `test/screens/nutrition_screen_test.dart` first. If it pumps `/nutrition` via `createRouter` with a seeded DB (same shape as `move_screen_test`), add these assertions after `pumpAndSettle`:

```dart
    expect(find.bySemanticsLabel('You'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Pal'), findsOneWidget);
    expect(find.bySemanticsLabel('Add a meal'), findsOneWidget);
```

If the existing test does not pump the full screen via the router, create `test/nutrition_header_test.dart` using the exact setup from `test/move_screen_test.dart` Step-1 scaffold but with `createRouter(initialLocation: '/nutrition')`, and assert the three labels above.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/nutrition_screen_test.dart` (or the new file)
Expected: FAIL — `You` / `Open Pal` semantics not found (only the `+` exists today).

- [ ] **Step 3: Write minimal implementation**

In `_NutritionBody.build`, replace the `return LargeTitleScrollView(` block (`title: 'Nutrition'`, `subtitle: "how you've been eating"`, `trailing: NavIconButton(name: 'plus', semanticLabel: 'Add a meal', ...)`) with:

```dart
    return TabHeaderScrollView(
      title: 'Nutrition',
      subtitle:
          '${state.day.meals} meal${state.day.meals == 1 ? '' : 's'} logged today',
      contextualAction: NavIconButton(
        name: 'plus',
        semanticLabel: 'Add a meal',
        onTap: () => showNutritionAddSheet(context),
      ),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        // ...existing children unchanged...
      ],
    );
```

Add the import:

```dart
import '../shell/tab_header.dart';
```

- [ ] **Step 4: Run test + analyzer**

Run: `flutter test test/screens/nutrition_screen_test.dart` (or the new file)
Expected: PASS.

Run: `flutter analyze lib/screens/nutrition/nutrition_screen.dart`
Expected: No issues (remove any import the analyzer flags as unused).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/nutrition/nutrition_screen.dart test/screens/nutrition_screen_test.dart
git commit -m "refactor(nav): Nutrition adopts TabHeaderScrollView with status subtitle"
```

---

### Task 5: Routines adopts the wrapper

**Files:**
- Modify: `lib/screens/rituals/rituals_screen.dart` (header ~lines 52–60)
- Test: `test/rituals_header_test.dart` (create — see Step 1)

**Interfaces:**
- Consumes: `TabHeaderScrollView` (Task 1); `RitualsState.doneSteps` / `RitualsState.totalSteps` (existing getters) for the subtitle (unchanged copy).
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Create `test/rituals_header_test.dart` using the `move_screen_test` scaffold with `createRouter(initialLocation: '/rituals')`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';

void main() {
  testWidgets('Routines header: profile + Pal + new-routine action',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final router = createRouter(initialLocation: '/rituals');
    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          palServiceProvider.overrideWithValue(
              MockPalService(latency: const Duration(milliseconds: 1))),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('You'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Pal'), findsOneWidget);
    expect(find.bySemanticsLabel('New routine'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/rituals_header_test.dart`
Expected: FAIL — `You` / `Open Pal` semantics not found.

- [ ] **Step 3: Write minimal implementation**

In `_RitualsBody.build`, replace the `return LargeTitleScrollView(` block (`title: 'Routines'`, `subtitle: '${state.doneSteps} of ${state.totalSteps} steps today'`, `trailing: NavIconButton(name: 'plus', semanticLabel: 'New routine', onTap: () => context.go('/rituals/manage'))`) with:

```dart
    return TabHeaderScrollView(
      title: 'Routines',
      subtitle: '${state.doneSteps} of ${state.totalSteps} steps today',
      contextualAction: NavIconButton(
        name: 'plus',
        semanticLabel: 'New routine',
        onTap: () => context.go('/rituals/manage'),
      ),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        // ...existing children unchanged...
      ],
    );
```

`_RitualsBody` is a `StatelessWidget`; `context` is the `build` parameter, so `context.go` works as before. Add the import:

```dart
import '../shell/tab_header.dart';
```

- [ ] **Step 4: Run test + analyzer**

Run: `flutter test test/rituals_header_test.dart`
Expected: PASS.

Run: `flutter analyze lib/screens/rituals/rituals_screen.dart`
Expected: No issues (remove any import the analyzer flags as unused — `app_icon.dart` / `pal_avatar.dart` may still be used by the body heroes; verify before removing).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/rituals/rituals_screen.dart test/rituals_header_test.dart
git commit -m "refactor(nav): Routines adopts TabHeaderScrollView"
```

---

### Task 6: Full-suite regression + analyzer sweep

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: PASS. If a pre-existing screen test asserted the old Today header (profile avatar via raw widget) or the Move overflow menu, update its expectation to the new slots and re-run.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: No new issues introduced by this change.

- [ ] **Step 3: Commit any test fixups**

```bash
git add -A
git commit -m "test(nav): align existing tests with consolidated tab headers"
```

(Skip the commit if Steps 1–2 produced no changes.)

---

## Self-Review

**1. Spec coverage**
- Layout (Profile leading + Pal + contextual trailing) → Task 1 (`TabHeaderScrollView`), adopted in Tasks 2–5.
- Styling (avatar + orb distinct, contextual = `NavIconButton`) → Task 1 implementation.
- Contextual action per tab → Today (T2, search), Workout (T3, `+` New routine), Nutrition (T4, `+` add meal), Routines (T5, `+` new routine).
- Move "Generate with AI" → Task 3, into `_QuickLinks`; `_showMoveMenu` deleted.
- Today inbox tray removal → Task 2.
- Status-line subtitles → Today (T2, date), Workout (T3, `weekWorkouts`/`weekGoal`), Nutrition (T4, `day.meals`), Routines (T5, `doneSteps`/`totalSteps`).
- New shared component / SSOT → Task 1.
- Pushed screens unchanged → enforced by putting anchors in `TabHeaderScrollView`, not `LargeTitleScrollView`; no task touches pushed screens.
- Testing requirements → Tasks 1–6 (slot tests per tab, overflow-gone test, inbox-gone test, full-suite regression).

**2. Placeholder scan** — No TBD/TODO. Every code step shows the exact code; every command shows expected output. The only `// ...existing children unchanged...` markers stand in for verbatim existing source the engineer is editing in place (not new code to author), and each is anchored by exact line ranges in the **Files** block.

**3. Type consistency** — `TabHeaderScrollView` signature in Task 1's Produces matches its usage in Tasks 2–5 (`title`, `subtitle`, `contextualAction`, `children`, `padding`). State fields verified against source: `MoveState.weekWorkouts`/`weekGoal`, `NutritionState.day.meals` (via `NutritionDay.meals`), `RitualsState.doneSteps`/`totalSteps`. `NavIconButton(name, semanticLabel, onTap)` matches `lib/widgets/nav_bar.dart`. `AppRoute.you`/`pal`/`routineEditor`/`routineGenerator` names verified against `lib/router.dart`.
