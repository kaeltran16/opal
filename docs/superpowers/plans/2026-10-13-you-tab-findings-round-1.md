# You Tab Round 1: Clear Row at Large Text Implementation Plan

**Verify:** `flutter test --exclude-tags scenario`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first-you\project\Main.dc.html

**Goal:** What Pal remembers' Clear row stops overflowing at large text on a phone-width screen,
without changing how it looks at the default text size.

**Architecture:** One widget fix in `lib/screens/you/pal_memory_screen.dart`: the idle
`Clear what Pal remembers` button sits in a `Row` with no flex, so its text cannot wrap. Give it
a `Flexible` so it wraps, and keep it left-aligned at its natural width.

**Tech Stack:** Flutter, flutter_test widget tests with the Ahem test font.

**Spec:** `docs/superpowers/plans/2026-10-13-you-tab-findings.md` (the run's plan; Task 4 is
What Pal remembers, and its canvas block is `sub.isMemory` in the Prototype).

## Global Constraints

- Touch only `lib/screens/you/pal_memory_screen.dart` and
  `test/screens/you/pal_memory_screen_test.dart`.
- At text scale 1.0 the Clear row looks the same as now: the idle button sits at the left of the
  row at its natural width, with the canvas's danger color and headline style.
- Every tap target stays at least 44 by 44.
- Do not edit `test/profile_test.dart`, `lib/widgets/glass_tab_bar.dart` or any file outside the
  two above.

## Review Focus

- Text scale 1.3 on a 390 px wide surface (the repo's large-text convention, as in
  `test/screens/area_page_test.dart`): neither the idle nor the asking Clear row overflows.
- Text scale 1.0: the idle button is not stretched or centered by the new `Flexible`. A bare
  `Flexible` around `_TextButton` would let its `Container(alignment: center)` fill the row and
  center the text.

---

### Task 1: Clear row wraps at large text

**Files:** `lib/screens/you/pal_memory_screen.dart`, `test/screens/you/pal_memory_screen_test.dart`

Modify `_ClearRow.build`, and `_TextButton` only if it needs an alignment parameter.

**Interfaces:**
- Consumes: the existing `_pump(tester, _FakePal(...))` helper and `_caffeine` fact in the test
  file.
- Produces: nothing new for other code.

- [ ] **Step 1: Write the failing tests**

Add to `main()` in `test/screens/you/pal_memory_screen_test.dart`:

```dart
  testWidgets('the Clear row fits at text scale 1.3 on a 390 wide surface, idle and asking',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pump(tester, _FakePal(facts: [_caffeine]));
    expect(tester.takeException(), isNull);
    final idle = find.text('Clear what Pal remembers');
    expect(idle, findsOneWidget);
    expect(tester.getSize(idle).width, lessThan(390));

    await tester.tap(idle);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['Cancel', 'Clear']) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
  });

  testWidgets('at text scale 1.0 the idle Clear button sits left at its natural width',
      (tester) async {
    // wide enough that the Ahem label fits on one line, so a stretched button shows.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, _FakePal(facts: [_caffeine]));
    final button = find.bySemanticsLabel('Clear what Pal remembers');
    final text = find.text('Clear what Pal remembers');
    // same left edge as the fact text above it: the row's gutter.
    expect(tester.getTopLeft(text).dx, tester.getTopLeft(find.text(_caffeine.text)).dx);
    // not stretched across the row by the Flexible: zero padding, so as wide as its text.
    expect(tester.getSize(button).width, lessThan(tester.getSize(text).width + 1));
  });
```

If `find.bySemanticsLabel('Clear what Pal remembers')` matches more than one node, take
`.first`.

- [ ] **Step 2: Run them and see the first one fail**

Run: `flutter test test/screens/you/pal_memory_screen_test.dart`
Expected: the text scale 1.3 test FAILS with a RenderFlex overflow. The 1.0 test passes at 800
wide, and it has to keep passing after the fix. Ahem glyphs are wider than real fonts, so the
idle label overflows at 390 wide even at scale 1.0. The 1.3 test covers that width.

- [ ] **Step 3: Fix the idle row**

In `_ClearRow.build`, give the idle button a `Flexible` and keep it left-aligned at its natural
width. One way: add an optional `alignment` (default `Alignment.center`) to `_TextButton` and
pass `Alignment.centerLeft` for the idle button, so the `Container` no longer centers its text
when the `Flexible` gives it a bounded width:

```dart
            : [
                Flexible(
                  child: _TextButton('Clear what Pal remembers',
                      color: c.dangerInk, alignment: Alignment.centerLeft, onTap: onAsk),
                ),
              ],
```

Keep the asking branch as it is unless the 1.3 test shows it overflowing. If it does, give the
question the space and keep both buttons at least 44 by 44. Do not shrink the buttons below that.

- [ ] **Step 4: Run the file, then the suite**

Run: `flutter test test/screens/you/pal_memory_screen_test.dart`
Expected: all tests PASS.

Run: `flutter test --exclude-tags scenario` and `flutter analyze --fatal-infos`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/you/pal_memory_screen.dart test/screens/you/pal_memory_screen_test.dart
git commit -m "What Pal remembers: Clear row wraps at large text"
```
