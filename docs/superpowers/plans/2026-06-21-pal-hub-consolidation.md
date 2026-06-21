# Pal Hub Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge Pal Home + Pal Inbox into one pushed `/pal` hub, keeping the Composer as the separate FAB input surface.

**Architecture:** One `PalScreen` (adapted from `PalHomeScreen`) renders the agenda regions (hero, Needs you, On autopilot, memory) and embeds a new `PalNoticedSection` widget for the observation feed. The two data sources stay separate — agenda from the remote one-shot `palAgendaProvider`, notes from the local reactive `palInboxControllerProvider` (compose, not fuse). The old `/pal-home` and `/pal-inbox` routes redirect to `/pal`; their screen files are deleted.

**Tech Stack:** Flutter, Riverpod (riverpod_annotation), go_router, drift. Tests: flutter_test with the existing `_pumpApp` harness (in-memory db + zero-latency `MockPalService`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-06-21-pal-hub-consolidation-design.md`.
- No data-layer changes: `PalAgenda`/`palAgendaProvider`, `PalNote`/`PalInboxController`, and the memory providers are used as-is.
- No new bottom tab — `/pal` is pushed above the shell via `_rootNavigatorKey`, using `_sheetPage` (the same page builder the old Pal routes use).
- Composer (`/pal-composer`) is untouched.
- Keep the `palHome`/`palInbox` enum values — their paths (`/pal-home`, `/pal-inbox`) are the redirect sources.
- Match existing patterns: `AppRoute` enum + `GoRoute`; `context.colors`/`AppType`/`Spacing`/`Radii` tokens; `ConsumerWidget`/`ConsumerStatefulWidget`.
- Run all tests with `flutter test`; analyze with `flutter analyze`.
- Do not commit without showing the diff first (user workflow); each task's commit step is the proposed message — get approval before running it.

---

### Task 1: Add the `/pal` hub route with the agenda regions; redirect the old routes

Create `PalScreen` by adapting the existing `PalHomeScreen` (same agenda state/logic), register it at `/pal`, and turn `/pal-home` + `/pal-inbox` into redirects. The observation feed is added in Task 2 — this task delivers the hub rendering the agenda, reachable at `/pal`, with the old paths redirecting in.

**Files:**
- Create: `lib/screens/pal/pal_screen.dart` (adapted copy of `lib/screens/pal/pal_home_screen.dart`)
- Modify: `lib/router.dart` (enum ~line 102-105; imports ~line 31-40 area; Pal GoRoutes at 466-479)
- Test: `test/pal_home_test.dart` (update `_pumpApp` locations; add redirect test)

**Interfaces:**
- Consumes: `palAgendaProvider`, `palMemoryProvider`, `palServiceProvider`, `allEntriesStreamProvider`, `settingsRepositoryProvider`, `moveStreakDays` — exactly as `PalHomeScreen` consumes them today.
- Produces: `class PalScreen extends ConsumerStatefulWidget` (const constructor); `AppRoute.pal` with path `/pal`.

- [ ] **Step 1: Create `PalScreen` as an adapted copy of `PalHomeScreen`**

Copy `lib/screens/pal/pal_home_screen.dart` to `lib/screens/pal/pal_screen.dart`, then make exactly these changes in the new file:
- Rename `class PalHomeScreen extends ConsumerStatefulWidget` → `class PalScreen extends ConsumerStatefulWidget`, its `createState` return type, and `class _PalHomeScreenState extends ConsumerState<PalHomeScreen>` → `class _PalScreenState extends ConsumerState<PalScreen>`.
- Update the doc comment header to: `/// Pal hub — the single destination for what Pal has for you (agenda: brief,\n/// Needs you, On autopilot, memory) and what it noticed (the observation\n/// feed). Composer stays the separate FAB input surface. Route: /pal.`
- Leave all state fields, `initState`, `_refreshBrief`, `_onApprove`, `_deleteFact`, `_wipeMemory`, and the `build` body unchanged. (The `PalNoticedSection` is inserted in Task 2.)

- [ ] **Step 2: Add the `pal` route enum value**

In `lib/router.dart`, in the Handoff #2 / Pal route enum group (next to `palComposer`/`palInbox`/`palHome` around lines 102-105), add:

```dart
  pal('pal', '/pal'),
```

- [ ] **Step 3: Add the `PalScreen` import and `/pal` GoRoute; redirect the old routes**

In `lib/router.dart`:

Add the import near the other Pal screen imports:

```dart
import 'screens/pal/pal_screen.dart';
```

Replace the two existing Pal GoRoutes (currently at lines 466-479):

```dart
      GoRoute(
        path: AppRoute.palInbox.path,
        name: AppRoute.palInbox.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _sheetPage(state.pageKey, const PalInboxScreen()),
      ),
      GoRoute(
        path: AppRoute.palHome.path,
        name: AppRoute.palHome.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _sheetPage(state.pageKey, const PalHomeScreen()),
      ),
```

with the new hub route plus two redirects (the redirect pattern mirrors the existing `/weekly-review`→`/recap` route):

```dart
      // Pal hub — the merged Home + Inbox destination.
      GoRoute(
        path: AppRoute.pal.path,
        name: AppRoute.pal.name,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _sheetPage(state.pageKey, const PalScreen()),
      ),
      // Old Pal routes kept as stable redirects into the hub.
      GoRoute(
        path: AppRoute.palInbox.path,
        name: AppRoute.palInbox.name,
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/pal',
      ),
      GoRoute(
        path: AppRoute.palHome.path,
        name: AppRoute.palHome.name,
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/pal',
      ),
```

Do NOT remove the `import` of `pal_home_screen.dart`/`pal_inbox_screen.dart` yet — they are deleted in Task 3. (They are now unused; the analyzer will warn. That is expected until Task 3 and is resolved there.)

- [ ] **Step 4: Write the failing tests — pump `/pal` and assert redirects**

In `test/pal_home_test.dart`, change the two `_pumpApp(tester, location: '/pal-home', ...)` calls in the `Pal Home` group to `location: '/pal'`. Then add a new group at the end of `main()`:

```dart
  group('Pal hub routing', () {
    testWidgets('/pal-home redirects to the hub', (tester) async {
      await _pumpApp(tester, location: '/pal-home');
      expect(find.text('Needs you'), findsOneWidget);
      await flushProviderTimers(tester);
    });

    testWidgets('/pal-inbox redirects to the hub', (tester) async {
      await _pumpApp(tester, location: '/pal-inbox');
      expect(find.text('Needs you'), findsOneWidget);
      await flushProviderTimers(tester);
    });
  });
```

- [ ] **Step 5: Run the tests to verify they fail**

Run: `flutter test test/pal_home_test.dart`
Expected: FAIL — `/pal` has no route yet / redirect group can't find 'Needs you' (or a GoError for unknown `/pal`).

(If Steps 2-3 are already applied, run after reverting them mentally is unnecessary — instead author Step 4 first if practicing strict TDD. Either order is fine here because the route and tests are in the same task; the gate is that Step 6 passes.)

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/pal_home_test.dart`
Expected: PASS — all existing `Pal Home` tests (now pumping `/pal`) and the two redirect tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/pal/pal_screen.dart lib/router.dart test/pal_home_test.dart
git commit -m "feat(pal): add /pal hub route; redirect /pal-home and /pal-inbox"
```

---

### Task 2: Extract the observation feed into `PalNoticedSection` and embed it in the hub

Pull the inbox's filter pills + note list out of `PalInboxScreen` into a reusable section widget (converting its inner `ListView` to a `Column` so it nests inside the hub's scroll view), and render it in `PalScreen` between "On autopilot" and "What Pal remembers".

