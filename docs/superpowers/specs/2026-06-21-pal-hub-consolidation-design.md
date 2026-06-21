# Pal hub consolidation — merge Home + Inbox into one destination

Date: 2026-06-21
Status: Approved design, ready for implementation planning

## Problem

Pal lives behind three doors with overlapping purposes (UX audit 2026-06-20, IA finding):

- **Pal Composer** (`/pal-composer`) — natural-language input + chat. A bottom sheet off
  the FAB. Reached from 6+ places. This one is fine: it's a transient *input* surface.
- **Pal Home** (`/pal-home`) — agentic dashboard: daily brief + streak, "Needs you"
  proposals (approve), "On autopilot" (toggles), "What Pal remembers" (memory). Reached
  from the Today orb and the You-tab "Pal" row.
- **Pal Inbox** (`/pal-inbox`) — passive observation feed: read-only notices, filterable
  by tracker, mark-all-read. Reached from the Today tray icon only.

Home and Inbox are both "lists of things Pal surfaced," split across two screens reached
two different ways. "Needs you" (decide) and Inbox observations (FYI) are two *item types*
of one mental model — "what does Pal have for me?" — but the user must learn two doors and
remember which holds what. That split is the actual confusion.

## Goal

One **Pal hub** destination that answers "what does Pal have for me, and what's it doing?"
in a single screen, with the conversational Composer kept separate.

Mental model: **Pal hub = act + review; Composer = talk.**

## Non-goals

- No change to the Composer (`/pal-composer`) — input/chat stays as-is.
- No data-layer rewrite: the agenda (remote) and inbox-notes (local) stores stay separate
  (see "Compose, not fuse" below).
- No new bottom tab — Pal stays a pushed destination (decided).
- No change to proposal-approval / autopilot-toggle / memory backend seams.

## Decisions (locked)

1. **Two surfaces, not one or three** — merge Home + Inbox into one hub; keep Composer.
2. **Pushed destination, not a 5th tab** — the 4 tabs are life dimensions; the center FAB
   is already Pal-composer. A Pal tab would compete and crowd.
3. **Redirect then remove** — `/pal-home` and `/pal-inbox` redirect to `/pal`; their screen
   files fold into the new `PalScreen` and are deleted.
4. **Compose, not fuse** — `PalScreen` reads both existing controllers as distinct regions;
   no merge of the two data sources into one list/stream.

## Why "compose, not fuse" (the key constraint)

The two surfaces have fundamentally different data lifecycles:

| | Inbox notes (`PalNote`) | Agenda (`PalAgenda`) |
|---|---|---|
| Source | local `palNoteRepository` | remote `/agenda` seam |
| Shape | reactive `watchNotes()` stream | one-shot `Future` (`palAgendaProvider`) |
| State | per-item unread + mark-read | ephemeral; proposals approved via backend |
| Offline | always available | degrades to empty `PalAgenda()` |

Fusing them into a single feed would force a remote one-shot fetch and a local reactive
stream with read-state into one list — invasive and fragile, for no user-visible gain. The
hub instead *composes* `palAgendaProvider` (top regions) and `palInboxControllerProvider`
(bottom region) on one screen. Each keeps its own loading/error/empty behavior.

## Architecture

New `lib/screens/pal/pal_screen.dart` → `PalScreen`, route `/pal` (`AppRoute.pal`), pushed
above the shell (same presentation as the current Pal screens).

`PalScreen` watches:
- `palAgendaProvider` (`AsyncValue<PalAgenda>`) → hero, Needs you, On autopilot.
- `palInboxControllerProvider` (`AsyncValue<PalInboxState>`) → the observation feed, filter
  pills, mark-all-read.
- memory provider (existing, as Pal Home uses today) → "What Pal remembers".

The two formerly-separate screens' widgets move into `PalScreen` as private section widgets.
Controllers (`palAgendaProvider`, `PalInboxController`, memory) are unchanged.

