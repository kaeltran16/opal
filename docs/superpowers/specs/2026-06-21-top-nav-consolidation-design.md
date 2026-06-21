# Top Nav Consolidation — Design

Date: 2026-06-21
Status: Approved (design)

## Problem

The four tab-root screens (Today, Workout, Nutrition, Routines) all render their
header via the shared `LargeTitleScrollView`, but the **action slots diverge**:

| Tab | Leading | Trailing |
|-----|---------|----------|
| Today | Profile avatar → `/you` | Pal orb → `/pal`, inbox tray → `/pal` (duplicate target), search |
| Workout | — | `⋯` overflow menu (New routine / Generate with AI) |
| Nutrition | — | `+` add meal |
| Routines | — | `+` new routine |

Concrete inconsistencies:

1. **Profile** and **Pal** are reachable only from Today's header; the other
   three tabs have no path to them.
2. **Trailing semantics differ:** Workout uses an overflow menu; Nutrition and
   Routines use a single direct `+`.
3. **Redundancy:** Today's Pal orb and inbox tray both navigate to `/pal`
   (leftover from the recent Pal-hub merge).
4. **Subtitle tone is mixed:** date / tagline / status line / descriptor.

Confirmed independently in `design-audit/LIVE_UX_AUDIT.md` (item #9 search,
redundant Pal surfaces).

## Model

**Persistent global anchors + exactly one contextual action per tab.**

Every tab header has the same slots in the same positions; only the single
contextual action varies by tab.

## Decisions

### Layout (every tab)

```
[Profile avatar]                    [Pal orb] [contextual]
 Title
 status-line subtitle
```

- **Leading (left):** Profile avatar → `/you`.
- **Trailing (right):** Pal gradient orb → `/pal`, then the tab's single
  contextual action.

### Styling

Profile (avatar) and Pal (gradient orb) keep their distinct brand look; the
contextual action is a filled-circle `NavIconButton`. Consistency means the
same **slots in the same places**, not identical pixels — identity and the
assistant deliberately read differently from a one-off action.

### Contextual action per tab (single direct action each)

| Tab | Action | Icon | Target |
|-----|--------|------|--------|
| Today | Search (timeline filter) | `magnifyingglass` | existing `_openSearch` |
| Workout | New routine | `plus` | `AppRoute.routineEditor` |
| Nutrition | Add meal | `plus` | existing `showNutritionAddSheet` |
| Routines | New routine | `plus` | `/rituals/manage` |

### Moves / removals

- **Workout "Generate with AI"** leaves the header. The header `+` becomes the
  single direct action (New routine → routine editor). "Generate with AI"
  becomes a row in the Move body's existing quick-links section
  (`_QuickLinks`, next to My routines / Exercise library), routing to
  `AppRoute.routineGenerator`. The `_showMoveMenu` overflow sheet is deleted.
- **Today's inbox tray** (`tray.fill`) is removed — the Pal orb already opens
  `/pal`, which is the merged hub + inbox.

### Subtitles → live status line (one convention, all four)

Each tab's subtitle is a dynamic "where you are today" line drawn from data the
controller already computes for its hero (no new computation):

- **Today:** date (unchanged — `Wed, Jun 21`).
- **Workout:** this-week progress, e.g. `2 of 4 workouts this week`, from
  `MoveState` (already powers the `_WeekHero` "workouts-vs-goal" headline).
- **Nutrition:** today's intake status, from `NutritionState` (already powers
  the `_TodayHero`).
- **Routines:** `X of Y steps today` (unchanged).

Exact copy is finalized during implementation, but all four follow the
status-line convention.

## Architecture

### New shared component — `TabHeaderScrollView`

A thin wrapper around `LargeTitleScrollView`, living in `lib/widgets/nav_bar.dart`
(or a sibling), that is the **single source of truth** for the tab-header
pattern. It:

- Hard-codes the Profile leading (avatar → `/you`).
- Hard-codes the Pal-orb trailing anchor (→ `/pal`).
- Takes a single `contextualAction` widget (nullable) appended after the Pal orb.
- Takes `title`, `subtitle`, `children`, `padding` and delegates to
  `LargeTitleScrollView`.

```
TabHeaderScrollView(
  title: 'Nutrition',
  subtitle: state.statusLine,
  contextualAction: NavIconButton(name: 'plus', ... onTap: addMeal),
  children: [...],
)
```

The four tab roots adopt it. **Pushed / secondary screens** (profile, recap,
insights, budgets, email dashboard, workout detail, nutrition sub-screens,
start workout, routine generator) keep using `LargeTitleScrollView` directly —
they must NOT inherit the profile/Pal anchors, so the anchors are deliberately
not baked into `LargeTitleScrollView` itself.

### Why a wrapper (not extending `LargeTitleScrollView`)

`LargeTitleScrollView` has ~15 call sites, most of them pushed screens that
need their own back/leading action and no global anchors. Baking anchors into
it would be wrong for those screens. A dedicated wrapper used only by the four
tab roots keeps the anchors in one place without polluting the general header.

## Scope guard

Only the following change:

- New `TabHeaderScrollView` widget.
- The four tab-root screens (`today_screen.dart`, `move_screen.dart`,
  `nutrition_screen.dart`, `rituals_screen.dart`) adopt it and pass their one
  contextual action + status-line subtitle.
- Move body gains a "Generate with AI" quick-links row; `_showMoveMenu` removed.
- Today loses its inbox-tray button.

No router changes. No changes to pushed/secondary screens. Subtitles are a copy
pass over existing controller data — no new state wiring beyond reading fields
the controllers already expose.

## Testing

- Widget test: each tab root renders Profile + Pal orb + exactly one contextual
  action in the header.
- Widget test: Today no longer renders the inbox-tray button.
- Widget test: Workout header has no overflow `⋯`; "Generate with AI" is
  reachable from the Move body and routes to the routine generator.
- Existing tab navigation / screen-render tests continue to pass.