**Files:**
- Create: `lib/screens/pal/pal_noticed_section.dart`
- Modify: `lib/screens/pal/pal_screen.dart` (insert the section into `build`)
- Test: `test/pal_home_test.dart` (assert the feed renders in the hub)

**Interfaces:**
- Consumes: `palInboxControllerProvider` (`AsyncValue<PalInboxState>`), `PalInboxState` (`.notes`, `.unreadCount`, `.visible`, `.filter`), `InboxFilter`, `PalNote`, `palInboxControllerProvider.notifier` (`setFilter`, `markAllRead`, `markRead`).
- Produces: `class PalNoticedSection extends ConsumerWidget` (const constructor, no params).

- [ ] **Step 1: Write the failing test — the hub shows the observation feed**

In `test/pal_home_test.dart`, add to the `Pal Home` group:

```dart
    testWidgets('hub renders the "What Pal noticed" feed with filter pills',
        (tester) async {
      await _pumpApp(tester, location: '/pal');

      expect(find.text('What Pal noticed'), findsOneWidget);
      // The five inbox filter pills.
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Routines'), findsOneWidget);
      // Mark-all-read affordance from the inbox.
      expect(find.bySemanticsLabel('Mark all read'), findsOneWidget);

      await flushProviderTimers(tester);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/pal_home_test.dart -k "What Pal noticed"`