## Screen layout (top → bottom)

1. **Nav bar** — title "Pal", leading "Today" back (matches existing Pal Home nav).
2. **Hero** — daily brief + workout streak (agenda). Refresh action retained.
3. **Needs you** — proposal cards with approve/decline (agenda). Hidden when empty.
4. **On autopilot** — delegation list with toggles (agenda). Hidden when empty.
5. **What Pal noticed** — observation feed: existing filter pills
   (All / Unread / Money / Move / Rituals) + mark-all-read + note rows (inbox stream).
   Empty → "A quiet Pal is a happy Pal."
6. **What Pal remembers** — memory facts + patterns, clearable (as today).
7. **Ask Pal anything** CTA → `/pal-composer` (kept).

Proposals (have approve buttons) and observations (read-only, unread dots) are visually
distinct regions, so "decide vs FYI" is legible without two screens.

## Routes & entry points

- Add `AppRoute.pal` → `/pal` → `PalScreen` (pushed via root navigator, like the current
  Pal routes).
- `/pal-home` and `/pal-inbox` → `redirect` to `/pal` (mirrors the existing
  `/weekly-review`→`/recap` and `/monthly-review`→`/recap` redirects in `router.dart`).
- Update entry points to push `AppRoute.pal`:
  - Today orb — `today_screen.dart` (currently → `palHome`).
  - Today tray icon — `today_screen.dart` (currently → `palInbox`). Unread count preserved;
    opening lands on the hub (observation region visible).
  - You-tab "Pal" row — `profile_screen.dart:273` (currently → `palHome`).
  - Any composer/inbox cross-links that targeted `palHome`/`palInbox` (audit found Pal Home
    "Ask Pal" CTA and Inbox action pills → composer; those stay pointing at composer).
- Delete `lib/screens/pal/pal_home_screen.dart` and `lib/screens/pal/pal_inbox_screen.dart`
  after their content lands in `PalScreen`.
- Remove the now-unused `AppRoute.palHome` / `AppRoute.palInbox` enum + GoRoute builders,
  *or* keep the enum values solely as redirect targets — decide in planning (redirects need
  a path to match; the enum names can go).

## Data flow

- Hub open → `palAgendaProvider` fires one-shot fetch (cached until invalidated); inbox
  stream is already live app-wide. No new fetch cadence.
- Approve proposal / toggle autopilot → existing action paths
  (`pal_action_executor` / agenda actions), unchanged.
- Note mark-read / mark-all-read → `PalInboxController`, unchanged.
- Tray unread badge on Today reads the same `palInboxController.unreadCount` it does now.

## Error / empty handling

- Agenda fetch fails/offline → empty `PalAgenda` → Needs you / On autopilot hidden; the
  observation feed (local) still renders. The hub never errors wholesale.
- Inbox empty → quiet empty state in its region.
- Both empty → hero + memory + Ask Pal CTA still present (never a blank screen).

## Testing

- Widget test: `PalScreen` renders agenda regions + observation feed from seeded providers;
  empty agenda hides Needs you / On autopilot but still shows the feed.
- Redirect test: navigating to `/pal-home` and `/pal-inbox` lands on `PalScreen`.
- Entry-point test (extend `pal_home_test.dart`): Today orb / tray / You "Pal" row open
  `/pal`.
- Preserve the existing inbox filter + mark-read behavior tests against the feed region.
- Tray unread badge still reflects `unreadCount`.

## Risks / watch-items

- `pal_home_screen.dart` is ~40KB; folding it in must preserve the proposal-approval and
  memory-clear flows exactly. Move widgets wholesale rather than reimplement.
- Two `AsyncValue`s on one screen → handle their loading states independently (don't gate
  the whole screen on the slower remote agenda).
- Deep links / notifications that target `palInbox` (e.g. a routine reminder tap) must route
  to `/pal` — audit during planning.
