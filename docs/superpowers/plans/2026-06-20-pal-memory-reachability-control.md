# Pal Memory Reachability & Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Pal's persistent memory discoverable, transparent, and controllable on the Pal Home hub.

**Architecture:** Pal Home (`lib/screens/pal/pal_home_screen.dart`) renders a `_MemoryCard` from the `palMemoryProvider` digest. Today the whole section is hidden when the digest is empty, so the feature never appears on a fresh device. This plan makes the section always-on with a first-run empty state, guarantees the card reflects current stored memory on every open, adds a Privacy-screen disclosure, guards the destructive wipe with a confirm dialog, raises memory-row accessibility, and lets the user dismiss a mislearned pattern locally.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod` + codegen `@riverpod`), go_router. Tests: `flutter_test` widget tests via the existing `_pumpApp` harness in `test/pal_home_test.dart`.

## Global Constraints

- App name is **Opal** — never "ExpensePal".
- Comments lower-case, "why" not "what", only when necessary (house style).
- No new dependencies; no server or schema changes (this theme is client-only).
- Terminology: "rituals" for daily checklist items, "routines" for saved workouts. Memory copy uses "facts" (user-authored) and "patterns" (Pal-derived).
- Accessibility: interactive controls expose a semantic label; tap targets ≥ 44pt.
- Verify each task with `flutter analyze` (clean) and `flutter test` (green) before committing.

---

### Task 1: Always-on memory section with first-run empty state

The section is currently gated by `if (!memory.isEmpty)` (`pal_home_screen.dart:221`), so on a fresh device — where there are no facts (authored via chat) and no patterns (derived on Recap) — the feature is invisible. Render it unconditionally; when empty, `_MemoryCard` shows an explanatory empty state. Also invalidate `palMemoryProvider` on open so a freshly-pushed screen always re-reads the current stored digest (the live audit saw a stale-empty card after a Recap refresh; this guarantees freshness regardless of provider lifecycle).

**Files:**
- Modify: `lib/screens/pal/pal_home_screen.dart` (the `if (!memory.isEmpty)` block ~221-236; `_MemoryCard.build` ~889-924; `initState` ~46-50)
- Test: `test/pal_home_test.dart`

**Interfaces:**
- Consumes: `palMemoryProvider` → `PalMemoryDigest { List<PalFact> facts; List<InsightPattern> patterns; bool get isEmpty }`; `PalFact { String id; String text }`; `InsightPattern { String colorToken; String title; String? detail }`.
- Produces: no new public symbols.

- [ ] **Step 1: Write the failing test**

Add to the `group('Pal Home', ...)` in `test/pal_home_test.dart`:

```dart
testWidgets('memory section is always shown, with an empty-state on first run',
    (tester) async {
  // no `memory:` override → MockPalService returns an empty digest
  await _pumpApp(tester, location: '/pal-home');

  expect(find.text('What Pal remembers'), findsOneWidget);
  expect(
    find.text("As we talk, I'll note facts you mention and patterns I learn "
        'here — you can delete anything.'),
    findsOneWidget,
  );

  await flushProviderTimers(tester);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pal_home_test.dart -p vm --name "always shown"`
Expected: FAIL — "What Pal remembers" not found (section hidden when empty).

- [ ] **Step 3: Remove the empty-gate so the section always renders**

In `pal_home_screen.dart`, change the gated block:

```dart
          // --- What Pal remembers ---
          if (!memory.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, 10),
              child: Text('What Pal remembers',
                  style:
                      AppType.title2.copyWith(color: c.ink, letterSpacing: 0.35)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 22),
              child: _MemoryCard(
                memory: memory,
                onDeleteFact: _deleteFact,
                onWipe: _wipeMemory,
              ),
            ),
          ],
```

to (drop the `if`, always render):

```dart
          // --- What Pal remembers ---
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, 10),
            child: Text('What Pal remembers',
                style:
                    AppType.title2.copyWith(color: c.ink, letterSpacing: 0.35)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 22),
            child: _MemoryCard(
              memory: memory,
              onDeleteFact: _deleteFact,
              onWipe: _wipeMemory,
            ),
          ),
