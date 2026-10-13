# Areas Tab Fix Round 1

**Verify:** `flutter test --exclude-tags "golden || scenario"`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first-areas\project\Main.dc.html

**Goal:** On the Areas tab, the ring legend shows its state word in full. Decision 1 of
`docs/superpowers/plans/2026-10-13-areas-tab.md` requires the word whenever a ring is not On
track, and the canvas legend sets it with `white-space: nowrap`.

**Defect (final verifier, round 1).** In `lib/screens/areas/areas_screen.dart`, `_LegendRow`
(around lines 286-306) wraps both the title and the state word in `Flexible` (flex 1). The Row
gives each at most half the free width, and the width `Routines` leaves unused is not passed to
the word. At 390 wide, `Worth watching` is cut to `Worth watc…`. The `areas_needs_care` shots
show this, and Move at Worth watching hits the same limit.

### Task 1: Ring legend state word renders in full
**Depends on:** none
**Files:** `lib/screens/areas/areas_screen.dart`, `test/screens/areas_screen_test.dart`

In `_LegendRow`, leave the title unwrapped: it is a short, fixed `Area.title`. Only the state
word is flexible (`Flexible`, so it still ellipsizes, instead of overflowing, at very large text
scales). Change nothing else on the screen.

Acceptance:
- `flutter test test/screens/areas_screen_test.dart` passes, with a new case. It pumps the Areas
  tab at 390x844 and text scale 1.0, once with Routines at Worth watching and once with Move at
  Worth watching. Each time it asserts:
  - the state word's `Text` renders without truncation (its laid-out `RenderParagraph` reports
    `didExceedMaxLines == false`);
  - its width equals the word's intrinsic width.
  The case must fail against the current two-`Flexible` layout.
- The scenario step `areas needs care` in `test/scenario/areas_scenario_test.dart` (unchanged)
  shows `Routines  Worth watching` in full in the Final run.
