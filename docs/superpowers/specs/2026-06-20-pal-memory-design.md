# Design: Persistent Pal memory

- **Date:** 2026-06-20
- **Status:** approved (design), pending implementation plan
- **Scope:** Server (new store, tools, endpoints, prompt injection) + Dart (Pal Home memory section, refresh cadence, mock service). No native changes.

## Problem

Pal already touches the LLM in nine places, but every surface is stateless: each
prompt hand-rebuilds context from today/week aggregates and has **no continuity**
with prior conversations or prior reflections. The clearest tell is the agenda —
`agendaPrompt` asks the model for a `memory` array ("up to 4 durable patterns
you've learned about them … 'Learned over 6 weeks'"), but there is no store behind
it: the model **invents those patterns fresh every request**. The UI promises a Pal
that remembers; the architecture has a Pal that re-guesses.

This adds one component — a persistent memory layer — that makes the existing
surfaces better at once, rather than adding a tenth one-off generation surface.

## Decision

Build a **server-side, per-device memory layer** holding two kinds of memory, with
separate write paths, injected as a compact digest into the surfaces that benefit.

Decisions taken during brainstorming:

- **Location:** server-side, keyed by device token (reuses the existing
  `TokenStore` device-token model). Chosen over device-local; accepts that the
  server becomes custodian of behavioral data, so the design includes a
  user-facing delete path and token-revoke teardown.
- **Contents (scoped tight):** (1) **explicit facts** the user states, and
  (2) **learned patterns** derived over time. Conversation-continuity and
  action-history memory are explicitly **out of scope**.
- **Write paths split by type:** facts captured inline in chat via a `remember`
  tool-call; patterns rewritten by a dedicated `POST /v1/memory/refresh` endpoint.
- **Capture is silent but fully visible** and deletable in the Pal Home memory
  section.
- **No auto-expiry** — capacity caps + full-rewrite keep memory bounded instead.

## Data model

New `MemoryStore` (SQLite), alongside `TokenStore`. May share the same DB file.

```
pal_facts(
  id          TEXT PRIMARY KEY,   -- short stable id, e.g. f-<rowid/uuid>
  token       TEXT NOT NULL,      -- device token (FK to device_tokens)
  text        TEXT NOT NULL,      -- one short fact
  created_at  INTEGER NOT NULL
)

pal_patterns(
  token       TEXT PRIMARY KEY,   -- one row per device
  json        TEXT NOT NULL,      -- validated pattern set, full-rewritten
  updated_at  INTEGER NOT NULL
)
```

- **Facts** cap at **20**. On overflow, drop the oldest. The `id` is short and
  stable so it can be injected into the chat prompt and addressed by `forget`.
- **Patterns** cap at **5**, stored as one JSON blob per device, **fully
  rewritten** each refresh (no per-pattern edit). Pattern shape reuses the
  insights shape: `{ colorToken: 'money'|'move'|'rituals', title: string, detail: string }`.

### Digest

The unit assembled, injected, and returned:

```ts
interface MemoryDigest {
  facts: Array<{ id: string; text: string }>
  patterns: Array<{ colorToken: string; title: string; detail: string }>
}
```

## Write paths

### Facts — inline in chat (`remember` / `forget` tools)

Add two tools to `CHAT_TOOLS`:

- `remember(fact: string)` — persist a durable fact.
- `forget(id: string)` — drop a fact by its injected id.

**Critical distinction from existing tools.** `log_expense` et al. return
`PalAction`s the *client* applies to on-device state. `remember`/`forget` mutate
*server* state and are applied **immediately, server-side**; they are **not**
returned as client actions. So `Pal.chat` splits the model's tool calls:

- memory tools → applied to `MemoryStore` for this token, in-handler;
- entry/goal tools → parsed to `PalAction`s and returned, exactly as today.

Facts are injected into the chat system prompt **with their ids** so `forget` is
precise, e.g. `[f3] training for a marathon in October`. A correction is the model
calling `forget(f3)` then `remember(...)` in the same turn.

### Patterns — `POST /v1/memory/refresh`

The client posts the aggregates + entries it already assembles for insights
(an `InsightsContext`-shaped payload). The server:

1. loads current facts + current patterns as **prior context**;
2. runs a pattern-extraction prompt framed as *"here is what we knew; revise it
   against this new data"* (so it does not echo itself);
3. validates the result with zod (≤5, same discipline as `insightsPrompt`);
4. **full-rewrites** `pal_patterns` for the token;
5. returns the updated `MemoryDigest`.

Triggered on a **client-chosen cadence**; the natural spot is when the weekly Recap
is generated (the data is already loaded there).

## Consumption

A single helper renders a compact `memoryBlock(digest)` text block, prepended to
the prompts that benefit. Each prompt fn takes an **optional** memory argument and
includes the block only when non-empty.

| Surface | Inject? | Note |
|---|---|---|
| Chat | Yes | Facts injected with ids (for `forget`) + patterns |
| Agenda | Yes | See cleanup below |
| Insights | Yes | Patterns as prior context |
| Recap / Review | Yes | Continuity across periods |
| Generate routine | Yes | Facts shape the plan (e.g. "marathon", "bad knee") |
| Suggest workout | No (fast-follow) | Marginal; revisit if useful |
| Parse | **No** | Deterministic extraction at temp 0 — memory is noise |
| Post-workout note | **No** | Self-contained on the session numbers |
| Receipts | **No** | Untrusted email input — never mix in personal memory |

**Cleanup folded in (correctness fix, not just addition):** remove the fabricated
`memory` array from `agendaModelSchema` and `agendaPrompt`. The model stops
inventing memory; `AgendaResult.memory` is populated from the store via the digest.

**Circularity guard:** patterns are derived *from* the same data Insights/Recap
reflect on, so the prompt contract frames injected patterns as prior knowledge
("what we've learned previously"), never as fresh observations to restate.

## API surface

- `POST /v1/chat` — unchanged contract; now injects the digest and applies memory
  tools server-side.
- `GET /v1/memory` — current digest, for Pal Home.
- `POST /v1/memory/refresh` — runs pattern extraction, returns updated digest.
- `DELETE /v1/memory/facts/:id` — delete one fact.
- `DELETE /v1/memory` — wipe all memory for the token.

Token revoke / account deletion drops the device's facts + patterns rows.

## App changes (Dart)

- Repoint the existing **Pal Home memory section** from the agenda's (now removed)
  fake array to `GET /v1/memory`; add per-item delete and wipe-all.
- Call `POST /v1/memory/refresh` on the chosen cadence — when the weekly Recap is
  generated.
- `mock_pal_service.dart` gains memory support (digest, remember/forget, refresh)
  for offline use and tests.

## Error handling

- Memory writes are **best-effort**: a failed `remember`/`forget` logs but never
  fails the chat reply.
- Digest read failure → inject empty memory; the call proceeds (Pal simply does not
  recall this turn). **Memory never blocks a user-facing call.**
- `/v1/memory/refresh` extraction failure → 502, mapped like other LLM calls; the
  client keeps showing last-known patterns.
- Invalid/missing token → 401, as existing auth.

## Privacy / lifecycle

- Facts cap 20 (drop oldest); patterns cap 5 (full rewrite). No auto-expiry.
- User-facing controls in Pal Home: view, per-item fact delete, wipe-all.
- Dropped on device-token revoke / account deletion.

## Testing

- **`MemoryStore`:** add / forget / cap-overflow / wipe; pattern full-rewrite;
  per-token isolation.
- **`pal.test.ts`:** chat splits memory tools from action tools; memory tools hit
  the store and are absent from returned actions; digest injected into the prompt;
  refresh validates + rewrites.
- **`prompts.test.ts`:** memory block renders when present, omitted when empty,
  and is absent from parse / post-workout / receipts prompts.
- **Dart:** mock service memory behavior; Pal Home renders facts + patterns and
  deletes per-item / wipes all.

## Out of scope

- Conversation-continuity memory (rolling chat summaries).
- Action-history memory (approved/declined proposals).
- Cross-device sync of memory (it is per device token).
- Injecting memory into Parse, Post-workout, Receipts.