```

- [ ] **Step 4: Render the empty state inside `_MemoryCard`**

In `_MemoryCard.build` (`pal_home_screen.dart` ~899), the `Column`'s children start with the fact/pattern rows. Insert an empty-state row when there is nothing stored, before the wipe footer. Replace the `Column(children: [ ... ])` body with:

```dart
      child: Column(
        children: [
          if (memory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon('sparkles', size: 13, color: c.ink3),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      "As we talk, I'll note facts you mention and patterns I "
                      'learn here — you can delete anything.',
                      style: AppType.footnote.copyWith(
                          color: c.ink3, letterSpacing: -0.08, height: 1.35),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            for (final f in memory.facts)
              _row(c, text: f.text, onDelete: () => onDeleteFact(f.id)),
            for (final p in memory.patterns)
              _row(c, text: p.title, meta: p.detail),
          ],
          // Wipe-all footer.
          PressScale(
            onTap: onWipe,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AppIcon('trash.fill', size: 13, color: c.accent),
                  const SizedBox(width: Spacing.sm),
                  Text('Clear what Pal remembers',
                      style: AppType.footnote
                          .copyWith(color: c.accent, letterSpacing: -0.08)),
                ],
              ),
            ),
          ),
        ],
      ),
```

Note: the wipe footer stays visible in the empty state; Task 3 hides it when there is nothing to wipe. Leave it as-is here so each task's test stays isolated.

- [ ] **Step 5: Invalidate memory on open for freshness**

In `_PalHomeScreenState.initState` (`pal_home_screen.dart` ~46), add the invalidate next to the existing brief fetch:

```dart
  @override
  void initState() {
    super.initState();
    _refreshBrief();
    // re-read stored memory on every open so a returning screen never shows a
    // stale-empty card (observed in the live audit after a Recap refresh).
    ref.invalidate(palMemoryProvider);
  }
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/pal_home_test.dart -p vm --name "always shown"`
Expected: PASS.

- [ ] **Step 7: Run the full Pal Home suite + analyze**

Run: `flutter analyze lib/screens/pal/pal_home_screen.dart && flutter test test/pal_home_test.dart`
Expected: analyze clean; all Pal Home tests pass (the existing "renders … all sections" test still passes — it passes a populated `memory:` and asserts the fact/pattern render).

- [ ] **Step 8: Commit**

```bash
git add lib/screens/pal/pal_home_screen.dart test/pal_home_test.dart
git commit -m "feat(pal): always-on memory section + first-run empty state"
```

---

### Task 2: Privacy-screen disclosure

The Privacy screen lists what data is stored and the two cases where data leaves the device, but never mentions that Pal stores facts + learned patterns. Add a disclosure row.

**Files:**
- Modify: `lib/screens/settings/privacy_screen.dart` (the "When data leaves your device" `InsetSection`, ~52-72)
- Test: `test/screens/privacy_screen_test.dart` (create)

**Interfaces:**
- Consumes: `ListRow { String icon; Color iconBg; String title; String subtitle; bool chevron; bool last }` (from `widgets/inset_section.dart`, already used in this file).
- Produces: none.

- [ ] **Step 1: Write the failing test**

Create `test/screens/privacy_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/screens/settings/privacy_screen.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  testWidgets('Privacy screen discloses Pal memory storage', (tester) async {
    final colors = AppColors.light(AppAccent.blue);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: const PrivacyScreen(),
    ));

    expect(find.text('Pal memory'), findsOneWidget);
    expect(
      find.text('Facts you mention and patterns Pal learns, '
          'stored to personalize replies. Clear anytime in Pal.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/privacy_screen_test.dart`
Expected: FAIL — "Pal memory" not found.

- [ ] **Step 3: Add the disclosure row**

In `privacy_screen.dart`, in the "When data leaves your device" section, change the Pal row from `chevron: false,` (no `last`) followed directly by the Email row, to insert a memory row between them. Replace:

```dart
              ListRow(
                icon: 'sparkles',
                iconBg: c.accent,
                title: 'Pal',
                subtitle: 'Text you send to Pal is processed to reply.',
                chevron: false,
              ),
              ListRow(
                icon: 'envelope.fill',
                iconBg: c.accent,
                title: 'Email sync',
                subtitle: 'Only if connected; reads filtered bank alerts.',
                chevron: false,
                last: true,
              ),
```

with:

```dart
              ListRow(
                icon: 'sparkles',
                iconBg: c.accent,
                title: 'Pal',
                subtitle: 'Text you send to Pal is processed to reply.',
                chevron: false,
              ),
              ListRow(
                icon: 'brain.head.profile',
                iconBg: c.accent,
                title: 'Pal memory',
                subtitle: 'Facts you mention and patterns Pal learns, '
                    'stored to personalize replies. Clear anytime in Pal.',
                chevron: false,
              ),
              ListRow(
                icon: 'envelope.fill',
                iconBg: c.accent,
                title: 'Email sync',
                subtitle: 'Only if connected; reads filtered bank alerts.',
                chevron: false,
                last: true,
              ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/privacy_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings/privacy_screen.dart test/screens/privacy_screen_test.dart
git commit -m "feat(pal): disclose memory storage on the Privacy screen"
```

---

### Task 3: Confirm before wiping memory

`_wipeMemory` (`pal_home_screen.dart` ~85) clears all memory immediately with no confirmation — an unrecoverable, easy-to-fat-finger action. Gate it behind a confirm dialog, and hide the wipe footer when there is nothing to wipe.

**Files:**
- Modify: `lib/screens/pal/pal_home_screen.dart` (`_wipeMemory` ~85; `_MemoryCard` wipe footer ~906-920)
- Test: `test/pal_home_test.dart`

**Interfaces:**
- Consumes: `showDialog` + `CupertinoAlertDialog`-style confirm. The app uses `flutter/widgets` + Material; reuse the project's existing dialog pattern — confirm via a Material `showDialog` with a custom dialog body (search the codebase: `grep -rn "showDialog" lib/` and match the nearest existing confirm dialog; if none exists, use a minimal `AlertDialog` with "Cancel" / "Clear" actions).
- Produces: `Future<void> _confirmAndWipe()` replacing the direct `_wipeMemory` wiring on the footer.

- [ ] **Step 1: Write the failing test**

Add to `test/pal_home_test.dart`:

```dart
testWidgets('wiping memory asks for confirmation first', (tester) async {
  await _pumpApp(tester, location: '/pal-home', memory: const PalMemoryDigest(
    facts: [PalFact(id: 'f-1', text: 'Training for a marathon in October')],
  ));

  await tester.tap(find.text('Clear what Pal remembers'));
  await tester.pumpAndSettle();

  // a confirm step appears; the fact is still present until confirmed
  expect(find.text('Clear all memory?'), findsOneWidget);
  expect(find.text('Training for a marathon in October'), findsOneWidget);

  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();
  expect(find.text('Clear all memory?'), findsNothing);
  expect(find.text('Training for a marathon in October'), findsOneWidget);

  await flushProviderTimers(tester);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pal_home_test.dart -p vm --name "confirmation first"`
Expected: FAIL — "Clear all memory?" not found (wipe is immediate).

- [ ] **Step 3: Add a confirm dialog**

`pal_home_screen.dart` imports `package:flutter/widgets.dart`, so the Material
dialog widgets are not in scope. Add the import at the top of the file:

```dart
import 'package:flutter/material.dart';
```

Then in `_PalHomeScreenState`, replace `_wipeMemory` with a confirm-then-wipe flow:

```dart
  Future<void> _wipeMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all memory?'),
        content: const Text(
            "Pal will forget every fact and pattern. This can't be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(palServiceProvider).clearMemory();
    ref.invalidate(palMemoryProvider);
  }
```

(The `_MemoryCard` footer already calls `onWipe`, wired to `_wipeMemory` — no change needed there for the dialog.)

- [ ] **Step 4: Hide the wipe footer when there is nothing to wipe**

In `_MemoryCard.build`, wrap the wipe `PressScale` footer so it only renders when non-empty:

```dart
          // Wipe-all footer — only when there is something to clear.
          if (!memory.isEmpty)
            PressScale(
              onTap: onWipe,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    AppIcon('trash.fill', size: 13, color: c.accent),
                    const SizedBox(width: Spacing.sm),
                    Text('Clear what Pal remembers',
                        style: AppType.footnote
                            .copyWith(color: c.accent, letterSpacing: -0.08)),
                  ],
                ),
              ),
            ),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/pal_home_test.dart -p vm --name "confirmation first"`
Expected: PASS.

- [ ] **Step 6: Run full suite + analyze**

Run: `flutter analyze lib/screens/pal/pal_home_screen.dart && flutter test test/pal_home_test.dart`
Expected: clean + green.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/pal/pal_home_screen.dart test/pal_home_test.dart
git commit -m "feat(pal): confirm before wiping Pal memory"
```

---

### Task 4: Memory-row accessibility

Three issues in `_MemoryCard._row` and the wipe footer (`pal_home_screen.dart` ~906-978): the fact-delete icon has a ~21pt tap target (below 44pt) and no semantic label; the wipe control has no semantic label; the sparkle glyph is full-accent on `accentTint` (low contrast).

**Files:**
- Modify: `lib/screens/pal/pal_home_screen.dart` (`_row` delete affordance ~967-974; row glyph ~943; wipe `PressScale` ~906)
- Test: `test/pal_home_test.dart`

**Interfaces:**
- Consumes: `PressScale { VoidCallback? onTap; String? semanticLabel; Widget child }` (already used in this file with `semanticLabel`, e.g. the brief Refresh control).
- Produces: none.

- [ ] **Step 1: Write the failing test**

Add to `test/pal_home_test.dart`:

```dart
testWidgets('memory controls expose accessibility labels', (tester) async {
  await _pumpApp(tester, location: '/pal-home', memory: const PalMemoryDigest(
    facts: [PalFact(id: 'f-1', text: 'Training for a marathon in October')],
  ));

  expect(find.bySemanticsLabel('Forget this fact'), findsOneWidget);
  expect(find.bySemanticsLabel('Clear all Pal memory'), findsOneWidget);

  await flushProviderTimers(tester);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pal_home_test.dart -p vm --name "accessibility labels"`
Expected: FAIL — semantics labels not found.

- [ ] **Step 3: Fix the delete affordance (label + tap target)**

In `_row`, replace the delete `PressScale`:

```dart
          if (onDelete != null)
            PressScale(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: Spacing.sm, top: 2),
                child: AppIcon('xmark', size: 13, color: c.ink4),
              ),
            ),
```

with (≥44pt hit area + label):

```dart
          if (onDelete != null)
            PressScale(
              onTap: onDelete,
              semanticLabel: 'Forget this fact',
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AppIcon('xmark', size: 13, color: c.ink4),
                ),
              ),
            ),
