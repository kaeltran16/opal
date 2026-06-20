# Pal new-surface polish

**Date:** 2026-06-20
**Status:** Design — pending implementation plan

## Problem

Four Pal surfaces shipped after the 2026-06-15 UX audit and were never audited:
the **Pal Home hub**, **logged-entry confirmation cards**, the **/agenda**
feature, and **persistent memory**. A fresh read-plus-live walkthrough (seeded
web build at iPhone width, both themes) surfaced a set of polish issues — no
logic bugs, but real copy/consistency/transparency/accessibility gaps. The
findings below were each confirmed against the running app except where noted.

This spec covers the verified, in-scope subset across three themes. The
context-aware-suggestions work is tracked separately
(`2026-06-20-pal-context-aware-suggestions-design.md`) and is out of scope here.

### Verified findings

**Pal Home — memory:**
- The "What Pal remembers" section never appears on a fresh run. It is gated on
  `if (!memory.isEmpty)` (`pal_home_screen.dart:221`); on first open memory is
  empty so the whole feature is invisible. It also failed to surface after
  opening Recap (which seeds patterns and invalidates the provider) — a subtler
  lifecycle/timing issue, since `palService` is a keepAlive singleton and
  `recapMemoryRefresh` already invalidates `palMemoryProvider`
  (`recap_controller.dart:221`).
- No disclosure anywhere that Pal stores facts + learned patterns. The Privacy
  screen does not mention memory.
- Wipe-all (`_wipeMemory`, `pal_home_screen.dart:85`) is destructive with no
  confirm and no undo.
- Learned patterns are read-only; only facts are deletable. A mislearned pattern
  cannot be removed.
- Memory-row accessibility: delete-icon tap target ≈21pt (below 44pt), the wipe
  control has no semantic label, and the sparkle icon is full-accent on an
  `accentTint` background (low contrast). *(Contrast/tap-target not live-verified
  — the card never rendered; carried from source read.)*

**Pal Home — brief & hub:**
- The daily brief is hardcoded showcase text (`_defaultBrief`,
  `pal_home_screen.dart:40-44`): a fabricated "11-day streak", "$60 spent",
  "66 minutes moved" shown to every new user until they tap Refresh. "66 minutes
  moved" also reintroduces the minutes unit the prior audit migrated to kcal.
- During agenda load the header stats default to "0" (NEED YOU / AUTOPILOT /
  STREAK), so the header transiently shows "0d STREAK HELD" while the brief reads
  "11-day streak" — an on-screen contradiction that resolves once loaded.
- The "Tune" control (top bar, `pal_home_screen.dart:112`) renders as a tappable
  accent action but is intentionally inert — clicking does nothing (confirmed).

**Confirmation card:**
- Money amount renders "−$5.00" (`pal_composer_screen.dart:678`,
  `trimZeroCents: false`); the rest of the app trims to "−$5" (confirmed).
- The "LOGGED" badge is hardcoded `c.move` green for all entry types
  (`pal_composer_screen.dart:724`); a money log shows a green badge (confirmed).
- The card's Undo/Edit actions have no accessibility semantics (plain
  `GestureDetector` + `Text`). *(The composer send button was initially flagged
  too but already carries `semanticLabel: 'Send'` — false positive, dropped.)*
- Move-entry subtitle reads "Movement · Just now" (`pal_composer_screen.dart:673`)
  while the input that created it is labeled "Workout" — terminology drift.

### Findings explicitly dropped

- "Undo disappears after navigating away from Pal Home" — **refuted live**: the
  done-card Undo persisted across navigation.
- The "over budget" state leaking across confirmation cards — **false positive**:
  `over` is a local in `_ring`, recreated per call and set only in the money case.

## Goal

Close the verified gaps so the new surfaces read as truthful, discoverable,
controllable, and accessible. Three independently shippable themes. No new
features; no server or schema changes except one line of Privacy copy.

Non-goals: context-aware suggestions (separate spec); the broader Composer / Ask
Pal / Inbox consolidation; autopilot empty-state (could not reproduce — seed
always populates it).

## Design

### Theme A — Memory reachability & control

Files: `pal_home_screen.dart`, `pal_memory_controller.dart`,
`screens/settings/privacy_screen.dart`.

- **Always-on section.** Render "What Pal remembers" unconditionally. When
  `memory.isEmpty`, show a first-run empty state ("As we talk, I'll note patterns
  and facts about you here — you can delete anything") rather than hiding the
  section. Removes the dependency on data existing for the feature to be
  discoverable.
- **Reachability fix.** Pin down and fix why seeded patterns do not surface after
  a Recap refresh. Acceptance: with a pattern present (seeded via Recap refresh
  or a chat-driven `remember`), reopening Pal Home shows it in the memory section.
- **Disclosure.** Add one line to the Privacy screen: Pal stores facts you
  mention and patterns it learns, on this device and the server, and you can
  delete any of it.
- **Wipe safety.** `_wipeMemory` gets a confirm step ("Clear everything Pal
  remembers? This can't be undone.") before calling `clearMemory()`.
- **Pattern correction.** Allow deleting/dismissing an individual learned pattern
  (mirroring fact deletion), so a mislearned pattern can be removed. Note in copy
  or behavior that a pattern may reappear on the next refresh.
- **Memory-row accessibility.** Delete-icon tap target ≥44pt; add a semantic
  label to the wipe control; raise sparkle contrast (use `ink2`/`ink3` rather
  than full accent on `accentTint`).

### Theme B — Brief & hub

File: `pal_home_screen.dart`.

- **Auto-fetch brief on open.** Remove the hardcoded `_defaultBrief`. Fire
  `_refreshBrief()` once from `initState` (not `build` — preserves the existing
  "many frames → N model calls" concern; `insights` is already cached). Show a
  loading skeleton while it resolves. On error, fall back to a neutral line — never
  fabricated stats.
- **Header stat skeleton.** While the agenda is loading, show a skeleton / em-dash
  for NEED YOU / AUTOPILOT / STREAK instead of "0", removing the transient
  contradiction with the brief.
- **Remove "Tune."** Delete the inert control and its top-bar row until a real
  "tune what Pal does" feature exists (matches the prior audit's removal of the
  orphaned `/quick-actions`).

### Theme C — Confirmation card

Files: `pal_composer_screen.dart`, `util/entry_glyph.dart`.

- **Currency.** `trimZeroCents: true` on the trailing amount so it reads "−$5"
  not "−$5.00", matching the rest of the app.
- **LOGGED badge color.** Use the entry-type color (already computed for the card)
  instead of hardcoded `c.move`, so money reads orange, rituals purple, etc.
- **Accessibility labels.** Wrap the Undo / Edit card actions in `Semantics`
  (button + label). The composer send button already has one.
- **Copy.** "Movement · Just now" → "Workout · Just now" to match the input label
  that created the entry.

## Testing

- Memory section renders in both empty (first-run copy) and populated states;
  widget test for the empty state.
- Reachability: a controller/widget test proving a seeded pattern surfaces on
  Pal Home after a refresh (the regression this fixes).
- Wipe confirm: tapping wipe shows the confirm step; confirming clears, cancelling
  does not.
- Confirmation card: golden or widget test for "−$5" formatting and entry-type
  badge color across money / move / rituals.
- `flutter analyze` clean; `flutter test` green.

## Risk

Theme A's reachability fix is the only item carrying investigation risk (root
cause not yet pinned). Themes B and C are mechanical. All three are
independently shippable, so the reachability fix can land separately if it proves
deeper than expected.