Expected: FAIL — `find.text('What Pal noticed')` finds nothing (section not embedded yet).

- [ ] **Step 3: Create `PalNoticedSection`**

Create `lib/screens/pal/pal_noticed_section.dart`. This is the inbox body extracted as a section: a `Column` (not a `ListView`), no nav bar, no "Tune what Pal notices" footer (a dead label — dropped), with a section header instead of the avatar title. Move `_FilterChip`, `_NoteCard`, and `_relativeTime` from `pal_inbox_screen.dart` verbatim (same code, now private to this file).

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/pal_inbox_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

/// "What Pal noticed" — the passive observation feed, embedded as a section of
/// the Pal hub. Reads [palInboxControllerProvider]; renders as a Column so it
/// nests inside the hub's scroll view. Handles its own loading/empty/error
/// independent of the agenda regions (compose, not fuse).
class PalNoticedSection extends ConsumerWidget {
  const PalNoticedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(palInboxControllerProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, Spacing.lg),
        child: Text("Couldn't load what Pal noticed.",
            style: AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.15)),
      ),
      data: (state) => _Body(state: state),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final PalInboxState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final controller = ref.read(palInboxControllerProvider.notifier);
    final unread = state.unreadCount;
    final visible = state.visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header: "What Pal noticed" + Mark all read --------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.lg, Spacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('What Pal noticed',
                  style: AppType.title3.copyWith(color: c.ink, letterSpacing: -0.3)),
              NavAction(
                label: 'Mark all read',
                onTap: controller.markAllRead,
                semanticLabel: 'Mark all read',
              ),
            ],
          ),
        ),

        // --- Filter chips -------------------------------------------------
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            children: [
              _FilterChip(
                label: 'All',
                count: state.notes.length,
                active: state.filter == InboxFilter.all,
                onTap: () => controller.setFilter(InboxFilter.all),
              ),
              const SizedBox(width: Spacing.sm),
              _FilterChip(
                label: 'Unread',
                count: unread,
                active: state.filter == InboxFilter.unread,
                onTap: () => controller.setFilter(InboxFilter.unread),
              ),
              const SizedBox(width: Spacing.sm),
              _FilterChip(
                label: 'Money',
                dotColor: c.money,
                active: state.filter == InboxFilter.money,
                onTap: () => controller.setFilter(InboxFilter.money),
              ),
              const SizedBox(width: Spacing.sm),
              _FilterChip(
                label: 'Workout',
                dotColor: c.move,
                active: state.filter == InboxFilter.move,
                onTap: () => controller.setFilter(InboxFilter.move),
              ),
              const SizedBox(width: Spacing.sm),
              _FilterChip(
                label: 'Routines',
                dotColor: c.rituals,
                active: state.filter == InboxFilter.rituals,
                onTap: () => controller.setFilter(InboxFilter.rituals),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // --- Notes --------------------------------------------------------
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, 24, Spacing.xl, 24),
            child: Text('Nothing here. A quiet Pal is a happy Pal.',
                textAlign: TextAlign.center,
                style: AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.15)),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: _NoteCard(note: visible[i]),
            ),
          ],
      ],
    );
  }
}
```

Then paste the `_FilterChip`, `_NoteCard`, and `_relativeTime` definitions from `lib/screens/pal/pal_inbox_screen.dart` (lines ~222-420) verbatim below `_Body` in this file. They are unchanged.

- [ ] **Step 4: Embed `PalNoticedSection` in the hub**

In `lib/screens/pal/pal_screen.dart`, add the import:

```dart
import 'pal_noticed_section.dart';
```

In the `build` method's scroll-children list, insert the section between the "On autopilot" region and the "What Pal remembers" region:

```dart
                const PalNoticedSection(),
```

(Locate the memory region by the `'What Pal remembers'` text or the `_wipeMemory`/`memory` references; place `const PalNoticedSection()` immediately before it. If the children list uses explicit spacing widgets between sections, add a matching `const SizedBox(height: Spacing.xxl)` before it to keep rhythm.)

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/pal_home_test.dart -k "What Pal noticed"`
Expected: PASS.

- [ ] **Step 6: Run the full Pal test file**