```

- [ ] **Step 4: Label the wipe control**

In the wipe `PressScale` (from Task 3, now guarded by `if (!memory.isEmpty)`), add the label:

```dart
            PressScale(
              onTap: onWipe,
              semanticLabel: 'Clear all Pal memory',
              child: Padding(
```

- [ ] **Step 5: Raise the row-glyph contrast**

In `_row`, the leading glyph container draws `AppIcon('sparkles', size: 13, color: c.accent)` on a `c.accentTint` background. Change the icon color to `c.ink2` so the glyph reads on the tint:

```dart
            child: AppIcon('sparkles', size: 13, color: c.ink2),
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/pal_home_test.dart -p vm --name "accessibility labels"`
Expected: PASS.

- [ ] **Step 7: Run full suite + analyze**

Run: `flutter analyze lib/screens/pal/pal_home_screen.dart && flutter test test/pal_home_test.dart`
Expected: clean + green.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/pal/pal_home_screen.dart test/pal_home_test.dart
git commit -m "fix(pal): memory-row a11y — labels, 44pt target, glyph contrast"
```

---

### Task 5: Dismiss a mislearned pattern (local)

Facts are deletable but Pal-derived patterns are read-only, so a wrong pattern can't be removed. Add a local, session-only dismiss (mirroring the existing optimistic `_statusById` pattern for proposals). A dismissed pattern is filtered from the displayed list; it may reappear on the next memory refresh — durable, server-persisted correction is out of scope here (it needs a `/v1/memory` mutation endpoint) and is a deferred follow-up.

**Files:**
- Modify: `lib/screens/pal/pal_home_screen.dart` (`_PalHomeScreenState` state + memory wiring ~50, ~230; `_MemoryCard` ~885-904)
- Test: `test/pal_home_test.dart`

**Interfaces:**
- Consumes: `InsightPattern { String colorToken; String title; String? detail }` (patterns have no id — key the dismiss by `title`).
- Produces: `_MemoryCard` gains `void Function(InsightPattern)? onDismissPattern`.

- [ ] **Step 1: Write the failing test**

Add to `test/pal_home_test.dart`:

```dart
testWidgets('a learned pattern can be dismissed locally', (tester) async {
  await _pumpApp(tester, location: '/pal-home', memory: const PalMemoryDigest(
    patterns: [InsightPattern(
        colorToken: 'money',
        title: 'Fridays cost the most',
        detail: 'Dining out drives the spike.')],
  ));

  expect(find.text('Fridays cost the most'), findsOneWidget);

  await tester.tap(find.bySemanticsLabel('Dismiss this pattern'));
  await tester.pumpAndSettle();

  expect(find.text('Fridays cost the most'), findsNothing);

  await flushProviderTimers(tester);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pal_home_test.dart -p vm --name "dismissed locally"`
Expected: FAIL — no "Dismiss this pattern" control.

- [ ] **Step 3: Track dismissed pattern titles in state**

In `_PalHomeScreenState`, add the set near the other optimistic maps (~50):

```dart
  // patterns have no id; dismiss is local + session-only (reappears on refresh).
  final Set<String> _dismissedPatterns = {};
```

- [ ] **Step 4: Filter dismissed patterns and pass the callback**

Where `_MemoryCard` is constructed (~230), filter the digest's patterns and pass a dismiss handler. Replace:

```dart
            child: _MemoryCard(
              memory: memory,
              onDeleteFact: _deleteFact,
              onWipe: _wipeMemory,
            ),
```

with:

```dart
            child: _MemoryCard(
              memory: PalMemoryDigest(
                facts: memory.facts,
                patterns: memory.patterns
                    .where((p) => !_dismissedPatterns.contains(p.title))
                    .toList(),
              ),
              onDeleteFact: _deleteFact,
              onDismissPattern: (p) =>
                  setState(() => _dismissedPatterns.add(p.title)),
              onWipe: _wipeMemory,
            ),
```

- [ ] **Step 5: Add the dismiss affordance to pattern rows**

In `_MemoryCard`, add the field and constructor param:

```dart
  const _MemoryCard({
    required this.memory,
    required this.onDeleteFact,
    required this.onDismissPattern,
    required this.onWipe,
  });

  final PalMemoryDigest memory;
  final Future<void> Function(String id) onDeleteFact;
  final void Function(InsightPattern) onDismissPattern;
  final Future<void> Function() onWipe;
```

Change the pattern loop to give patterns a dismiss control. Replace:

```dart
            for (final p in memory.patterns)
              _row(c, text: p.title, meta: p.detail),
```

with:

```dart
            for (final p in memory.patterns)
              _row(c,
                  text: p.title,
                  meta: p.detail,
                  onDelete: () => onDismissPattern(p),
                  deleteLabel: 'Dismiss this pattern'),
```

Update `_row`'s signature to accept the label (default keeps the fact label):

```dart
  Widget _row(AppColors c,
      {required String text,
      String? meta,
      VoidCallback? onDelete,
      String deleteLabel = 'Forget this fact'}) {
```

and use it on the delete `PressScale` (from Task 4):

```dart
            PressScale(
              onTap: onDelete,
              semanticLabel: deleteLabel,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AppIcon('xmark', size: 13, color: c.ink4),
                ),
              ),
            ),
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/pal_home_test.dart -p vm --name "dismissed locally"`
Expected: PASS.

- [ ] **Step 7: Run full suite + analyze**

Run: `flutter analyze lib/screens/pal/pal_home_screen.dart && flutter test`
Expected: analyze clean; all tests pass except the two pre-existing date-drift goldens (`golden: move`, `golden: today`) that fail on `main` independent of this work.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/pal/pal_home_screen.dart test/pal_home_test.dart
git commit -m "feat(pal): dismiss a mislearned pattern locally"
```

---

## Deferred (out of scope, noted for follow-up)

- **Durable pattern correction.** Task 5 is session-local; a dismissed pattern reappears on the next refresh. Persisting it needs a `/v1/memory` pattern-mutation endpoint (server) and is a separate spec.
- **Memory contrast/tap-target on real iOS.** Verified by code + widget test here; a device pass under VoiceOver + Dynamic Type would confirm the rendered result.
