# Pal-generated context-aware suggestions

**Date:** 2026-06-20
**Status:** Design — pending implementation plan

## Problem

Three places in the app show a hard-coded list of "quick-pick" chips the user
taps to act. The labels are static — the same six examples regardless of the
time of day, what the user has already logged, or their recent habits:

- **Pal composer starters** (`lib/screens/pal/pal_composer_screen.dart`,
  `_CompactBody._starters`): "Verve coffee, $5" / "Finished morning pages" /
  "How's my week so far?"
- **New Entry quick-picks** (`lib/screens/entry/new_entry_sheet.dart`,
  `_picks`): six presets — "Verve Coffee $5", "Lunch $14", "Run 30 min",
  "Walk 20 min", "Morning pages", "Read 20 min".
- **Routine Generator goals** (`lib/screens/workout/routine_generator_screen.dart`,
  `_goals`): six goal strings — "45-min push for strength", "Quick full-body, no
  barbell", etc.

All three are the same shape — a static suggestion list → tap to act — and all
three could be personalized from signals the app already has locally (today's
entries, goals, streaks, recent categories, time of day, recent workouts).

## Goal

Let Pal generate these chips, context-aware, behind **one reusable seam** reused
by all three surfaces. The change is **purely additive**: when Pal is reachable
its suggestions replace the static list; otherwise each surface falls back to its
existing hard-coded constants. No regression to logging, including offline.

Non-goals (deferred follow-ups): LLM-authored notification copy, composer hint
text, response streaming.

## Architecture

One new client seam method, one new server endpoint, reused by three surfaces.

### Client DTO

A single data-driven chip shape (modeled on `PalProposal` + `StarterEntry`),
added to `lib/services/pal/pal_service.dart`:

```dart
enum SuggestionSurface { composer, newEntry, routineGoal }

class PalSuggestion {
  const PalSuggestion({
    required this.label,
    required this.icon,
    required this.colorToken,
    this.entry,
  });

  final String label;        // display text AND the action text (chat msg / goal)
  final String icon;         // SF symbol; server-derived from a safe kind→icon map
  final String colorToken;   // 'money' | 'move' | 'rituals' | 'accent' (clamped)
  final StarterEntry? entry;  // optional structured payload (type/title/amount/category/minutes)

  // value equality (== / hashCode) over all four fields, matching the other DTOs
}
```

The optional `entry` reuses the existing `StarterEntry` type (it already carries
`type`, `title`, `amount`, `category`, `durationMinutes`). It is what lets a chip
log or prefill deterministically; surfaces that only need text (routine goals)
ignore it. `StarterEntry` moves from `pal_composer_controller.dart` into
`pal_service.dart` so the seam and all surfaces share one definition (single
source of truth); the controller re-exports / imports it.

### Seam method

Discriminated by surface, parameterized like `insights(InsightRange range)`:

```dart
Future<List<PalSuggestion>> suggestions(SuggestionSurface surface);
```

Added to the `PalService` interface and implemented in both `HttpPalService`
and `MockPalService`.

### Data flow (mirrors `/agenda`)

1. `HttpPalService.suggestions(surface)` builds the right context — the **chat**
   context for `composer`/`newEntry`, the **suggest** context for `routineGoal`
   — and calls `_cachedPost('suggestions:$surface', '/v1/suggestions', ctx)`,
   sending `{ surface, context }`.
2. The server LLM returns `{ suggestions: [...] }`. The model picks each item's
   `kind` + copy + optional `entry` fields; the **server derives the icon** from
   the kind via a safe map (so the model can never name a bad glyph), and zod
   `.catch`-clamps `colorToken` and `kind`.
3. The client decodes the wire into `List<PalSuggestion>`, dropping malformed
   items (newer-server-safe, exactly like `_actionFromWire`).

### Graceful degradation (the key safety property)

A new provider, mirroring `palAgenda`:

```dart
@riverpod
Future<List<PalSuggestion>> palSuggestions(Ref ref, SuggestionSurface surface) async {
  final pal = ref.watch(palServiceProvider);
  try {
    return await pal.suggestions(surface);
  } catch (_) {
    return const [];  // screen renders its own static fallback
  }
}
```

Each screen renders Pal's list when non-empty and its **existing hard-coded
constants** otherwise. Therefore offline / failure / loading all reproduce
today's exact behavior, including the offline-logging `entry` payloads on the
composer and New Entry chips. The feature is additive; logging is never at risk.

### Latency

Screens show their static defaults instantly on open, then swap to Pal's set
when the future resolves. With `PrefsPalCache` keyed by surface + serialized
context, repeat opens within a stable context hit the cache and feel instant. No
prefetch machinery (YAGNI).

## Surface adaptations

Each screen swaps its static list for `ref.watch(palSuggestionsProvider(surface))`,
falling back to the existing constant when the list is empty. The chip *widgets*
(`_StarterChip`, the New Entry quick-pick tile, `_QuickGoal` button) are
untouched — they receive `PalSuggestion`-derived values instead of hard-coded
ones. One small adapter per surface maps `PalSuggestion` to that surface's
existing tap call; no new tap paths.