Run: `flutter test test/pal_home_test.dart`
Expected: PASS — agenda sections, redirects, and the embedded feed all render.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/pal/pal_noticed_section.dart lib/screens/pal/pal_screen.dart test/pal_home_test.dart
git commit -m "feat(pal): embed the observation feed in the hub as PalNoticedSection"
```

---

### Task 3: Repoint entry points to `/pal`; delete the old screens

Point the Today orb, Today tray icon, and You-tab Pal row at `/pal`, delete the now-unused `pal_home_screen.dart` and `pal_inbox_screen.dart`, and remove their router imports. Ends with a clean analyzer and full green suite.

**Files:**
- Modify: `lib/screens/today/today_screen.dart` (orb line 106, tray line 117)
- Modify: `lib/screens/profile/profile_screen.dart` (Pal row line 273)
- Modify: `lib/router.dart` (remove the two old screen imports)
- Delete: `lib/screens/pal/pal_home_screen.dart`, `lib/screens/pal/pal_inbox_screen.dart`
- Test: `test/pal_home_test.dart` (entry-point assertions)

**Interfaces:**
- Consumes: `AppRoute.pal` (from Task 1).
- Produces: nothing new (wiring + deletion).

- [ ] **Step 1: Write the failing entry-point tests**

In `test/pal_home_test.dart`, in the `Pal Home entry points` group, update the orb/You-row tests to also assert the feed is present, and add a tray test. Replace the orb test body's assertions and add the tray test:

```dart
    testWidgets('Today Pal orb opens the hub', (tester) async {
      await _pumpApp(tester, location: '/today');
      final orb = find.bySemanticsLabel('Open Pal');
      expect(orb, findsOneWidget);
      await tester.tap(orb);
      await tester.pumpAndSettle();
      expect(find.text('Needs you'), findsOneWidget);
      expect(find.text('What Pal noticed'), findsOneWidget);
      await flushProviderTimers(tester);
    });

    testWidgets('Today tray icon opens the hub', (tester) async {
      await _pumpApp(tester, location: '/today');
      final tray = find.bySemanticsLabel('Pal inbox');
      expect(tray, findsOneWidget);
      await tester.tap(tray);
      await tester.pumpAndSettle();
      expect(find.text('What Pal noticed'), findsOneWidget);
      await flushProviderTimers(tester);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/pal_home_test.dart -k "tray icon opens the hub"`
Expected: FAIL — tapping the tray still routes to the old inbox (no `'What Pal noticed'`), or the assertion for `'What Pal noticed'` after the orb tap is the only one failing if the orb already redirects.

- [ ] **Step 3: Repoint the Today orb and tray**

In `lib/screens/today/today_screen.dart`:
- Line 106: `onTap: () => context.pushNamed(AppRoute.palHome.name),` → `onTap: () => context.pushNamed(AppRoute.pal.name),`
- Line 117: `onTap: () => context.pushNamed(AppRoute.palInbox.name),` → `onTap: () => context.pushNamed(AppRoute.pal.name),`

- [ ] **Step 4: Repoint the You-tab Pal row**

In `lib/screens/profile/profile_screen.dart` line 273: `onTap: () => context.pushNamed(AppRoute.palHome.name),` → `onTap: () => context.pushNamed(AppRoute.pal.name),`

- [ ] **Step 5: Delete the old screens and their router imports**

Delete the files:

```bash
git rm lib/screens/pal/pal_home_screen.dart lib/screens/pal/pal_inbox_screen.dart
```

In `lib/router.dart`, remove the now-unused imports:

```dart
import 'screens/pal/pal_home_screen.dart';
import 'screens/pal/pal_inbox_screen.dart';
```

- [ ] **Step 6: Verify analyzer is clean**

Run: `flutter analyze`
Expected: No issues found (no unused-import or unresolved-reference warnings).

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: PASS — all tests green.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/today/today_screen.dart lib/screens/profile/profile_screen.dart lib/router.dart test/pal_home_test.dart
git commit -m "feat(pal): route all Pal entry points to the hub; remove old screens"
```

---

## Notes / follow-ups (out of scope for this plan)

- Deep links / notifications that target `/pal-inbox` (e.g. routine-reminder taps) now redirect to `/pal` automatically. Audit notification payloads during execution; no code change expected.
- `pal_note_repository_test.dart` is unaffected (repository-level, no screen dependency).
- Renaming `test/pal_home_test.dart` → `test/pal_screen_test.dart` is optional polish; skipped to keep the diff focused.
