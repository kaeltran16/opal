# Design: Merge Ask Pal into the unified Pal composer sheet

- **Date:** 2026-06-15
- **Status:** approved (design), pending implementation plan
- **Scope:** Dart-only; no schema, native, or backend changes.

## Problem

Three Pal surfaces exist, two of which overlap:

| Surface | Entry | Role |
|---|---|---|
| Composer (`pal_composer_screen.dart`, 678 ln) | FAB, Today card/stat | Quick NL input, auto-applies actions |
| Ask Pal (`ask_pal_screen.dart`, 566 ln) | detail-screen pill, `/pal` | Conversation, auto-applies **with undo** |
| Inbox (`pal_inbox_screen.dart`, 448 ln) | Today bell | Proactive "Pal noticed" notices |

Composer and Ask Pal are near-identical chat view models: both hold a `messages`
transcript + `isLoading`, both call `palService.chat(history, message)`, both call
`applyPalActions(ref, result.actions)`. Two user→Pal input surfaces with no
signposting between them; Ask Pal's input hint even advertises "or log something"
(the Composer's whole job). The Live UX audit (2026-06-15) flagged the overlap.

The Inbox is genuinely distinct (proactive, not input) and stays untouched.

## Decision

Collapse Composer + Ask Pal into **one** conversational surface: the composer's
expanding bottom sheet (FAB presentation), which gains Ask Pal's per-message undo.

Decisions taken during brainstorming:
- **Presentation:** composer's expanding bottom-sheet-over-dim-barrier. Retire the
  full-page `/pal` route.
- **Undo:** adopt Ask Pal's per-message undo into the unified surface. Side effect:
  closes the deferred audit item "composer auto-applies mutations with no undo".

## What survives / what's deleted

**Survives** — `PalComposerController` + `PalComposerSheet`. It is the superset
(seed param, `expanded` state, `sendStarter` offline local-log fallback).

**Deleted**
- `lib/screens/pal/ask_pal_screen.dart`
- `lib/controllers/ask_pal_controller.dart` (+ generated `ask_pal_controller.g.dart`)
- `askPal` route: `router.dart:79` (enum), `router.dart:293–297` (GoRoute), and the
  `AskPalScreen` import
- `'/pal'` entry in the overlay-route set, `app.dart:98`
- Dead empty dir `lib/screens/money/` (unrelated cleanup, folded in — referenced nowhere)

## Controller change — `pal_composer_controller.dart`

Port the undo mechanism from `AskPalController`:
- Add `final Map<int, AppliedActions> _undo = {};`.
- In `_reply`, capture the (currently discarded) return value of `applyPalActions`
  and record it against the assistant message index: `if (!applied.isEmpty) _undo[index] = applied;`.
- Add the `undo(int index)` method verbatim from Ask Pal: delete created entries
  (`entryRepository.deleteById`) and routines (`routineRepository.deleteById`),
  restore `priorGoals` if present, mark the message `undone: true`.

This is the only behavioral addition. All existing composer behavior (seed, expanded,
`sendStarter`, offline confirmation) is preserved unchanged.

## UI change — `pal_composer_screen.dart`

Wire each assistant bubble's `onUndo` to `controller.undo(i)`, matching
`ask_pal_screen.dart:100`. If the composer's bubble does not already render the undo
affordance, port that rendering from Ask Pal's `_Bubble` (reads `message.actions` /
`message.undone`). No new state model — `PalMessage` already carries `actions` and
`undone`.

## Entry-point rewiring

- `detail_screen.dart:663` — `_AskPalPill.onTap` → `pushNamed(AppRoute.palComposer.name)`
  instead of `askPal`. **Preserves current behavior:** this pill today opens a *blank*
  chat (it never seeded the prompt), so it stays un-seeded to the compact greeting. The
  pill label ("Ask Pal about …") is unchanged. (Seeding it is a possible future
  enhancement, explicitly out of scope here.)
- FAB (`loop_shell.dart:38`), Today Spent stat (`today_screen.dart:224`), Today "Pal
  noticed" card (`today_screen.dart:781`) already route to `palComposer` — unchanged.

## Testing

- Delete `test/ask_pal_test.dart` and `test/ask_pal_controller_test.dart`.
- Port undo coverage into the composer controller test (`test/controllers/pal_composer_controller_test.dart`
  — create if absent, else extend):
  - an action-bearing turn records an undo entry;
  - `undo()` deletes the created entries/routines, restores prior goals, marks the
    message `undone`;
  - a non-action turn records nothing.
- Existing composer/FAB tests (`test/quick_actions_test.dart`) must stay green
  (legacy-named; actually exercises FAB→composer).
- Gate: `flutter analyze` clean, `flutter test` all pass.

## Risk / reversibility

Low. Removes ~700 lines and one route; the surviving surface is a strict superset of
the deleted one. No data-layer, schema, native, or backend changes. Fully reversible
via git.