| Surface | `surface` | Context | Chip maps to | Tap action (unchanged) |
|---|---|---|---|---|
| Composer starters | `composer` | chat | `label` → chat text; `entry` → offline fallback | `sendStarter(label, entry)` |
| New Entry quick-picks | `newEntry` | chat | `entry` → prefill keypad / title / category | local form prefill (no Pal call) |
| Routine Generator goals | `routineGoal` | suggest | `label` → goal string | `_runQuickGoal(label)` → `generateRoutine` |

All three target widgets are already `ConsumerStatefulWidget`s, so they have
`ref` available with no structural change.

## Server (`/v1/suggestions`)

Mirrors the `/agenda` implementation end to end.

- **`schemas.ts`** — `suggestionsBody = z.object({ surface: z.enum(['composer',
  'newEntry', 'routineGoal']), context: <chatContext | suggestContext> })`.
  Accept either context shape (a permissive union); the `surface` tells the
  handler which prompt to use.
- **`prompts.ts`** — `suggestionsPrompt(surface, ctx)` branches copy by surface:
  - `composer`: "propose 3 quick chips — a mix of one-tap **logs** and short
    **asks** — grounded in time-of-day, what is not yet logged today, recent
    categories, and budget pace." Log chips carry an `entry`; ask chips do not.
  - `newEntry`: "propose up to 6 concrete one-tap **log** presets (no questions —
    this surface has no chat), across money / move / rituals, grounded in the
    user's recent entries and time-of-day." Every chip carries an `entry`.
  - `routineGoal`: "propose up to 6 goal chips drawn from recent muscle groups
    and available equipment." Label only; no `entry`.
  - Requests strict JSON.
- **`pal.ts`** — `suggestionsModelSchema` with a `kind` enum mapped through a
  server-side `SUGGESTION_ICON` record (like `PROPOSAL_PRESENTATION`),
  `colorToken` clamped to the four accents, and an optional `entry` validated
  with the existing `posAmount` / `posInt` / `optStr` helpers. Uses
  `extractJson` + `schema.parse`, and the existing `response_format` strict-JSON
  request path. Off-list / malformed items are dropped.
- **Model** — the existing `PAL_MODEL` slug; a cheap/fast model is adequate for
  short chips.
- **`app.ts`** — `app.post('/v1/suggestions', guardTok(suggestionsBody, async (b)
  => deps.pal.suggestions(b.surface, b.context)))`, bearer-gated like the others.

## Time-of-day context (one supporting change)

`buildChatContext` does not currently include "now," but time-aware chips
("morning pages" at 8am vs a wind-down ritual at 9pm) need it. Add a single
time signal — `hourOfDay` (0–23) plus `weekday` — to the chat context map, and
thread it through the server's `chatContext` zod schema and `ChatContext` type.
Small, and it also quietly improves `/chat` and `/agenda` grounding.

## Caching

Reuse `_cachedPost` + `PrefsPalCache` unchanged. The cache key includes the
surface and the serialized context, so logging a new entry changes the context,
misses the cache, and refetches — the context-keying does the freshness work.
The default 30-day TTL is fine; no new cache code.

## Testing

Matches the existing `server/src/pal.test.ts` and controller-test style.

**Server**
- `suggestions` returns validated chips for each surface.
- An off-list `kind` coerces to the generic icon; an unknown `colorToken`
  clamps to `accent`.
- Malformed model JSON falls back tolerantly (no throw to the client).
- Off-list / malformed items are dropped from the list.

**Client**
- `HttpPalService.suggestions` decodes the wire into `PalSuggestion`s and drops
  malformed items.
- `palSuggestionsProvider` returns `[]` when the service throws `PalException`.
- `MockPalService.suggestions` returns canned per-surface chips (keeps the mock
  build and golden tests green).

**Surface behavior**
- Each screen renders Pal's list when present and **falls back to its static
  constants when the list is empty** (the regression guard).
- A tapped composer chip offline-logs via its `entry` payload when Pal is
  unreachable (unchanged behavior, now exercised through `PalSuggestion`).

## Files touched

- `lib/services/pal/pal_service.dart` — `PalSuggestion`, `SuggestionSurface`,
  `suggestions` on the interface; host the moved `StarterEntry`.
- `lib/services/pal/http_pal_service.dart` — `suggestions` impl + wire decode;
  add a `suggestions` context builder to `PalContextSource` (or reuse `chat` /
  `suggest`).
- `lib/services/pal/mock_pal_service.dart` — canned per-surface suggestions.
- `lib/services/pal/pal_context_builder.dart` — add `hourOfDay` + `weekday` to
  `buildChatContext`.
- `lib/controllers/` — `pal_suggestions_controller.dart` (the provider);
  `pal_composer_controller.dart` (import `StarterEntry` from the seam).
- `lib/screens/pal/pal_composer_screen.dart`,
  `lib/screens/entry/new_entry_sheet.dart`,
  `lib/screens/workout/routine_generator_screen.dart` — read the provider, keep
  constants as fallback, adapter to existing tap calls.
- `server/src/schemas.ts`, `server/src/prompts.ts`, `server/src/pal.ts`,
  `server/src/app.ts` — endpoint, prompt, schema, route.
- Tests alongside each.
