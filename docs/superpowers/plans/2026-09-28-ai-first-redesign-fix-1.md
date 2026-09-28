# AI-first Redesign, fix round 1: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the three gaps the final stage found at 300f339: Today never refreshes the brief or
the agenda, the moved-route redirects drop the query string, and the Done by Pal row is missing its
`Logged ` prefix.

**Architecture:** Two independent edits. Today gains a pull-to-refresh plus an app-resume trigger
that share one refresh method. The router's `_todayChild` redirect carries the incoming query
string.

**Tech Stack:** Flutter 3.44.1, Riverpod 3 (codegen), go_router 16, `package:clock`.

**Spec:** `docs/superpowers/specs/2026-09-28-ai-first-redesign-design.md` (Today section 3,
"Refresh"; decision 9 on route moves). Base plan:
`docs/superpowers/plans/2026-09-28-ai-first-redesign.md` (Task 8 Step 3, Task 9 "Refresh").

**Effort:** effort:579571b0-46fa-4c4f-8c84-43719b4b615c
**Verify:** `if [ -n "$ARC_VERIFY_CHANGED" ] && ! grep -qE '^(lib|test|ios)/|^pubspec|^analysis_options|^dart_test' "$ARC_VERIFY_CHANGED"; then echo "no app paths changed"; exit 0; fi; flutter analyze --fatal-infos && flutter test`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter build web --release`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\ai-first\project

## Global Constraints

- No backend or `PalService` contract change. No new dependency.
- There is no visible refresh button on Today. Refresh is pull-to-refresh and app resume only.
- New lib code calls `clock.now()` (package:clock), never `DateTime.now()`.
- Every `AppRoute` path that exists today still resolves. Moved routes keep their `AppRoute` name.
- Comments explain why, not what, and are lower case. Match surrounding code style.
- The token guard (`test/theme/token_guard_test.dart`) fails on a raw `Color(0x........)` or
  `BorderRadius.circular(<digit>` in `lib/` outside `lib/theme` unless `kept literal: <why>` is on
  the same line or the line above.
- Goldens are machine-local (Ahem font) and tagged `golden`. Regenerate only the goldens a task
  intentionally changes (`flutter test --update-goldens --plain-name 'golden: today'
  test/golden/design_system_golden_test.dart`), and name them in the commit body.
- Do not touch `server/`.

## Review Focus

1. **Refresh fails after a good brief.** The last good headline stays; the fallback row does not
   replace it. `TodayBrief.refresh()` already guarantees this (base Task 6); the refresh test below
   uses a service that succeeds, so do not change the controller.
2. **Resume while Today is not the visible tab.** Today stays mounted in the indexed stack, so the
   listener still fires and refetches. That is intended: the brief is fresh when the user returns.
3. **A query on a redirect that has none today** (`/sleep` with no query). The result has no
   trailing `?`.

---

### Task 1: Today refreshes the brief and the agenda; Done by Pal reads "Logged"
**Depends on:** none
**Chunk:** P4: redesign Today + detail

**Files:**
- Modify: `lib/screens/today/today_screen.dart`
- Test: `test/today_screen_test.dart`
- Goldens: `today_light.png` / `today_dark.png` only if the seeded data shows a Done by Pal row.

**Interfaces:**
- Consumes: `todayBriefProvider` and its notifier's `Future<void> refresh()`
  (`lib/controllers/today_brief_controller.dart`), `palAgendaProvider`.
- Produces: nothing new for other code.

- [ ] **Step 1: Write the failing tests** in `test/today_screen_test.dart`.
  Add an `int insightsCalls = 0;` field to the existing `_Pal` fake. Increment it at the top of its
  `insights()` override, only when `range == InsightRange.day`. Import
  `package:opal/screens/shell/tab_header.dart` for `TabHeaderScrollView`. Then add:

```dart
  testWidgets('pulling Today down refetches the brief', (tester) async {
    await withClock(_monday, () async {
      final pal = _Pal(headline: 'Steady start.');
      await _boot(tester, pal);
      final before = pal.insightsCalls;

      await tester.fling(find.byType(TabHeaderScrollView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(pal.insightsCalls, before + 1);
      await flushProviderTimers(tester);
    });
  });

  testWidgets('returning to the app refetches the brief', (tester) async {
    await withClock(_monday, () async {
      final pal = _Pal(headline: 'Steady start.');
      await _boot(tester, pal);
      final before = pal.insightsCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(pal.insightsCalls, before + 1);
      await flushProviderTimers(tester);
    });
  });
```

  In the existing `'Undo deletes a Done-by-Pal entry, even one already gone'` test, add after the
  first `expect(find.text('Done by Pal · from your Gmail receipt'), findsWidgets);`:

```dart
      expect(find.textContaining('Logged Verve Coffee, '), findsOneWidget);
```

- [ ] **Step 2: Run to verify they fail**
  Run: `flutter test test/today_screen_test.dart`
  Expected: the two new tests FAIL (`insightsCalls` unchanged), and the Undo test FAILS on the
  `Logged Verve Coffee, ` finder.

- [ ] **Step 3: Implement.**
  - Make `TodayScreen` a `ConsumerStatefulWidget` with a `ConsumerState`. Move the current `build`
    body into the state unchanged, apart from the wrapping below.
  - Add one method to the state:

```dart
  Future<void> _refresh() async {
    ref.invalidate(palAgendaProvider);
    await ref.read(todayBriefProvider.notifier).refresh();
  }
```

  - In `initState`, create `_lifecycle = AppLifecycleListener(onResume: _refresh);`. Dispose it in
    `dispose` before `super.dispose()`.
  - Wrap the returned `TabHeaderScrollView` in `RefreshIndicator(onRefresh: _refresh, child: ...)`.
    `RefreshIndicator` is in `package:flutter/material.dart`; import only that symbol
    (`show RefreshIndicator`) if the file uses `widgets.dart`. If the scroll view's physics stop
    the indicator from triggering, give the inner scroll view
    `AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())`. Do not add a refresh button.
  - In `_DoneByPal._row`, prefix the title with `Logged `:
    `'Logged ${e.title}'` without an amount, and
    `'Logged ${e.title}, ${formatCurrency(...)}'` with one. Leave the `Undo ${e.title}` semantics
    label unchanged.

- [ ] **Step 4: Run to verify they pass**
  Run: `flutter test test/today_screen_test.dart && flutter analyze --fatal-infos`
  Expected: PASS, no issues. Then run
  `flutter test --tags golden --plain-name 'golden: today' test/golden/design_system_golden_test.dart`.
  If it fails only because of the `Logged ` prefix, regenerate those two goldens with
  `--update-goldens` and name them in the commit body. Any other golden diff is a defect: stop and
  report it.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/today/today_screen.dart test/today_screen_test.dart test/golden/goldens/today_light.png test/golden/goldens/today_dark.png
git commit -m "fix(today): refresh brief and agenda on pull and resume; label Done by Pal rows"
```

### Task 2: Moved-route redirects keep the query string
**Depends on:** none
**Chunk:** P3: new foundations (tokens + 23 shared widgets)

**Files:**
- Modify: `lib/router.dart` (`_todayChild` and its four callers: the `/rituals`,
  `/rituals/manage`, `/sleep` and `/mood` redirects)
- Test: `test/navigation/route_compat_test.dart`

**Interfaces:**
- Consumes: `GoRouterState.uri`.
- Produces: `String _todayChild(AppRoute child, GoRouterState state, [String suffix = ''])`, private
  to `router.dart`.

- [ ] **Step 1: Write the failing test** in `test/navigation/route_compat_test.dart`, after the
  existing `'old and current paths resolve to their location'` test:

```dart
  testWidgets('moved-route redirects keep the query string', (tester) async {
    await bootApp(tester);
    final router = _router(tester);
    const cases = {
      '/rituals?from=widget': '/today/rituals?from=widget',
      '/rituals/manage?from=widget': '/today/rituals/manage?from=widget',
      '/sleep?from=siri': '/today/sleep?from=siri',
      '/mood?from=siri': '/today/mood?from=siri',
      '/sleep': '/today/sleep',
    };
    for (final MapEntry(key: from, value: to) in cases.entries) {
      router.go(from);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), to,
          reason: 'go($from)');
    }
    await flushProviderTimers(tester);
  });
```

- [ ] **Step 2: Run to verify it fails**
  Run: `flutter test test/navigation/route_compat_test.dart`
  Expected: FAIL on `go(/rituals?from=widget)`, which yields `/today/rituals`.

- [ ] **Step 3: Implement.** Replace `_todayChild` with:

```dart
String _todayChild(AppRoute child, GoRouterState state, [String suffix = '']) {
  final query = state.uri.query;
  final path = '${AppRoute.today.path}/${child.path}$suffix';
  return query.isEmpty ? path : '$path?$query';
}
```

  Update the callers: `/rituals` returns `_todayChild(AppRoute.todayRituals, state)`,
  `/rituals/manage` returns
  `_todayChild(AppRoute.todayRituals, state, '/${AppRoute.todayManageRituals.path}')`, `/sleep`
  returns `_todayChild(AppRoute.todaySleep, state)`, and `/mood` returns
  `_todayChild(AppRoute.todayMood, state)`. Keep the `/rituals` guard that redirects only its own
  path.

- [ ] **Step 4: Run to verify it passes**
  Run: `flutter test test/navigation/ test/deep_link_routing_test.dart && flutter analyze --fatal-infos`
  Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/router.dart test/navigation/route_compat_test.dart
git commit -m "fix(router): keep the query string on moved-route redirects"
```
